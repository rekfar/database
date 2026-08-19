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
    /// Required for now. When the download stage lands, an absent path will mean "fetch the
    /// current extract" rather than "fail"; supplying one will stay supported, because
    /// re-running against the exact file a previous run read is how a parsing change is
    /// compared against a known result.
    /// </remarks>
    public string? ExtractPath { get; init; }

    /// <summary>
    /// The <c>navneobjekttype</c> values to stage, comma-separated. Defaults to the two the
    /// import was measured against (ADR-0016).
    /// </summary>
    /// <remarks>
    /// Configuration rather than a constant so that widening the peak rule later is a setting
    /// and a re-run, not a code change.
    /// </remarks>
    public string NavneobjektTypes { get; init; } = "fjell,topp";

    public string[] ParseNavneobjektTypes()
        => NavneobjektTypes.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}
