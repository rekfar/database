using Rekfar.Ingest.Peaks.Ssr;
using Xunit;

namespace Rekfar.Ingest.Peaks.Tests;

/// <summary>
/// The scope filter, and the axis-order guard it doubles as. These bounds are duplicated in
/// <c>CK_ingest_SsrPlacePoint_Latitude</c> and <c>_Longitude</c>; the constraints are the
/// tripwire, this is what keeps the tripwire from being hit in normal operation.
/// </summary>
public sealed class MainlandNorwayBoundsTests
{
    [Theory]
    [InlineData(61.636440, 8.312477)]   // Galdhøpiggen
    [InlineData(58.000000, 5.000000)]   // the south-western corner
    [InlineData(71.000000, 31.000000)]  // the north-eastern corner
    public void Accepts_points_in_mainland_norway(decimal latitude, decimal longitude)
        => Assert.True(MainlandNorwayBounds.Contains(new SsrPoint(latitude, longitude)));

    [Theory]
    [InlineData(79.010322, 17.490750)]  // Newtontoppen, Svalbard — real, but not in scope
    [InlineData(68.560155, -31.266885)] // Sortekap, East Greenland — likewise
    public void Rejects_real_places_outside_the_catalogues_scope(decimal latitude, decimal longitude)
        => Assert.False(MainlandNorwayBounds.Contains(new SsrPoint(latitude, longitude)));

    [Fact]
    public void Rejects_a_transposed_coordinate()
    {
        var galdhopiggen = new SsrPoint(61.636440m, 8.312477m);
        var transposed = new SsrPoint(galdhopiggen.Longitude, galdhopiggen.Latitude);

        // The failure these bounds exist for. Both numbers are individually valid, and the
        // transposed pair lands in the Gulf of Guinea rather than Jotunheimen.
        Assert.True(MainlandNorwayBounds.Contains(galdhopiggen));
        Assert.False(MainlandNorwayBounds.Contains(transposed));
    }

    [Fact]
    public void A_place_is_out_of_scope_if_any_of_its_points_is()
    {
        SsrPoint[] mixed = [new(61.6m, 8.3m), new(79.0m, 17.5m)];

        // Partial geometry would be worse than none: the highest sampled point becomes the
        // summit position, so keeping half a place could put a peak in the wrong country.
        Assert.False(MainlandNorwayBounds.Contains(mixed));
    }

    [Fact]
    public void A_place_with_no_points_at_all_stays_in_scope()
    {
        // 37 peaks in the extract have no position. "No geometry" is not "outside Norway",
        // and conflating them would lose real peaks.
        Assert.True(MainlandNorwayBounds.Contains([]));
    }
}
