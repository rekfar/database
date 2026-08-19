# Operations

Creating the Azure database, wiring up deployment, and the routine jobs: backup, restore,
account deletion, reference-data rebuild.

## Creating the Azure SQL database

One-time, and already done — what follows is the record of how, and what to repeat if the
database ever has to be rebuilt. The order matters, and one step is irreversible.

What exists: resource group `rekfar` and logical server `rekfar.database.windows.net`, both
in **Sweden Central**, holding the database `Rekfar`.

1. Create the resource group and the logical server in an **EEA region** (NFR-PRIV-5).
   Authentication is **Entra-only**, so the server has no SQL admin password to store or
   rotate; the `--external-admin-*` arguments name the human administrator.

   ```bash
   az group create --name rekfar --location swedencentral
   ```

   ```bash
   az sql server create --name rekfar --resource-group rekfar --location swedencentral --enable-ad-only-auth --external-admin-principal-type User --external-admin-name "<upn>" --external-admin-sid "<object-id>" --minimal-tls-version 1.2
   ```

   **On the region.** Sweden Central rather than Norway East, which would otherwise be the
   obvious choice: Norway East returns `RegionDoesNotAllowProvisioning` for new SQL servers
   on this subscription, and lifting that needs a support request. Note the trap if a region
   ever has to be changed — a *failed* create still pins the server name to that region in
   ARM, so a later attempt elsewhere fails with `InvalidResourceLocation` even though no
   server exists. Deleting and recreating the (empty) resource group clears it.

