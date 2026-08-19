using Rekfar.Ingest.Peaks.Ssr;
using Xunit;

namespace Rekfar.Ingest.Peaks.Tests;

/// <summary>
/// The display-name rule (ADR-0016's open follow-up), tested through the parser against real
/// places so that the fixture's own attributes — not an invented arrangement of them — decide
/// the answer.
/// </summary>
public sealed class PlaceNameSelectorTests
{
    private static async Task<List<SsrPlace>> ReadFixtureAsync()
    {
        var reader = new SsrGmlReader(["fjell", "topp"]);
        await using var stream = File.OpenRead(Path.Combine("Fixtures", "ssr-sample.gml"));

        var places = new List<SsrPlace>();
        await foreach (var place in reader.ReadAsync(stream))
        {
            places.Add(place);
        }

        return places;
    }

    private static SsrPlace Place(List<SsrPlace> places, string stedsnummer)
        => places.Single(p => p.Stedsnummer == stedsnummer);

    [Fact]
    public async Task Name_status_outranks_everything_else()
    {
        var place = Place(await ReadFixtureAsync(), "445400");

        // Two Norwegian names: hovednavn "Korssjøvola" and undernavn "Korssjøfjellet".
        Assert.Equal("Korssjøvola", place.Name);
        Assert.Equal("hovednavn", place.Navnestatus);
    }

    [Fact]
    public async Task The_places_own_language_priority_decides_and_can_choose_a_sami_name()
    {
        var place = Place(await ReadFixtureAsync(), "74621");

        // Both names are hovednavn: Norwegian "Skjækerskaftet" and South Sami "Rihkedetjahke".
        // This place publishes språkprioritering "sørsamisk-lulesamisk-nordsamisk-norsk-kvensk",
        // so the South Sami name is the one Kartverket ranks first — and a parser that simply
        // preferred Norwegian would rename a real mountain.
        Assert.Equal("Rihkedetjahke", place.Name);
        Assert.Equal("sørsamisk", place.Sprak);
    }

    [Fact]
    public async Task The_same_rule_chooses_the_norwegian_name_when_that_is_what_the_place_ranks_first()
    {
        var place = Place(await ReadFixtureAsync(), "681313");

        // The mirror image of the case above, and the reason it is here: the South Sami name
        // "Skaanja-Stoerrevaerie" appears FIRST in the document, but this place ranks Norwegian
        // first, so "Jøssundvarden" wins. Document order is not the rule.
        Assert.Equal("Jøssundvarden", place.Name);
        Assert.Equal("norsk", place.Sprak);
    }

    [Fact]
    public async Task Falls_back_to_stedsnavnnummer_when_status_and_language_tie()
    {
        var place = Place(await ReadFixtureAsync(), "185763");

        // This place has no hovednavn at all — two sidenavn, both Norwegian. SSR's own ordering
        // within the place is the only thing left to break the tie.
        Assert.Equal("Svandalsgryvlenuten", place.Name);
        Assert.Equal("sidenavn", place.Navnestatus);
    }

    [Fact]
    public void Prefers_a_decided_spelling_over_a_merely_proposed_one()
    {
        var selected = PlaceNameSelector.Select(
            [
                new CandidateName
                {
                    Sprak = "norsk",
                    Navnestatus = "hovednavn",
                    Stedsnavnnummer = 1,
                    Spellings =
                    [
                        new CandidateSpelling("Tjuvanuten", "foreslått", 2),
                        new CandidateSpelling("Tjuanuten", "godkjent", 1),
                    ],
                },
            ],
            "norsk-sørsamisk");

        Assert.Equal("Tjuanuten", selected!.Value.Name);
        Assert.Equal("godkjent", selected.Value.SkrivemateStatus);
    }

    [Fact]
    public void Ranks_vedtatt_above_godkjent()
    {
        var selected = PlaceNameSelector.Select(
            [
                new CandidateName
                {
                    Navnestatus = "hovednavn",
                    Spellings =
                    [
                        new CandidateSpelling("Godkjent form", "godkjent", 1),
                        new CandidateSpelling("Vedtatt form", "vedtatt", 2),
                    ],
                },
            ],
            languagePriority: null);

        // Lower skrivemåtenummer loses to the more settled status: the ordering is by how
        // decided the spelling is first, and only then by SSR's numbering.
        Assert.Equal("Vedtatt form", selected!.Value.Name);
    }

    [Fact]
    public void Returns_null_when_no_candidate_carries_a_usable_spelling()
    {
        var selected = PlaceNameSelector.Select(
            [new CandidateName { Navnestatus = "hovednavn", Spellings = [new CandidateSpelling("  ", "vedtatt", 1)] }],
            languagePriority: null);

        Assert.Null(selected);
    }

    [Fact]
    public void Copes_with_a_language_the_priority_list_does_not_mention()
    {
        var selected = PlaceNameSelector.Select(
            [
                new CandidateName { Sprak = "russisk", Navnestatus = "hovednavn", Spellings = [new CandidateSpelling("Russian", "vedtatt", 1)] },
                new CandidateName { Sprak = "norsk", Navnestatus = "hovednavn", Spellings = [new CandidateSpelling("Norsk", "vedtatt", 1)] },
            ],
            "norsk-kvensk");

        // The extract does contain names in languages outside the priority list. An unranked
        // language sorts last rather than throwing or winning by accident.
        Assert.Equal("Norsk", selected!.Value.Name);
    }
}
