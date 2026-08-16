-- Cached terrain heights from Kartverket Høydedata, keyed by the coordinate they were
-- sampled at (FR-REF-10, ADR-0012 §3).
--
-- SSR carries no height, so every peak's elevation costs a call to the elevation service.
-- This table is what stops that cost being paid twice. It is deliberately **not** keyed
-- by run or by place: a coordinate's terrain height does not depend on which extract
-- mentioned it, so a re-run, a widened peak rule, or a second dataset asking about the
-- same point all hit a row that is already here. That is what makes re-running ingestion
-- cheap enough to be routine.
--
-- A miss and a null are different answers and both are cached. Outside the model's
-- coverage the service returns no height at all; recording that as a row with a NULL
-- elevation means the next run does not ask again and get the same nothing.
CREATE TABLE ingest.ElevationSample
(
    -- Matches [ingest].SsrPlacePoint exactly: same type, same scale, so the join is a
    -- seek and never an implicit conversion.
    Latitude        decimal(9, 6)   NOT NULL,
    Longitude       decimal(9, 6)   NOT NULL,
    -- NULL means "asked, and the service had no height here" — not "not yet asked".
    ElevationMeters decimal(7, 2)   NULL,
    -- Which model answered: dtm1, dom1, hoydekurver, innsjohoyde, or dybdekurver. The
    -- service returns the best available source, and for a coastal point that can be a
    -- *depth* rather than a height, which is why the range below reaches below sea level
    -- and why ingestion filters on this column rather than trusting the number alone.
    Datakilde       varchar(20)     NULL,
    -- The service's own classification of what the point sits on.
    Terreng         nvarchar(40)    NULL,
    -- The sample's accuracy is a property of when it was taken, because the terrain model
    -- is itself re-flown and republished. Re-sampling is a DELETE of rows older than
    -- whatever age is judged stale; there is no expiry policy in the schema because there
    -- is not yet a reason to prefer one.
    SampledAt       datetime2(3)    NOT NULL    CONSTRAINT DF_ingest_ElevationSample_SampledAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_ingest_ElevationSample PRIMARY KEY CLUSTERED (Latitude, Longitude),
    CONSTRAINT CK_ingest_ElevationSample_Latitude CHECK (Latitude BETWEEN 57 AND 72),
    CONSTRAINT CK_ingest_ElevationSample_Longitude CHECK (Longitude BETWEEN 4 AND 32),
    -- Norway's highest point is 2469 m; the lower bound admits a bathymetric answer.
    CONSTRAINT CK_ingest_ElevationSample_ElevationMeters CHECK (ElevationMeters BETWEEN -6000 AND 2600),
    -- The same rule [ref].Peak enforces on the elevation it publishes, applied where the
    -- number is first recorded: a height without the model it came from is a claim that
    -- cannot be checked later.
    CONSTRAINT CK_ingest_ElevationSample_Provenance CHECK (ElevationMeters IS NULL OR Datakilde IS NOT NULL)
);
