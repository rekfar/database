-- The central entity (data architecture §3). A planned trip and a completed trip are
-- the same row in different states: planning becomes logging by changing [Status] and
-- filling in the outcome (FR-PLAN-3).
--
-- [Date] carries the target date while planned (optional, FR-PLAN-1) and the actual
-- date once completed (required, FR-LOG-1) — enforced by CK_app_Trip_CompletedHasDate.
CREATE TABLE app.Trip
(
    Id              uniqueidentifier    NOT NULL    CONSTRAINT DF_app_Trip_Id DEFAULT NEWSEQUENTIALID(),
    UserId          uniqueidentifier    NOT NULL,
    [Status]        varchar(16)         NOT NULL,
    [Type]          varchar(16)         NOT NULL,
    [Date]          date                NULL,
    AscentMeters    int                 NULL,
    Difficulty      varchar(16)         NULL,
    Conditions      nvarchar(200)       NULL,
    Notes           nvarchar(max)       NULL,
    Privacy         varchar(16)         NOT NULL    CONSTRAINT DF_app_Trip_Privacy DEFAULT 'private',
    CreatedAt       datetime2(3)        NOT NULL    CONSTRAINT DF_app_Trip_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt       datetime2(3)        NOT NULL    CONSTRAINT DF_app_Trip_UpdatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_app_Trip PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_app_Trip_User FOREIGN KEY (UserId) REFERENCES app.[User] (Id) ON DELETE CASCADE,
    CONSTRAINT CK_app_Trip_Status CHECK ([Status] IN ('planned', 'completed')),
    CONSTRAINT CK_app_Trip_Type CHECK ([Type] IN ('fottur', 'topptur')),
    CONSTRAINT CK_app_Trip_Difficulty CHECK (Difficulty IN ('enkel', 'middels', 'krevende', 'ekspert')),
    CONSTRAINT CK_app_Trip_Privacy CHECK (Privacy IN ('private', 'public')),
    CONSTRAINT CK_app_Trip_AscentMeters CHECK (AscentMeters >= 0),
    CONSTRAINT CK_app_Trip_CompletedHasDate CHECK ([Status] <> 'completed' OR [Date] IS NOT NULL)
);
GO

-- The trip list and the year-by-year statistics (FR-STAT-2) are both "this user's
-- trips, newest first".
CREATE INDEX IX_app_Trip_UserId_Date
    ON app.Trip (UserId, [Date] DESC)
    INCLUDE ([Status], [Type], AscentMeters);
