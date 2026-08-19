using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace Rekfar.Ingest.Peaks.Database;

/// <summary>
/// One row in <c>ingest.Run</c>, from <c>running</c> to a terminal status.
/// </summary>
/// <remarks>
/// <para>
/// This is the record that answers "when was the peak catalogue last refreshed, from which
/// upstream version, and did it work?". Its row counts are also the cheapest available
/// signal that an upstream schema or distribution change has broken parsing — a run that
/// succeeds while reading a fraction of the usual rows.
/// </para>
/// <para>
/// A run must always reach a terminal status, or the record lies by omission. Disposing an
/// open run therefore fails it rather than leaving it <c>running</c> forever, which covers
/// the paths a <c>catch</c> block does not: an early <c>return</c>, or a cancellation.
/// </para>
/// </remarks>
internal sealed class IngestRun : IAsyncDisposable
{
    /// <summary>Matches <c>[Message] nvarchar(2000)</c>; a longer message is truncated rather than rejected.</summary>
    private const int MessageMaxLength = 2000;

    private readonly SqlConnection _connection;
    private readonly ILogger<IngestRun> _logger;
    private bool _closed;

    private IngestRun(SqlConnection connection, ILogger<IngestRun> logger, long id, short sourceDatasetId)
    {
        _connection = connection;
        _logger = logger;
        Id = id;
        SourceDatasetId = sourceDatasetId;
    }

    public long Id { get; }

    public short SourceDatasetId { get; }

    /// <summary>
    /// Whatever identifies the upstream snapshot that was read — for SSR, the extract's own
    /// <c>datauttaksdato</c>. Set by the stage that reads it.
    /// </summary>
    public string? SourceVersion { get; set; }

    /// <summary>Row counts, filled in by the stages as they go.</summary>
    public IngestRunCounts Counts { get; } = new();

    /// <summary>
    /// Opens a run and returns it. Warns about any run for the same dataset that is still
    /// <c>running</c>: that is either a concurrent job or the remains of a crashed one, and
    /// both are worth knowing about. It deliberately does not clean them up — what the right
    /// policy is depends on how often it actually happens, which nobody knows yet.
    /// </summary>
    public static async Task<IngestRun> OpenAsync(
        SqlConnection connection,
        short sourceDatasetId,
        ILoggerFactory loggerFactory,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentNullException.ThrowIfNull(loggerFactory);

        var logger = loggerFactory.CreateLogger<IngestRun>();

        await WarnAboutOpenRunsAsync(connection, sourceDatasetId, logger, cancellationToken).ConfigureAwait(false);

        const string sql = """
            INSERT INTO ingest.[Run] (SourceDatasetId)
            OUTPUT INSERTED.Id
            VALUES (@SourceDatasetId);
            """;

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@SourceDatasetId", System.Data.SqlDbType.SmallInt).Value = sourceDatasetId;

        var id = (long)(await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false))!;

        logger.LogInformation(
            "Ingestion run {RunId} opened for dataset {SourceDatasetId}.", id, sourceDatasetId);

