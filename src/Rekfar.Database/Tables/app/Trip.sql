-- The central entity (data architecture §3). A wish, a plan and a logged trip are the
-- same row in three states (ADR-0019): wishlist -> planned -> completed. Moving a wish
-- into planning (FR-PLAN-5) and a plan into the log (FR-PLAN-3) are each a change of
-- [Status] on one row, never a copy between tables.
--
-- [Date] follows the state:
--   wishlist   absent — a wish with a date is a plan (CK_app_Trip_WishlistHasNoDate)
--   planned    the target date, optional (FR-PLAN-1)
--   completed  the actual date, required (FR-LOG-1, CK_app_Trip_CompletedHasDate)
--
-- Notes is the private diary note (dagboknotat, FR-BOOK-1/2, FR-LOG-4) — there is no
-- separate diary-note entity (ADR-0020). It is never published, whatever Privacy says:
-- Privacy governs the trip, and a trip that is shared is shared without its Notes.
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
    CONSTRAINT CK_app_Trip_Status CHECK ([Status] IN ('wishlist', 'planned', 'completed')),
    CONSTRAINT CK_app_Trip_Type CHECK ([Type] IN ('fottur', 'topptur')),
    CONSTRAINT CK_app_Trip_Difficulty CHECK (Difficulty IN ('enkel', 'middels', 'krevende', 'ekspert')),
    CONSTRAINT CK_app_Trip_Privacy CHECK (Privacy IN ('private', 'public')),
    CONSTRAINT CK_app_Trip_AscentMeters CHECK (AscentMeters >= 0),
    CONSTRAINT CK_app_Trip_CompletedHasDate CHECK ([Status] <> 'completed' OR [Date] IS NOT NULL),
    CONSTRAINT CK_app_Trip_WishlistHasNoDate CHECK ([Status] <> 'wishlist' OR [Date] IS NULL)
);
GO

-- The trip list and the year-by-year statistics (FR-STAT-2) are both "this user's
-- trips, newest first".
CREATE INDEX IX_app_Trip_UserId_Date
    ON app.Trip (UserId, [Date] DESC)
    INCLUDE ([Status], [Type], AscentMeters);
