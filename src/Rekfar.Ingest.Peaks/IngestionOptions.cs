namespace Rekfar.Ingest.Peaks;

/// <summary>What the job needs to be told, and its defaults.</summary>
/// <remarks>
/// Read from configuration, which is <c>appsettings.json</c>, environment variables and
/// command-line arguments — in that order of increasing precedence. The connection string is
/// deliberately not here: it belongs to <c>ConnectionStrings:Rekfar</c> and never to a file
/// in this repository.
/// </remarks>
internal sealed class IngestionOptions
{
    /// <summary>
    /// Path to the SSR extract — either the published <c>.zip</c> or an unpacked <c>.gml</c>.
    /// </summary>
    /// <remarks>
    /// Optional. Left unset, the job downloads the current extract from
    /// <see cref="ExtractUrl"/>. Setting it is how a run is repeated against the exact file an
    /// earlier one read — which is how a parsing change is compared against a known result.
    /// </remarks>
    public string? ExtractPath { get; init; }

    /// <summary>Where the extract is published. A direct download: no order API, no key.</summary>
    public string ExtractUrl { get; init; } =
        "https://nedlasting.geonorge.no/geonorge/Basisdata/Stedsnavn/GML/Basisdata_0000_Norge_4258_Stedsnavn_GML.zip";

    /// <summary>
    /// The <c>navneobjekttype</c> values to stage, comma-separated. Defaults to the two the
    /// import was measured against (ADR-0016).
    /// </summary>
    /// <remarks>
    /// Configuration rather than a constant so that widening the peak rule later is a setting
    /// and a re-run, not a code change.
    /// </remarks>
    public string NavneobjektTypes { get; init; } = "fjell,topp";

    /// <summary>
    /// Which peak rule version to merge under. It must already be seeded — the rule is data
    /// with a documented rationale, not something the job invents (FR-REF-11).
    /// </summary>
    public string PeakRuleVersion { get; init; } = "1.0";

    /// <summary>Base address of the Kartverket Høydedata point service.</summary>
    public string HoydedataBaseUrl { get; init; } = "https://ws.geonorge.no/hoydedata/v1/";

    /// <summary>
    /// Coordinates per elevation request. The service refuses more than 50, and since latency
    /// dominates its own cost, fewer would only mean more round trips.
    /// </summary>
    public int ElevationBatchSize { get; init; } = 50;

    /// <summary>
    /// Elevation requests in flight at once. Deliberately small: this is a free public
    /// service, the job runs monthly, and the whole extract is about 1,150 requests.
    /// </summary>
    public int ElevationConcurrency { get; init; } = 4;

    /// <summary>Attempts per elevation request before the run gives up.</summary>
    public int ElevationMaxAttempts { get; init; } = 5;

    public string[] ParseNavneobjektTypes()
        => NavneobjektTypes.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}