        return new IngestRun(connection, logger, id, sourceDatasetId);
    }

    /// <summary>Closes the run as <c>succeeded</c>, recording the counts and source version.</summary>
    /// <remarks>
    /// Takes no cancellation token, and none of the close path does. A run that is being
    /// cancelled still has to record that it was — a token here would let the one write that
    /// must happen be the one that gets skipped.
    /// </remarks>
    public Task SucceedAsync(string? message)
        => CloseAsync("succeeded", message);

    /// <summary>
    /// Closes the run as <c>failed</c>, recording the exception. The message is what somebody
    /// reads months later without the logs to hand, so it carries the type as well as the text.
    /// </summary>
    public Task FailAsync(Exception exception)
    {
        ArgumentNullException.ThrowIfNull(exception);
        return CloseAsync("failed", $"{exception.GetType().Name}: {exception.Message}");
    }

    private async Task CloseAsync(string status, string? message)
    {
        if (_closed)
        {
            return;
        }

        // The status filter makes closing idempotent at the database as well as in memory,
        // so a second attempt cannot overwrite the first outcome with a worse one.
        const string sql = """
            UPDATE ingest.[Run]
            SET [Status]        = @Status,
                CompletedAt     = SYSUTCDATETIME(),
                SourceVersion   = @SourceVersion,
                RowsRead        = @RowsRead,
                RowsInserted    = @RowsInserted,
                RowsUpdated     = @RowsUpdated,
                RowsRetired     = @RowsRetired,
                [Message]       = @Message
            WHERE Id = @Id AND [Status] = 'running';
            """;

        await using var command = new SqlCommand(sql, _connection);
        command.Parameters.Add("@Status", System.Data.SqlDbType.VarChar, 16).Value = status;
        command.Parameters.Add("@SourceVersion", System.Data.SqlDbType.NVarChar, 80).Value = (object?)SourceVersion ?? DBNull.Value;
        command.Parameters.Add("@RowsRead", System.Data.SqlDbType.Int).Value = Counts.Read;
        command.Parameters.Add("@RowsInserted", System.Data.SqlDbType.Int).Value = Counts.Inserted;
        command.Parameters.Add("@RowsUpdated", System.Data.SqlDbType.Int).Value = Counts.Updated;
        command.Parameters.Add("@RowsRetired", System.Data.SqlDbType.Int).Value = Counts.Retired;
        command.Parameters.Add("@Message", System.Data.SqlDbType.NVarChar, MessageMaxLength).Value = (object?)Truncate(message) ?? DBNull.Value;
        command.Parameters.Add("@Id", System.Data.SqlDbType.BigInt).Value = Id;

        var rows = await command.ExecuteNonQueryAsync(CancellationToken.None).ConfigureAwait(false);
        _closed = true;

        if (rows == 0)
        {
            _logger.LogWarning(
                "Ingestion run {RunId} was already closed by somebody else; status {Status} not recorded.", Id, status);
            return;
        }

        _logger.LogInformation(
            "Ingestion run {RunId} closed as {Status}. Read {RowsRead}, inserted {RowsInserted}, updated {RowsUpdated}, retired {RowsRetired}. Source version {SourceVersion}.",
            Id, status, Counts.Read, Counts.Inserted, Counts.Updated, Counts.Retired, SourceVersion ?? "(none)");
    }

    private static async Task WarnAboutOpenRunsAsync(
        SqlConnection connection,
        short sourceDatasetId,
        ILogger logger,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT Id, StartedAt
            FROM ingest.[Run]
            WHERE SourceDatasetId = @SourceDatasetId AND [Status] = 'running'
            ORDER BY StartedAt;
            """;

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@SourceDatasetId", System.Data.SqlDbType.SmallInt).Value = sourceDatasetId;

        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            logger.LogWarning(
                "Run {RunId} for dataset {SourceDatasetId} has been running since {StartedAt:O}. It is either a concurrent job or a crashed one — see docs/operations.md.",
                reader.GetInt64(0), sourceDatasetId, reader.GetDateTime(1));
        }
    }

    private static string? Truncate(string? message)
        => message is { Length: > MessageMaxLength } ? message[..MessageMaxLength] : message;

    /// <summary>
    /// Fails an unclosed run. Covers the paths an explicit <c>catch</c> misses — an early
    /// return, or a cancellation that unwinds past it.
    /// </summary>
    public async ValueTask DisposeAsync()
    {
        if (_closed)
        {
            return;
        }

        await CloseAsync("failed", "The run ended without recording an outcome.").ConfigureAwait(false);
    }
}

/// <summary>Mutable row counts for a run, matching the columns on <c>ingest.Run</c>.</summary>
internal sealed class IngestRunCounts
{
    public int Read { get; set; }

    public int Inserted { get; set; }

    public int Updated { get; set; }

    public int Retired { get; set; }
}
