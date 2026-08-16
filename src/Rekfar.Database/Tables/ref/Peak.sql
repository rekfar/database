-- Mountain tops (fjelltopper), sourced from Kartverket SSR with elevation sampled from
-- Høydedata (FR-REF-5/6/10, ADR-0012).
--
-- Three things about this table are load-bearing:
--   * (SourceDatasetId, ExternalId) is the join key for refresh and reconciliation —
--     the `stedsnummer` is what makes a re-import an update rather than a duplicate.
--   * Elevation is derived, not quoted: SSR carries no height. It travels with the
--     dataset it was sampled from and the date it was sampled, because its accuracy is
--     a property of that sample.
--   * Rows are retired, never deleted. Upstream deletion detection is still an open
--     question (ADR-0012 §5.3), and a peak a user has logged must survive whatever the
--     answer turns out to be.
CREATE TABLE [ref].Peak
(
    Id                          bigint          IDENTITY(1, 1) NOT NULL,
    SourceDatasetId             smallint        NOT NULL,
    ExternalId                  varchar(64)     NOT NULL,
    [Name]                      nvarchar(200)   NOT NULL,
    -- The same name in an accent-insensitive collation, so searching "Galdhopiggen"
    -- finds Galdhøpiggen (FR-PEAK-1). [Name] keeps the database collation so that
    -- sorting still puts æ, ø and å where Norwegian expects them; a single column
    -- cannot do both. Populated by ingestion as a straight copy of [Name].
    --
    -- Deliberately NOT a Norwegian collation. Norwegian treats æ, ø and å as distinct
    -- letters sorting after z, not as accented vowels, so Norwegian_100_CI_AI has no
    -- diacritic to strip and leaves "Galdhopiggen" not matching Galdhøpiggen — the
    -- exact thing this column exists to do. A Western European collation does treat
    -- them as accented forms, which is what makes the fold work. Sorting is unaffected:
    -- that is [Name]'s job, and it keeps the database collation.
    SearchName                  nvarchar(200)   COLLATE Latin1_General_100_CI_AI NOT NULL,
    NavneobjektType             nvarchar(60)    NOT NULL,
    [Location]                  geography       NOT NULL,
    ElevationMeters             int             NULL,
    ElevationSourceDatasetId    smallint        NULL,
    ElevationSampledAt          datetime2(3)    NULL,
    ProminenceMeters            int             NULL,
    -- Which version of the peak-qualification rule admitted this row (FR-REF-11).
    PeakRuleVersion             varchar(20)     NULL,
    -- Optional outbound link to a human-written description (FR-REF-7). Nullable, and
    -- every view must render without it: UT.no is a link target, never a data source.
    UtnoUrl                     nvarchar(400)   NULL,
    FetchedAt                   datetime2(3)    NOT NULL,
    IsActive                    bit             NOT NULL    CONSTRAINT DF_ref_Peak_IsActive DEFAULT 1,
    RetiredAt                   datetime2(3)    NULL,

    CONSTRAINT PK_ref_Peak PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_ref_Peak_Source UNIQUE (SourceDatasetId, ExternalId),
    CONSTRAINT FK_ref_Peak_SourceDataset FOREIGN KEY (SourceDatasetId) REFERENCES [ref].SourceDataset (Id),
    CONSTRAINT FK_ref_Peak_ElevationSourceDataset FOREIGN KEY (ElevationSourceDatasetId) REFERENCES [ref].SourceDataset (Id),
    CONSTRAINT FK_ref_Peak_PeakRule FOREIGN KEY (PeakRuleVersion) REFERENCES [ref].PeakRule ([Version]),
    -- Canonical storage is WGS84 and nothing else; transforms happen at ingestion and at
    -- the map layer (NFR-INTEROP-2, ADR-0010). Enforced rather than assumed, because a
    -- wrong-SRID row is invisible until a spatial query silently returns nothing.
    CONSTRAINT CK_ref_Peak_LocationSrid CHECK (Location.STSrid = 4326),
    -- Norway's highest point is 2469 m; the range is a sanity guard on a sampled value.
    CONSTRAINT CK_ref_Peak_ElevationMeters CHECK (ElevationMeters BETWEEN -10 AND 2600),
    CONSTRAINT CK_ref_Peak_ProminenceMeters CHECK (ProminenceMeters >= 0),
    CONSTRAINT CK_ref_Peak_ElevationProvenance CHECK (ElevationMeters IS NULL OR (ElevationSourceDatasetId IS NOT NULL AND ElevationSampledAt IS NOT NULL)),
    CONSTRAINT CK_ref_Peak_Retired CHECK ((IsActive = 1 AND RetiredAt IS NULL) OR (IsActive = 0 AND RetiredAt IS NOT NULL))
);
GO

-- "Peaks in the current map extent" is the query the map issues on every pan and zoom
-- (FR-MAP-5, NFR-PERF-2). AUTO_GRID lets SQL Server pick the tessellation; for points
-- spread across Norway there is nothing to hand-tune.
CREATE SPATIAL INDEX SIX_ref_Peak_Location
    ON [ref].Peak ([Location]) USING GEOGRAPHY_AUTO_GRID;
GO

-- Name search (FR-PEAK-1), covering enough to render a result list without a lookup.
CREATE INDEX IX_ref_Peak_SearchName
    ON [ref].Peak (SearchName)
    INCLUDE ([Name], ElevationMeters, IsActive);