2. Create the database on the **Azure SQL Database free offer** — General Purpose,
   serverless. The free grant is 100,000 vCore-seconds and 32 GB of data per database per
   month, renewing monthly for the lifetime of the subscription rather than expiring after a
   year
   ([ADR-0010](https://github.com/rekfar/docs/blob/main/adr/0010-tech-stack-dotnet-azure-sql.md)).

   **Set the collation to `Norwegian_100_CI_AS` at creation.** Azure SQL cannot change a
   database's collation afterwards — fixing a mistake here means creating a new database and
   migrating the data into it. The portal's default is
   `SQL_Latin1_General_CP1_CI_AS`; it must be changed on the *Additional settings* tab
   before the database is created. `tests/smoke.sql` asserts the collation, so CI catches a
   mismatch, but only after the fact.

   ```bash
   az sql db create --resource-group rekfar --server rekfar --name Rekfar --collation Norwegian_100_CI_AS --edition GeneralPurpose --compute-model Serverless --family Gen5 --capacity 1 --use-free-limit --free-limit-exhaustion-behavior AutoPause
   ```

3. `--free-limit-exhaustion-behavior` is the choice of what happens when the monthly free
   limit is exhausted: `AutoPause` until the next month (stays free, the app goes down) or
   `BillOverUsage` to continue and be billed. Under
   [P1](https://github.com/rekfar/docs/blob/main/architecture/principles.md) the free choice
   is the right one for a hobby project — a bill is a worse outcome than an outage. It is set
   to `AutoPause`, which is also the Azure default; it is passed explicitly so that the
   intent is in the command rather than inherited silently.

4. Allow Azure services through the firewall, so the GitHub runner can connect. The
   `0.0.0.0`–`0.0.0.0` range is the special "allow Azure services" rule, not "allow the
   internet". A second rule per administrator IP is needed for `sqlcmd` from a laptop.

   ```bash
   az sql server firewall-rule create -g rekfar -s rekfar -n AllowAllWindowsAzureIps --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
   ```

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

1. Create an Entra **app registration** for deployment (`rekfar-database-deploy`) and a
   service principal for it.
2. Add a **federated credential** on it: GitHub → organisation `rekfar`, repository
   `database`, entity type *Environment*, environment `production`. The subject this
   produces is why the deploy job declares `environment: production` — the credential will
   not issue a token without it.

   **The subject is not the one the portal suggests.** This organisation has GitHub's OIDC
   *immutable unique IDs* enabled, so the token GitHub actually presents embeds the numeric
   organisation and repository IDs:

   ```
   repo:rekfar@317530418/database@1335787582:environment:production
   ```

   rather than the documented `repo:rekfar/database:environment:production`. A credential
   registered with the plain-name form fails with `AADSTS700213: No matching federated
   identity record found`, naming the subject it did receive — read that error, it tells you
   exactly what to register. Both forms are registered on the app, so turning the setting off
   later will not break the deploy.
3. Grant it rights on the database, connected as the Entra admin. Note that `sqlcmd` can
   reuse an `az login` session with `--authentication-method ActiveDirectoryDefault`, which
   avoids handling a password:

   ```sql
   CREATE USER [rekfar-database-deploy] FROM EXTERNAL PROVIDER;
   ALTER ROLE db_owner ADD MEMBER [rekfar-database-deploy];
   ```

   `db_owner` is required: publishing creates and alters schema objects. This principal is
   for deployment only — the API connects as its own, far more limited user.
4. Give the service principal **Reader** on the resource group. Nothing about publishing a
   dacpac needs ARM rights, but `azure/login` runs `az account set --subscription`, which
   fails outright if the principal holds no role at all.
5. Set `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` as repository
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

### Re-running against data already staged

A **rule change does not need a re-download.** The parsed extract stays in
`ingest.SsrPlace` / `ingest.SsrPlacePoint` for as long as its `ingest.Run` row is kept, and
sampled heights stay in `ingest.ElevationSample` indefinitely, so applying a new
`ref.PeakRule` version is a local merge over the most recent snapshot. Only a *wider* rule —
one admitting `navneobjekttype` values that were never staged — needs the extract fetched
and sampled again.

Prune an old snapshot by deleting its run; staging cascades, and the elevation cache does
not, which is the point of keying it by coordinate:

```sql
DELETE FROM ingest.[Run] WHERE Id = @runId;
```

Force re-sampling of stale heights — the terrain model is itself re-flown and republished —
by deleting from the cache. There is no expiry policy in the schema because there is not yet
a reason to prefer one:

```sql
DELETE FROM ingest.ElevationSample WHERE SampledAt < '2026-01-01';
```

Check what happened afterwards:

```sql
SELECT d.Code, r.Status, r.StartedAt, r.SourceVersion, r.RowsRead, r.RowsInserted, r.RowsUpdated, r.RowsRetired
FROM ingest.[Run] r
JOIN [ref].SourceDataset d ON d.Id = r.SourceDatasetId
ORDER BY r.StartedAt DESC;
```

A run that succeeded while reading far fewer rows than usual is the cheapest available
signal that an upstream schema or distribution change has broken parsing.

### Runs stuck in `running`

The import closes its own run on every path it controls, including cancellation. A row left
in `running` therefore means the process died without being able to write — a killed
container, a lost connection, or a runner that ran out of time. It is not harmful: "last
successful run" filters on `succeeded` and is unaffected. What it does do is make the next
run log a warning, because from the database alone a crashed run and a concurrently running
one look identical.

The import deliberately does **not** clean these up. What the right policy is depends on how
often it actually happens, and nobody knows that yet. Close them by hand after confirming no
job is genuinely in flight:

```sql
UPDATE ingest.[Run]
SET [Status] = 'failed', CompletedAt = SYSUTCDATETIME(), [Message] = N'Abandoned; closed by hand.'
WHERE [Status] = 'running' AND StartedAt < DATEADD(hour, -6, SYSUTCDATETIME());
```

## Checking for drift

What the deployed database has that the project does not, or vice versa:

```bash
sqlpackage /Action:DeployReport /SourceFile:src/Rekfar.Database/bin/Release/Rekfar.Database.dacpac /Profile:publish/azure.publish.xml /TargetServerName:rekfar.database.windows.net /TargetDatabaseName:Rekfar /OutputPath:drift.xml
```

Against a database in the state `main` deployed, this reports no changes. Anything else is
drift — a manual change somebody made against the live database — and belongs back in the
project as a proper change.
