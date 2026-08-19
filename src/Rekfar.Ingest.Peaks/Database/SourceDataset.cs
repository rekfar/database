namespace Rekfar.Ingest.Peaks.Database;

/// <summary>
/// The dataset ids seeded by <c>Scripts/PostDeployment/Seed.SourceDataset.sql</c>.
/// </summary>
/// <remarks>
/// These are assigned rather than generated precisely so that code can refer to them by
/// meaning, and they are identical in every environment. Duplicating them here is the
/// intended use, not a shortcut — but it does mean the seed script is the authority, and
/// <see cref="SchemaPreflight"/> checks the two still agree before a run starts.
/// </remarks>
internal static class SourceDataset
{
    /// <summary>Stedsnavn — the general-use SSR distribution (ADR-0016).</summary>
    public const short Ssr = 1;

    /// <summary>Høydedata (DTM), the source of every sampled elevation.</summary>
    public const short Hoydedata = 2;

    /// <summary>N50 Kartdata — cabins. Not ingested yet (Phase 2).</summary>
    public const short N50 = 3;

    /// <summary>Turrutebasen — routes. Not ingested yet (Phase 2).</summary>
    public const short Turrutebasen = 4;
}
