namespace Rekfar.Ingest.Peaks.Ssr;

/// <summary>
/// The geographic extent the peak catalogue covers.
/// </summary>
/// <remarks>
/// <para>
/// These values are the same ones <c>CK_ingest_SsrPlacePoint_Latitude</c> and
/// <c>CK_ingest_SsrPlacePoint_Longitude</c> enforce, and the two must stay in step: this
/// filter decides what is offered to the database, and the constraints are the tripwire that
/// catches anything getting past it.
/// </para>
/// <para>
/// They bound mainland Norway rather than the globe because their real job is catching a
/// transposed coordinate. The extract declares <c>urn:ogc:def:crs:EPSG::4258</c>, which puts
/// latitude first; read the other way round, every Norwegian point becomes a longitude in the
/// fifties and sixties and a latitude in the single digits — individually valid, wholly wrong,
/// and invisible without a bounds check.
/// </para>
/// <para>
/// The mainland extract does contain a few places outside these bounds, and they are real
/// rather than corrupt: <b>Newtontoppen</b> on Svalbard, and ten peaks in <b>East Greenland</b>
/// — <i>Saddelbjerg</i>, <i>Sortekap</i>, <i>Rignys Bjerg</i> and others — whose Norwegian
/// names SSR still carries from the Erik the Red's Land claim of 1931. None of them belong in
/// a catalogue scoped to Norway (ADR-0002), and Svalbard has its own dataset if it is ever
/// wanted, so they are excluded and counted rather than admitted or silently dropped.
/// </para>
/// </remarks>
internal static class MainlandNorwayBounds
{
    public const decimal MinLatitude = 57m;

    public const decimal MaxLatitude = 72m;

    public const decimal MinLongitude = 4m;

    public const decimal MaxLongitude = 32m;

    public static bool Contains(SsrPoint point)
        => point.Latitude >= MinLatitude
        && point.Latitude <= MaxLatitude
        && point.Longitude >= MinLongitude
        && point.Longitude <= MaxLongitude;

    /// <summary>
    /// True when every point of a place is in scope. A place with no points at all is in
    /// scope: it is a real Norwegian peak SSR happens to have no position for, and dropping it
    /// here would confuse "outside Norway" with "no geometry".
    /// </summary>
    public static bool Contains(IReadOnlyList<SsrPoint> points)
    {
        ArgumentNullException.ThrowIfNull(points);

        foreach (var point in points)
        {
            if (!Contains(point))
            {
                return false;
            }
        }

        return true;
    }
}
