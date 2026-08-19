using System.Globalization;
using System.Runtime.CompilerServices;
using System.Xml;
using System.Xml.Linq;

namespace Rekfar.Ingest.Peaks.Ssr;

/// <summary>
/// Streams places out of a Kartverket SSR GML extract.
/// </summary>
/// <remarks>
/// <para>
/// The whole-country extract is roughly 2.6 GB of XML, so it is read one feature at a time
/// and never held in memory as a document. Each feature is small — a few kilobytes — so
/// within a feature it is worth the convenience of LINQ to XML; it is only across features
/// that streaming matters.
/// </para>
/// <para>
/// Two things are checked rather than assumed, because both fail silently otherwise: the
/// product specification the file declares, and the coordinate reference system. See
/// <see cref="ProductSpecVersion"/> and <see cref="RequiredEpsgCode"/>.
/// </para>
/// </remarks>
internal sealed class SsrGmlReader
{
    /// <summary>
    /// ETRS89 geographic, which is what the import expects and stores as SRID 4326 (ADR-0016).
    /// </summary>
    /// <remarks>
    /// Kartverket publishes the same data in UTM projections too, under names differing by
    /// four characters. Downloading the wrong one produces coordinates that parse perfectly
    /// and are wholly wrong, so the file is required to say which it is.
    /// </remarks>
    public const int RequiredEpsgCode = 4258;

    private static readonly XNamespace Gml = "http://www.opengis.net/gml/3.2";

    private readonly HashSet<string> _includedTypes;

    /// <param name="includedNavneobjektTypes">
    /// The <c>navneobjekttype</c> values to emit. Everything else is skipped — the extract is
    /// 97% places that are not peaks.
    /// </param>
    public SsrGmlReader(IEnumerable<string> includedNavneobjektTypes)
    {
        ArgumentNullException.ThrowIfNull(includedNavneobjektTypes);
        _includedTypes = new HashSet<string>(includedNavneobjektTypes, StringComparer.OrdinalIgnoreCase);
    }

    /// <summary>
    /// The product specification the file declares, as <c>"StedsnavnForVanligBruk 20231001"</c>,
    /// read from the root element's namespace. Null until reading starts.
    /// </summary>
    /// <remarks>
    /// Taken from the file rather than from configuration precisely so that an upstream
    /// specification change announces itself in the thing being parsed. It is what gets
    /// recorded as the run's source version and compared against the seeded pin.
    /// </remarks>
    public string? ProductSpecVersion { get; private set; }

    /// <summary>The extract's own <c>datauttaksdato</c> — when Kartverket generated the file.</summary>
    public DateTime? ExtractedAt { get; private set; }

    /// <summary>Every feature seen, including the ones filtered out by type.</summary>
    public int FeaturesRead { get; private set; }

    /// <summary>Places of an included type that carry no representation point at all.</summary>
    public int PlacesWithoutGeometry { get; private set; }

