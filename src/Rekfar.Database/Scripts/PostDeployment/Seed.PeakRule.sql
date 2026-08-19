/*
    The rule that decides which SSR places qualify as peaks (FR-REF-11, ADR-0012 §5.1).

    Kartverket publishes place names, not an editorial notion of "a summit worth visiting",
    so this judgement is ours. Recording it as data — and stamping every peak with the rule
    version that admitted it — is what makes the catalogue reproducible and lets a change be
    re-run and diffed rather than silently reinterpreted.

    The reasoning behind version 1.0, and the measurements it was chosen against, are in
    docs/peak-rule.md. In short: the navneobjekttype filter is the editorial rule, and the
    elevation floor is a sanity guard against sea-level artefacts rather than a curation
    device.

    A PUBLISHED VERSION IS NOT EDITED. Peaks carry the version that admitted them, so
    changing 1.0's threshold would silently reinterpret rows already stamped with it and
    make the catalogue unreproducible. A different rule is a new version and a re-merge —
    which is cheap, because staging and the elevation cache both survive it.
*/

MERGE INTO [ref].PeakRule AS target
USING
(
    VALUES
    (
        '1.0',
        N'SSR places of navneobjekttype fjell or topp, within mainland Norway, whose highest '
        + N'representation point samples at 100 m or more in Kartverket''s terrain model. '
        + N'Elevation is the maximum over the place''s points, ignoring answers from a '
        + N'bathymetric source. The type filter is the editorial rule; the floor removes '
        + N'sea-level artefacts rather than curating.',
        100,
        NULL,
        N'https://github.com/rekfar/database/blob/main/docs/peak-rule.md'
    )
) AS source ([Version], [Description], MinElevationMeters, MinProminenceMeters, DocumentUrl)
ON target.[Version] = source.[Version]
WHEN MATCHED AND
(
    target.[Description] <> source.[Description]
    OR ISNULL(target.MinElevationMeters, -1) <> ISNULL(source.MinElevationMeters, -1)
    OR ISNULL(target.MinProminenceMeters, -1) <> ISNULL(source.MinProminenceMeters, -1)
    OR ISNULL(target.DocumentUrl, N'') <> ISNULL(source.DocumentUrl, N'')
)
THEN UPDATE SET
    [Description]       = source.[Description],
    MinElevationMeters  = source.MinElevationMeters,
    MinProminenceMeters = source.MinProminenceMeters,
    DocumentUrl         = source.DocumentUrl
WHEN NOT MATCHED BY TARGET
THEN INSERT ([Version], [Description], MinElevationMeters, MinProminenceMeters, DocumentUrl)
     VALUES (source.[Version], source.[Description], source.MinElevationMeters, source.MinProminenceMeters, source.DocumentUrl);

/*
    The navneobjekttype values version 1.0 admits.

    Lower case, exactly as the GML publishes them — the API's own documentation capitalises
    them, but what ingestion compares against is what is in the file. The database collation
    is case-insensitive, so this is a matter of matching the source rather than of
    correctness.

    Scoped to version 1.0 on both sides, so seeding a later version never disturbs this one.
*/
MERGE INTO [ref].PeakRuleObjectType AS target
USING
(
    VALUES ('1.0', N'fjell'), ('1.0', N'topp')
) AS source (PeakRuleVersion, NavneobjektType)
ON  target.PeakRuleVersion = source.PeakRuleVersion
AND target.NavneobjektType = source.NavneobjektType
WHEN NOT MATCHED BY TARGET
THEN INSERT (PeakRuleVersion, NavneobjektType) VALUES (source.PeakRuleVersion, source.NavneobjektType)
WHEN NOT MATCHED BY SOURCE AND target.PeakRuleVersion = '1.0'
THEN DELETE;
