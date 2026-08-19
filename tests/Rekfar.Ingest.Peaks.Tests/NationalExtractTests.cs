using System.Diagnostics;
using Rekfar.Ingest.Peaks.Ssr;
using Xunit;
using Xunit.Abstractions;

namespace Rekfar.Ingest.Peaks.Tests;

/// <summary>
/// Runs the parser over a real whole-country extract — the thing the fixture cannot prove.
/// </summary>
/// <remarks>
/// Opt-in: set <c>REKFAR_SSR_EXTRACT</c> to the path of an unpacked
/// <c>Basisdata_0000_Norge_4258_Stedsnavn_GML.gml</c>. Skipped otherwise, so CI and a normal
/// <c>dotnet test</c> stay fast and need no 138 MB download. Its value is the two properties a
/// 30 KB fixture can never demonstrate: that memory stays flat across a million features, and
/// that the counts match what the extract actually contains.
/// </remarks>
public sealed class NationalExtractTests(ITestOutputHelper output)
{
    private const string ExtractPathVariable = "REKFAR_SSR_EXTRACT";

    [Fact]
    public async Task Streams_the_national_extract_without_accumulating_memory()
    {
        var path = Environment.GetEnvironmentVariable(ExtractPathVariable);
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            output.WriteLine($"Skipped: set {ExtractPathVariable} to an unpacked national extract to run this.");
            return;
        }

        var reader = new SsrGmlReader(["fjell", "topp"]);
        await using var stream = File.OpenRead(path);

        var stopwatch = Stopwatch.StartNew();
        var before = GC.GetTotalAllocatedBytes();
        var places = 0;
        var points = 0;

        await foreach (var place in reader.ReadAsync(stream))
        {
            places++;
            points += place.Points.Count;
        }

        stopwatch.Stop();

        output.WriteLine($"file            {new FileInfo(path).Length / 1024 / 1024} MB");
        output.WriteLine($"features read   {reader.FeaturesRead:N0}");
        output.WriteLine($"peaks emitted   {places:N0}");
        output.WriteLine($"points          {points:N0}");
        output.WriteLine($"no geometry     {reader.PlacesWithoutGeometry:N0}");
        output.WriteLine($"product spec    {reader.ProductSpecVersion}");
        output.WriteLine($"extracted at    {reader.ExtractedAt:O}");
        output.WriteLine($"elapsed         {stopwatch.Elapsed.TotalSeconds:F1} s");
        output.WriteLine($"allocated       {(GC.GetTotalAllocatedBytes() - before) / 1024 / 1024:N0} MB total");
        output.WriteLine($"live heap       {GC.GetTotalMemory(forceFullCollection: true) / 1024 / 1024:N0} MB at end");

        // Measured against the 2026-08-14 extract. Loose bounds on purpose: these assert that
        // parsing has not broken, not that Kartverket has stopped publishing new places.
        Assert.InRange(reader.FeaturesRead, 900_000, 1_300_000);
        Assert.InRange(places, 25_000, 40_000);
        Assert.InRange(points, 50_000, 90_000);
        Assert.Equal("StedsnavnForVanligBruk 20231001", reader.ProductSpecVersion);

        // The live heap is the assertion that matters: a reader that accumulated would be
        // holding hundreds of megabytes by now.
        Assert.True(GC.GetTotalMemory(forceFullCollection: true) < 100L * 1024 * 1024);
    }
}
