using Rekfar.Ingest.Peaks.Ssr;
using Xunit;

namespace Rekfar.Ingest.Peaks.Tests;

/// <summary>
/// Parser tests against <c>Fixtures/ssr-sample.gml</c> — nine real features taken verbatim
/// from the whole-country extract, each present because it isolates one decision the parser
/// has to get right. Real data rather than hand-written XML, so the tests cannot quietly
/// agree with a wrong assumption about the format.
/// </summary>
public sealed class SsrGmlReaderTests
{
    /// <summary>The types the import stages, per the plan: fjell and topp (ADR-0016).</summary>
    private static readonly string[] PeakTypes = ["fjell", "topp"];

    private static async Task<(SsrGmlReader Reader, List<SsrPlace> Places)> ReadFixtureAsync(
        params string[] types)
    {
        var reader = new SsrGmlReader(types.Length == 0 ? PeakTypes : types);
        await using var stream = File.OpenRead(Path.Combine("Fixtures", "ssr-sample.gml"));

        var places = new List<SsrPlace>();
        await foreach (var place in reader.ReadAsync(stream))
        {
            places.Add(place);
        }

        return (reader, places);
    }

    private static SsrPlace Place(List<SsrPlace> places, string stedsnummer)
        => places.Single(p => p.Stedsnummer == stedsnummer);

    [Fact]
    public async Task Reads_only_the_requested_navneobjekttype()
    {
        var (reader, places) = await ReadFixtureAsync();

        // Nine features in the file; the adressenavn is not a peak and must not survive.
        Assert.Equal(9, reader.FeaturesRead);
        Assert.Equal(8, places.Count);
        Assert.DoesNotContain(places, p => p.Stedsnummer == "829767");
        Assert.All(places, p => Assert.Contains(p.NavneobjektType, PeakTypes));
    }

    [Fact]
    public async Task Reads_the_product_specification_from_the_file_rather_than_configuration()
    {
        var (reader, _) = await ReadFixtureAsync();

        // The value ADR-0016 pinned and the seed asserts. It comes from the root namespace, so
        // an upstream specification change shows up here instead of passing unnoticed.
        Assert.Equal("StedsnavnForVanligBruk 20231001", reader.ProductSpecVersion);
    }

    [Fact]
    public async Task Reads_the_extract_timestamp_as_utc()
    {
        var (reader, _) = await ReadFixtureAsync();

        Assert.NotNull(reader.ExtractedAt);
        Assert.Equal(DateTimeKind.Utc, reader.ExtractedAt!.Value.Kind);
    }

    [Fact]
    public async Task Reads_a_single_representation_point_in_latitude_longitude_order()
    {
        var (_, places) = await ReadFixtureAsync();
        var galdhopiggen = Place(places, "313058");

        Assert.Equal("Galdhøpiggen", galdhopiggen.Name);

        var point = Assert.Single(galdhopiggen.Points);

        // Latitude first: the extract declares urn:ogc:def:crs:EPSG::4258, whose axis order is
        // north then east. Transposed, this peak would land off the coast of West Africa.
        Assert.Equal(61.636440m, point.Latitude);
        Assert.Equal(8.312477m, point.Longitude);
    }

    [Fact]
    public async Task Preserves_the_published_coordinate_precision_exactly()
    {
        var (_, places) = await ReadFixtureAsync();
        var point = Assert.Single(Place(places, "313058").Points);

        // decimal, not double: the value is the key into the elevation-sample cache, and two
        // runs that round it differently would miss each other's entries.
        Assert.Equal(6, decimal.GetBits(point.Latitude)[3] >> 16 & 0xFF);
        Assert.Equal(6, decimal.GetBits(point.Longitude)[3] >> 16 & 0xFF);
    }

    [Fact]
    public async Task Reads_every_point_of_a_multipoint_place()
    {
        var (_, places) = await ReadFixtureAsync();
        var grodnibbene = Place(places, "488933");

        // Roughly half of all peaks carry several points; the highest sampled one becomes both
        // the elevation and the position, so losing any of them loses the summit.
        Assert.Equal(4, grodnibbene.Points.Count);
        Assert.All(grodnibbene.Points, p =>
        {
            Assert.InRange(p.Latitude, 57m, 72m);
            Assert.InRange(p.Longitude, 4m, 32m);
        });
    }

    [Fact]
    public async Task Keeps_places_that_have_no_geometry_and_counts_them()
    {
        var (reader, places) = await ReadFixtureAsync();
        var romssavarit = Place(places, "1077614");

        // 37 peaks in the national extract have no position. They are counted rather than
        // dropped silently, because the run's row counts are how a parsing regression is spotted.
        Assert.Empty(romssavarit.Points);
        Assert.Equal(1, reader.PlacesWithoutGeometry);
    }

    [Fact]
    public async Task Reads_the_municipality_so_areas_need_no_spatial_join()
    {
        var (_, places) = await ReadFixtureAsync();
        var galdhopiggen = Place(places, "313058");

        Assert.False(string.IsNullOrWhiteSpace(galdhopiggen.Kommunenummer));
        Assert.False(string.IsNullOrWhiteSpace(galdhopiggen.Kommunenavn));
    }

    [Fact]
    public async Task Reads_the_upstream_change_date_as_utc()
    {
        var (_, places) = await ReadFixtureAsync();

        var updated = Place(places, "313058").UpdatedUpstreamAt;

        Assert.NotNull(updated);
        Assert.Equal(DateTimeKind.Utc, updated!.Value.Kind);
    }

    [Fact]
    public async Task Can_be_widened_to_other_types_without_code_changes()
    {
        var (_, places) = await ReadFixtureAsync("adressenavn");

        // The staged type set is configuration, so widening the peak rule later does not mean
        // editing the parser.
        var road = Assert.Single(places);
        Assert.Equal("Alvøyvegen", road.Name);
    }
}
