# Schema conventions

Rules for this project, and the reasoning behind the ones that are not obvious. Follow
them; if a rule is wrong, change it here and change the schema with it.

## Files and naming

- **One object per file**, named after the object, under `Tables/<schema>/`. A diff should
  show which object changed from the file list alone.
- Indexes live in the same file as the table they belong to. They are part of how that
  table is meant to be read, not independent objects.
- **PascalCase, singular** table names (`Trip`, not `trips`). `Id` for a primary key,
  `<Table>Id` for a foreign key.
- **Every constraint and index is named explicitly**, prefixed by kind, then schema, then
  table, then column or purpose:

  | Prefix | Example |
  | --- | --- |
  | `PK_` | `PK_app_Trip` |
  | `FK_` | `FK_app_Trip_User` |
  | `UQ_` / `UX_` | `UQ_ref_Peak_Source` (constraint) / `UX_auth_User_NormalizedEmail` (index) |
  | `IX_` | `IX_app_Trip_UserId_Date` |
  | `SIX_` | `SIX_ref_Peak_Location` (spatial) |
  | `CK_` | `CK_app_Trip_CompletedHasDate` |
  | `DF_` | `DF_app_Trip_Privacy` |

  Auto-generated names are the reason schema comparisons produce noise: they differ
  between environments, so a deploy proposes changes that are not changes.
- Bracket `[ref]` always — `REF` is reserved in ODBC and unbracketed usage is fragile.
  Bracket `[User]`, `[Status]`, `[Type]`, `[Date]`, `[Name]`, `[Text]`, `[Message]`,
  `[Version]`, `[Kind]`, `[Location]`, `[Run]` for the same reason.
- `.sql` files are saved **UTF-8 with a byte-order mark**. Without it the build can read
  `æøå` as the wrong code page, which silently corrupts seeded Norwegian text.

## Types

| Purpose | Type | Why |
| --- | --- | --- |
| Human-readable text | `nvarchar(n)` | Norwegian place names; `n` is a real bound, not `max` |
| Long free text | `nvarchar(max)` | Notes and diary entries have no useful bound |
| Code values | `varchar(n)` | ASCII by definition; see below |
| Timestamps | `datetime2(3)` | UTC always. Millisecond precision is enough and cheaper than the default |
| Dates without a time | `date` | A trip happens on a day, not at an instant |
| Geometry | `geography` | SRID 4326 only |
| Booleans | `bit` | `NOT NULL` with a default |

Timestamps are UTC, defaulted with `SYSUTCDATETIME()`. `GETDATE()` must not appear
anywhere in this project.

Every table carries `CreatedAt`; tables whose rows are edited also carry `UpdatedAt`.
`UpdatedAt` is maintained by the application, not by a trigger — a trigger would be
invisible to anyone reading the schema, and this project has no other triggers.

## Keys

**`app` and `auth` use `uniqueidentifier`** with `NEWSEQUENTIALID()` defaults.
**`ref` uses `bigint IDENTITY`.**

The split is deliberate:

- User-facing ids appear in API URLs. Sequential integers there advertise how many trips
  exist and invite enumeration; access control makes that harmless but it is still
  information the API has no reason to publish (P9). GUIDs also let a future native client
  create a row offline and sync it without an id round-trip (P6).
- Reference data is high-volume, never appears in a URL as a bare id, and already has a
  stable natural key from Kartverket. A `bigint` keeps the many-to-many tables that point
  at it narrow, and `NEWSEQUENTIALID()` on a million-row bulk import would waste both space
  and index depth for nothing.

`NEWSEQUENTIALID()` rather than `NEWID()` so inserts stay at the end of the clustered index
instead of fragmenting it.

Reference tables also carry a **`UNIQUE (SourceDatasetId, ExternalId)`** constraint. That
pair — not the surrogate key — is what makes a refresh an update instead of a duplicate
(FR-REF-6).

## Code values

Small fixed vocabularies are `varchar` columns with a `CHECK` constraint, not lookup
tables. A lookup table for four values that only change with a code change buys a join and
nothing else (P7). Code lists that *Kartverket* supplies get real tables, because their
values arrive as data and ingestion has to validate against them.

