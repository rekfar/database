/*
    The four Kartverket datasets Rekfar sources reference data from (ADR-0012 §3).

    Ids are fixed and meaningful — ingestion code and tests refer to them — so they are
    asserted here rather than generated. All four are free products under CC BY 4.0,
    which is why one attribution string covers every one of them (NFR-LEGAL-2).

    ProductSpecVersion stays NULL until the ingestion job for a dataset is written and
    pins the specification version it parses against.
*/

MERGE INTO [ref].SourceDataset AS target
USING
(
    VALUES
        (1, 'ssr',          N'Stedsnavn (komplett SSR)',                'CC-BY-4.0', N'© Kartverket', N'https://kartkatalog.geonorge.no/metadata/stedsnavn-komplett-ssr/08e96235-0166-4161-97bb-cb64c09f50eb'),
        (2, 'hoydedata',    N'Høydedata (DTM)',                         'CC-BY-4.0', N'© Kartverket', N'https://www.kartverket.no/en/api-and-data/terrengdata'),
        (3, 'n50',          N'N50 Kartdata',                            'CC-BY-4.0', N'© Kartverket', N'https://register.geonorge.no/det-offentlige-kartgrunnlaget/n50-kartdata/ea192681-d039-42ec-b1bc-f3ce04c189ac'),
        (4, 'turrutebasen', N'Tur- og friluftsruter (Turrutebasen)',    'CC-BY-4.0', N'© Kartverket', N'https://register.geonorge.no/det-offentlige-kartgrunnlaget/tur-og-friluftsruter/d1422d17-6d95-4ef1-96ab-8af31744dd63')
) AS source (Id, Code, [Name], LicenceCode, Attribution, SourceUrl)
ON target.Id = source.Id
WHEN MATCHED AND
(
    target.Code         <> source.Code
    OR target.[Name]    <> source.[Name]
    OR target.LicenceCode <> source.LicenceCode
    OR target.Attribution <> source.Attribution
    OR ISNULL(target.SourceUrl, N'') <> source.SourceUrl
)
THEN UPDATE SET
    Code        = source.Code,
    [Name]      = source.[Name],
    LicenceCode = source.LicenceCode,
    Attribution = source.Attribution,
    SourceUrl   = source.SourceUrl
WHEN NOT MATCHED BY TARGET
THEN INSERT (Id, Code, [Name], LicenceCode, Attribution, SourceUrl)
     VALUES (source.Id, source.Code, source.[Name], source.LicenceCode, source.Attribution, source.SourceUrl);
