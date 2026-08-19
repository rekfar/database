namespace Rekfar.Ingest.Peaks.Ssr;

/// <summary>One SSR place, as parsed from the extract and before any peak rule is applied.</summary>
/// <remarks>
/// A faithful copy of the source fields under their Kartverket names, matching
/// <c>ingest.SsrPlace</c>. Norwegian identifiers are ASCII-folded the same way the code
/// values are (docs/conventions.md) — <c>SkrivemateStatus</c>, not <c>Skrivemåtestatus</c>.
/// </remarks>
internal sealed record SsrPlace
{
    /// <summary>SSR's stable place id, and the value that becomes <c>ref.Peak.ExternalId</c>.</summary>
    public required string Stedsnummer { get; init; }

    /// <summary>The display name chosen by <see cref="PlaceNameSelector"/>.</summary>
    public required string Name { get; init; }

    /// <summary>Which language the chosen name is in — recorded so the choice can be audited.</summary>
    public string? Sprak { get; init; }

    public string? Navnestatus { get; init; }

    public string? SkrivemateStatus { get; init; }

    public required string NavneobjektType { get; init; }

    public required string NavneobjektGruppe { get; init; }

    public string? Kommunenummer { get; init; }

    public string? Kommunenavn { get; init; }

    public string? Fylkesnummer { get; init; }

    public string? Fylkesnavn { get; init; }

    /// <summary>The upstream row's own last-changed date, in UTC.</summary>
    public DateTime? UpdatedUpstreamAt { get; init; }

    /// <summary>
    /// Every representation point the place carries. Frequently more than one, and
    /// occasionally none at all — SSR does not guarantee a geometry.
    /// </summary>
    public required IReadOnlyList<SsrPoint> Points { get; init; }
}

/// <summary>A single representation point, in ETRS89 geographic degrees exactly as published.</summary>
internal readonly record struct SsrPoint(decimal Latitude, decimal Longitude);
