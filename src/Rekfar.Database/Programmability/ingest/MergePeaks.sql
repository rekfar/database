-- Turns a staged snapshot into the peak catalogue (FR-REF-1/6/10/11).
--
-- Set-based on purpose. The alternative — pulling 30,000 rows into the ingestion job,
-- deciding row by row, and writing them back — would be slower, harder to reason about, and
-- would put the definition of "what counts as a peak" somewhere other than next to the
-- tables it applies to.
--
-- Three rules are load-bearing here:
--
--   * A place's elevation and its position are the same decision. Roughly half of all peaks
--     carry several representation points and SSR does not say which is the summit, so the
--     highest sampled point supplies both.
--   * A bathymetric answer is not an elevation. Nine points in the national extract sample
--     from `dybdekurver` because their representation point sits just offshore; taken at face
--     value, Systrene in Aurland would enter the catalogue at -246 m.
--   * Rows are retired, never deleted. Somebody may have logged a trip to a peak the current
--     rule no longer admits, and app.TripPeak's foreign key deliberately refuses to cascade.
CREATE PROCEDURE ingest.MergePeaks
    @RunId              bigint,
    @PeakRuleVersion    varchar(20),
    @RowsInserted       int             OUTPUT,
    @RowsUpdated        int             OUTPUT,
    @RowsRetired        int             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SsrDatasetId       smallint = 1;
    DECLARE @HoydedataDatasetId smallint = 2;
    DECLARE @MinElevationMeters int;
    DECLARE @FetchedAt          datetime2(3);
    DECLARE @RuleExists         bit = 0;

    SELECT @MinElevationMeters = MinElevationMeters, @RuleExists = 1
    FROM [ref].PeakRule
    WHERE [Version] = @PeakRuleVersion;

    IF @RuleExists = 0
        THROW 51000, 'No such peak rule version. Seed it before merging — see docs/peak-rule.md.', 1;

    SELECT @FetchedAt = StartedAt FROM ingest.[Run] WHERE Id = @RunId;

    IF @FetchedAt IS NULL
        THROW 51001, 'No such ingestion run.', 1;

    -- What the rule admits, with the position and height it admits them at.
    -- COLLATE DATABASE_DEFAULT on every text column, and it is not optional. A temp table
    -- lives in tempdb, which uses the *server's* collation — SQL_Latin1_General_CP1_CI_AS on
    -- Azure SQL and on the local container alike — while this database is Norwegian_100_CI_AS.
    -- Without it, every comparison between this table and a real one fails outright with
    -- "cannot resolve the collation conflict".
    CREATE TABLE #Candidate
    (
        Stedsnummer         varchar(64)     COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
        [Name]              nvarchar(200)   COLLATE DATABASE_DEFAULT NOT NULL,
        NavneobjektType     nvarchar(60)    COLLATE DATABASE_DEFAULT NOT NULL,
        Latitude            decimal(9, 6)   NOT NULL,
        Longitude           decimal(9, 6)   NOT NULL,
        ElevationMeters     int             NOT NULL,
        ElevationSampledAt  datetime2(3)    NOT NULL,
        Kommunenummer       varchar(8)      COLLATE DATABASE_DEFAULT NULL,
        Kommunenavn         nvarchar(120)   COLLATE DATABASE_DEFAULT NULL
    );

    INSERT INTO #Candidate
        (Stedsnummer, [Name], NavneobjektType, Latitude, Longitude, ElevationMeters, ElevationSampledAt, Kommunenummer, Kommunenavn)
    SELECT
        p.Stedsnummer,
        p.[Name],
        p.NavneobjektType,
        highest.Latitude,
        highest.Longitude,
        CONVERT(int, ROUND(highest.ElevationMeters, 0)),
        highest.SampledAt,
        p.Kommunenummer,
        p.Kommunenavn
    FROM ingest.SsrPlace AS p
    -- CROSS APPLY rather than a join: a place with no usable sample has no highest point and
    -- drops out here, which is exactly the intended treatment of the 49 that have none.
    CROSS APPLY
    (
        SELECT TOP (1) pt.Latitude, pt.Longitude, s.ElevationMeters, s.SampledAt
        FROM ingest.SsrPlacePoint AS pt
        JOIN ingest.ElevationSample AS s
          ON s.Latitude = pt.Latitude AND s.Longitude = pt.Longitude
        WHERE pt.RunId = p.RunId
          AND pt.Stedsnummer = p.Stedsnummer
          AND s.ElevationMeters IS NOT NULL
          AND s.Datakilde IS NOT NULL
          AND s.Datakilde <> 'dybdekurver'
        ORDER BY s.ElevationMeters DESC
    ) AS highest
    WHERE p.RunId = @RunId
      AND p.NavneobjektType IN
          (SELECT NavneobjektType FROM [ref].PeakRuleObjectType WHERE PeakRuleVersion = @PeakRuleVersion)
      AND (@MinElevationMeters IS NULL OR highest.ElevationMeters >= @MinElevationMeters)
      -- Matches CK_ref_Peak_ElevationMeters. Anything outside is a data fault rather than a
      -- peak, and is dropped here so it cannot fail the whole merge on a constraint.
      AND highest.ElevationMeters BETWEEN -10 AND 2600;

    DECLARE @Changes TABLE ([Action] nvarchar(10) NOT NULL);

    BEGIN TRANSACTION;

    MERGE INTO [ref].Peak WITH (HOLDLOCK) AS target
    USING #Candidate AS source
       ON target.SourceDatasetId = @SsrDatasetId
      AND target.ExternalId = source.Stedsnummer
    -- Only touch a row that actually differs, so RowsUpdated reports change rather than
    -- traffic. FetchedAt therefore records when this version of the row was fetched; "was it
    -- still there last month" is a question ingest.Run answers.
    WHEN MATCHED AND
    (
        target.[Name] <> source.[Name]
        OR target.NavneobjektType <> source.NavneobjektType
        OR ISNULL(target.ElevationMeters, -32768) <> source.ElevationMeters
        OR ISNULL(target.PeakRuleVersion, '') <> @PeakRuleVersion
        OR target.IsActive = 0
        OR target.[Location].STEquals(geography::Point(source.Latitude, source.Longitude, 4326)) = 0
    )
    THEN UPDATE SET
        [Name]                      = source.[Name],
        SearchName                  = source.[Name],
        NavneobjektType             = source.NavneobjektType,
        [Location]                  = geography::Point(source.Latitude, source.Longitude, 4326),
        ElevationMeters             = source.ElevationMeters,
        ElevationSourceDatasetId    = @HoydedataDatasetId,
        ElevationSampledAt          = source.ElevationSampledAt,
        PeakRuleVersion             = @PeakRuleVersion,
        FetchedAt                   = @FetchedAt,
        -- A peak the rule admits again comes back rather than being inserted a second time;
        -- the unique key on (SourceDatasetId, ExternalId) is what makes that possible.
        IsActive                    = 1,
        RetiredAt                   = NULL
    WHEN NOT MATCHED BY TARGET
    THEN INSERT
    (
        SourceDatasetId, ExternalId, [Name], SearchName, NavneobjektType, [Location],
        ElevationMeters, ElevationSourceDatasetId, ElevationSampledAt, PeakRuleVersion, FetchedAt
    )
    VALUES
    (
        @SsrDatasetId, source.Stedsnummer, source.[Name], source.[Name], source.NavneobjektType,
        geography::Point(source.Latitude, source.Longitude, 4326),
        source.ElevationMeters, @HoydedataDatasetId, source.ElevationSampledAt, @PeakRuleVersion, @FetchedAt
    )
    OUTPUT $action INTO @Changes;

    SELECT @RowsInserted = SUM(CASE WHEN [Action] = 'INSERT' THEN 1 ELSE 0 END),
           @RowsUpdated  = SUM(CASE WHEN [Action] = 'UPDATE' THEN 1 ELSE 0 END)
    FROM @Changes;

    -- Retire what this run no longer admits: dropped upstream, dropped by a new rule, or its
    -- sampled height moved below the floor. Never a DELETE — see the header.
    UPDATE p
    SET IsActive = 0,
        RetiredAt = SYSUTCDATETIME()
    FROM [ref].Peak AS p
    WHERE p.SourceDatasetId = @SsrDatasetId
      AND p.IsActive = 1
      AND NOT EXISTS (SELECT 1 FROM #Candidate AS c WHERE c.Stedsnummer = p.ExternalId);

    SET @RowsRetired = @@ROWCOUNT;

    /*
        Areas.

        Every SSR place carries its kommunenummer as an attribute, so membership is copied
        rather than derived — no polygon containment, and no boundary geometry needed. The
        provenance is honestly the SSR extract, because that is where these values were read;
        when Administrative Enheter is loaded for its boundaries it can take the rows over.
    */
    MERGE INTO [ref].Area AS target
    USING
    (
        SELECT DISTINCT Kommunenummer, Kommunenavn
        FROM #Candidate
        WHERE Kommunenummer IS NOT NULL AND Kommunenavn IS NOT NULL
    ) AS source
       ON target.SourceDatasetId = @SsrDatasetId
      AND target.ExternalId = source.Kommunenummer
      AND target.[Kind] = 'kommune'
    WHEN MATCHED AND (target.[Name] <> source.Kommunenavn OR target.FetchedAt < @FetchedAt)
    THEN UPDATE SET [Name] = source.Kommunenavn, FetchedAt = @FetchedAt
    WHEN NOT MATCHED BY TARGET
    THEN INSERT ([Kind], [Name], SourceDatasetId, ExternalId, FetchedAt)
         VALUES ('kommune', source.Kommunenavn, @SsrDatasetId, source.Kommunenummer, @FetchedAt);

    -- A peak's kommune can change when a municipality is merged or split, so stale
    -- memberships are removed rather than accumulated alongside the new one.
    DELETE pa
    FROM [ref].PeakArea AS pa
    JOIN [ref].Area AS a ON a.Id = pa.AreaId AND a.[Kind] = 'kommune'
    JOIN [ref].Peak AS p ON p.Id = pa.PeakId AND p.SourceDatasetId = @SsrDatasetId
    JOIN #Candidate AS c ON c.Stedsnummer = p.ExternalId
    LEFT JOIN [ref].Area AS want
           ON want.SourceDatasetId = @SsrDatasetId
          AND want.ExternalId = c.Kommunenummer
          AND want.[Kind] = 'kommune'
    WHERE want.Id IS NULL OR want.Id <> pa.AreaId;

    INSERT INTO [ref].PeakArea (PeakId, AreaId)
    SELECT p.Id, a.Id
    FROM #Candidate AS c
    JOIN [ref].Peak AS p ON p.SourceDatasetId = @SsrDatasetId AND p.ExternalId = c.Stedsnummer
    JOIN [ref].Area AS a
      ON a.SourceDatasetId = @SsrDatasetId AND a.ExternalId = c.Kommunenummer AND a.[Kind] = 'kommune'
    WHERE NOT EXISTS (SELECT 1 FROM [ref].PeakArea AS pa WHERE pa.PeakId = p.Id AND pa.AreaId = a.Id);

    COMMIT TRANSACTION;

    DROP TABLE #Candidate;
END
