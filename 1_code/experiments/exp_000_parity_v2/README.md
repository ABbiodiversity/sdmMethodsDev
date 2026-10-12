# exp_000_parity_v2

![Status](https://img.shields.io/badge/Status-Not%20yet%20gatable-yellow)
![Languages](https://img.shields.io/badge/Languages-R-blue)

The validation gate. Runs each taxon's v2 spec through the harness and
compares the result with the published v2 output. Every other
experiment is compared against this one.

## Question

Does the framework, configured as v2, reproduce the v2 results? If it
does, a difference in a later experiment is a difference in method,
not in plumbing.

## How to run

From the repository root:

```r
source("1_code/experiments/exp_000_parity_v2/run.R")
```

Every decision is in `run.R`'s `experiment_config()` call (section
1.2); section 1.3 points the run at the v2 reference. As committed,
`run.R` runs the `parity_check` species at 5 draws on 12 workers. For
the gate, set `species = NULL` and `n_bootstraps = 100`.
`run_experiment()` fits, summarizes, then runs this experiment's steps:

| Step | Script | Writes, in `3_output/exp_000_parity_v2/` |
| --- | --- | --- |
| compare | `01_compare_to_v2.R` | `tables/parity_terms.csv`, `tables/parity_summary.csv` |
| plot | `02_plot_parity.R` | `figures/parity_<taxon>.png`, `parity_mean.png`, `parity_bell.png` |
| report | `03_build_report.R` | `report.md` |

`utils/parity_targets.R` holds the targets the compare step reads.
`v2_self_agreement.R` is not part of `run.R`: run it once, after
`_setup/03` and `_setup/06`, to write
`tables/v2_self_agreement.csv` and `v2_self_agreement_summary.csv`.

## Inputs and outputs

- **Inputs:** the published test dataset, and
  `abmiexplorer/v2_results.csv` from the published v2 results (both
  via `harness/data_source.R`).
- **Outputs:** the stores in `2_pipeline/exp_000_parity_v2/`, the
  summary tables every experiment writes (see the
  [harness README](../../harness/README.md#outputs)), and:

| Output | Holds |
| --- | --- |
| `tables/parity_terms.csv` | Term by term: `coefficient_summary.csv` joined to the v2 reference. Adds `ref_region`, `ref_part`, the v2 summary (`v2_median`, `v2_p10`, `v2_p90`, `v2_n`), `comparison` (`median`, or `iteration 1` where v2 fits once), `reachable`, `in_band`, `absolute_difference` and `standardized_difference` (gap ÷ half this run's band). Gitignored |
| `tables/parity_summary.csv` | The gate: one row per taxon × region × stage, with in-band rates, gaps, `median_band_ratio`, `median_spearman` (not gated), `min_draws`, `verdict` and `indicative_verdict` |
| `figures/` | Each term's run and v2 median and band relative to v2; the per-taxon mean; v2 and the run as distributions |
| `report.md` | Run kind and seed, what each spec reproduces of v2, parity by stage, model fit |

## What it covers

Each spec's `v2_coverage` is the authoritative statement, and
`report.md` prints it. In short:

| Taxon | Climate | Habitat or landcover | Resampling |
| --- | --- | --- | --- |
| Plant group (×4) | v2's 58-model set, fitted once province-wide; exact to v2's code | IVW on the grid, stand-age splines, cutblock convergence, footprint pooling and pAspen; exact to v2 on the full-data draw | Once per species over the province, or v2's stored draws |
| Mammals | v2's precomputed climate prediction | The hurdle (presence, abundance, total) on the full habitat set, with splines, calibration and convergence; exact to v2's published tables | v2 fits once; iteration 1 is compared |
| Birds | v2's 25 candidates, province-wide, carried as exp(link) without the QPAD offset; exact to v2's code | Weighted staged BIC; exact to v2's code | v2's stored draws |

If this table and the specs disagree, the specs are right.

## The v2 reference

`v2_results.csv` is built by `_setup/06` from ABMIexploreR's published
coefficients (`data/species-coefs.RData`), pinned to commit `848eeed`.
On 2026-10-02 it matched the retired by-hand build from the network
drives to about 1e-15 on every shared species and term. Gaps:

- `Bryum.All`, and `Trhypochthonius.tectorum` in the north, are not
  published.
- Bird `TreedFen` is one coefficient in the package and nine age
  classes in v2, so those terms do not join.
- Mammals: the pinned commit holds the 2024 tables the harness
  reproduces, on the link scale; `08` back-transforms them. Its draws
  are one fit repeated, so they are scored on iteration 1. South
  `WetlandMargin`, the placeholder `Bare`, woodland caribou and deer
  are not published.

`08` relabels the package's terms to the harness's names only where
values were checked identical. Plant habitat terms are relabelled as
v2 publishes them; bird landcover is translated onto v2's habitat
template by `modules/birds/standardize.R`; mammal seasons are averaged,
as v2's `.all` tables are. Terms v2 sets by machinery the harness
lacks are listed in `v2_unreachable_terms()` (`01_compare_to_v2.R`)
and left out of the reachable scores.

## Parity targets (proposed)

In `utils/parity_targets.R`. **Proposals until agreed.**

| Comparison | Passes when |
| --- | --- |
| Numerical (iteration 1, where v2 fits once: the mammal hurdle) | Every reachable term within 1e-6 |
| Distributional (plant and bird stages) | At least 90% of reachable terms in band, median standardized difference ≤ 0.25, and median band-width ratio between 0.75 and 1.33 |

They are set from how closely two v2 runs agree with each other
(`v2_self_agreement.R`: the bryophyte climate stage, ABMIexploreR's
run against `_setup/03`'s rerun). Measured against v2's `COEFS.RData`:

| Measure | v2 against itself |
| --- | --- |
| Terms with one run's median in the other's 10–90% band | 100% |
| Median standardized difference | 0.019 |
| Band-width ratio, median per species | 1.005 (5th–95th percentile 0.81–1.19) |
| Median per-species Spearman of the medians | 0.998 |

The band ratio and Spearman skip **negligible terms**, those both runs
put below a millionth of the term's typical size (`is_negligible()`).
Spearman is reported but not gated: it failed mite climate with every
term in band, on the ordering of near-zero terms.

Only a full run (every species, 100 draws) is gated. A 100-draw run on
a species subset gets an `indicative_verdict` instead. Neither is
given to a row whose store holds fewer draws than v2 (`min_draws`).

Assumptions: the calibration covers plant climate only, and is applied
to plant habitat and birds without a second v2 run to check it. No test
compares whole-model predictions. The negligible-term fraction and the
90th-percentile typical size are judgement calls.

## Status

**Indicative result, 2026-10-03, `parity_check` set, 100 draws:** all
22 rows pass, 100% of reachable terms in band. Mammal habitat matches
v2 to ≤1e-14; plant band-width ratios are 0.88–1.05. Birds passed after
two fixes on 2026-10-02: the dataset is harmonized from the
pre-rebuild `Stratified.Rdata` in `remote/birds_data_v2/`, and the
carried climate prediction no longer includes the QPAD offset.

The committed `tables/` and `run_record.md` are from a later 5-draw
trial (2026-10-06) and are not gated.

## Before this gate can be closed

1. **Agree the parity targets**, or change them in
   `utils/parity_targets.R`.
2. **Run the full species queues at 100 draws** and commit the report
   and record. That run is days of compute.
3. **Get references that can be matched exactly.** The published
   lichen, mite and vascular plant models were fitted on draws v2 did
   not keep. Re-running v2 on the stored draws, as `_setup/03` did for
   bryophytes, would make those gates numerical.

## See also

- [`docs/taxon_quirks.md`](../../../docs/taxon_quirks.md): every
  taxon-specific v2 behaviour and the harness's status against each.
- [`docs/reviews/2026-09-28_alignment_review.md`](../../../docs/reviews/2026-09-28_alignment_review.md):
  the evidence behind the gaps above.
