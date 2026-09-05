-- Credential store, column-compatible with ASP.NET Core Identity's IdentityUser so
-- the framework's default stores work against it. The table is named for this schema
-- rather than `AspNetUsers`; the backend maps it explicitly (see docs/conventions.md).
--
-- Rekfar stores no passwords at all: sign-in is a one-time code emailed to the user,
-- issued and verified by Identity (ADR-0017). The columns that served a password are
-- still here, because Identity's own stores read and write them — what has changed is
-- that the schema now refuses the password rather than merely not using it.
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
    -- Present so Identity's default store works unchanged, and constrained below so it
    -- can never hold anything. Dropping it instead would mean writing a custom user
    -- store for no gain.
    PasswordHash        nvarchar(max)       NULL,
    -- Load-bearing under passwordless, in two ways it was not before: the sign-in code
    -- is derived from it, and rotating it is the only revocation a user has over a lost
    -- device, since there is no password to change. NULL is not a valid account state.
    SecurityStamp       nvarchar(max)       NOT NULL,
    ConcurrencyStamp    nvarchar(max)       NULL,
    TwoFactorEnabled    bit                 NOT NULL    CONSTRAINT DF_auth_User_TwoFactorEnabled DEFAULT 0,
    -- Lockout counts failed *sign-in code* attempts now, not password guesses: it is the
    -- attempt cap ADR-0017 §3 asks for, reusing Identity's own machinery rather than
    -- adding a second counter beside it. See docs/conventions.md.
    LockoutEnd          datetimeoffset(7)   NULL,
    LockoutEnabled      bit                 NOT NULL    CONSTRAINT DF_auth_User_LockoutEnabled DEFAULT 1,
    AccessFailedCount   int                 NOT NULL    CONSTRAINT DF_auth_User_AccessFailedCount DEFAULT 0,
    CreatedAt           datetime2(3)        NOT NULL    CONSTRAINT DF_auth_User_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt           datetime2(3)        NOT NULL    CONSTRAINT DF_auth_User_UpdatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_auth_User PRIMARY KEY CLUSTERED (Id),
    -- No user password is ever stored (FR-ACC-1/2, ADR-0017, NFR-SEC-2). This is a
    -- property of the data, so it is enforced here rather than trusted to the one code
    -- path that writes the table today.
    CONSTRAINT CK_auth_User_NoPassword CHECK (PasswordHash IS NULL),
    CONSTRAINT CK_auth_User_SecurityStamp CHECK (LEN(LTRIM(RTRIM(SecurityStamp))) > 0),
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
