/*
    Smoke tests for a freshly published Rekfar database.

    These are not unit tests for application logic — they assert the invariants the
    schema itself is supposed to guarantee, the ones that would otherwise be discovered
    in production:

        * ADR-0009's private/public separation cannot be violated by a bad write.
        * Geometry cannot be stored in the wrong coordinate system (NFR-INTEROP-2).
        * Deleting an account really does remove all of its data (FR-ACC-5, GDPR).
        * A reference row a user has logged against cannot be deleted by a refresh,
          but can still be retired by one.
        * Accent-insensitive name search actually works (FR-PEAK-1).
        * Staged coordinates cannot be transposed (the EPSG:4258 axis-order trap).
        * The peak rule is seeded, and a peak can only cite a rule that exists.
        * Pruning an ingestion run takes its staging snapshot with it.
        * The merge admits what the rule admits, and retires rather than deletes.

    Run against a scratch database only. Everything happens in one transaction that is
    rolled back, and the guard below refuses to run if the database holds any accounts.

    Usage:  sqlcmd -b -S <server> -d <database> -i tests/smoke.sql
*/

-- sqlcmd is an ODBC client and connects with QUOTED_IDENTIFIER OFF, unlike SqlPackage
-- and every application driver. SQL Server then refuses any DML against a table with a
-- spatial index or a constraint calling a spatial method — which [ref].Peak has both of
-- — with error 1934. Set here rather than relying on sqlcmd's -I, so the file is correct
-- however it is invoked.
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT OFF;     -- negative tests must abort a statement, not the transaction
GO

IF EXISTS (SELECT 1 FROM auth.[User])
    THROW 50000, 'Refusing to run: this database contains accounts. Smoke tests are for a scratch database.', 1;
GO

DECLARE @failed bit;
DECLARE @count int;
DECLARE @collation nvarchar(128);
DECLARE @message nvarchar(2048);
DECLARE @userId uniqueidentifier = '11111111-1111-1111-1111-111111111111';
DECLARE @tripId uniqueidentifier = '22222222-2222-2222-2222-222222222222';
DECLARE @peakId bigint;
DECLARE @runId bigint;
DECLARE @mergeRunId bigint;
DECLARE @inserted int, @updated int, @retired int;

