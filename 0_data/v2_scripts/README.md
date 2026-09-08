# v2_scripts

![Status](https://img.shields.io/badge/Status-Reference%20only-lightgrey)
![Languages](https://img.shields.io/badge/Languages-R-blue)

Cloned snapshots of the v2 modelling code, taken on **2026-09-08**, one
subfolder per taxon.

These are the code as received, kept unmodified. They are the reference the
rewritten modules in `1_code/modules/` are checked against, and they are
**not run** — nothing in the harness, modules, or experiments sources them.
Subfolder names match those under `1_code/modules/`, so each module has an
obvious reference.

## Sources

| Folder | Source | Taken from | Commit |
| --- | --- | --- | --- |
| `birds/` | <https://github.com/ABbiodiversity/BirdModels> | whole repository | `1a3e086` (2026-04-22) |
| `mammals/` | <https://github.com/ABbiodiversity/MammalModels> | `1_code/2_habitat-modeling/2024/` | `2874dec` (2026-09-01) |
| `plants/` | `\\ABMI-DATA2\science\sc\ToEmily\VegetationModels\1_code\r-scripts` | `1_code/r-scripts/` | `24e97e3` (2025-04-02) |

Each snapshot was verified against its source on 2026-09-08:

- `birds/` — 21 files, cloned that day from `main`.
- `mammals/` — 21 files, every blob hash matches the commit above.
- `plants/` — 19 files, byte-identical to the network path.

The `plants/` source is a working copy on ABMI-DATA2 of
<https://github.com/beallen/VegetationModels>, on `main`. The commit was read
from its `.git` refs; whether that working copy had uncommitted changes was
not checked, so treat the commit as indicative rather than exact.

Soil mites sit in `plants/` because that is how the vegetation repository
groups them — "plant group" names a file layout, not a taxonomy, and covers
vascular plants, bryophytes, lichens and soil mites alike.

## No nested repositories

The `.git/` directories were not kept. An embedded repository is recorded by
the parent as a gitlink rather than as files, which would leave these scripts
untracked here. Re-clone at the commit above to recover history.

`birds/.gitignore` came with the clone and was kept as received. It applies
to that subtree and would exclude `data/`, `figs/` and `out/` if any were
added there.

## Refreshing a snapshot

Replace the folder's contents, update the commit and date in the table above,
and re-check the rewritten module against it. A change here is a change to
the reference the parity gate is measured against, so it should not be made
silently — see [Parity gate](../../README.md#parity-gate).
