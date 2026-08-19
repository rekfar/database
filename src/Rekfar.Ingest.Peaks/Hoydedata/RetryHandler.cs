using System.Net;
using Microsoft.Extensions.Logging;

namespace Rekfar.Ingest.Peaks.Hoydedata;

/// <summary>
/// Retries transient Høydedata failures with exponential backoff.
/// </summary>
/// <remarks>
/// <para>
/// A run makes on the order of 1,150 requests to a free public service, so it will meet the
/// occasional timeout or 503 whatever the service's quality. Retrying here rather than around
/// the whole stage keeps a single bad request from costing the batch — and because every
/// successful batch is cached before the next is attempted, even a run that eventually fails
/// leaves its progress behind.
/// </para>
/// <para>
/// Only failures worth repeating are repeated. A 422 means the request itself is wrong
/// (too many coordinates, a malformed pair) and will be just as wrong next time.
/// </para>
/// </remarks>
internal sealed class RetryHandler(
    ILogger<RetryHandler> logger, int maxAttempts = 5, TimeSpan? firstDelay = null) : DelegatingHandler
{
    // Injectable so the tests can exercise the retry logic without sleeping through it.
    private readonly TimeSpan _firstDelay = firstDelay ?? TimeSpan.FromSeconds(1);

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        for (var attempt = 1; ; attempt++)
        {
            HttpResponseMessage? response = null;
            Exception? failure = null;

            try
            {
                response = await base.SendAsync(request, cancellationToken).ConfigureAwait(false);

                if (!IsTransient(response.StatusCode))
                {
                    return response;
                }
            }
            catch (HttpRequestException ex)
            {
                failure = ex;
            }
            catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
            {
                // The request timed out rather than the run being cancelled.
                failure = ex;
            }

            if (attempt >= maxAttempts)
            {
                response?.Dispose();

                if (failure is not null)
                {
                    throw failure;
                }

                // Out of attempts on a transient status: re-send once more and let the caller
                // see the real response rather than inventing an exception here.
                return await base.SendAsync(request, cancellationToken).ConfigureAwait(false);
            }

            var delay = DelayFor(attempt, response, _firstDelay);
            var reason = failure?.GetType().Name ?? ((int)response!.StatusCode).ToString(System.Globalization.CultureInfo.InvariantCulture);
            response?.Dispose();

            logger.LogWarning(
                "Høydedata request failed ({Reason}); retrying in {Delay:0.0}s, attempt {Attempt} of {MaxAttempts}.",
                reason, delay.TotalSeconds, attempt + 1, maxAttempts);

            await Task.Delay(delay, cancellationToken).ConfigureAwait(false);
        }
    }

    private static bool IsTransient(HttpStatusCode status)
        => status is HttpStatusCode.RequestTimeout
            or HttpStatusCode.TooManyRequests
            or HttpStatusCode.InternalServerError
            or HttpStatusCode.BadGateway
            or HttpStatusCode.ServiceUnavailable
            or HttpStatusCode.GatewayTimeout;

    /// <summary>
    /// Exponential backoff with jitter, except when the service says how long to wait — being
    /// told to back off and then ignoring it is how a client earns a block.
    /// </summary>
    private static TimeSpan DelayFor(int attempt, HttpResponseMessage? response, TimeSpan firstDelay)
    {
        var retryAfter = response?.Headers.RetryAfter;
        if (retryAfter?.Delta is { } delta)
        {
            return delta;
        }

        if (retryAfter?.Date is { } date)
        {
            var wait = date - DateTimeOffset.UtcNow;
            if (wait > TimeSpan.Zero)
            {
                return wait;
            }
        }

        var backoff = firstDelay * Math.Pow(2, attempt - 1);
        var jitter = backoff > TimeSpan.Zero ? TimeSpan.FromMilliseconds(Random.Shared.Next(0, 500)) : TimeSpan.Zero;
        return backoff + jitter;
    }
}
