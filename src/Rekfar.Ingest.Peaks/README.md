# Rekfar.Ingest.Peaks

The Kartverket peak import: reads the SSR place-name extract, samples elevations from
Høydedata, applies the peak-qualification rule, and merges the result into `ref.Peak`.

It lives in this repository rather than in `backend` because what it consumes is the schema
rather than the domain — see
[ADR-0015](https://github.com/rekfar/docs/blob/main/adr/0015-ingestion-lives-in-the-database-repository.md)
for the reasoning and for the named trigger to revisit it. Which SSR product it reads, and
why, is [ADR-0016](https://github.com/rekfar/docs/blob/main/adr/0016-ssr-general-use-distribution.md).

> **Status: parsing.** Configuration, structured logging, the run record, the schema
> preflight and the GML parser are in place. The parser is not yet wired into a run, so
> running the job still opens `ingest.Run`, does nothing, and closes it with zero counts.

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

## Reading the extract

`SsrGmlReader` streams places out of the whole-country GML — 2.5 GB of XML, read one feature
at a time and never held as a document. Parsing the national extract takes about 18 seconds
and ends with a live heap of 2 MB.

Two things it checks rather than assumes, because both fail silently otherwise:

- **The product specification**, read from the root element's namespace rather than from
  configuration, so an upstream change announces itself in the file being parsed. It is what
  gets recorded as the run's source version.
- **The coordinate reference system.** Kartverket publishes the same data in UTM projections
  under names differing by four characters, and the wrong file parses perfectly into wholly
  wrong coordinates. Anything but EPSG:4258 is refused.

Coordinates are read latitude-first, because `urn:ogc:def:crs:EPSG::4258` declares north-east
axis order, and as `decimal` rather than `double` — the value is the key into the elevation
cache, and two runs that rounded it differently would miss each other's entries.

## Which name a peak gets

A place carries up to five names across Norwegian, three Sami languages and Kvensk, each with
one or more spellings. `PlaceNameSelector` picks one — this is the rule ADR-0016 left open.

1. **Name status:** `hovednavn`, then `sidenavn`, `undernavn`, `historisk`.
2. **The place's own `språkprioritering`.** Each place publishes its own language ordering,
   and the earlier a language appears, the stronger its claim.
3. **Lowest `stedsnavnnummer`** — SSR's own ordering within a place.

Then, within the chosen name, the spelling: by `skrivemåtestatus` (`vedtatt` above `godkjent`,
anything settled above what is merely proposed or historical), then lowest `skrivemåtenummer`.

Step 2 is the one worth understanding. It is deliberately **not** a fixed preference for
Norwegian: 2,042 peaks in the extract rank a Sami language first, and Kartverket's own
ordering is a better authority on which name belongs to a place than a blanket rule would be.
*Rihkedetjahke* is a South Sami peak that a Norwegian-first parser would silently rename to
*Skjækerskaftet*. Document order is never used either — the extract contains places whose
first-listed name is the one the rule rejects.

## What is left out

The extract reaches beyond mainland Norway, and a few of its peaks are outside what this
catalogue covers (ADR-0002): **Newtontoppen** on Svalbard, and ten East Greenland peaks whose
Norwegian names SSR still carries from the Erik the Red's Land claim of 1931. They are
excluded by `MainlandNorwayBounds`, counted, and named in the run log rather than dropped
silently — a change in that count means either the extract or the bounds have moved.

Those same bounds are the axis-order guard, and they are duplicated in
`CK_ingest_SsrPlacePoint_Latitude` / `_Longitude`. The filter decides what is offered to the
database; the constraints are the tripwire for anything that gets past it. Bulk loading passes
`SqlBulkCopyOptions.CheckConstraints` so that tripwire actually runs — without it `SqlBulkCopy`
loads straight past every `CHECK` on the table, silently.

## Tests

```bash
dotnet test tests/Rekfar.Ingest.Peaks.Tests
```

No network, no database. The fixture is nine real features taken verbatim from the national
extract, each present because it isolates one decision: a single point, a multipoint, a place
where status decides the name, one where language decides it, one where the numbering breaks a
tie, a place with no geometry at all, and a road that must be filtered out.

One test reads a whole national extract and is skipped unless you point it at one:

```bash
REKFAR_SSR_EXTRACT=/path/to/Basisdata_0000_Norge_4258_Stedsnavn_GML.gml dotnet test tests/Rekfar.Ingest.Peaks.Tests
```

It asserts what a 30 KB fixture cannot: that memory stays flat across a million features.

## Layout

```
Program.cs                  Wiring, the stage sequence, and exit codes
Database/IngestRun.cs       One row in ingest.Run, from running to a terminal status
Database/SchemaPreflight.cs Fails fast when the database is not the one this build expects
Database/SourceDataset.cs   The dataset ids fixed by the post-deployment seed
Ssr/SsrGmlReader.cs         Streams places out of the GML extract
Ssr/PlaceNameSelector.cs    Chooses the one name a place is displayed under
Ssr/SsrPlace.cs             A parsed place, matching ingest.SsrPlace
```
