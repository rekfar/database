# Rekfar — database

The schema for [Rekfar](https://github.com/rekfar/docs), as a declarative **SQL Database
Project**. Every database object is one `.sql` file; `dotnet build` aggregates them into a
`.dacpac`, and `SqlPackage` works out the change script needed to bring a database to
that state.

The target is **Azure SQL Database** on its free offer, with `geography` columns for
spatial data ([ADR-0010](https://github.com/rekfar/docs/blob/main/adr/0010-tech-stack-dotnet-azure-sql.md)).

## Stack

| | |
| --- | --- |
| Schema format | SQL Database Project, `Microsoft.Build.Sql` 2.2.0 (SDK-style `.sqlproj`) |
| Build output | `src/Rekfar.Database/bin/Release/Rekfar.Database.dacpac` |
| Deploy tool | `Microsoft.SqlPackage` 170.4.83 (.NET global tool) |
| Target | Azure SQL Database (`SqlAzureV12` provider) |
| Local | SQL Server 2022 in Docker |

Requires the .NET 8 SDK or newer (`global.json` sets the floor and rolls forward).

## This repository owns the schema

The schema is defined **here**, not by EF Core migrations in the backend. The backend
uses EF Core purely as a query and mapping layer, with its model configured to match what
this project defines — `dotnet ef migrations` is not used against this database.

The reason is that the schema is the longest-lived thing in the project and the part where
a mistake is most expensive. A declarative definition means a pull request shows the
schema as it will be, a deploy computes its own change script, and drift from what is
deployed is detectable rather than assumed.

The practical contract for the backend is in [docs/conventions.md](docs/conventions.md);
the short version is that CI publishes a versioned `dacpac` artifact, which is what the
backend's integration tests should stand a real database up from.

## Getting started

```bash
cp local/.env.example local/.env
```

```bash
dotnet tool install --global microsoft.sqlpackage
```

```bash
local/reset.sh --smoke
```

`reset.sh` starts SQL Server in Docker, recreates the database with the Norwegian
collation, publishes the current schema, and runs the smoke tests.

| Command | Purpose |
| --- | --- |
| `dotnet build src/Rekfar.Database` | Build the `.dacpac`; fails on any T-SQL warning |
| `local/reset.sh` | Rebuild the local database from scratch |
| `local/reset.sh --smoke` | …and run `tests/smoke.sql` against it |
| `docker compose -f local/docker-compose.yml down -v` | Remove the local database entirely |

On Apple Silicon the SQL Server image runs under x86-64 emulation — Microsoft publishes
no arm64 build. First start takes a while; the engine itself, spatial types included,
behaves the same.

## Layout

```
src/Rekfar.Database/        The schema — one file per object
  Schemas/                  auth, app, ref, ingest
  Tables/<schema>/
  Scripts/PostDeployment/   Idempotent seed data (code lists, provenance)
publish/                    Publish profiles — behaviour only, no credentials
local/                      Docker Compose + reset script
tests/smoke.sql             Invariants the schema must guarantee
docs/                       Conventions, data model, operations
```

Four schemas, mirroring the split in the
[data architecture](https://github.com/rekfar/docs/blob/main/architecture/03-data-architecture.md):

| Schema | Contents | Backup |
| --- | --- | --- |
| `auth` | Credentials and sign-in state | Yes |
| `app` | User data — profile, trips, diary notes | **Yes — the one hard line** |
| `ref` | Kartverket reference data + provenance | No: rebuildable by re-import |
| `ingest` | Ingestion run history | No |

Keeping them apart is what makes that last column actionable instead of aspirational.

## Testing

`tests/smoke.sql` asserts the invariants the schema is responsible for — that a diary note
cannot be made public, that geometry cannot be stored in the wrong coordinate system, that
deleting an account removes all of its data, that a peak a user has logged cannot be
deleted by a data refresh. CI runs it against a freshly published database on every push
and pull request.

It refuses to run against a database that contains accounts.

## Deployment

`.github/workflows/ci.yml` builds the `dacpac`, proves it publishes cleanly onto an empty
database, proves publishing twice is a no-op, and runs the smoke tests. On `main`, and only
if all of that passed, it publishes to Azure SQL using the artifact the tests ran against.

Two settings in `publish/azure.publish.xml` are deliberate and should not be relaxed
casually: `BlockOnPossibleDataLoss` stops any deploy that would discard data, and
`DropObjectsNotInSource` is off, so removing an object from the project produces a line in
the deploy report to review rather than a `DROP` on the next push.

Azure authentication uses a **federated credential** (OIDC), so there is no long-lived
secret in the repository. Setup steps, along with backup and restore, are in
[docs/operations.md](docs/operations.md).

### Required repository configuration

Variables, under _Settings → Secrets and variables → Actions → Variables_:

| Variable | Example |
| --- | --- |
| `AZURE_SQL_SERVER` | `rekfar.database.windows.net` |
| `AZURE_SQL_DATABASE` | `Rekfar` |

Secrets, under _Secrets_:

| Secret | Where it comes from |
| --- | --- |
| `AZURE_CLIENT_ID` | The Entra app registration used for deployment |
| `AZURE_TENANT_ID` | Entra tenant |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription |

## Documentation

- [docs/data-model.md](docs/data-model.md) — what is modelled, and the traceability back
  to requirements and decisions.
- [docs/conventions.md](docs/conventions.md) — naming, types, keys, code values, and the
  contract with the backend.
- [docs/operations.md](docs/operations.md) — creating the Azure database, deploy
  authentication, backups, restore, GDPR deletion, reference-data rebuild.

Architecture, requirements and decisions live in the
[docs repository](https://github.com/rekfar/docs).
