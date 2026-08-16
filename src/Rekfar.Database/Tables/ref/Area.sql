-- Administrative or natural groupings used for filtering and statistics: municipality
-- (kommune), region, mountain area (fjellområde) — data architecture §3, FR-PEAK-3,
-- FR-STAT-3.
--
-- Kommuner come from a published dataset and carry an external id (kommunenummer);
-- fjellområder are ours to curate and have none, which is why the uniqueness rule is a
-- filtered index rather than a constraint (a UNIQUE constraint treats NULLs as equal and
-- would permit only one un-sourced area).
CREATE TABLE [ref].Area
(
    Id              int             IDENTITY(1, 1) NOT NULL,
    [Kind]          varchar(20)     NOT NULL,
    [Name]          nvarchar(200)   NOT NULL,
    SourceDatasetId smallint        NULL,
    ExternalId      varchar(64)     NULL,
    -- Optional: not every area needs geometry, and boundaries are large. Peak-to-area
    -- membership is resolved once at ingestion into [ref].PeakArea rather than by
    -- spatial join at query time.
    Boundary        geography       NULL,
    FetchedAt       datetime2(3)    NULL,

    CONSTRAINT PK_ref_Area PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_ref_Area_SourceDataset FOREIGN KEY (SourceDatasetId) REFERENCES [ref].SourceDataset (Id),
    CONSTRAINT CK_ref_Area_Kind CHECK ([Kind] IN ('kommune', 'region', 'fjellomrade')),
    CONSTRAINT CK_ref_Area_BoundarySrid CHECK (Boundary IS NULL OR Boundary.STSrid = 4326),
    CONSTRAINT CK_ref_Area_SourceProvenance CHECK ((SourceDatasetId IS NULL AND ExternalId IS NULL AND FetchedAt IS NULL)
                                                OR (SourceDatasetId IS NOT NULL AND ExternalId IS NOT NULL AND FetchedAt IS NOT NULL))
);
GO

CREATE UNIQUE INDEX UX_ref_Area_Source
    ON [ref].Area (SourceDatasetId, ExternalId)
    WHERE ExternalId IS NOT NULL;
