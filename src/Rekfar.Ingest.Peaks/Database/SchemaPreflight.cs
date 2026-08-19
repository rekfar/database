using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace Rekfar.Ingest.Peaks.Database;

/// <summary>
/// Checks that the database this job is pointed at is the one it was built against.
/// </summary>
/// <remarks>
/// <para>
/// ADR-0013 accepted that the model is expressed twice — once in the SQL project, once in
/// the code that consumes it — and that the two can drift. This is where that drift is
/// caught for ingestion: the alternative is a run that gets halfway, fails on a missing
/// column, and leaves the operator reading a stack trace to work out that the target
/// database is simply older than the program.
/// </para>
/// <para>
/// It checks the shape it depends on, not the whole schema. A full comparison is what
/// <c>SqlPackage /Action:DeployReport</c> is for.
/// </para>
/// </remarks>
internal static class SchemaPreflight
{
    /// <summary>The product specification this build parses against — pinned in ADR-0016.</summary>
    public const string ExpectedSsrProductSpecVersion = "StedsnavnForVanligBruk 20231001";

    private static readonly string[] RequiredTables =
    [
        "ingest.Run",
        "ingest.SsrPlace",
        "ingest.SsrPlacePoint",
        "ingest.ElevationSample",
        "ref.Peak",
        "ref.SourceDataset",
    ];

    /// <summary>Throws <see cref="InvalidOperationException"/> if the target database is not usable.</summary>
    public static async Task AssertAsync(SqlConnection connection, ILogger logger, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentNullException.ThrowIfNull(logger);

        var missing = new List<string>();

        foreach (var table in RequiredTables)
        {
            if (!await TableExistsAsync(connection, table, cancellationToken).ConfigureAwait(false))
            {
                missing.Add(table);
            }
        }

        if (missing.Count > 0)
        {
            throw new InvalidOperationException(
                $"The target database is missing {string.Join(", ", missing)}. It is older than this build — publish the dacpac first.");
        }

        var productSpecVersion = await ReadSsrProductSpecVersionAsync(connection, cancellationToken).ConfigureAwait(false);

        if (productSpecVersion is null)
        {
            throw new InvalidOperationException(
                $"ref.SourceDataset has no row with Id {SourceDataset.Ssr}. The post-deployment seed has not run against this database.");
        }

        // A mismatch is not fatal on its own — the parser may well still be correct — but it
        // means the seed and this build disagree about which specification is being read, and
        // that is exactly the disagreement ADR-0016 pinned the version to make visible.
        if (!string.Equals(productSpecVersion, ExpectedSsrProductSpecVersion, StringComparison.Ordinal))
        {
            logger.LogWarning(
                "ref.SourceDataset pins the SSR product specification as {SeededVersion}, but this build parses {ExpectedVersion}. One of the two is out of date.",
                productSpecVersion, ExpectedSsrProductSpecVersion);
        }

        logger.LogInformation(
            "Schema preflight passed against {Database} on {DataSource}.", connection.Database, connection.DataSource);
    }

    private static async Task<bool> TableExistsAsync(
        SqlConnection connection, string qualifiedName, CancellationToken cancellationToken)
    {
        const string sql = "SELECT CASE WHEN OBJECT_ID(@Name, 'U') IS NULL THEN 0 ELSE 1 END;";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@Name", System.Data.SqlDbType.NVarChar, 256).Value = qualifiedName;

        return (int)(await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false))! == 1;
    }

    private static async Task<string?> ReadSsrProductSpecVersionAsync(
        SqlConnection connection, CancellationToken cancellationToken)
    {
        const string sql = "SELECT ProductSpecVersion FROM [ref].SourceDataset WHERE Id = @Id;";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@Id", System.Data.SqlDbType.SmallInt).Value = SourceDataset.Ssr;

        var value = await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);

        // No row at all and a row with a NULL version are different failures: the first means
        // the seed never ran, the second that this dataset has no ingestion job yet. Only the
        // first is this method's to report, so an unseeded version comes back as an empty
        // string rather than collapsing into null.
        return value switch
        {
            null => null,
            DBNull => string.Empty,
            _ => (string)value,
        };
    }
}
