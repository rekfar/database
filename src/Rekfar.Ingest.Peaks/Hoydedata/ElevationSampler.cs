using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Rekfar.Ingest.Peaks.Database;
using Rekfar.Ingest.Peaks.Ssr;

namespace Rekfar.Ingest.Peaks.Hoydedata;

/// <summary>
/// Fills the elevation cache for everything a run staged.
/// </summary>
/// <remarks>
/// <para>
/// Works in waves: a handful of batches are fetched concurrently, then their results are
/// written together. Concurrency is deliberately small — this is a free public service and
/// the job runs monthly, so there is nothing to gain by leaning on it, and the whole national
/// extract is only about 1,150 requests.
/// </para>
/// <para>
/// Each wave is cached before the next begins, which is what makes the stage resumable: a run
/// that dies partway leaves its samples behind, and the next one asks only about what is still
/// missing.
/// </para>
/// </remarks>
internal sealed class ElevationSampler(
    HoydedataClient client, ILogger<ElevationSampler> logger, int batchSize, int concurrency)
{
    public async Task<ElevationSamplingResult> SampleAsync(
        SqlConnection connection, long runId, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(connection);

        var (total, alreadySampled) = await ElevationSampleStore
            .CountCoverageAsync(connection, runId, cancellationToken).ConfigureAwait(false);

        var missing = await ElevationSampleStore
            .ReadUnsampledPointsAsync(connection, runId, cancellationToken).ConfigureAwait(false);

        logger.LogInformation(
            "{Total} distinct points staged; {Cached} already cached, {Missing} to sample in about {Requests} requests.",
            total, alreadySampled, missing.Count, (missing.Count + batchSize - 1) / batchSize);

        if (missing.Count == 0)
        {
            return new ElevationSamplingResult(total, 0, 0);
        }

        var batches = Chunk(missing, batchSize);
        var sampled = 0;
        var withoutCoverage = 0;

        for (var offset = 0; offset < batches.Count; offset += concurrency)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var wave = batches.Skip(offset).Take(concurrency).ToList();

            var results = await Task.WhenAll(
                wave.Select(batch => client.SampleAsync(batch, cancellationToken))).ConfigureAwait(false);

            var samples = results.SelectMany(r => r).ToList();

            await ElevationSampleStore.SaveAsync(connection, samples, cancellationToken).ConfigureAwait(false);

            sampled += samples.Count;
            withoutCoverage += samples.Count(s => s.ElevationMeters is null);

            // Progress on a stage measured in minutes, at a rate that stays readable in a log.
            if ((offset / concurrency) % 20 == 0 || offset + concurrency >= batches.Count)
            {
                logger.LogInformation(
                    "Sampled {Sampled} of {Missing} points ({Percent:0}%).",
                    sampled, missing.Count, 100.0 * sampled / missing.Count);
            }
        }

        if (withoutCoverage > 0)
        {
            logger.LogInformation(
                "{Count} points have no height in the terrain model; cached as such so they are not asked about again.",
                withoutCoverage);
        }

        return new ElevationSamplingResult(total, sampled, withoutCoverage);
    }

    private static List<List<SsrPoint>> Chunk(List<SsrPoint> points, int size)
    {
        var batches = new List<List<SsrPoint>>((points.Count + size - 1) / size);

        for (var i = 0; i < points.Count; i += size)
        {
            batches.Add(points.GetRange(i, Math.Min(size, points.Count - i)));
        }

        return batches;
    }
}

/// <param name="DistinctPoints">Distinct coordinates the run staged.</param>
/// <param name="NewlySampled">Points asked about this run; the rest were already cached.</param>
/// <param name="WithoutCoverage">Of those, the ones the terrain model has no height for.</param>
internal readonly record struct ElevationSamplingResult(int DistinctPoints, int NewlySampled, int WithoutCoverage);
