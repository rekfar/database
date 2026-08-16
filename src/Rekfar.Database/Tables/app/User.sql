-- The user's profile — the domain identity the API exposes (FR-ACC-3/4).
-- Minimal by design: no fields beyond what a feature needs (P9, NFR-PRIV-2).
--
-- Id is not generated here: it is the same value as auth.[User].Id, so a user has one
-- identifier across authentication and domain data and the two can never drift.
CREATE TABLE app.[User]
(
    Id              uniqueidentifier    NOT NULL,
    DisplayName     nvarchar(80)        NOT NULL,
    Locale          varchar(16)         NOT NULL    CONSTRAINT DF_app_User_Locale DEFAULT 'nb-NO',
    DefaultPrivacy  varchar(16)         NOT NULL    CONSTRAINT DF_app_User_DefaultPrivacy DEFAULT 'private',
    CreatedAt       datetime2(3)        NOT NULL    CONSTRAINT DF_app_User_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt       datetime2(3)        NOT NULL    CONSTRAINT DF_app_User_UpdatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_app_User PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_app_User_auth_User FOREIGN KEY (Id) REFERENCES auth.[User] (Id) ON DELETE CASCADE,
    CONSTRAINT CK_app_User_DisplayName CHECK (LEN(LTRIM(RTRIM(DisplayName))) > 0),
    CONSTRAINT CK_app_User_DefaultPrivacy CHECK (DefaultPrivacy IN ('private', 'public'))
);