    public async IAsyncEnumerable<SsrPlace> ReadAsync(
        Stream stream, [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(stream);

        var settings = new XmlReaderSettings
        {
            Async = true,
            IgnoreWhitespace = true,
            IgnoreComments = true,
            // The extract references a schema on skjema.geonorge.no. Resolving it would turn
            // parsing into a network operation, and a DTD is a well-known attack surface even
            // for a file from a trusted source.
            DtdProcessing = DtdProcessing.Prohibit,
            XmlResolver = null,
        };

        using var reader = XmlReader.Create(stream, settings);

        XNamespace? app = null;

        while (await reader.ReadAsync().ConfigureAwait(false))
        {
            cancellationToken.ThrowIfCancellationRequested();

            if (reader.NodeType != XmlNodeType.Element)
            {
                continue;
            }

            // The application namespace carries the product specification version, so it is
            // looked up rather than hardcoded — a new version must not be silently ignored.
            app ??= ResolveApplicationNamespace(reader);

            if (app is null || reader.LocalName != "Sted" || reader.NamespaceURI != app.NamespaceName)
            {
                continue;
            }

            var element = (XElement)(await XNode.ReadFromAsync(reader, cancellationToken).ConfigureAwait(false));
            FeaturesRead++;

            ExtractedAt ??= ParseTimestamp(element.Element(app + "datauttaksdato")?.Value);

            var type = element.Element(app + "navneobjekttype")?.Value;
            if (type is null || !_includedTypes.Contains(type))
            {
                continue;
            }

            var place = ToPlace(element, app, type);
            if (place.Points.Count == 0)
            {
                PlacesWithoutGeometry++;
            }

            yield return place;
        }
    }

    private XNamespace? ResolveApplicationNamespace(XmlReader reader)
    {
        var uri = reader.LookupNamespace("app");
        if (uri is null)
        {
            return null;
        }

        ProductSpecVersion = ToProductSpecVersion(uri);
        return XNamespace.Get(uri);
    }

    /// <summary>
    /// Turns the namespace into the pinned form, e.g.
    /// <c>.../produktspesifikasjon/StedsnavnForVanligBruk/20231001</c> becomes
    /// <c>StedsnavnForVanligBruk 20231001</c>.
    /// </summary>
    private static string ToProductSpecVersion(string namespaceUri)
    {
        var segments = namespaceUri.TrimEnd('/').Split('/');
        return segments.Length >= 2
            ? $"{segments[^2]} {segments[^1]}"
            : namespaceUri;
    }

    private static SsrPlace ToPlace(XElement element, XNamespace app, string type)
    {
        var kommune = element.Element(app + "kommune")?.Element(app + "Kommune");
        var selected = PlaceNameSelector.Select(ReadCandidateNames(element, app), element.Element(app + "språkprioritering")?.Value);

        return new SsrPlace
        {
            // stedsnummer is the documented external id; lokalId carries the same value, but
            // only one of them is what ADR-0012 named as the join key.
            Stedsnummer = element.Element(app + "stedsnummer")?.Value
                ?? throw new InvalidDataException("A Sted element has no stedsnummer."),
            Name = selected?.Name ?? throw new InvalidDataException(
                $"Place {element.Element(app + "stedsnummer")?.Value} has no usable name."),
            Sprak = selected?.Sprak,
            Navnestatus = selected?.Navnestatus,
            SkrivemateStatus = selected?.SkrivemateStatus,
            NavneobjektType = type,
            NavneobjektGruppe = element.Element(app + "navneobjektgruppe")?.Value ?? string.Empty,
            Kommunenummer = kommune?.Element(app + "kommunenummer")?.Value,
            Kommunenavn = kommune?.Element(app + "kommunenavn")?.Value,
            Fylkesnummer = kommune?.Element(app + "fylkesnummer")?.Value,
            Fylkesnavn = kommune?.Element(app + "fylkesnavn")?.Value,
            UpdatedUpstreamAt = ParseTimestamp(element.Element(app + "oppdateringsdato")?.Value),
            Points = ReadPoints(element, app),
        };
    }

    private static List<CandidateName> ReadCandidateNames(XElement element, XNamespace app)
    {
        var names = new List<CandidateName>();

        foreach (var stedsnavn in element.Elements(app + "stedsnavn").Elements(app + "Stedsnavn"))
        {
            var spellings = stedsnavn
                .Elements(app + "skrivemåte")
                .Elements(app + "Skrivemåte")
                .Select(s => new CandidateSpelling(
                    s.Element(app + "komplettskrivemåte")?.Value ?? string.Empty,
                    s.Element(app + "skrivemåtestatus")?.Value,
                    ParseInt(s.Element(app + "skrivemåtenummer")?.Value)))
                .ToList();

            names.Add(new CandidateName
            {
                Sprak = stedsnavn.Element(app + "språk")?.Value,
                Navnestatus = stedsnavn.Element(app + "navnestatus")?.Value,
                Stedsnavnnummer = ParseInt(stedsnavn.Element(app + "stedsnavnnummer")?.Value),
                Spellings = spellings,
            });
        }

        return names;
    }

    /// <summary>
    /// Reads every representation point. Only <c>posisjon</c> and <c>multipunkt</c> are
    /// considered: a place may also carry line or surface geometry, whose coordinates live in
    /// <c>gml:posList</c> and are not points at all.
    /// </summary>
    private static List<SsrPoint> ReadPoints(XElement element, XNamespace app)
    {
        var points = new List<SsrPoint>();

        foreach (var container in element.Elements(app + "posisjon").Concat(element.Elements(app + "multipunkt")))
        {
            foreach (var point in container.Descendants(Gml + "Point"))
            {
                AssertCoordinateSystem(point);

                var pos = point.Element(Gml + "pos")?.Value;
                if (pos is not null)
                {
                    points.Add(ParsePoint(pos));
                }
            }
        }

        return points;
    }

    /// <summary>
    /// Requires EPSG:4258. The srsName may sit on the point or on the multipoint that contains
    /// it, so the nearest ancestor carrying one wins.
    /// </summary>
    private static void AssertCoordinateSystem(XElement point)
    {
        var srsName = point
            .AncestorsAndSelf()
            .Select(e => (string?)e.Attribute("srsName"))
            .FirstOrDefault(v => v is not null);

        if (srsName is null)
        {
            return;
        }

        var code = srsName[(srsName.LastIndexOf(':') + 1)..];
        if (!int.TryParse(code, NumberStyles.Integer, CultureInfo.InvariantCulture, out var epsg) || epsg != RequiredEpsgCode)
        {
            throw new InvalidDataException(
                $"The extract declares {srsName}, but this import requires EPSG:{RequiredEpsgCode}. It is the wrong projection of the dataset.");
        }
    }

    /// <summary>
    /// Parses a <c>gml:pos</c>. The order is latitude then longitude: the extract declares
    /// <c>urn:ogc:def:crs:EPSG::4258</c>, whose axis order is north then east. Reading the pair
    /// the other way round yields coordinates that are individually valid and silently wrong.
    /// </summary>
    private static SsrPoint ParsePoint(string pos)
    {
        var parts = pos.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length < 2)
        {
            throw new InvalidDataException($"Could not read a coordinate pair from '{pos}'.");
        }

        return new SsrPoint(
            decimal.Parse(parts[0], CultureInfo.InvariantCulture),
            decimal.Parse(parts[1], CultureInfo.InvariantCulture));
    }

    private static int? ParseInt(string? value)
        => int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) ? parsed : null;

    private static DateTime? ParseTimestamp(string? value)
        => DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed)
            ? parsed.UtcDateTime
            : null;
}
