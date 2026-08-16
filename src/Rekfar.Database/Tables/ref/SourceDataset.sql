-- Provenance for every reference row: which published dataset it came from, which
-- product-specification version we parsed, and what licence and attribution apply
-- (FR-REF-3/5, NFR-LEGAL-2, ADR-0012 §3).
--
-- Ids are assigned rather than IDENTITY: they are stable, seeded values that ingestion
-- code and the API refer to by meaning, and they must be identical in every
-- environment. See Scripts/PostDeployment/Seed.SourceDataset.sql.
CREATE TABLE [ref].SourceDataset
(
    Id                  smallint        NOT NULL,
    Code                varchar(32)     NOT NULL,
    [Name]              nvarchar(120)   NOT NULL,
    Provider            nvarchar(60)    NOT NULL    CONSTRAINT DF_ref_SourceDataset_Provider DEFAULT N'Kartverket',
    -- Pinned deliberately: the roadmap's mitigation for an upstream schema change is to
    -- know which specification version the ingestion code was written against.
    ProductSpecVersion  nvarchar(40)    NULL,
    LicenceCode         varchar(32)     NOT NULL,
    Attribution         nvarchar(120)   NOT NULL,
    SourceUrl           nvarchar(400)   NULL,

    CONSTRAINT PK_ref_SourceDataset PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_ref_SourceDataset_Code UNIQUE (Code)
);
