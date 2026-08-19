using System.Globalization;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using Rekfar.Ingest.Peaks.Ssr;

namespace Rekfar.Ingest.Peaks.Hoydedata;

/// <summary>
/// Samples terrain heights from Kartverket Høydedata's point service.
/// </summary>
/// <remarks>
/// <para>
/// SSR carries no heights, so every peak's elevation costs a call here (FR-REF-10). The
/// service accepts up to 50 coordinates per request and answers a 50-point batch in about a
/// second once warm, so latency dominates and batching is what makes the run practical:
/// roughly 1,150 requests instead of 58,000.
/// </para>
/// <para>
/// <b>The coordinate order is the opposite of the extract's.</b> The GML declares
/// EPSG:4258 and publishes latitude first; this service takes each pair as
/// <c>[øst, nord]</c> — longitude first. Getting it the wrong way round does not fail, it
/// just answers <c>null</c> for every point on land, which looks exactly like missing
/// coverage. Hence <see cref="ToRequestPair"/> and the echo check below.
/// </para>
/// </remarks>
internal sealed class HoydedataClient(HttpClient httpClient, string baseUrl, ILogger<HoydedataClient> logger)
{
    /// <summary>The service's documented ceiling; 51 is refused with HTTP 422.</summary>
    public const int MaxPointsPerRequest = 50;

    /// <summary>
    /// How far a returned coordinate may differ from the one sent before the response is
    /// treated as unusable. The extract publishes six decimal places, so anything beyond half
    /// of the sixth is a different point rather than rounding.
    /// </summary>
    private const decimal EchoTolerance = 0.0000005m;

    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    /// <summary>Samples one batch. The caller is responsible for keeping it within the limit.</summary>
    public async Task<IReadOnlyList<ElevationSample>> SampleAsync(
        IReadOnlyList<SsrPoint> points, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(points);

        if (points.Count == 0)
        {
            return [];
        }

        if (points.Count > MaxPointsPerRequest)
        {
            throw new ArgumentException(
                $"The service accepts at most {MaxPointsPerRequest} coordinates per request; {points.Count} were given.",
                nameof(points));
        }

        var response = await SendAsync(baseUrl.TrimEnd('/') + "/" + BuildRequestUri(points), cancellationToken).ConfigureAwait(false);
        return Map(points, response);
    }

    private static string BuildRequestUri(IReadOnlyList<SsrPoint> points)
    {
        var pairs = new StringBuilder("[");
        for (var i = 0; i < points.Count; i++)
        {
            if (i > 0)
            {
                pairs.Append(',');
            }

            pairs.Append(ToRequestPair(points[i]));
        }

        pairs.Append(']');

        return $"punkt?koordsys={SsrGmlReader.RequiredEpsgCode}&punkter={Uri.EscapeDataString(pairs.ToString())}";
    }

    /// <summary>Longitude first — see the note on coordinate order in the class remarks.</summary>
    private static string ToRequestPair(SsrPoint point)
        => string.Create(
            CultureInfo.InvariantCulture, $"[{point.Longitude},{point.Latitude}]");

    private async Task<PunktResponse> SendAsync(string requestUri, CancellationToken cancellationToken)
    {
        using var response = await httpClient.GetAsync(requestUri, cancellationToken).ConfigureAwait(false);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            throw new HoydedataException(
                $"Høydedata answered {(int)response.StatusCode} {response.StatusCode}: {Trim(body)}",
                response.StatusCode);
        }

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);

        return await JsonSerializer.DeserializeAsync<PunktResponse>(stream, JsonOptions, cancellationToken)
                   .ConfigureAwait(false)
               ?? throw new HoydedataException("Høydedata returned an empty body.", response.StatusCode);
    }

    /// <summary>
    /// Pairs each answer with the point it was asked about.
    /// </summary>
    /// <remarks>
    /// The service answers in request order, and this relies on that — but verifies it rather
    /// than trusting it, because the failure mode is silent and severe: a shifted response
    /// would give every peak its neighbour's elevation, and nothing downstream could tell.
    /// The response echoes the coordinates, which makes the check nearly free.
    /// </remarks>
    private List<ElevationSample> Map(IReadOnlyList<SsrPoint> requested, PunktResponse response)
    {
        var answers = response.Punkter ?? [];

        if (answers.Count != requested.Count)
        {
            throw new HoydedataException(
                $"Asked about {requested.Count} points and got {answers.Count} answers.", HttpStatusCode.OK);
        }

        var samples = new List<ElevationSample>(requested.Count);

        for (var i = 0; i < requested.Count; i++)
        {
            var point = requested[i];
            var answer = answers[i];

            if (Math.Abs((answer.Y ?? 0m) - point.Latitude) > EchoTolerance
                || Math.Abs((answer.X ?? 0m) - point.Longitude) > EchoTolerance)
            {
                throw new HoydedataException(
                    $"Høydedata answered about ({answer.Y}, {answer.X}) when asked about ({point.Latitude}, {point.Longitude}). "
                    + "The response does not line up with the request.",
                    HttpStatusCode.OK);
            }

            samples.Add(new ElevationSample(point.Latitude, point.Longitude, answer.Z, answer.Datakilde, answer.Terreng));
        }

        logger.LogDebug("Sampled {Count} points, {WithHeight} with a height.", samples.Count, samples.Count(s => s.ElevationMeters is not null));

        return samples;
    }

    private static string Trim(string body)
        => body.Length > 300 ? body[..300] : body;

    private sealed record PunktResponse
    {
        [JsonPropertyName("punkter")]
        public IReadOnlyList<Punkt>? Punkter { get; init; }
    }

    private sealed record Punkt
    {
        public decimal? X { get; init; }

        public decimal? Y { get; init; }

        public decimal? Z { get; init; }

        public string? Datakilde { get; init; }

        public string? Terreng { get; init; }
    }
}

/// <summary>A failure talking to Høydedata, carrying the status so retry can judge it.</summary>
internal sealed class HoydedataException(string message, HttpStatusCode statusCode) : Exception(message)
{
    public HttpStatusCode StatusCode { get; } = statusCode;
}