**Which language a code value uses is not a style choice** — it follows the
[data architecture](https://github.com/rekfar/docs/blob/main/architecture/03-data-architecture.md)
model exactly, which uses Norwegian for domain vocabulary from the glossary and English for
technical states:

| Column | Values |
| --- | --- |
| `app.Trip.Type` | `fottur`, `topptur` |
| `app.Trip.Difficulty` | `enkel`, `middels`, `krevende`, `ekspert` |
| `ref.Area.Kind` | `kommune`, `region`, `fjellomrade` |
| `app.Trip.Status` | `planned`, `completed` |
| `app.DiaryNote.Visibility` | `private` |
| `app.*.Privacy` | `private`, `public` |
| `ingest.Run.Status` | `running`, `succeeded`, `failed` |

`fjellomrade` is ASCII, matching how the data architecture writes it. Code values are
identifiers, and an `ø` in one is a bug waiting to happen in a URL, a config file or a CSV.

## Collation

Database collation is **`Norwegian_100_CI_AS`**, so `æ`, `ø` and `å` sort where a Norwegian
reader expects them rather than as `a` and `o`.

**On Azure SQL this is fixed when the database is created and cannot be changed
afterwards.** Getting it wrong means exporting and reimporting into a new database.

Name columns that exist for *searching* are declared `COLLATE Norwegian_100_CI_AI`
(accent-insensitive), so typing `Galdhopiggen` finds `Galdhøpiggen`. One column cannot
both sort correctly and match insensitively, which is why `ref.Peak` has `Name` for display
and `SearchName` for lookup. The duplication is 200 characters per peak and it is worth it.

## Constraints

Invariants belong in the schema when they are true of the data rather than of one code
path. The application will also enforce them — the point is that a bug, a manual fix or a
future second writer cannot get around them.

Enforced here on purpose:

- `CK_ref_Peak_LocationSrid` — canonical storage is WGS84 and nothing else
  (NFR-INTEROP-2). A wrong-SRID row is invisible until a spatial query silently returns
  nothing.
- `CK_app_DiaryNote_Visibility` — a diary note is private, full stop
  ([ADR-0009](https://github.com/rekfar/docs/blob/main/adr/0009-private-and-public-logbook.md)).
- `CK_app_Trip_CompletedHasDate` — a logged trip without a date is not a logged trip.
- `CK_ref_Peak_ElevationProvenance` — a derived elevation must carry the dataset and date
  it was sampled from, because its accuracy is a property of that sample (FR-REF-10).
- `CK_ref_Peak_Retired` — `IsActive` and `RetiredAt` must agree.

### Cascades

`auth.User` → `app.User` → `Trip` → (`TripPeak`, `DiaryNote`) all cascade on delete, which
makes "delete my account" (FR-ACC-5) one statement that cannot leave orphans behind.

Foreign keys **from user data into reference data do not cascade** — `FK_app_TripPeak_Peak`
is the important one. A reference refresh must never be able to delete a peak someone has
logged. Reference rows are retired in place (`IsActive = 0`, `RetiredAt` set) and this
foreign key is what enforces that, rather than trusting the ingestion job to remember.

## Post-deployment scripts

`Scripts/PostDeployment/` runs on **every** publish, so everything in it must be
idempotent: `MERGE`, or `IF NOT EXISTS`. CI publishes twice in a row and fails if the
second publish is not a no-op.

Seed only data whose values the schema's meaning depends on — code lists and provenance
rows. Reference data comes from ingestion, never from a seed script.

## The contract with the backend

The backend consumes this schema; it does not define it.

- **No EF Core migrations** against this database. `dotnet ef migrations add` produces a
  second, competing definition of the schema.
- EF Core maps to these tables explicitly. ASP.NET Core Identity's default table names are
  not used, so the Identity entities need `ToTable("User", "auth")` and equivalents.
  `auth.User` is column-compatible with `IdentityUser` so the framework's own stores work
  unchanged.
- Identity entities this schema does not model (roles, claims, tokens, external logins) are
  not needed yet and should be ignored in the model rather than created. They get added
  here when a feature needs them.
- Geometry is `NetTopologySuite` types, never provider-specific spatial SQL. That is what
  keeps a later move to PostGIS a provider swap plus a data migration instead of a rewrite
  ([ADR-0010](https://github.com/rekfar/docs/blob/main/adr/0010-tech-stack-dotnet-azure-sql.md)).
- Integration tests should publish the `dacpac` artifact from this repository's CI onto a
  throwaway database rather than reconstructing the schema. Testing against a
  hand-maintained approximation of production is how drift stops being visible.

## Changing the schema

1. Edit the object's `.sql` file.
2. `local/reset.sh --smoke` — the schema must publish onto an empty database and pass.
3. Add or update an assertion in `tests/smoke.sql` if the change concerns an invariant.
4. Update [data-model.md](data-model.md) if an entity, relationship or open question moved.
5. Open a pull request. CI proves it builds, publishes from empty, publishes twice, and
   passes the smoke tests. The deploy report on `main` records what actually changed.

A change that needs data to be moved or backfilled needs a pre-deployment script, and a
`BlockOnPossibleDataLoss` failure is a signal to write one — not to turn the setting off.
