-- One row per ingestion run, per dataset (FR-REF-3/4, capability C12).
--
-- This is the record that answers "when was the peak catalogue last refreshed, from
-- which upstream version, and did it work?" — and the row counts are the cheapest
-- available signal that an upstream schema or distribution change has broken parsing
-- (a run that succeeds while reading a fraction of the usual rows).
CREATE TABLE ingest.[Run]
(
    Id              bigint          IDENTITY(1, 1) NOT NULL,
    SourceDatasetId smallint        NOT NULL,
    [Status]        varchar(16)     NOT NULL    CONSTRAINT DF_ingest_Run_Status DEFAULT 'running',
    StartedAt       datetime2(3)    NOT NULL    CONSTRAINT DF_ingest_Run_StartedAt DEFAULT SYSUTCDATETIME(),
    CompletedAt     datetime2(3)    NULL,
    -- Whatever identifies the upstream snapshot we read: a Geonorge distribution date,
    -- a dataset version, or the download timestamp.
    SourceVersion   nvarchar(80)    NULL,
    RowsRead        int             NULL,
    RowsInserted    int             NULL,
    RowsUpdated     int             NULL,
    RowsRetired     int             NULL,
    [Message]       nvarchar(2000)  NULL,

    CONSTRAINT PK_ingest_Run PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_ingest_Run_SourceDataset FOREIGN KEY (SourceDatasetId) REFERENCES [ref].SourceDataset (Id),
    CONSTRAINT CK_ingest_Run_Status CHECK ([Status] IN ('running', 'succeeded', 'failed')),
    CONSTRAINT CK_ingest_Run_Completed CHECK (([Status] = 'running' AND CompletedAt IS NULL)
                                           OR ([Status] <> 'running' AND CompletedAt IS NOT NULL)),
    CONSTRAINT CK_ingest_Run_RowCounts CHECK (COALESCE(RowsRead, 0) >= 0
                                          AND COALESCE(RowsInserted, 0) >= 0
                                          AND COALESCE(RowsUpdated, 0) >= 0
                                          AND COALESCE(RowsRetired, 0) >= 0)
);
GO

-- "Last successful run for this dataset" — the query the scheduler and any admin view
-- both need.
CREATE INDEX IX_ingest_Run_SourceDatasetId_StartedAt
    ON ingest.[Run] (SourceDatasetId, StartedAt DESC)
    INCLUDE ([Status]);
