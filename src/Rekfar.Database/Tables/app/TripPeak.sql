-- Which peaks a trip involves: 0..n, because a traverse can bag several (FR-LOG-2).
-- For a wish or a plan these are the target peaks (FR-PLAN-1, FR-PLAN-4); only rows
-- joined to a *completed* trip mean the peak was reached.
--
-- "Bagged (toppet)" (FR-LOG-8) is therefore derived from this table joined to completed
-- trips, and "on the wishlist" and "planned" from the same join on the other two values
-- of Trip.[Status] (ADR-0019). None of the three is stored as a flag on the peak, which
-- would be per-user state sitting in rebuildable reference data.
--
-- "At most one wish per user and peak" is not enforced here: it spans Trip and TripPeak,
-- which a filtered unique index cannot express. The API owns that rule.
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
