using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace Rekfar.Ingest.Peaks.Database;

/// <summary>
/// Applies the peak rule to a staged snapshot and merges the result into <c>ref.Peak</c>.
/// </summary>
/// <remarks>
/// The work itself is <c>ingest.MergePeaks</c>, a set operation over tables this repository
/// owns. Keeping it in the schema project rather than in a string here means it is reviewable
/// as a schema diff, deployed with the tables it depends on, and exercised by the smoke tests.
/// This class exists to call it and to report what it did.
/// </remarks>
internal sealed class PeakMerger(ILogger<PeakMerger> logger)
{
    public async Task<PeakMergeResult> MergeAsync(
        SqlConnection connection, long runId, string peakRuleVersion, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentException.ThrowIfNullOrWhiteSpace(peakRuleVersion);

        await using var command = new SqlCommand("ingest.MergePeaks", connection)
        {
            CommandType = CommandType.StoredProcedure,
            // The merge touches every row of the catalogue and runs in one transaction; the
            // default thirty seconds is optimistic on a serverless database resuming from
            // auto-pause.
            CommandTimeout = 600,
        };

        command.Parameters.Add("@RunId", SqlDbType.BigInt).Value = runId;
        command.Parameters.Add("@PeakRuleVersion", SqlDbType.VarChar, 20).Value = peakRuleVersion;

        var inserted = command.Parameters.Add("@RowsInserted", SqlDbType.Int);
        var updated = command.Parameters.Add("@RowsUpdated", SqlDbType.Int);
        var retired = command.Parameters.Add("@RowsRetired", SqlDbType.Int);
        inserted.Direction = ParameterDirection.Output;
        updated.Direction = ParameterDirection.Output;
        retired.Direction = ParameterDirection.Output;

        await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);

        var result = new PeakMergeResult(
            Inserted: ToCount(inserted.Value),
            Updated: ToCount(updated.Value),
            Retired: ToCount(retired.Value));

        logger.LogInformation(
            "Catalogue merged under rule {PeakRuleVersion}: {Inserted} inserted, {Updated} updated, {Retired} retired.",
            peakRuleVersion, result.Inserted, result.Updated, result.Retired);

        if (result.Retired > 0)
        {
            // Retirement is normal — a rule change or an upstream removal — but it is also
            // what a broken parse looks like, so it never passes without being said out loud.
            logger.LogWarning(
                "{Retired} peaks were retired. They are kept, not deleted, because a trip may reference them.",
                result.Retired);
        }

        return result;
    }

    /// <summary>The procedure returns NULL rather than zero when a MERGE changed nothing.</summary>
    private static int ToCount(object? value)
        => value is null or DBNull ? 0 : (int)value;
}

/// <param name="Inserted">Peaks new to the catalogue.</param>
/// <param name="Updated">Peaks whose details changed, including any brought back from retirement.</param>
/// <param name="Retired">Peaks the current rule no longer admits.</param>
internal readonly record struct PeakMergeResult(int Inserted, int Updated, int Retired);
