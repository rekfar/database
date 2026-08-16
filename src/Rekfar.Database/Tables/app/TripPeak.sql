-- Which peaks a trip involves: 0..n, because a traverse can bag several (FR-LOG-2).
-- For a planned trip these are the target peaks (FR-PLAN-1).
--
-- "Bagged (toppet)" (FR-LOG-8) is derived from this table joined to completed trips —
-- deliberately not stored as a flag on the peak, which would be per-user state sitting
-- in rebuildable reference data.
CREATE TABLE app.TripPeak
(
    TripId      uniqueidentifier    NOT NULL,
    PeakId      bigint              NOT NULL,
    CreatedAt   datetime2(3)        NOT NULL    CONSTRAINT DF_app_TripPeak_CreatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_app_TripPeak PRIMARY KEY CLUSTERED (TripId, PeakId),
    CONSTRAINT FK_app_TripPeak_Trip FOREIGN KEY (TripId) REFERENCES app.Trip (Id) ON DELETE CASCADE,
    -- No cascade: a refresh must never delete a peak a user has logged. Reference rows
    -- are retired in place instead (see [ref].Peak.IsActive), and this FK enforces it.
    CONSTRAINT FK_app_TripPeak_Peak FOREIGN KEY (PeakId) REFERENCES [ref].Peak (Id)
);
GO

-- "Have I done this peak?" on a peak detail page (FR-PEAK-2).
CREATE INDEX IX_app_TripPeak_PeakId
    ON app.TripPeak (PeakId);
