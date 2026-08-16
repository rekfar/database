-- The rule that decides which SSR points qualify as a peak (FR-REF-11, ADR-0012 §5.1).
--
-- Kartverket publishes place names, not an editorial notion of "a summit worth
-- visiting", so this judgement is ours to make and ours to document. Recording it as
-- data — and stamping each peak with the rule version that admitted it — is what makes
-- the catalogue reproducible and lets a rule change be re-run and diffed rather than
-- silently reinterpreted.
--
-- Ships empty on purpose: the first rule version cannot be seeded until the rule is
-- decided, which is a prerequisite for the Phase 1 catalogue seed, not for this schema.
CREATE TABLE [ref].PeakRule
(
    [Version]           varchar(20)     NOT NULL,
    [Description]       nvarchar(1000)  NOT NULL,
    MinElevationMeters  int             NULL,
    MinProminenceMeters int             NULL,
    DocumentedAt        datetime2(3)    NOT NULL    CONSTRAINT DF_ref_PeakRule_DocumentedAt DEFAULT SYSUTCDATETIME(),
    DocumentUrl         nvarchar(400)   NULL,

    CONSTRAINT PK_ref_PeakRule PRIMARY KEY CLUSTERED ([Version]),
    CONSTRAINT CK_ref_PeakRule_Thresholds CHECK (MinElevationMeters IS NOT NULL OR MinProminenceMeters IS NOT NULL)
);
