-- Which areas a peak falls in, resolved spatially once at ingestion (ADR-0012 §4.5).
-- Many-to-many because the groupings overlap: a peak is in one kommune and may also be
-- in a region and a fjellområde.
--
-- This exists so that "peaks in Jotunheimen" (FR-PEAK-3) is an index seek instead of a
-- polygon containment test across the whole catalogue on every request (NFR-PERF-2).
CREATE TABLE [ref].PeakArea
(
    PeakId      bigint          NOT NULL,
    AreaId      int             NOT NULL,
    ResolvedAt  datetime2(3)    NOT NULL    CONSTRAINT DF_ref_PeakArea_ResolvedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_ref_PeakArea PRIMARY KEY CLUSTERED (AreaId, PeakId),
    CONSTRAINT FK_ref_PeakArea_Peak FOREIGN KEY (PeakId) REFERENCES [ref].Peak (Id) ON DELETE CASCADE,
    CONSTRAINT FK_ref_PeakArea_Area FOREIGN KEY (AreaId) REFERENCES [ref].Area (Id) ON DELETE CASCADE
);
GO

CREATE INDEX IX_ref_PeakArea_PeakId
    ON [ref].PeakArea (PeakId);
