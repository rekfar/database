using System.Globalization;
using Microsoft.Extensions.Logging;

namespace Rekfar.Ingest.Peaks.Ssr;

/// <summary>
/// Fetches the published SSR extract from Geonorge.
/// </summary>
/// <remarks>
/// <para>
/// The whole-country file is a direct download — no order API, no key, no account. It is
/// about 138 MB, streamed to a temporary file rather than held in memory, and deleted when
/// the run is done with it.
/// </para>
/// <para>
/// Kartverket republishes it continually, so a scheduled run always takes the current one.
/// Which snapshot was actually read is not inferred from the download: the parser reads
/// <c>datauttaksdato</c> out of the file itself and that is what the run records.
/// </para>
/// </remarks>
internal sealed class SsrExtractDownloader(HttpClient httpClient, ILogger<SsrExtractDownloader> logger)
{
    public async Task<DownloadedExtract> DownloadAsync(string url, CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(url);

        var path = Path.Combine(Path.GetTempPath(), $"rekfar-ssr-{Guid.NewGuid():N}.zip");

        logger.LogInformation("Downloading {Url}.", url);

        try
        {
            using var response = await httpClient
                .GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken)
                .ConfigureAwait(false);

            response.EnsureSuccessStatusCode();

            // Geonorge's Last-Modified is the closest thing the transfer itself offers to a
            // distribution date. Logged rather than recorded, because the authority on which
            // snapshot this is lives inside the file.
            var lastModified = response.Content.Headers.LastModified;
            var expectedBytes = response.Content.Headers.ContentLength;

            await using (var source = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false))
            await using (var destination = File.Create(path))
            {
                await source.CopyToAsync(destination, cancellationToken).ConfigureAwait(false);
            }

            var actualBytes = new FileInfo(path).Length;

            // A truncated download is a plausible failure on a file this size, and a zip that
            // stops early fails later with something far less obvious than this.
            if (expectedBytes is { } expected && actualBytes != expected)
            {
                throw new InvalidDataException(
                    $"The download is {actualBytes} bytes but was declared as {expected}. It is incomplete.");
            }

            logger.LogInformation(
                "Downloaded {Megabytes} MB{Published}.",
                (actualBytes / 1024 / 1024).ToString(CultureInfo.InvariantCulture),
                lastModified is null ? string.Empty : $", published {lastModified:yyyy-MM-dd}");

            return new DownloadedExtract(path, logger);
        }
        catch
        {
            TryDelete(path, logger);
            throw;
        }
    }

    internal static void TryDelete(string path, ILogger logger)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch (IOException ex)
        {
            // Worth saying, not worth failing a completed run over.
            logger.LogWarning("Could not delete the downloaded extract at {Path}: {Reason}", path, ex.Message);
        }
    }
}

/// <summary>A downloaded extract, deleted when the run has finished with it.</summary>
internal sealed class DownloadedExtract(string path, ILogger logger) : IDisposable
{
    public string Path { get; } = path;

    public void Dispose() => SsrExtractDownloader.TryDelete(Path, logger);
}
