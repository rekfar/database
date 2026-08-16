-- Credential store, column-compatible with ASP.NET Core Identity's IdentityUser so
-- the framework's default stores work against it. The table is named for this schema
-- rather than `AspNetUsers`; the backend maps it explicitly (see docs/conventions.md).
--
-- The 1:1 profile row in app.[User] shares this primary key, and deleting here
-- cascades all the way down the user's data — which is what makes "delete my account"
-- (FR-ACC-5, GDPR) a single statement.
CREATE TABLE auth.[User]
(
    Id                  uniqueidentifier    NOT NULL    CONSTRAINT DF_auth_User_Id DEFAULT NEWSEQUENTIALID(),
    UserName            nvarchar(256)       NOT NULL,
    NormalizedUserName  nvarchar(256)       NOT NULL,
    Email               nvarchar(256)       NOT NULL,
    NormalizedEmail     nvarchar(256)       NOT NULL,
    EmailConfirmed      bit                 NOT NULL    CONSTRAINT DF_auth_User_EmailConfirmed DEFAULT 0,
    PasswordHash        nvarchar(max)       NULL,
    SecurityStamp       nvarchar(max)       NULL,
    ConcurrencyStamp    nvarchar(max)       NULL,
    TwoFactorEnabled    bit                 NOT NULL    CONSTRAINT DF_auth_User_TwoFactorEnabled DEFAULT 0,
    LockoutEnd          datetimeoffset(7)   NULL,
    LockoutEnabled      bit                 NOT NULL    CONSTRAINT DF_auth_User_LockoutEnabled DEFAULT 1,
    AccessFailedCount   int                 NOT NULL    CONSTRAINT DF_auth_User_AccessFailedCount DEFAULT 0,
    CreatedAt           datetime2(3)        NOT NULL    CONSTRAINT DF_auth_User_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt           datetime2(3)        NOT NULL    CONSTRAINT DF_auth_User_UpdatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_auth_User PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT CK_auth_User_AccessFailedCount CHECK (AccessFailedCount >= 0)
);
GO

-- One account per email address (FR-ACC-1). Identity normalises to upper case before
-- writing; the unique index is what actually enforces the rule.
CREATE UNIQUE INDEX UX_auth_User_NormalizedEmail
    ON auth.[User] (NormalizedEmail);
GO

CREATE UNIQUE INDEX UX_auth_User_NormalizedUserName
    ON auth.[User] (NormalizedUserName);
