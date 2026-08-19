using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Rekfar.Ingest.Peaks.Ssr;

namespace Rekfar.Ingest.Peaks.Database;

/// <summary>
/// Bulk-loads parsed places into <c>ingest.SsrPlace</c> and <c>ingest.SsrPlacePoint</c>.
/// </summary>
/// <remarks>
/// <para>
/// Batched rather than one row at a time: roughly 30,000 places and 58,000 points per run,
/// which is nothing for <see cref="SqlBulkCopy"/> and a great deal for individual inserts.
/// The batch is deliberately modest — the point is to keep memory flat while the parser
/// streams, not to minimise round trips on a job that runs once a month.
/// </para>
/// <para>
/// Places are written before their points within each batch, because the points carry a
/// composite foreign key back to them.
/// </para>
/// <para>
/// There is deliberately no explicit transaction. The property that matters — a snapshot is
/// complete or absent, never half-overwriting the previous one — comes from staging being
/// keyed by run, not from atomicity: a failed run's rows are keyed to that run, are never
/// read (the merge consumes the last <em>succeeded</em> run), and go away when it is pruned.
/// A transaction spanning 88,000 inserts would hold locks for the duration and buy none of
/// that.
/// </para>
/// </remarks>
internal sealed class SsrStagingWriter(ILogger<SsrStagingWriter> logger)
{
    /// <summary>Places per round trip. Points travel with the batch their places are in.</summary>
    private const int BatchSize = 5_000;

    public async Task<StagingCounts> WriteAsync(
        SqlConnection connection,
        long runId,
        IAsyncEnumerable<SsrPlace> places,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentNullException.ThrowIfNull(places);

        using var placeTable = CreatePlaceTable();
        using var pointTable = CreatePointTable();

        var totalPlaces = 0;
        var totalPoints = 0;
        var batched = 0;
        var skipped = new List<string>();

        await foreach (var place in places.WithCancellation(cancellationToken).ConfigureAwait(false))
        {
            if (!MainlandNorwayBounds.Contains(place.Points))
            {
                // Real places, but outside the catalogue's scope — see MainlandNorwayBounds.
                // Counted and named rather than dropped quietly, because a sudden change in
                // this number means either the extract or the bounds have moved.
                skipped.Add(place.Name);
                continue;
            }

            AddPlace(placeTable, runId, place);

            for (var index = 0; index < place.Points.Count; index++)
            {
                AddPoint(pointTable, runId, place.Stedsnummer, index, place.Points[index]);
            }

            totalPlaces++;
            totalPoints += place.Points.Count;

            if (++batched >= BatchSize)
            {
                await FlushAsync(connection, placeTable, pointTable, cancellationToken).ConfigureAwait(false);
                batched = 0;
                logger.LogInformation("Staged {Places} places and {Points} points so far.", totalPlaces, totalPoints);
            }
        }

        await FlushAsync(connection, placeTable, pointTable, cancellationToken).ConfigureAwait(false);

        if (skipped.Count > 0)
        {
            logger.LogInformation(
                "Skipped {Count} places outside mainland Norway: {Names}.", skipped.Count, string.Join(", ", skipped));
        }

        logger.LogInformation("Staging complete: {Places} places, {Points} points.", totalPlaces, totalPoints);

        return new StagingCounts(totalPlaces, totalPoints, skipped.Count);
    }

    private static async Task FlushAsync(
        SqlConnection connection, DataTable placeTable, DataTable pointTable, CancellationToken cancellationToken)
    {
        if (placeTable.Rows.Count > 0)
        {
            await CopyAsync(connection, placeTable, "ingest.SsrPlace", cancellationToken).ConfigureAwait(false);
            placeTable.Clear();
        }

        if (pointTable.Rows.Count > 0)
        {
            await CopyAsync(connection, pointTable, "ingest.SsrPlacePoint", cancellationToken).ConfigureAwait(false);
            pointTable.Clear();
        }
    }

    private static async Task CopyAsync(
        SqlConnection connection, DataTable table, string destination, CancellationToken cancellationToken)
    {
        // CheckConstraints is not the default, and its absence is silent: without it
        // SqlBulkCopy loads rows straight past every CHECK on the table. The bounds guard on
        // the coordinates is the whole reason those constraints exist, so a bulk loader that
        // bypasses them would leave the guard documented but not running.
        using var bulk = new SqlBulkCopy(connection, SqlBulkCopyOptions.CheckConstraints, externalTransaction: null)
        {
            DestinationTableName = destination,
            BatchSize = table.Rows.Count,
            // A monthly job on a serverless database that may be resuming from auto-pause;
            // the default 30 seconds is optimistic for the first batch of a cold run.
            BulkCopyTimeout = 300,
        };

        // Mapped by name, never by ordinal. A column added to the middle of a staging table
        // would otherwise start silently loading values into the wrong column.
        foreach (DataColumn column in table.Columns)
        {
            bulk.ColumnMappings.Add(column.ColumnName, column.ColumnName);
        }

        await bulk.WriteToServerAsync(table, cancellationToken).ConfigureAwait(false);
    }

    private static DataTable CreatePlaceTable()
    {
        var table = new DataTable("SsrPlace");
        table.Columns.Add("RunId", typeof(long));
        table.Columns.Add("Stedsnummer", typeof(string));
        table.Columns.Add("Name", typeof(string));
        table.Columns.Add("Sprak", typeof(string));
        table.Columns.Add("Navnestatus", typeof(string));
        table.Columns.Add("SkrivemateStatus", typeof(string));
        table.Columns.Add("NavneobjektType", typeof(string));
        table.Columns.Add("NavneobjektGruppe", typeof(string));
        table.Columns.Add("Kommunenummer", typeof(string));
        table.Columns.Add("Kommunenavn", typeof(string));
        table.Columns.Add("Fylkesnummer", typeof(string));
        table.Columns.Add("Fylkesnavn", typeof(string));
        table.Columns.Add("UpdatedUpstreamAt", typeof(DateTime));
        table.Columns.Add("PointCount", typeof(short));
        return table;
    }

    private static DataTable CreatePointTable()
    {
        var table = new DataTable("SsrPlacePoint");
        table.Columns.Add("RunId", typeof(long));
        table.Columns.Add("Stedsnummer", typeof(string));
        table.Columns.Add("PointIndex", typeof(short));
        table.Columns.Add("Latitude", typeof(decimal));
        table.Columns.Add("Longitude", typeof(decimal));
        return table;
    }

    private static void AddPlace(DataTable table, long runId, SsrPlace place)
        => table.Rows.Add(
            runId,
            place.Stedsnummer,
            place.Name,
            (object?)place.Sprak ?? DBNull.Value,
            (object?)place.Navnestatus ?? DBNull.Value,
            (object?)place.SkrivemateStatus ?? DBNull.Value,
            place.NavneobjektType,
            place.NavneobjektGruppe,
            (object?)place.Kommunenummer ?? DBNull.Value,
            (object?)place.Kommunenavn ?? DBNull.Value,
            (object?)place.Fylkesnummer ?? DBNull.Value,
            (object?)place.Fylkesnavn ?? DBNull.Value,
            (object?)place.UpdatedUpstreamAt ?? DBNull.Value,
            (short)place.Points.Count);

    private static void AddPoint(DataTable table, long runId, string stedsnummer, int index, SsrPoint point)
        => table.Rows.Add(runId, stedsnummer, (short)index, point.Latitude, point.Longitude);
}

/// <summary>What a staging load wrote, and what it declined to.</summary>
internal readonly record struct StagingCounts(int Places, int Points, int SkippedOutOfScope);
