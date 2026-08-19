namespace Rekfar.Ingest.Peaks.Ssr;

/// <summary>
/// Chooses the one name a place is displayed under, from the several it may carry.
/// </summary>
/// <remarks>
/// <para>
/// This closes the open follow-up in ADR-0016. A place carries up to five names, across
/// Norwegian, three Sami languages and Kvensk, and each name carries one or more spellings.
/// Something has to pick one, and picking badly is not a cosmetic problem: it is the name
/// the peak is listed and searched under.
/// </para>
/// <para>
/// The rule, in order:
/// </para>
/// <list type="number">
///   <item><description>
///     <b>Name status.</b> <c>hovednavn</c> before <c>sidenavn</c> before <c>undernavn</c>
///     before <c>historisk</c>. The primary name wins whatever language it is in.
///   </description></item>
///   <item><description>
///     <b>The place's own language priority.</b> Each place publishes a
///     <c>språkprioritering</c> such as <c>sørsamisk-lulesamisk-nordsamisk-norsk-kvensk</c>,
///     and the earlier a language appears in it, the stronger its claim. This is deliberately
///     not a fixed preference for Norwegian: 1,562 peaks in the extract rank a Sami language
///     first, and Kartverket's own ordering is a better authority on which name belongs to a
///     place than a blanket rule would be. Getting this wrong would rename real mountains.
///   </description></item>
///   <item><description>
///     <b>Lowest <c>stedsnavnnummer</c></b>, which is SSR's own ordering within a place.
///   </description></item>
/// </list>
/// <para>
/// Then, within the chosen name, the spelling: by <c>skrivemåtestatus</c>
/// (<c>vedtatt</c> ranks above <c>godkjent</c>, and anything formally settled ranks above
/// what is merely proposed or historical), then by lowest <c>skrivemåtenummer</c>.
/// </para>
/// <para>
/// Document order is never used. It does not track any of the above — the extract contains
/// places whose first-listed name is the one the rule rejects.
/// </para>
/// </remarks>
internal static class PlaceNameSelector
{
    /// <summary>Ranks below are "lower is better"; an unrecognised value sorts last but is still usable.</summary>
    private const int Unranked = int.MaxValue;

    private static readonly string[] NameStatusOrder = ["hovednavn", "sidenavn", "undernavn", "historisk"];

    // Ordered by how settled the spelling is. `vedtattNavneledd` is a decision about a name
    // element rather than the whole name, so it sits below a wholly decided spelling but
    // above one that is only proposed.
    private static readonly string[] SpellingStatusOrder =
        ["vedtatt", "godkjent", "vedtattNavneledd", "internasjonal", "uvurdert", "foreslått", "historisk"];

    /// <summary>
    /// Returns the chosen name, or <see langword="null"/> when the place carries no usable
    /// spelling at all.
    /// </summary>
    /// <param name="candidates">Every name on the place.</param>
    /// <param name="languagePriority">
    /// The place's <c>språkprioritering</c>, as published — a hyphen-separated list, most
    /// preferred first.
    /// </param>
    public static SelectedName? Select(IReadOnlyList<CandidateName> candidates, string? languagePriority)
    {
        ArgumentNullException.ThrowIfNull(candidates);

        var languages = ParseLanguagePriority(languagePriority);

        SelectedName? best = null;
        (int Status, int Language, int Number) bestRank = default;

        foreach (var candidate in candidates)
        {
            var spelling = SelectSpelling(candidate);
            if (spelling is null)
            {
                continue;
            }

            var rank = (
                Status: RankOf(NameStatusOrder, candidate.Navnestatus),
                Language: RankLanguage(languages, candidate.Sprak),
                Number: candidate.Stedsnavnnummer ?? Unranked);

            if (best is null || rank.CompareTo(bestRank) < 0)
            {
                best = new SelectedName(spelling.Value.Name, candidate.Sprak, candidate.Navnestatus, spelling.Value.Status);
                bestRank = rank;
            }
        }

        return best;
    }

    private static (string Name, string? Status)? SelectSpelling(CandidateName candidate)
    {
        (string Name, string? Status)? best = null;
        (int Status, int Number) bestRank = default;

        foreach (var spelling in candidate.Spellings)
        {
            if (string.IsNullOrWhiteSpace(spelling.Name))
            {
                continue;
            }

            var rank = (
                Status: RankOf(SpellingStatusOrder, spelling.Status),
                Number: spelling.Skrivematenummer ?? Unranked);

            if (best is null || rank.CompareTo(bestRank) < 0)
            {
                best = (spelling.Name, spelling.Status);
                bestRank = rank;
            }
        }

        return best;
    }

    private static string[] ParseLanguagePriority(string? languagePriority)
        => string.IsNullOrWhiteSpace(languagePriority)
            ? []
            : languagePriority.Split('-', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static int RankLanguage(string[] languages, string? language)
    {
        if (language is null)
        {
            return Unranked;
        }

        var index = Array.FindIndex(languages, l => string.Equals(l, language, StringComparison.OrdinalIgnoreCase));
        return index < 0 ? Unranked : index;
    }

    private static int RankOf(string[] order, string? value)
    {
        if (value is null)
        {
            return Unranked;
        }

        var index = Array.FindIndex(order, v => string.Equals(v, value, StringComparison.OrdinalIgnoreCase));
        return index < 0 ? Unranked : index;
    }
}

/// <summary>One <c>Stedsnavn</c> on a place, with every spelling it carries.</summary>
internal sealed record CandidateName
{
    public string? Sprak { get; init; }

    public string? Navnestatus { get; init; }

    public int? Stedsnavnnummer { get; init; }

    public required IReadOnlyList<CandidateSpelling> Spellings { get; init; }
}

/// <summary>One <c>Skrivemåte</c> — a spelling of a name, and how settled it is.</summary>
internal readonly record struct CandidateSpelling(string Name, string? Status, int? Skrivematenummer);

/// <summary>The outcome: which name won, and the attributes that made it win.</summary>
internal readonly record struct SelectedName(string Name, string? Sprak, string? Navnestatus, string? SkrivemateStatus);
