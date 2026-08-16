/*
    Smoke tests for a freshly published Rekfar database.

    These are not unit tests for application logic — they assert the invariants the
    schema itself is supposed to guarantee, the ones that would otherwise be discovered
    in production:

        * ADR-0009's private/public separation cannot be violated by a bad write.
        * Geometry cannot be stored in the wrong coordinate system (NFR-INTEROP-2).
        * Deleting an account really does remove all of its data (FR-ACC-5, GDPR).
        * A reference row a user has logged against cannot be deleted by a refresh.
        * Accent-insensitive name search actually works (FR-PEAK-1).

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
DECLARE @userId uniqueidentifier = '11111111-1111-1111-1111-111111111111';
DECLARE @tripId uniqueidentifier = '22222222-2222-2222-2222-222222222222';
DECLARE @peakId bigint;

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

    /* ---------- spatial index on the map's hot query ---------- */

    SELECT @count = COUNT(*)
    FROM sys.spatial_indexes
    WHERE object_id = OBJECT_ID('[ref].Peak') AND name = 'SIX_ref_Peak_Location';
    IF @count <> 1 THROW 50004, 'Missing spatial index on [ref].Peak.Location.', 1;

    /* ---------- collation intent ---------- */

    IF DATABASEPROPERTYEX(DB_NAME(), 'Collation') <> 'Norwegian_100_CI_AS'
        THROW 50005, 'Database collation is not Norwegian_100_CI_AS — see docs/operations.md.', 1;

    SELECT @count = COUNT(*)
    FROM sys.columns
    WHERE object_id = OBJECT_ID('[ref].Peak') AND name = 'SearchName' AND collation_name = 'Norwegian_100_CI_AI';
    IF @count <> 1 THROW 50006, '[ref].Peak.SearchName must be accent-insensitive.', 1;

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

    ROLLBACK TRANSACTION;
    PRINT 'Smoke tests passed.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Smoke tests FAILED: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO
