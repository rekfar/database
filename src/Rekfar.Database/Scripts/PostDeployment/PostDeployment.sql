/*
    Post-deployment script — runs after every publish, in every environment.

    Everything here must be idempotent: publishing twice must leave the same state as
    publishing once. Seed only data the schema's meaning depends on (code lists,
    provenance rows). Never seed user data, and never seed reference rows that belong to
    ingestion — those come from Kartverket, not from a script.

    Exactly one post-deployment file is allowed per project, so it includes the rest.
*/

:r ./Seed.SourceDataset.sql
:r ./Seed.PeakRule.sql
