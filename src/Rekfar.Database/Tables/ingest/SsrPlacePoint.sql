-- The representation points of a staged SSR place — one row per point.
--
-- A place is not one coordinate. Roughly half of all peaks in the extract carry a
-- MultiPoint of two to sixteen positions, and SSR does not say which of them is the
-- summit. Ingestion samples the terrain model at every one and keeps the highest: that
-- single rule gives both the elevation and the best available summit position, and it
-- costs nothing beyond the samples that would be taken anyway.
--
-- Deliberately not a geography column. This table is written by bulk copy and read by a
-- join against the elevation cache, and neither needs spatial types; the conversion to
-- SRID 4326 happens once, in the merge into [ref].Peak, where the SRID constraint that
-- matters is already enforced. Keeping staging non-spatial also keeps it free of the
-- QUOTED_IDENTIFIER requirement that spatial constraints impose on every writer.
CREATE TABLE ingest.SsrPlacePoint
(
    RunId       bigint          NOT NULL,
    Stedsnummer varchar(64)     NOT NULL,
    -- Position within the source geometry, preserved so a staged point can be traced back
    -- to the GML element it was read from.
    PointIndex  smallint        NOT NULL,
    -- ETRS89 geographic degrees, exactly as published: the extract quotes six decimal
    -- places, so decimal(9, 6) stores it losslessly and can serve as an exact key into
    -- [ingest].ElevationSample. A float could not — two runs would round differently and
    -- the cache would miss.
    Latitude    decimal(9, 6)   NOT NULL,
    Longitude   decimal(9, 6)   NOT NULL,

    CONSTRAINT PK_ingest_SsrPlacePoint PRIMARY KEY CLUSTERED (RunId, Stedsnummer, PointIndex),
    CONSTRAINT FK_ingest_SsrPlacePoint_SsrPlace FOREIGN KEY (RunId, Stedsnummer)
        REFERENCES ingest.SsrPlace (RunId, Stedsnummer) ON DELETE CASCADE,
    -- Bounds mainland Norway rather than the globe, because the failure this guards
    -- against is not an impossible coordinate but a transposed one. The source declares
    -- urn:ogc:def:crs:EPSG::4258, which puts latitude first; a parser that reads the pair
    -- the other way round produces coordinates that are individually valid and silently
    -- wrong. Swapped, every Norwegian point falls outside these ranges and the load
    -- fails on the first row instead of populating a catalogue off the coast of Africa.
    CONSTRAINT CK_ingest_SsrPlacePoint_Latitude CHECK (Latitude BETWEEN 57 AND 72),
    CONSTRAINT CK_ingest_SsrPlacePoint_Longitude CHECK (Longitude BETWEEN 4 AND 32)
);

-- No secondary index, deliberately. Both queries this table serves — "which of this run's
-- points still need sampling" and "the highest sampled point per place" — read one run's
-- rows as a range seek on the clustered key and probe [ingest].ElevationSample by its own
-- primary key. An index on (Latitude, Longitude) would serve the opposite direction, which
-- nothing asks for, and cost a write on every bulk load.