BEGIN TRY
    BEGIN TRANSACTION;

    /* ---------- schemas ---------- */

    SELECT @count = COUNT(*) FROM sys.schemas WHERE name IN ('auth', 'app', 'ref', 'ingest');
    IF @count <> 4 THROW 50001, 'Expected four schemas: auth, app, ref, ingest.', 1;

    /* ---------- seeded provenance (ADR-0012, NFR-LEGAL-2) ---------- */

    SELECT @count = COUNT(*) FROM [ref].SourceDataset
    WHERE Code IN ('ssr', 'hoydedata', 'n50', 'turrutebasen');
    IF @count <> 4 THROW 50002, 'Expected the four Kartverket datasets to be seeded.', 1;

    SELECT @count = COUNT(*) FROM [ref].SourceDataset WHERE LicenceCode <> 'CC-BY-4.0' OR Attribution <> N'© Kartverket';
    IF @count <> 0 THROW 50003, 'Every seeded dataset must be CC BY 4.0 attributed to Kartverket.', 1;

    -- The roadmap's mitigation for an upstream schema change is knowing which
    -- specification version the ingestion code was written against, so a dataset that has
    -- an ingestion job must name one. The two not yet ingested are expected to be NULL.
    SELECT @count = COUNT(*) FROM [ref].SourceDataset WHERE Code IN ('ssr', 'hoydedata') AND ProductSpecVersion IS NULL;
    IF @count <> 0 THROW 50007, 'An ingested dataset is missing its pinned ProductSpecVersion.', 1;

    /* ---------- the peak rule (FR-REF-11, ADR-0012 §5.1) ---------- */

    -- The schema shipped this table empty on purpose; once a version exists, the catalogue's
    -- reproducibility depends on it being there and on its types being recorded as rows.
    SELECT @count = COUNT(*) FROM [ref].PeakRule WHERE [Version] = '1.0';
    IF @count <> 1 THROW 50008, 'Peak rule 1.0 is not seeded — see docs/peak-rule.md.', 1;

    SELECT @count = COUNT(*) FROM [ref].PeakRuleObjectType
    WHERE PeakRuleVersion = '1.0' AND NavneobjektType IN (N'fjell', N'topp');
    IF @count <> 2 THROW 50009, 'Peak rule 1.0 must admit exactly the fjell and topp types.', 1;

    /* ---------- spatial index on the map's hot query ---------- */

    SELECT @count = COUNT(*)
    FROM sys.spatial_indexes
    WHERE object_id = OBJECT_ID('[ref].Peak') AND name = 'SIX_ref_Peak_Location';
    IF @count <> 1 THROW 50004, 'Missing spatial index on [ref].Peak.Location.', 1;

    /* ---------- collation intent ---------- */

    -- CONVERT is load-bearing. DATABASEPROPERTYEX returns sql_variant, which outranks
    -- varchar in type precedence, so comparing it to a bare literal converts the literal
    -- to sql_variant instead — and sql_variant compares by type family before content.
    -- nvarchar (Unicode) and varchar (ANSI) are different families, so the two are never
    -- equal and the assertion fired on every database, correct collation or not.
    SET @collation = CONVERT(nvarchar(128), DATABASEPROPERTYEX(DB_NAME(), N'Collation'));
    IF @collation <> N'Norwegian_100_CI_AS'
    BEGIN
        SET @message = N'Database collation is ' + ISNULL(@collation, N'(null)')
                     + N', not Norwegian_100_CI_AS — see docs/operations.md.';
        THROW 50005, @message, 1;
    END

    SELECT @count = COUNT(*)
    FROM sys.columns
    WHERE object_id = OBJECT_ID('[ref].Peak') AND name = 'SearchName' AND collation_name = 'Latin1_General_100_CI_AI';
    IF @count <> 1 THROW 50006, '[ref].Peak.SearchName must be accent-insensitive — and not a Norwegian collation, which does not fold ø.', 1;

    /* ---------- a peak cannot cite a rule version that does not exist ---------- */

    SET @failed = 0;
    BEGIN TRY
        INSERT INTO [ref].Peak (SourceDatasetId, ExternalId, [Name], SearchName, NavneobjektType, [Location], PeakRuleVersion, FetchedAt)
        VALUES (1, 'smoke-0004', N'Ingen regel', N'Ingen regel', N'fjell', geography::Point(61.6, 8.3, 4326), '99.9', SYSUTCDATETIME());
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50014, 'A peak was admitted by a rule version that does not exist.', 1;

    /* ---------- fixtures ---------- */

    INSERT INTO auth.[User] (Id, UserName, NormalizedUserName, Email, NormalizedEmail, PasswordHash)
    VALUES (@userId, N'smoke@example.test', N'SMOKE@EXAMPLE.TEST', N'smoke@example.test', N'SMOKE@EXAMPLE.TEST', N'not-a-real-hash');

    INSERT INTO app.[User] (Id, DisplayName)
    VALUES (@userId, N'Smoke Test');

    INSERT INTO [ref].Peak (SourceDatasetId, ExternalId, [Name], SearchName, NavneobjektType, [Location],
                            ElevationMeters, ElevationSourceDatasetId, ElevationSampledAt, FetchedAt)
    VALUES (1, 'smoke-0001', N'Galdhøpiggen', N'Galdhøpiggen', N'Fjell', geography::Point(61.6361, 8.3128, 4326),
            2469, 2, SYSUTCDATETIME(), SYSUTCDATETIME());

    SET @peakId = SCOPE_IDENTITY();

    INSERT INTO app.Trip (Id, UserId, [Status], [Type], [Date], AscentMeters, Difficulty)
    VALUES (@tripId, @userId, 'completed', 'topptur', '2026-07-14', 1300, 'middels');

    INSERT INTO app.TripPeak (TripId, PeakId) VALUES (@tripId, @peakId);
    INSERT INTO app.DiaryNote (TripId, [Text]) VALUES (@tripId, N'Fint vær, kaldt på toppen.');

    /* ---------- defaults ---------- */

    SELECT @count = COUNT(*) FROM app.Trip WHERE Id = @tripId AND Privacy = 'private';
    IF @count <> 1 THROW 50010, 'A trip must default to private (P9, FR-ACC-4).', 1;

    SELECT @count = COUNT(*) FROM app.[User] WHERE Id = @userId AND Locale = 'nb-NO' AND DefaultPrivacy = 'private';
    IF @count <> 1 THROW 50011, 'A profile must default to nb-NO and private.', 1;

    /* ---------- accent-insensitive search (FR-PEAK-1) ---------- */

    SELECT @count = COUNT(*) FROM [ref].Peak WHERE SearchName = N'Galdhopiggen';
    IF @count <> 1 THROW 50012, 'Searching without the ø must still find Galdhøpiggen.', 1;

    SELECT @count = COUNT(*) FROM [ref].Peak WHERE [Name] = N'Galdhopiggen';
    IF @count <> 0 THROW 50013, '[Name] must stay accent-sensitive so Norwegian sorting is preserved.', 1;

    /* ---------- ADR-0009: a diary note cannot be made public ---------- */

    SET @failed = 0;
    BEGIN TRY
        INSERT INTO app.DiaryNote (TripId, [Text], Visibility) VALUES (@tripId, N'should not be allowed', 'public');
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50020, 'A diary note was accepted as public — ADR-0009 separation is not enforced.', 1;

    /* ---------- NFR-INTEROP-2: canonical storage is WGS84 only ---------- */

    SET @failed = 0;
    BEGIN TRY
        INSERT INTO [ref].Peak (SourceDatasetId, ExternalId, [Name], SearchName, NavneobjektType, [Location], FetchedAt)
        VALUES (1, 'smoke-0002', N'Feil projeksjon', N'Feil projeksjon', N'Fjell', geography::Point(61.6, 8.3, 4258), SYSUTCDATETIME());
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50021, 'A peak was accepted with a non-4326 SRID.', 1;

    /* ---------- elevation must carry its provenance ---------- */

    SET @failed = 0;
    BEGIN TRY
        INSERT INTO [ref].Peak (SourceDatasetId, ExternalId, [Name], SearchName, NavneobjektType, [Location], ElevationMeters, FetchedAt)
        VALUES (1, 'smoke-0003', N'Uten kilde', N'Uten kilde', N'Fjell', geography::Point(61.6, 8.3, 4326), 1500, SYSUTCDATETIME());
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50022, 'An elevation was accepted without a source dataset and sampling date.', 1;

    /* ---------- a completed trip must have a date ---------- */

    SET @failed = 0;
    BEGIN TRY
        INSERT INTO app.Trip (UserId, [Status], [Type]) VALUES (@userId, 'completed', 'topptur');
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50023, 'A completed trip was accepted without a date.', 1;

    /* ---------- a planned trip may omit the date (FR-PLAN-1) ---------- */

    INSERT INTO app.Trip (UserId, [Status], [Type]) VALUES (@userId, 'planned', 'topptur');

    /* ---------- glossary code values are the only ones allowed ---------- */

    SET @failed = 0;
    BEGIN TRY
        INSERT INTO app.Trip (UserId, [Status], [Type], [Date]) VALUES (@userId, 'completed', 'hiking', '2026-07-14');
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50024, 'A trip type outside the glossary vocabulary was accepted.', 1;

    /* ---------- a logged peak survives reference refresh ---------- */

    SET @failed = 0;
    BEGIN TRY
        DELETE FROM [ref].Peak WHERE Id = @peakId;
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50025, 'A peak referenced by a logged trip was deletable.', 1;

    /* ---------- …but a refresh must still be able to retire it ---------- */

    -- The other half of the rule above. Retirement in place is the documented behaviour
    -- of a rebuild (docs/operations.md), so if this ever stopped working, a peak the new
    -- rule no longer admits would have nowhere to go.
    UPDATE [ref].Peak SET IsActive = 0, RetiredAt = SYSUTCDATETIME() WHERE Id = @peakId;

    SELECT @count = COUNT(*) FROM app.TripPeak WHERE PeakId = @peakId;
    IF @count <> 1 THROW 50026, 'Retiring a peak lost the trip that logged it.', 1;

    SET @failed = 0;
    BEGIN TRY
        UPDATE [ref].Peak SET IsActive = 0, RetiredAt = NULL WHERE Id = @peakId;
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50027, 'A peak was retired without a retirement date.', 1;

    UPDATE [ref].Peak SET IsActive = 1, RetiredAt = NULL WHERE Id = @peakId;

    /* ---------- ingestion staging ---------- */

    INSERT INTO ingest.[Run] (SourceDatasetId) VALUES (1);
    SET @runId = SCOPE_IDENTITY();

    INSERT INTO ingest.SsrPlace (RunId, Stedsnummer, [Name], NavneobjektType, NavneobjektGruppe, Kommunenummer, PointCount)
    VALUES (@runId, '148421', N'Galdhøpiggen', N'fjell', N'høyder', '3434', 1);

    INSERT INTO ingest.SsrPlacePoint (RunId, Stedsnummer, PointIndex, Latitude, Longitude)
    VALUES (@runId, '148421', 0, 61.636440, 8.312477);

    -- The extract declares urn:ogc:def:crs:EPSG::4258, which puts latitude first. A
    -- parser that reads the pair the other way round produces coordinates that are each
    -- individually valid, so nothing but a bounds check catches it.
    SET @failed = 0;
    BEGIN TRY
        INSERT INTO ingest.SsrPlacePoint (RunId, Stedsnummer, PointIndex, Latitude, Longitude)
        VALUES (@runId, '148421', 1, 8.312477, 61.636440);
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50040, 'A transposed coordinate was accepted into staging.', 1;

    -- A cached height must say which model produced it, for the same reason [ref].Peak
    -- refuses an elevation without its provenance.
    SET @failed = 0;
    BEGIN TRY
        INSERT INTO ingest.ElevationSample (Latitude, Longitude, ElevationMeters)
        VALUES (61.636440, 8.312477, 2462.65);
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50041, 'A cached elevation was accepted without its datakilde.', 1;

    -- The cache is keyed by coordinate and deliberately outlives runs, so on a database that
    -- has really been imported into these coordinates already exist. Clearing them inside the
    -- transaction keeps the fixture independent of whatever else is in the cache; the rollback
    -- puts the real rows back.
    DELETE FROM ingest.ElevationSample
    WHERE (Latitude = 61.636440 AND Longitude = 8.312477)
       OR (Latitude = 61.640680 AND Longitude = 8.306035);

    -- "Asked, and there was no height here" is a real answer and must be cacheable, or
    -- every run re-asks the same uncovered points.
    INSERT INTO ingest.ElevationSample (Latitude, Longitude, ElevationMeters, Datakilde, Terreng)
    VALUES (61.636440, 8.312477, 2462.65, 'dtm1', N'ÅpentOmråde'),
           (61.640680, 8.306035, NULL,    NULL,   NULL);

    -- Pruning a snapshot is a DELETE of its run row; anything left behind would
    -- accumulate silently, since nothing else references staging.
    DELETE FROM ingest.[Run] WHERE Id = @runId;

    SELECT @count = (SELECT COUNT(*) FROM ingest.SsrPlace WHERE RunId = @runId)
                  + (SELECT COUNT(*) FROM ingest.SsrPlacePoint WHERE RunId = @runId);
    IF @count <> 0 THROW 50042, 'Deleting an ingestion run left its staging snapshot behind.', 1;

    -- The elevation cache is keyed by coordinate, not by run, and must survive: it is
    -- what makes re-running ingestion cheap.
    SELECT @count = COUNT(*) FROM ingest.ElevationSample WHERE Latitude = 61.636440 AND Longitude = 8.312477;
    IF @count <> 1 THROW 50043, 'Pruning a run destroyed the elevation cache.', 1;

    /* ---------- the merge into the catalogue (ingest.MergePeaks) ---------- */

    -- Exercised here because the procedure joins temp tables to real ones, and a temp table
    -- carries tempdb's collation rather than this database's. That mismatch is invisible in a
    -- build and fatal at run time, so it needs a test that actually executes the merge.

    INSERT INTO ingest.[Run] (SourceDatasetId) VALUES (1);
    SET @mergeRunId = SCOPE_IDENTITY();

    INSERT INTO ingest.SsrPlace (RunId, Stedsnummer, [Name], NavneobjektType, NavneobjektGruppe, Kommunenummer, Kommunenavn, PointCount)
    VALUES (@mergeRunId, 'smoke-high', N'Smoketoppen',  N'fjell', N'høyder', '9999', N'Smokekommune', 2),
           (@mergeRunId, 'smoke-low',  N'Smokehaugen',  N'fjell', N'høyder', '9999', N'Smokekommune', 1),
           (@mergeRunId, 'smoke-sea',  N'Smokeskjeret', N'fjell', N'høyder', '9999', N'Smokekommune', 1);

    INSERT INTO ingest.SsrPlacePoint (RunId, Stedsnummer, PointIndex, Latitude, Longitude)
    VALUES (@mergeRunId, 'smoke-high', 0, 61.500000, 8.500000),
           (@mergeRunId, 'smoke-high', 1, 61.510000, 8.510000),
           (@mergeRunId, 'smoke-low',  0, 61.520000, 8.520000),
           (@mergeRunId, 'smoke-sea',  0, 61.530000, 8.530000);

    DELETE FROM ingest.ElevationSample
    WHERE Latitude IN (61.500000, 61.510000, 61.520000, 61.530000)
      AND Longitude IN (8.500000, 8.510000, 8.520000, 8.530000);

    INSERT INTO ingest.ElevationSample (Latitude, Longitude, ElevationMeters, Datakilde)
    VALUES (61.500000, 8.500000, 1000.00, 'dtm1'),          -- the lower of two points
           (61.510000, 8.510000, 1500.00, 'dtm1'),          -- the summit: highest wins
           (61.520000, 8.520000,   50.00, 'dtm1'),          -- below the rule's floor
           (61.530000, 8.530000, -246.00, 'dybdekurver');   -- a depth, not a height

    EXEC ingest.MergePeaks
        @RunId = @mergeRunId, @PeakRuleVersion = '1.0',
        @RowsInserted = @inserted OUTPUT, @RowsUpdated = @updated OUTPUT, @RowsRetired = @retired OUTPUT;

    IF @inserted <> 1 THROW 50050, 'The merge should have admitted exactly the one qualifying place.', 1;

    SELECT @count = COUNT(*) FROM [ref].Peak
    WHERE SourceDatasetId = 1 AND ExternalId = 'smoke-high' AND ElevationMeters = 1500 AND IsActive = 1;
    IF @count <> 1 THROW 50051, 'A place must take the elevation of its highest sampled point.', 1;

    -- The highest point supplies the position as well as the height; they are one decision.
    SELECT @count = COUNT(*) FROM [ref].Peak
    WHERE ExternalId = 'smoke-high' AND ROUND([Location].Lat, 2) = 61.51 AND ROUND([Location].Long, 2) = 8.51;
    IF @count <> 1 THROW 50052, 'A peak must sit at its highest sampled point, not its first.', 1;

    SELECT @count = COUNT(*) FROM [ref].Peak WHERE ExternalId = 'smoke-low';
    IF @count <> 0 THROW 50053, 'A place below the rule''s elevation floor was admitted.', 1;

    -- Nine points in the national extract answer from a bathymetric source because their
    -- representation point sits just offshore. Taken at face value they would enter the
    -- catalogue hundreds of metres below sea level.
    SELECT @count = COUNT(*) FROM [ref].Peak WHERE ExternalId = 'smoke-sea';
    IF @count <> 0 THROW 50054, 'A bathymetric depth was accepted as an elevation.', 1;

    /* ---------- areas resolved from the attribute, with no spatial join ---------- */

    SELECT @count = COUNT(*) FROM [ref].Area WHERE [Kind] = 'kommune' AND ExternalId = '9999' AND SourceDatasetId = 1;
    IF @count <> 1 THROW 50055, 'The merge did not create the kommune it read from the extract.', 1;

    SELECT @count = COUNT(*)
    FROM [ref].PeakArea pa
    JOIN [ref].Peak p ON p.Id = pa.PeakId AND p.ExternalId = 'smoke-high'
    JOIN [ref].Area a ON a.Id = pa.AreaId AND a.ExternalId = '9999';
    IF @count <> 1 THROW 50056, 'The peak was not linked to its kommune.', 1;

    /* ---------- a refresh retires what it no longer admits, and never deletes ---------- */

    -- The fixture peak is not in this run's snapshot, so the merge must retire it — while the
    -- trip that logged it survives untouched. This is the invariant the whole retire-never-
    -- delete design exists for, tested end to end rather than by hand.
    SELECT @count = COUNT(*) FROM [ref].Peak WHERE Id = @peakId AND IsActive = 0 AND RetiredAt IS NOT NULL;
    IF @count <> 1 THROW 50057, 'A peak absent from the refresh was not retired.', 1;

    SELECT @count = COUNT(*) FROM app.TripPeak WHERE PeakId = @peakId;
    IF @count <> 1 THROW 50058, 'Retiring a peak destroyed the trip that logged it.', 1;

    /* ---------- merging the same snapshot again changes nothing ---------- */

    EXEC ingest.MergePeaks
        @RunId = @mergeRunId, @PeakRuleVersion = '1.0',
        @RowsInserted = @inserted OUTPUT, @RowsUpdated = @updated OUTPUT, @RowsRetired = @retired OUTPUT;

    IF @inserted <> 0 OR @updated <> 0 OR @retired <> 0
        THROW 50059, 'Re-merging an unchanged snapshot reported work it did not need to do.', 1;

    /* ---------- FR-ACC-5: deleting the account removes everything ---------- */

    DELETE FROM auth.[User] WHERE Id = @userId;

    SELECT @count = (SELECT COUNT(*) FROM app.[User] WHERE Id = @userId)
                  + (SELECT COUNT(*) FROM app.Trip WHERE UserId = @userId)
                  + (SELECT COUNT(*) FROM app.TripPeak WHERE TripId = @tripId)
                  + (SELECT COUNT(*) FROM app.DiaryNote WHERE TripId = @tripId);
    IF @count <> 0 THROW 50030, 'Deleting the account left user data behind (FR-ACC-5).', 1;

    /* Reference data must be untouched by an account deletion. */
    SELECT @count = COUNT(*) FROM [ref].Peak WHERE Id = @peakId;
    IF @count <> 1 THROW 50031, 'Deleting an account removed reference data.', 1;

    /* ---------- a rule version that does not exist is refused ---------- */

    -- Deliberately last. ingest.MergePeaks runs with XACT_ABORT ON — correct when it owns its
    -- own transaction, but it dooms this one, so no assertion may read anything after it.
    SET @failed = 0;
    BEGIN TRY
        EXEC ingest.MergePeaks
            @RunId = @mergeRunId, @PeakRuleVersion = '99.9',
            @RowsInserted = @inserted OUTPUT, @RowsUpdated = @updated OUTPUT, @RowsRetired = @retired OUTPUT;
    END TRY
    BEGIN CATCH
        SET @failed = 1;
    END CATCH
    IF @failed = 0 THROW 50060, 'The merge ran under a peak rule version that is not seeded.', 1;

    ROLLBACK TRANSACTION;
    PRINT 'Smoke tests passed.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Smoke tests FAILED: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO
