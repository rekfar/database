-- Private diary notes (dagboknotat) on a trip (FR-BOOK-1/2, ADR-0009).
--
-- Visibility is constrained to a single value on purpose. A diary note is private by
-- definition, and ADR-0009 requires that private and public content never cross over;
-- the public counterpart is a separate table (GuestbookEntry, Phase 2). If public
-- diary notes are ever wanted, that is a schema change with a decision behind it —
-- not something an application bug can do by writing a different string.
CREATE TABLE app.DiaryNote
(
    Id          uniqueidentifier    NOT NULL    CONSTRAINT DF_app_DiaryNote_Id DEFAULT NEWSEQUENTIALID(),
    TripId      uniqueidentifier    NOT NULL,
    [Text]      nvarchar(max)       NOT NULL,
    Visibility  varchar(16)         NOT NULL    CONSTRAINT DF_app_DiaryNote_Visibility DEFAULT 'private',
    CreatedAt   datetime2(3)        NOT NULL    CONSTRAINT DF_app_DiaryNote_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt   datetime2(3)        NOT NULL    CONSTRAINT DF_app_DiaryNote_UpdatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_app_DiaryNote PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_app_DiaryNote_Trip FOREIGN KEY (TripId) REFERENCES app.Trip (Id) ON DELETE CASCADE,
    CONSTRAINT CK_app_DiaryNote_Visibility CHECK (Visibility = 'private')
);
GO

CREATE INDEX IX_app_DiaryNote_TripId
    ON app.DiaryNote (TripId);
