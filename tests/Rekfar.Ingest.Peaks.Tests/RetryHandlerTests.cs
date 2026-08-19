using System.Net;
using Microsoft.Extensions.Logging.Abstractions;
using Rekfar.Ingest.Peaks.Hoydedata;
using Xunit;

namespace Rekfar.Ingest.Peaks.Tests;

/// <summary>
/// Retry behaviour, with the backoff collapsed to zero so the suite does not sleep through it.
/// </summary>
public sealed class RetryHandlerTests
{
    private sealed class SequenceHandler(params HttpStatusCode[] statuses) : HttpMessageHandler
    {
        public int Calls { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var status = statuses[Math.Min(Calls, statuses.Length - 1)];
            Calls++;
            return Task.FromResult(new HttpResponseMessage(status));
        }
    }

    private sealed class ThrowingHandler(int failures) : HttpMessageHandler
    {
        public int Calls { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            return Calls <= failures
                ? throw new HttpRequestException("the connection went away")
                : Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK));
        }
    }

    private static HttpClient Client(HttpMessageHandler inner, int maxAttempts = 5)
        => new(new RetryHandler(NullLogger<RetryHandler>.Instance, maxAttempts, TimeSpan.Zero) { InnerHandler = inner })
        {
            BaseAddress = new Uri("https://example.test/"),
        };

    [Theory]
    [InlineData(HttpStatusCode.ServiceUnavailable)]
    [InlineData(HttpStatusCode.TooManyRequests)]
    [InlineData(HttpStatusCode.GatewayTimeout)]
    [InlineData(HttpStatusCode.InternalServerError)]
    public async Task Retries_a_transient_status_until_it_succeeds(HttpStatusCode transient)
    {
        var inner = new SequenceHandler(transient, transient, HttpStatusCode.OK);

        var response = await Client(inner).GetAsync("punkt", CancellationToken.None);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(3, inner.Calls);
    }

    [Fact]
    public async Task Does_not_retry_a_request_that_will_be_just_as_wrong_next_time()
    {
        // 422 is how the service reports too many coordinates or a malformed pair. Repeating
        // it only wastes the service's time and ours.
        var inner = new SequenceHandler(HttpStatusCode.UnprocessableEntity);

        var response = await Client(inner).GetAsync("punkt", CancellationToken.None);

        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
        Assert.Equal(1, inner.Calls);
    }

    [Fact]
    public async Task Retries_a_dropped_connection()
    {
        var inner = new ThrowingHandler(failures: 2);

        var response = await Client(inner).GetAsync("punkt", CancellationToken.None);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(3, inner.Calls);
    }

    [Fact]
    public async Task Gives_up_after_the_attempt_limit_and_surfaces_the_failure()
    {
        var inner = new ThrowingHandler(failures: 100);

        await Assert.ThrowsAsync<HttpRequestException>(
            () => Client(inner, maxAttempts: 3).GetAsync("punkt", CancellationToken.None));

        // Three attempts, not three retries on top of the first.
        Assert.Equal(3, inner.Calls);
    }

    [Fact]
    public async Task Returns_the_last_response_when_a_transient_status_never_clears()
    {
        var inner = new SequenceHandler(HttpStatusCode.ServiceUnavailable);

        var response = await Client(inner, maxAttempts: 3).GetAsync("punkt", CancellationToken.None);

        // The caller gets the real status to report, rather than an exception invented here.
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }
}
