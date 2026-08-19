# The peak rule

Which SSR places become peaks in Rekfar's catalogue, why, and how to change it.

Kartverket publishes place names, not an editorial judgement about which summits are worth
visiting. [ADR-0012](https://github.com/rekfar/docs/blob/main/adr/0012-kartverket-primary-source.md)
§5.1 recorded that as something Rekfar has to decide for itself, and FR-REF-11 requires the
decision to be **documented and versioned** so the catalogue is reproducible. This is that
document; the rule itself is data, in `ref.PeakRule` and `ref.PeakRuleObjectType`, seeded by
`Scripts/PostDeployment/Seed.PeakRule.sql`.

Every peak carries the version that admitted it, in `ref.Peak.PeakRuleVersion`.

## Version 1.0

An SSR place is a peak when all of the following hold.

| | Criterion |
| --- | --- |
| **Type** | `navneobjekttype` is `fjell` or `topp` |
| **Extent** | Every representation point is within mainland Norway |
| **Elevation** | The highest point samples at **100 m or more** in Kartverket's terrain model |

Elevation is the **maximum** over the place's representation points — roughly half carry
more than one, and SSR does not say which is the summit — ignoring any answer from a
bathymetric source.

This admits **28,876** of the extract's 1,058,852 places.

### Why the type filter is the editorial rule

SSR's `høyder` group holds 175,026 places across eleven types. Most of them are not
mountains in any useful sense:

| Type | Count | |
| --- | --- | --- |
| `ås` | 51,014 | ridge / hill |
| `haug` | 49,986 | mound, knoll |
| **`fjell`** | **25,375** | **mountain** |
| `berg` | 16,021 | rock, crag |
| `høyde` | 10,233 | height, rise |
| `hei` | 8,904 | moor |
| `rygg` | 7,529 | ridge |
| **`topp`** | **4,562** | **summit** |

Taking `fjell` and `topp` and leaving the rest is the judgement. Including `ås` and `haug`
would roughly six-fold the catalogue with features that no one logs as a summit trip;
excluding them costs almost nothing, because a genuine mountain is very rarely typed as a
mound.

### Why the floor is 100 m and not higher

The floor is a **sanity guard, not a curation device**. Its job is to remove sea-level
artefacts — coastal knolls typed `fjell`, and points whose sampled height is essentially the
shoreline. It is deliberately not doing the work the type filter already does.

Norway's peak-bagging culture runs a long way below the treeline, and a threshold chosen for
tidiness cuts real destinations:

| Destination | Elevation | Survives 100 m | Survives 300 m | Survives 500 m |
| --- | --- | --- | --- | --- |
| Gaustatoppen | 1882 | yes | yes | yes |
| Kjerag | 1108 | yes | yes | yes |
| Ulriken, Bergen | 647 | yes | yes | yes |
| Segla, Senja | 635 | yes | yes | yes |
| Reinebringen, Lofoten | 483 | yes | yes | **no** |
| Hoven, Vågan | 367 | yes | yes | **no** |
| **Torghatten, Brønnøy** | **257** | yes | **no** | **no** |

Losing Torghatten — one of the best-known landmarks on the coast — is the kind of thing that
would have to be defended to a user who had just hiked it. Below 100 m what remains is
genuinely marginal: *Fuggelfjell* at 11 m, *Selsnipa* at 36 m.

What each floor would admit, measured against the 2026-08-14 extract:

| Floor | Peaks |
| --- | --- |
| 0 m | 29,876 |
| **100 m** | **28,876** |
| 200 m | 27,046 |
| 300 m | 24,864 |
| 500 m | 20,397 |
| 1000 m | 9,939 |

### What 1.0 deliberately leaves out

- **Prominence (*primærfaktor*).** The obvious way to decide whether a bump is its own
  summit, and the usual basis for Norwegian peak lists. Kartverket publishes no prominence
  value, so it would have to be computed from the terrain model — a raster analysis over the
  whole country, and a piece of work in its own right. `ref.Peak.ProminenceMeters` and
  `ref.PeakRule.MinProminenceMeters` exist for when it is.
- **Svalbard and the Norwegian names in East Greenland.** Excluded with the rest of what
  falls outside mainland Norway; see `MainlandNorwayBounds`.
- **Manual curation.** Nothing is added or removed by hand. If that ever becomes necessary
  it should be a separate, visible layer rather than edits to a generated catalogue.

### Known consequences

- **49 candidates have no usable elevation** and so cannot pass the floor: 37 carry no
  representation point at all, and the rest are answered only from a bathymetric source or
  from outside the model's coverage.
- **Nine points sample as depths** rather than heights, because their representation point
  sits just offshore — *Systrene* in Aurland at −246 m for both of its points. Ignoring
  bathymetric answers is part of the rule for this reason.
- **Names repeat heavily.** Ten places called *Fløyen*, five *Skåla*, two *Galdhøpiggen*.
  `stedsnummer` is the identity; the name is not.

## Changing the rule

**A published version is never edited.** Peaks carry the version that admitted them, so
changing 1.0's threshold would silently reinterpret rows already stamped with it, and the
catalogue would no longer be reproducible from its own record.

A change is a new version:

1. Add it to `Seed.PeakRule.sql` with its own `Version`, and its types to
   `ref.PeakRuleObjectType`.
2. Re-run the merge stage of the import.

That is deliberately cheap. The parsed extract lives in `ingest.SsrPlace` and the sampled
heights in `ingest.ElevationSample`, so a new rule is a re-merge over local data rather than
a re-download and a re-sample. Only a rule admitting `navneobjekttype` values that were never
staged needs the extract fetched again — and which types are staged is configuration
(`Ingestion__NavneobjektTypes`), not code.

Rows the new rule no longer admits are **retired**, never deleted: `IsActive = 0` with
`RetiredAt` set, because somebody may have logged a trip to one.
