# Rekfar.Ingest.Peaks

The Kartverket peak import: reads the SSR place-name extract, samples elevations from
Høydedata, applies the peak-qualification rule, and merges the result into `ref.Peak`.

It lives in this repository rather than in `backend` because what it consumes is the schema
rather than the domain — see
[ADR-0015](https://github.com/rekfar/docs/blob/main/adr/0015-ingestion-lives-in-the-database-repository.md)
for the reasoning and for the named trigger to revisit it. Which SSR product it reads, and
why, is [ADR-0016](https://github.com/rekfar/docs/blob/main/adr/0016-ssr-general-use-distribution.md).

> **Status: skeleton.** Configuration, structured logging, the run record and the schema
> preflight are in place. None of the ingestion stages are implemented yet, so a run
> currently opens `ingest.Run`, does nothing, and closes it as succeeded with zero counts.

## Running it

The connection string comes from the environment. There is deliberately no configuration
file for it in this repository: it names a server and carries either credentials or an
authentication mode, and neither belongs in version control.

```bash
export ConnectionStrings__Rekfar="Server=localhost,1433;Database=Rekfar;User Id=sa;Password=$MSSQL_SA_PASSWORD;Encrypt=True;TrustServerCertificate=True"
```

```bash
dotnet run --project src/Rekfar.Ingest.Peaks
```

Against Azure SQL it authenticates as its own least-privileged principal rather than the
deployment one — a job that refreshes reference data has no business being able to read a
diary note:

```bash
export ConnectionStrings__Rekfar="Server=rekfar.database.windows.net;Database=Rekfar;Authentication=Active Directory Default;Encrypt=True"
```

`TrustServerCertificate=True` is for the local container's self-signed certificate only.
Never set it against Azure.

## Exit codes

The scheduled workflow reads these, so they are part of the contract rather than incidental.

| Code | Meaning |
| --- | --- |
| `0` | The run completed and is recorded as `succeeded` |
| `1` | The run failed. `ingest.Run` records it as `failed` with the reason, unless the failure was reaching the database at all |
| `2` | Misconfigured — nothing ran, and nothing was recorded |

## What it checks before doing anything

`SchemaPreflight` asserts that the target database has the tables this build expects and
that `ref.SourceDataset` has been seeded. ADR-0013 accepted that the model is expressed
twice and that the two can drift; this is where that drift is caught for ingestion. Without
it, a database older than the program fails somewhere in the middle of a run with a stack
trace that does not say so.

It also warns — without failing — when the seeded `ProductSpecVersion` disagrees with the
specification this build parses. That disagreement is exactly what ADR-0016 pinned the
version to make visible.

## Logging

One JSON object per line, on stdout. Every line emitted after the run opens carries its
`RunId`, so a run can be followed through a log aggregator without correlating timestamps.

```bash
dotnet run --project src/Rekfar.Ingest.Peaks | jq -r '"\(.LogLevel)\t\(.Message)"'
```

## Layout

```
Program.cs                  Wiring, the stage sequence, and exit codes
Database/IngestRun.cs       One row in ingest.Run, from running to a terminal status
Database/SchemaPreflight.cs Fails fast when the database is not the one this build expects
Database/SourceDataset.cs   The dataset ids fixed by the post-deployment seed
```
