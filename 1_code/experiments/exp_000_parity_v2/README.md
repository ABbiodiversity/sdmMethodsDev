# exp_000_parity_v2

![Status](https://img.shields.io/badge/Status-Scaffolded-yellow)
![Languages](https://img.shields.io/badge/Languages-R-blue)

The validation gate. Runs the v2.0 models through this repository's
pipeline and compares the results against the published species models
v2.0 outputs.

## Question

Does running the unmodified v2 scripts through this repository's
harness and modules reproduce the v2.0 results?

Everything downstream depends on the answer. Later experiments are
compared against this one, so a difference here is a difference in the
plumbing, not in the method being tested.

## Design

| Element | Value |
| --- | --- |
| Taxa | Set per run in `run.R` (`mites <- TRUE`, and so on) |
| Species | Set per taxon in `utils/species_lists.R`; `NULL` runs all |
| Bootstraps | 100, hard-coded in the v2 scripts |
| Reference | The published v2.0 output — source still to be agreed |
| Target | Not yet defined; to be agreed per taxon |

## Files

| File | Purpose |
| --- | --- |
| `run.R` | Entry point. Taxon flags, staging, module calls |
| `utils/species_lists.R` | The species vector for each taxon |
| `01_collect_results.R` | Raw v2 output → flat summary tables |
| `02_compare_to_v2.R` | The parity comparison itself |
| `03_build_report.R` | Tables and figures → `report.md` |

## How to run

1. Set `SDM_V2_ROOT` to the v2 project holding the source data. It is
   read only, and only while staging.
2. Edit `utils/species_lists.R` to name the species to model. Start
   short — the v2 scripts always run 100 bootstraps, so the species
   count is the only way to shorten a run.
3. Set the taxon flags in `run.R` section 1.4.
4. Run `run.R` from the repository root.

```r
source("1_code/experiments/exp_000_parity_v2/run.R")
```

## Outputs

Intermediates, per taxon, in `2_pipeline/exp_000_parity_v2/`:

- `<taxon>/` — the staged run root, plus the raw v2 model and
  validation output. Gitignored; too large to commit.
- `logs/` — one timestamped log per pipeline step.

Deliverables in `3_output/exp_000_parity_v2/`:

- `tables/`, `figures/`, `report.md` — committed, so comparisons
  across experiments can be made from the repository alone.

## Status

Scaffolded. The taxon modules and staging run; `01`–`03` are
placeholders pending two decisions:

- Where the v2.0 reference output comes from.
- What the minimum acceptable parity target is, per taxon.
