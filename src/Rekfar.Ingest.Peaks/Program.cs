using System.Text.Json;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Rekfar.Ingest.Peaks;
using Rekfar.Ingest.Peaks.Database;
using Rekfar.Ingest.Peaks.Ssr;

// The Kartverket peak import (ADR-0015, ADR-0016).
//
// A console job: started by a schedule, one pass, then an exit code the workflow reads.
// The stages land here one at a time. Today it reads the SSR extract and stages it; what
// follows is sampling elevations, applying the peak rule, and merging into ref.Peak.

const int ExitSuccess = 0;
const int ExitFailure = 1;
const int ExitMisconfigured = 2;

var builder = Host.CreateApplicationBuilder(args);

// One JSON object per line. A scheduled job's output is read by a machine first and a
// human second, and the run's identifier has to travel with every line it emits for either
// of them to be able to follow it (ADR-0010 T10).
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(options =>
{
    options.IncludeScopes = true;
    options.UseUtcTimestamp = true;
    options.TimestampFormat = "yyyy-MM-dd'T'HH:mm:ss.fff'Z'";
    options.JsonWriterOptions = new JsonWriterOptions { Indented = false };
});

using var host = builder.Build();

var loggerFactory = host.Services.GetRequiredService<ILoggerFactory>();
var logger = loggerFactory.CreateLogger("Rekfar.Ingest.Peaks");

// Ctrl+C and the runner's SIGTERM both mean "stop cleanly", which for this job means
// closing the run record on the way out rather than abandoning it as `running`.
using var cancellation = new CancellationTokenSource();
Console.CancelKeyPress += (_, eventArgs) =>
{
    eventArgs.Cancel = true;
    logger.LogWarning("Cancellation requested; finishing the current step and closing the run.");
    cancellation.Cancel();
};

var connectionString = builder.Configuration.GetConnectionString("Rekfar");
if (string.IsNullOrWhiteSpace(connectionString))
{
    // Never a configuration file in this repository: the connection string names a server
    // and carries credentials or an auth mode, and neither belongs in version control.
    logger.LogCritical(
        "No connection string. Set ConnectionStrings__Rekfar in the environment — see src/Rekfar.Ingest.Peaks/README.md.");
    return ExitMisconfigured;
}

var options = new IngestionOptions
{
    ExtractPath = builder.Configuration["Ingestion:ExtractPath"],
    NavneobjektTypes = builder.Configuration["Ingestion:NavneobjektTypes"] ?? new IngestionOptions().NavneobjektTypes,
};

var extractPath = options.ExtractPath;
if (string.IsNullOrWhiteSpace(extractPath))
{
    // Until the download stage lands, the extract is supplied rather than fetched.
    logger.LogCritical(
        "No extract. Set Ingestion__ExtractPath to a Kartverket SSR .zip or .gml — see src/Rekfar.Ingest.Peaks/README.md.");
    return ExitMisconfigured;
}

if (!File.Exists(extractPath))
{
    logger.LogCritical("The extract {ExtractPath} does not exist.", extractPath);
    return ExitMisconfigured;
}

try
{
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync(cancellation.Token).ConfigureAwait(false);

    await SchemaPreflight.AssertAsync(connection, logger, cancellation.Token).ConfigureAwait(false);

    await using var run = await IngestRun
        .OpenAsync(connection, SourceDataset.Ssr, loggerFactory, cancellation.Token)
        .ConfigureAwait(false);

    // A format-string scope rather than a dictionary: both carry RunId as a structured
    // property, but this one also renders as "run 42" instead of the dictionary's type name.
    using var runScope = logger.BeginScope("run {RunId}", run.Id);

    try
    {
        // Remaining stages, in the order set out in the import plan: sample elevations, apply
        // the peak rule, merge into ref.Peak, resolve areas.
        using var extract = SsrExtractFile.Open(extractPath);
        logger.LogInformation("Reading {Extract}.", extract.Name);

        var reader = new SsrGmlReader(options.ParseNavneobjektTypes());
        var writer = new SsrStagingWriter(loggerFactory.CreateLogger<SsrStagingWriter>());

        var staged = await writer
            .WriteAsync(connection, run.Id, reader.ReadAsync(extract.Content, cancellation.Token), cancellation.Token)
            .ConfigureAwait(false);

        // The snapshot's identity, not the run's: which specification was parsed and which
        // extract of it. Both come from the file, so neither can drift from what was read.
        run.SourceVersion = $"{reader.ProductSpecVersion} @ {reader.ExtractedAt:yyyy-MM-dd'T'HH:mm:ss'Z'}";

        // RowsRead is what was staged. Inserted, updated and retired describe changes to the
        // catalogue itself and stay zero until the merge stage exists.
        run.Counts.Read = staged.Places;

        if (reader.PlacesWithoutGeometry > 0)
        {
            logger.LogWarning(
                "{Count} staged places carry no representation point and cannot be given an elevation.",
                reader.PlacesWithoutGeometry);
        }

        var scopeNote = staged.SkippedOutOfScope > 0
            ? $" Skipped {staged.SkippedOutOfScope} outside mainland Norway."
            : string.Empty;

        await run.SucceedAsync(
            $"Staged {staged.Places} places and {staged.Points} points from {reader.FeaturesRead} features.{scopeNote}")
            .ConfigureAwait(false);
    }
    catch (Exception ex)
    {
        // Recorded here, where the run is, and rethrown so the outer handler decides the
        // exit code. Disposal would also close the run, but with a far vaguer message.
        await run.FailAsync(ex).ConfigureAwait(false);
        throw;
    }

    return ExitSuccess;
}
catch (OperationCanceledException)
{
    logger.LogWarning("Ingestion was cancelled.");
    return ExitFailure;
}
catch (Exception ex)
{
    logger.LogCritical(ex, "Ingestion failed.");
    return ExitFailure;
}
