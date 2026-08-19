namespace Rekfar.Ingest.Peaks.Hoydedata;

/// <summary>
/// One sampled point, as it will be cached in <c>ingest.ElevationSample</c>.
/// </summary>
/// <param name="Latitude">The coordinate asked about, echoed back unchanged.</param>
/// <param name="Longitude">The coordinate asked about, echoed back unchanged.</param>
/// <param name="ElevationMeters">
/// The height, or <see langword="null"/> where the service has no coverage. A null is a real
/// answer and is cached as one — otherwise every run re-asks the same uncovered points and
/// gets the same nothing.
/// </param>
/// <param name="Datakilde">
/// Which model answered: <c>dtm1</c>, <c>dom1</c>, <c>hoydekurver</c>, <c>innsjohoyde</c> or
/// <c>dybdekurver</c>. Recorded because the service returns the best available source, and
/// for a coastal point that can be a bathymetric <em>depth</em> rather than a height.
/// </param>
/// <param name="Terreng">The service's own classification of what the point sits on.</param>
internal readonly record struct ElevationSample(
    decimal Latitude,
    decimal Longitude,
    decimal? ElevationMeters,
    string? Datakilde,
    string? Terreng);
