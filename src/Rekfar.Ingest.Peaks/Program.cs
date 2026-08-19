using System.Text.Json;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Rekfar.Ingest.Peaks.Database;

// The Kartverket peak import (ADR-0015, ADR-0016).
//
// A console job: started by a schedule, one pass, then an exit code the workflow reads.
// The ingestion stages themselves land here one at a time; what exists today is the frame
// they hang on — configuration, structured logging, the run record, and a preflight check
// that the target database is the one this build was compiled against.

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
        // Stages land here, in the order set out in the import plan: download, parse and
        // stage, sample elevations, apply the peak rule, merge, resolve areas.
        logger.LogWarning("No ingestion stages are implemented yet — this run is a no-op.");

        await run.SucceedAsync("Skeleton run: no stages implemented.").ConfigureAwait(false);
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
