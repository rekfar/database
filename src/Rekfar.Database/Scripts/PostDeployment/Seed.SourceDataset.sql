/*
    The four Kartverket datasets Rekfar sources reference data from (ADR-0012 §3).

    Ids are fixed and meaningful — ingestion code and tests refer to them — so they are
    asserted here rather than generated. All four are free products under CC BY 4.0,
    which is why one attribution string covers every one of them (NFR-LEGAL-2).

    ProductSpecVersion is pinned once the ingestion job for a dataset is written, to the
    specification version that job actually parses against; it stays NULL for the two
    datasets not yet ingested. It is the roadmap's stated mitigation for an upstream
    schema change, so it must name a real published version rather than a guess.

    On the SSR row. ADR-0012 §3 names the "Stedsnavn (komplett SSR)" product, but the
    peak import reads **Stedsnavn** — the "for vanlig bruk" distribution — and this row
    describes what is actually read. The complete register carries every name case ever
    raised, including rejected, superseded and historical spellings; the general-use
    extract carries the names Kartverket publishes for map and general use, which is what
    a peak catalogue wants and what the qualification rule was measured against. The
    stable identifier, the licence and the attribution are identical either way, so the
    Code stays 'ssr' and nothing downstream changes. Recorded in ADR-0016.

    The metadata UUID previously carried on this row (08e96235-…) does not resolve in the
    Geonorge catalogue; the URLs below were each confirmed against the live catalogue.
*/

MERGE INTO [ref].SourceDataset AS target
USING
(
    VALUES
        (1, 'ssr',          N'Stedsnavn',                               N'StedsnavnForVanligBruk 20231001', 'CC-BY-4.0', N'© Kartverket', N'https://kartkatalog.geonorge.no/metadata/stedsnavn/30caed2f-454e-44be-b5cc-26bb5c0110ca'),
        (2, 'hoydedata',    N'Høydedata (DTM)',                         N'Høydedata API v1',                'CC-BY-4.0', N'© Kartverket', N'https://www.kartverket.no/en/api-and-data/terrengdata'),
        (3, 'n50',          N'N50 Kartdata',                            NULL,                               'CC-BY-4.0', N'© Kartverket', N'https://register.geonorge.no/det-offentlige-kartgrunnlaget/n50-kartdata/ea192681-d039-42ec-b1bc-f3ce04c189ac'),
        (4, 'turrutebasen', N'Tur- og friluftsruter (Turrutebasen)',    NULL,                               'CC-BY-4.0', N'© Kartverket', N'https://register.geonorge.no/det-offentlige-kartgrunnlaget/tur-og-friluftsruter/d1422d17-6d95-4ef1-96ab-8af31744dd63')
) AS source (Id, Code, [Name], ProductSpecVersion, LicenceCode, Attribution, SourceUrl)
ON target.Id = source.Id
WHEN MATCHED AND
(
    target.Code         <> source.Code
    OR target.[Name]    <> source.[Name]
    OR ISNULL(target.ProductSpecVersion, N'') <> ISNULL(source.ProductSpecVersion, N'')
    OR target.LicenceCode <> source.LicenceCode
    OR target.Attribution <> source.Attribution
    OR ISNULL(target.SourceUrl, N'') <> source.SourceUrl
)
THEN UPDATE SET
    Code                = source.Code,
    [Name]              = source.[Name],
    ProductSpecVersion  = source.ProductSpecVersion,
    LicenceCode         = source.LicenceCode,
    Attribution         = source.Attribution,
    SourceUrl           = source.SourceUrl
WHEN NOT MATCHED BY TARGET
THEN INSERT (Id, Code, [Name], ProductSpecVersion, LicenceCode, Attribution, SourceUrl)
     VALUES (source.Id, source.Code, source.[Name], source.ProductSpecVersion, source.LicenceCode, source.Attribution, source.SourceUrl);
