# Operations

Creating the Azure database, wiring up deployment, and the routine jobs: backup, restore,
account deletion, reference-data rebuild.

## Creating the Azure SQL database

One-time. The order matters, and one step is irreversible.

1. Create the database on the **Azure SQL Database free offer** — General Purpose,
   serverless, in an **EEA region** (NFR-PRIV-5). The free grant is 100,000 vCore-seconds
   and 32 GB of data per database per month, renewing monthly for the lifetime of the
   subscription rather than expiring after a year
   ([ADR-0010](https://github.com/rekfar/docs/blob/main/adr/0010-tech-stack-dotnet-azure-sql.md)).

2. **Set the collation to `Norwegian_100_CI_AS` at creation.** Azure SQL cannot change a
   database's collation afterwards — fixing a mistake here means creating a new database and
   migrating the data into it. The portal's default is
   `SQL_Latin1_General_CP1_CI_AS`; it must be changed on the *Additional settings* tab
   before the database is created. `tests/smoke.sql` asserts the collation, so CI catches a
   mismatch, but only after the fact.

   ```bash
   az sql db create --resource-group rekfar --server rekfar --name Rekfar --collation Norwegian_100_CI_AS --edition GeneralPurpose --compute-model Serverless --family Gen5 --capacity 1 --use-free-limit
   ```

3. Choose the behaviour when the monthly free limit is exhausted: **auto-pause until the
   next month** (stays free, the app goes down) or continue and be billed. Under
   [P1](https://github.com/rekfar/docs/blob/main/architecture/principles.md) the free choice
   is the right one for a hobby project — a bill is a worse outcome than an outage.

4. Set an **Entra admin** on the logical server, and allow Azure services through the
   firewall so the GitHub runner can connect.

### Auto-pause and cold starts

Serverless pauses the database after an idle period, and the first query afterwards can take
tens of seconds while it resumes. This is a known accepted trade-off with an open follow-up
against it: measure the resume time with a realistic spatial query before the Phase 1 exit
review. Mitigations, in order of preference, are raising the auto-pause delay and adding a
lightweight warm-up ping. Neither belongs in this repository — record the measurement in the
ADR follow-up.

## Deployment authentication

The deploy workflow uses a **federated credential**, so no long-lived database or Azure
secret is stored in the repository.

1. Create an Entra **app registration** for deployment (e.g. `rekfar-database-deploy`).
2. Add a **federated credential** on it: GitHub → organisation `rekfar`, repository
   `database`, entity type *Environment*, environment `production`. That produces the
   subject `repo:rekfar/database:environment:production`, which is why the deploy job
   declares `environment: production` — the credential will not issue a token without it.
3. Grant it rights on the database, connected as the Entra admin:

   ```sql
   CREATE USER [rekfar-database-deploy] FROM EXTERNAL PROVIDER;
   ALTER ROLE db_owner ADD MEMBER [rekfar-database-deploy];
   ```

   `db_owner` is required: publishing creates and alters schema objects. This principal is
   for deployment only — the API connects as its own, far more limited user.
4. Set `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` as repository
   secrets, and `AZURE_SQL_SERVER` and `AZURE_SQL_DATABASE` as repository variables.

If federated credentials turn out to be more setup than is wanted on day one, the fallback
is a `SqlPackage /TargetConnectionString:` from a repository secret. It works, and it means a
long-lived credential in GitHub that has to be rotated by hand — prefer OIDC.

## Backups

Azure SQL takes **automated backups** with point-in-time restore; on the free offer the
retention is the default 7 days. That satisfies NFR-REL-1 without anything to run, but two
things still need doing:

- **Confirm the retention actually in effect** on the database, rather than assuming the
  default.
- **Test a restore.** An untested restore path is not a restore path. Do it once, note how
  long it took, and note whether the restored database lands inside or outside the free
  offer — a restore creates a *new* database, and the free offer covers up to 10 databases
  per subscription, so a restore can silently become billable.

Only `auth` and `app` data needs any of this. `ref` and `ingest` are rebuildable
(NFR-REL-2, NFR-INTEG-6).

### Restoring

```bash
az sql db restore --resource-group rekfar --server rekfar --name Rekfar --dest-name Rekfar-restored --time "2026-08-16T09:00:00Z"
```

Restore to a new name, verify it, then repoint the API. Do not restore over a live database.

## Deleting an account (FR-ACC-5, GDPR)

One statement. Every user-data table cascades from `auth.User`:

```sql
DELETE FROM auth.[User] WHERE Id = @userId;
```

`tests/smoke.sql` asserts that this leaves nothing behind and that it does not touch
reference data. When photos arrive (Phase 2) this stops being sufficient on its own —
blobs live in object storage and will need deleting alongside.

## Rebuilding reference data

Reference data is a local copy of published Kartverket datasets, so the recovery procedure
for it is re-import rather than restore. Re-running ingestion is the normal path: the
`(SourceDatasetId, ExternalId)` key turns a re-import into updates.

A full rebuild — new peak rule, or a corrupted catalogue — has one constraint:
`app.TripPeak` references `ref.Peak`, so peaks users have logged cannot be deleted. That
foreign key is deliberate. A rebuild updates rows in place and retires the ones the new rule
no longer admits (`IsActive = 0`); it does not truncate.

Check what happened afterwards:

```sql
SELECT d.Code, r.Status, r.StartedAt, r.SourceVersion, r.RowsRead, r.RowsInserted, r.RowsUpdated, r.RowsRetired
FROM ingest.[Run] r
JOIN [ref].SourceDataset d ON d.Id = r.SourceDatasetId
ORDER BY r.StartedAt DESC;
```

A run that succeeded while reading far fewer rows than usual is the cheapest available
signal that an upstream schema or distribution change has broken parsing.

## Checking for drift

What the deployed database has that the project does not, or vice versa:

```bash
sqlpackage /Action:DeployReport /SourceFile:src/Rekfar.Database/bin/Release/Rekfar.Database.dacpac /Profile:publish/azure.publish.xml /TargetServerName:rekfar.database.windows.net /TargetDatabaseName:Rekfar /OutputPath:drift.xml
```

Against a database in the state `main` deployed, this reports no changes. Anything else is
drift — a manual change somebody made against the live database — and belongs back in the
project as a proper change.
