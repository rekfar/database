using System.Net;
using System.Text;
using Microsoft.Extensions.Logging.Abstractions;
using Rekfar.Ingest.Peaks.Hoydedata;
using Rekfar.Ingest.Peaks.Ssr;
using Xunit;

namespace Rekfar.Ingest.Peaks.Tests;

/// <summary>
/// The Høydedata client, tested with a stubbed transport so the suite stays offline.
/// The real service was used to establish the contract these stubs imitate: pairs go out as
/// [longitude, latitude], answers come back in request order, and every answer echoes the
/// coordinate it is about.
/// </summary>
public sealed class HoydedataClientTests
{
    private static readonly SsrPoint Galdhopiggen = new(61.636440m, 8.312477m);

    private sealed class StubHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public List<string> Requests { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add(request.RequestUri!.ToString());
            return Task.FromResult(respond(request));
        }
    }

    private static HttpResponseMessage Json(string body, HttpStatusCode status = HttpStatusCode.OK)
        => new(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    private static HoydedataClient Client(StubHandler handler)
        => new(
            new HttpClient(handler),
            "https://example.test/hoydedata/v1/",
            NullLogger<HoydedataClient>.Instance);

    [Fact]
    public async Task Sends_each_pair_as_longitude_then_latitude()
    {
        var handler = new StubHandler(_ => Json(
            """{"koordsys":4258,"punkter":[{"datakilde":"dtm1","terreng":"ÅpentOmråde","x":8.312477,"y":61.636440,"z":2468.25}]}"""));

        await Client(handler).SampleAsync([Galdhopiggen], CancellationToken.None);

        var uri = Uri.UnescapeDataString(handler.Requests.Single());

        // The extract publishes latitude first and this service wants longitude first. Getting
        // it backwards does not fail — it answers null for every point on land, which is
        // indistinguishable from missing coverage.
        Assert.Contains("[[8.312477,61.636440]]", uri, StringComparison.Ordinal);
        Assert.Contains("koordsys=4258", uri, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Maps_a_height_onto_the_point_it_was_asked_about()
    {
        var handler = new StubHandler(_ => Json(
            """{"koordsys":4258,"punkter":[{"datakilde":"dtm1","terreng":"ÅpentOmråde","x":8.312477,"y":61.636440,"z":2468.25}]}"""));

        var sample = Assert.Single(await Client(handler).SampleAsync([Galdhopiggen], CancellationToken.None));

        Assert.Equal(Galdhopiggen.Latitude, sample.Latitude);
        Assert.Equal(Galdhopiggen.Longitude, sample.Longitude);
        Assert.Equal(2468.25m, sample.ElevationMeters);
        Assert.Equal("dtm1", sample.Datakilde);
        Assert.Equal("ÅpentOmråde", sample.Terreng);
    }

    [Fact]
    public async Task Treats_no_coverage_as_an_answer_rather_than_a_failure()
    {
        var handler = new StubHandler(_ => Json(
            """{"koordsys":4258,"punkter":[{"datakilde":null,"terreng":null,"x":8.312477,"y":61.636440,"z":null}]}"""));

        var sample = Assert.Single(await Client(handler).SampleAsync([Galdhopiggen], CancellationToken.None));

        // Cached as a null so the next run does not ask again and get the same nothing.
        Assert.Null(sample.ElevationMeters);
        Assert.Null(sample.Datakilde);
    }

    [Fact]
    public async Task Accepts_a_shortened_echo_of_the_same_number()
    {
        // The service drops trailing zeros: 61.636440 comes back as 61.63644.
        var handler = new StubHandler(_ => Json(
            """{"koordsys":4258,"punkter":[{"datakilde":"dtm1","terreng":"Skog","x":8.312477,"y":61.63644,"z":1000}]}"""));

        var sample = Assert.Single(await Client(handler).SampleAsync([Galdhopiggen], CancellationToken.None));

        Assert.Equal(1000m, sample.ElevationMeters);
    }

    [Fact]
    public async Task Refuses_a_response_that_does_not_line_up_with_the_request()
    {
        // A shifted response is the severe silent failure: every peak would get its
        // neighbour's elevation and nothing downstream could tell. The echoed coordinates make
        // that cheap to detect, so it is detected.
        var handler = new StubHandler(_ => Json(
            """{"koordsys":4258,"punkter":[{"datakilde":"dtm1","terreng":"Skog","x":9.000000,"y":62.000000,"z":500}]}"""));

        var exception = await Assert.ThrowsAsync<HoydedataException>(
            () => Client(handler).SampleAsync([Galdhopiggen], CancellationToken.None));

        Assert.Contains("does not line up", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Refuses_a_response_with_the_wrong_number_of_answers()
    {
        var handler = new StubHandler(_ => Json("""{"koordsys":4258,"punkter":[]}"""));

        await Assert.ThrowsAsync<HoydedataException>(
            () => Client(handler).SampleAsync([Galdhopiggen], CancellationToken.None));
    }

    [Fact]
    public async Task Reports_an_error_status_with_the_body()
    {
        var handler = new StubHandler(_ => Json(
            """{"errors":{"message":"Man kan sende inn maksimum 50 koordinater"}}""", HttpStatusCode.UnprocessableEntity));

        var exception = await Assert.ThrowsAsync<HoydedataException>(
            () => Client(handler).SampleAsync([Galdhopiggen], CancellationToken.None));

        Assert.Equal(HttpStatusCode.UnprocessableEntity, exception.StatusCode);
        Assert.Contains("maksimum 50", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Refuses_a_batch_larger_than_the_service_accepts()
    {
        var handler = new StubHandler(_ => Json("""{"koordsys":4258,"punkter":[]}"""));
        var tooMany = Enumerable.Range(0, HoydedataClient.MaxPointsPerRequest + 1)
            .Select(i => new SsrPoint(60m + (i * 0.001m), 8m)).ToList();

        // Caught here rather than spending a round trip to be told 422 by the service.
        await Assert.ThrowsAsync<ArgumentException>(
            () => Client(handler).SampleAsync(tooMany, CancellationToken.None));
    }

    [Fact]
    public async Task Sends_nothing_for_an_empty_batch()
    {
        var handler = new StubHandler(_ => Json("""{"koordsys":4258,"punkter":[]}"""));

        Assert.Empty(await Client(handler).SampleAsync([], CancellationToken.None));
        Assert.Empty(handler.Requests);
    }
}
