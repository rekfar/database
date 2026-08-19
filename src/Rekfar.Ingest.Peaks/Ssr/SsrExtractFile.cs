using System.IO.Compression;

namespace Rekfar.Ingest.Peaks.Ssr;

/// <summary>
/// Opens an SSR extract for reading, whether it is the published <c>.zip</c> or an already
/// unpacked <c>.gml</c>.
/// </summary>
/// <remarks>
/// Kartverket distributes the extract as a 138 MB zip containing a single 2.5 GB GML file.
/// Reading it straight out of the archive avoids unpacking twenty times its size to disk, and
/// costs nothing: the parser streams either way.
/// </remarks>
internal sealed class SsrExtractFile : IDisposable
{
    private readonly FileStream _file;
    private readonly ZipArchive? _archive;

    private SsrExtractFile(FileStream file, ZipArchive? archive, Stream content, string name)
    {
        _file = file;
        _archive = archive;
        Content = content;
        Name = name;
    }

    /// <summary>The GML itself, ready to stream.</summary>
    public Stream Content { get; }

    /// <summary>The name of the GML, for logging — inside the archive when there is one.</summary>
    public string Name { get; }

    public static SsrExtractFile Open(string path)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);

        var file = File.OpenRead(path);

        if (!path.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
        {
            return new SsrExtractFile(file, archive: null, file, Path.GetFileName(path));
        }

        try
        {
            var archive = new ZipArchive(file, ZipArchiveMode.Read);
            var entry = archive.Entries.FirstOrDefault(e => e.FullName.EndsWith(".gml", StringComparison.OrdinalIgnoreCase))
                ?? throw new InvalidDataException($"'{path}' contains no .gml file.");

            return new SsrExtractFile(file, archive, entry.Open(), entry.FullName);
        }
        catch
        {
            file.Dispose();
            throw;
        }
    }

    public void Dispose()
    {
        Content.Dispose();
        _archive?.Dispose();
        _file.Dispose();
    }
}
