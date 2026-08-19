using System.Data;
using Microsoft.Data.SqlClient;
using Rekfar.Ingest.Peaks.Hoydedata;
using Rekfar.Ingest.Peaks.Ssr;

namespace Rekfar.Ingest.Peaks.Database;

/// <summary>
/// Reads and writes <c>ingest.ElevationSample</c> — the durable cache of sampled heights.
/// </summary>
/// <remarks>
/// The cache is keyed by coordinate rather than by run, because a point's terrain height does
/// not depend on which extract mentioned it. That is what makes a re-run, a widened peak rule,
/// or a resumed run after a failure cost only the points nobody has asked about yet.
/// </remarks>
internal sealed class ElevationSampleStore
{
    /// <summary>
    /// The distinct points of a run that have never been sampled.
    /// </summary>
    /// <remarks>
    /// Distinct because places share coordinates more often than one would guess, and because
    /// asking twice about the same point in one run would waste a request and then collide on
    /// insert.
    /// </remarks>
    public static async Task<List<SsrPoint>> ReadUnsampledPointsAsync(
        SqlConnection connection, long runId, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(connection);

        const string sql = """
            SELECT DISTINCT p.Latitude, p.Longitude
            FROM ingest.SsrPlacePoint AS p
            WHERE p.RunId = @RunId
              AND NOT EXISTS (
                    SELECT 1 FROM ingest.ElevationSample AS s
                    WHERE s.Latitude = p.Latitude AND s.Longitude = p.Longitude)
            ORDER BY p.Latitude, p.Longitude;
            """;

        await using var command = new SqlCommand(sql, connection) { CommandTimeout = 300 };
        command.Parameters.Add("@RunId", SqlDbType.BigInt).Value = runId;

        var points = new List<SsrPoint>();

        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            points.Add(new SsrPoint(reader.GetDecimal(0), reader.GetDecimal(1)));
        }

        return points;
    }

    /// <summary>How many of a run's points already have a sample, and how many exist at all.</summary>
    public static async Task<(int Total, int Sampled)> CountCoverageAsync(
        SqlConnection connection, long runId, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(connection);

        const string sql = """
            SELECT COUNT(*) AS Total,
                   SUM(CASE WHEN s.Latitude IS NULL THEN 0 ELSE 1 END) AS Sampled
            FROM (SELECT DISTINCT Latitude, Longitude FROM ingest.SsrPlacePoint WHERE RunId = @RunId) AS p
            LEFT JOIN ingest.ElevationSample AS s
                   ON s.Latitude = p.Latitude AND s.Longitude = p.Longitude;
            """;

        await using var command = new SqlCommand(sql, connection) { CommandTimeout = 300 };
        command.Parameters.Add("@RunId", SqlDbType.BigInt).Value = runId;

        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            return (0, 0);
        }

        return (reader.GetInt32(0), reader.IsDBNull(1) ? 0 : reader.GetInt32(1));
    }

    /// <summary>
    /// Adds samples to the cache, skipping any coordinate already there.
    /// </summary>
    /// <remarks>
    /// Written through a temporary table and an anti-join rather than row-by-row inserts, so
    /// that a coordinate another run cached in the meantime is a no-op instead of a primary
    /// key violation that would fail the batch.
    /// </remarks>
    public static async Task SaveAsync(
        SqlConnection connection, IReadOnlyList<ElevationSample> samples, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentNullException.ThrowIfNull(samples);

        if (samples.Count == 0)
        {
            return;
        }

        const string createTemp = """
            CREATE TABLE #NewElevationSample
            (
                Latitude        decimal(9, 6)   NOT NULL,
                Longitude       decimal(9, 6)   NOT NULL,
                ElevationMeters decimal(7, 2)   NULL,
                Datakilde       varchar(20)     NULL,
                Terreng         nvarchar(40)    NULL
            );
            """;

        await using (var command = new SqlCommand(createTemp, connection))
        {
            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        try
        {
            using var table = new DataTable("NewElevationSample");
            table.Columns.Add("Latitude", typeof(decimal));
            table.Columns.Add("Longitude", typeof(decimal));
            table.Columns.Add("ElevationMeters", typeof(decimal));
            table.Columns.Add("Datakilde", typeof(string));
            table.Columns.Add("Terreng", typeof(string));

            foreach (var sample in samples)
            {
                table.Rows.Add(
                    sample.Latitude,
                    sample.Longitude,
                    (object?)sample.ElevationMeters ?? DBNull.Value,
                    (object?)sample.Datakilde ?? DBNull.Value,
                    (object?)sample.Terreng ?? DBNull.Value);
            }

            using (var bulk = new SqlBulkCopy(connection) { DestinationTableName = "#NewElevationSample" })
            {
                foreach (DataColumn column in table.Columns)
                {
                    bulk.ColumnMappings.Add(column.ColumnName, column.ColumnName);
                }

                await bulk.WriteToServerAsync(table, cancellationToken).ConfigureAwait(false);
            }

            // The GROUP BY is not redundant: the service can answer about the same coordinate
            // twice within one batch if the extract listed it twice, and a duplicate here would
            // violate the primary key rather than simply being ignored.
            const string merge = """
                INSERT INTO ingest.ElevationSample (Latitude, Longitude, ElevationMeters, Datakilde, Terreng)
                SELECT n.Latitude, n.Longitude, MIN(n.ElevationMeters), MIN(n.Datakilde), MIN(n.Terreng)
                FROM #NewElevationSample AS n
                WHERE NOT EXISTS (
                        SELECT 1 FROM ingest.ElevationSample AS s
                        WHERE s.Latitude = n.Latitude AND s.Longitude = n.Longitude)
                GROUP BY n.Latitude, n.Longitude;
                """;

            await using var insert = new SqlCommand(merge, connection) { CommandTimeout = 300 };
            await insert.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            await using var drop = new SqlCommand("DROP TABLE #NewElevationSample;", connection);
            await drop.ExecuteNonQueryAsync(CancellationToken.None).ConfigureAwait(false);
        }
    }
}
