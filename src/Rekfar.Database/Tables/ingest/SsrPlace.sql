-- One row per SSR place in a single extract — the parsed staging snapshot the peak
-- catalogue is merged from (FR-REF-1/10/11, ADR-0012).
--
-- Why staging exists at all: the published extract is a 2.6 GB GML file and elevation
-- has to be sampled point by point from a separate service. Landing the parse here first
-- means the expensive half of ingestion is done once, and the cheap half — deciding
-- which rows qualify as peaks and merging them into [ref].Peak — can be re-run against
-- local data whenever the rule changes. The peak-qualification rule (FR-REF-11) is
-- therefore a re-MERGE, not a re-download.
--
-- Keyed by run rather than replaced in place, so a snapshot is only ever complete or
-- absent: a failed run cannot leave the previous extract half-overwritten, and two runs
-- can be diffed to see what upstream changed. Pruning an old snapshot is a DELETE of its
-- [ingest].[Run] row, which cascades.
--
-- The columns are a faithful copy of the source fields, under their Kartverket names, so
-- a staged row can be checked against the GML it came from without a mapping table in
-- between. Norwegian identifiers are ASCII-folded the same way the code values are
-- (docs/conventions.md) — SkrivemateStatus, not Skrivemåtestatus.
CREATE TABLE ingest.SsrPlace
(
    RunId               bigint          NOT NULL,
    -- SSR's stable place id, and the value that becomes [ref].Peak.ExternalId.
    Stedsnummer         varchar(64)     NOT NULL,
    -- The chosen display name: one place carries up to five, across Norwegian, three
    -- Sami languages and Kvensk. Which one lands here is a decision the parser makes and
    -- records in the three columns below, not something to re-derive later.
    [Name]              nvarchar(200)   NOT NULL,
    Sprak               nvarchar(20)    NULL,
    Navnestatus         nvarchar(20)    NULL,
    SkrivemateStatus    nvarchar(30)    NULL,
    -- Kartverket's own classification. The group is kept alongside the type because it is
    -- the coarser handle a future rule version may want: every peak-like type is in
    -- 'høyder', so widening the rule is a group filter rather than a longer type list.
    NavneobjektType     nvarchar(60)    NOT NULL,
    NavneobjektGruppe   nvarchar(60)    NOT NULL,
    -- Every place carries its municipality as an attribute, which is what lets
    -- [ref].PeakArea be resolved without a polygon containment test (ADR-0012 §4.5).
    Kommunenummer       varchar(8)      NULL,
    Kommunenavn         nvarchar(120)   NULL,
    Fylkesnummer        varchar(8)      NULL,
    Fylkesnavn          nvarchar(120)   NULL,
    -- The upstream row's own last-changed date. Kept because detecting deletions and
    -- changes between refreshes is still an open question (ADR-0012 §5.3) and this is the
    -- only signal the extract offers towards answering it.
    UpdatedUpstreamAt   datetime2(3)    NULL,
    -- Denormalised from [ingest].SsrPlacePoint so that "places the parser found no
    -- position for" is a query rather than an anti-join. It is not always zero-or-one:
    -- roughly half of all peaks carry several representation points.
    PointCount          smallint        NOT NULL,
    LoadedAt            datetime2(3)    NOT NULL    CONSTRAINT DF_ingest_SsrPlace_LoadedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_ingest_SsrPlace PRIMARY KEY CLUSTERED (RunId, Stedsnummer),
    CONSTRAINT FK_ingest_SsrPlace_Run FOREIGN KEY (RunId) REFERENCES ingest.[Run] (Id) ON DELETE CASCADE,
    CONSTRAINT CK_ingest_SsrPlace_PointCount CHECK (PointCount >= 0)
);
