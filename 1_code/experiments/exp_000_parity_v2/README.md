# exp_000_parity_v2

![Status](https://img.shields.io/badge/Status-Not%20yet%20gatable-yellow)
![Languages](https://img.shields.io/badge/Languages-R-blue)

The validation gate. Runs each taxon's v2 spec through the harness and
compares the result against the published v2 output.

## Question

Does the framework, configured as v2, reproduce the v2 results?

Everything downstream depends on the answer. Later experiments are
compared against this one, so a difference here is a difference in the
plumbing, not in the method being tested.

## What it covers

Coverage is stated in one place: each spec's `v2_coverage`, in
`1_code/modules/<taxon>/spec.R` (the four plant-group taxa share
`_shared/plant_group.R`). The report prints it from there on every run,
so read `3_output/exp_000_parity_v2/report.md` for the current
statement. In short:

| Taxon | Climate | Habitat or landcover | Resampling |
| --- | --- | --- | --- |
| Plant group (×4) | Reproduced: v2's 58-model set, fitted once province-wide; exact to v2's code | Reproduced: IVW on the grid, stand-age splines, cutblock convergence, footprint pooling and pAspen; exact to v2 on the full-data draw | Reproduced: once per species over the province, or v2's own stored draws |
| Mammals | Reproduced: v2's precomputed climate prediction | Reproduced: the hurdle (presence, abundance, total) on the full habitat set, with splines, calibration and convergence; exact to v2's published tables | v2 fits once; iteration 1 is compared |
| Birds | Reproduced: v2's 25 candidates, province-wide, carried as exp(link + offset); exact to v2's code | Reproduced: weighted staged BIC from `count ~ climate`; exact to v2's code | Reproduced: v2's stored draws |

If this table and the specs disagree, the specs are right; update this
table.

## What the gate compares today

`02_compare_to_v2.R` compares **every stage** against one
`v2_results.csv`, so it runs with the network drives unmounted.
`v2_reference` in `run.R` section 1.3a picks which build of it:

| `v2_reference` | Built by | Source | Holds |
| -------------- | -------- | ------ | ----- |
| `"abmiexplorer"` (default) | `_setup/08_harmonize_abmiexplorer_results.R` | `data/species-coefs.RData` from [ABMIexploreR](https://github.com/ABbiodiversity/ABMIexploreR), pinned to commit `848eeed` | Only the published species. Every taxon, plus amphibians. |
| `"drives"` | `_setup/05_harmonize_v2_results.R` | `COEFS.RData`, the Mammals drive, `Birds2024.RData` | Every species v2 fitted. |

The two builds use the same models for every taxon. On 2026-10-02
every shared species and term matched to about 1e-15, except where
some v2 draws failed. `05` drops failed draws; the package stores 100 finite
draws for every cell. Re-scoring the `parity_check` run against both
builds gave the same in-band rates, standardized differences and
verdicts wherever both had the species. The differences are in
coverage:

- **Species.** `Bryum.All`, plus `Trhypochthonius.tectorum` in the
  north, are not published, so they have no package reference.
- **Bird `TreedFen`.** The package holds one `TreedFen` coefficient
  where v2 has nine age classes, so those terms do not join. The
  package's value correlates at about 0.99 with each age class.
- **Mammals.** The package's mammal data were replaced on 2026-07-27.
  The pinned commit holds the 2024 coefficient tables the harness
  reproduces (an earlier July 2025 set was a different fit, presence
  in the north only). The package stores them on the link scale, and
  `08` back-transforms them (logit for presence, log for abundance
  and total). Its 100 draws are one fit repeated, so they are scored
  on iteration 1, as against `05`. South `WetlandMargin` and the
  placeholder `Bare` are not in the package. Woodland caribou and
  deer are not published.

`08` adds the package's relabelled terms under the harness's names
(`TreedBog*` → `BlackSpruce*` for birds, `TreedFen` → each plant fen
age, `RuralResidential` → `Rural`, mammals' `WhiteSpruce*` → `Spruce*`,
and so on). It adds these only where
the values were checked to be identical. It also drops the template's
all-zero padding cells.

- **Climate:** scored against v2's single province-wide fit
  (`region = "all"`), which the harness now reproduces: one fit per draw,
  shared by both regions.
- **Plant habitat:** terms relabelled as v2's `04a` standardization
  publishes them (`BlackSpruce` as `TreedBog`, `UrbInd` copied to
  `Urban`, `Industrial` and `Rural`, and so on). The unaged stand types do
  not join, because v2 publishes only their spline-fitted age classes.
- **Bird habitat:** the landcover coefficients translated onto v2's
  standardized template by `modules/birds/standardize.R`, a port of
  v2's `08.PackageCoefficients.R`. Checked against v2's own packaged
  output: translating v2's raw per-draw coefficients reproduces
  `Birds2024.RData` exactly. The raw `landcover` stage is kept in the
  summary but not scored.
- **Mammals:** the summer and winter runs are averaged, as v2's `.all`
  tables are, and compared at iteration 1, because v2 fits once. The
  hurdle writes presence, abundance and total abundance on v2's full
  habitat set, each joined to its own v2 table.

Terms v2 sets with machinery the harness lacks, or fixes at a placeholder,
are listed from the v2 code in `v2_unreachable_terms()` and left out of
the reachable scores. The report lists anything its comparison could not
join, so this is checkable run by run.

Earlier ad hoc checks put mammal presence at r = 0.985 and abundance at
r = 0.79 against v2 on iteration 1. They were not produced by the
committed gate and cannot be regenerated from it.

## Parity targets (proposed)

The targets live in `utils/parity_targets.R`, and `02_compare_to_v2.R`
reads a `verdict` per taxon, region and stage against them. **They are
proposals until agreed**; the report says so.

**How closely v2 agrees with itself.** `v2_self_agreement.R` compares two
v2 runs of the same code on the same data: the bryophyte climate stage as
published in `COEFS.RData`, and the rerun `_setup/03` made, 134 species by
19 terms by 100 draws each, scored exactly as the gate scores the harness.

| Measure | v2 against itself |
| --- | --- |
| Terms with one run's median in the other's 10–90% band | 100% |
| Median standardized difference | 0.019 |
| Band-width ratio (one run's band over the other's), median per species | 1.005 (5th–95th percentile over species 0.81–1.19) |
| Median per-species Spearman correlation of the medians | 0.998 (10th percentile 0.917) |

The ratio and the Spearman leave out **negligible terms**: those both runs
put below a millionth of the term's typical size, the 90th percentile of its
absolute v2 median over every species of the taxon and stage
(`is_negligible()` in `utils/parity_targets.R`). Model averaging shrinks
unsupported terms to 1e-20 or 1e-140, where band widths and ranks are
noise. Typical size is per term because terms carry units: an `Easting`
coefficient of 1e-6 is real, a `MAP` one of 1e-21 is not.

At 100 draws a median is stable relative to the 10–90% band, so a correct
reimplementation should reach close to these. The targets leave a margin
for one run being compared with one run:

| Comparison | Passes when |
| --- | --- |
| Numerical (iteration 1, where v2 fits once: the mammal hurdle) | Every reachable term within 1e-6 |
| Distributional (v2 bootstraps: plant and bird stages) | At least 90% of reachable terms in band, median standardized difference ≤ 0.25, and median band-width ratio between 0.75 and 1.33 |

**Why a band-width ratio, and not Spearman.** The in-band and standardized
difference tests both measure against this run's own band, so a harness
noisier than v2 passes them more easily; the ratio fails a band that is too
wide or too narrow, including one read from a store holding too few draws.
Spearman of the medians is still reported (`median_spearman`) but not
gated: it failed mite climate with every term in band, on the ordering of
near-zero terms, and caught nothing the other tests missed.

Only a full run is gated: every species, 100 draws. A run with 100 draws
on a species subset also gets an `indicative_verdict`, never to be read
as the gate. Either verdict is withheld from a distributional row whose
store holds fewer draws than v2 (`min_draws` in `parity_summary.csv`),
whatever the run was configured for; a store overwritten by a shorter run
would otherwise be scored on five-draw bands.

**Indicative result (2026-09-30, `parity_check` set, 100 draws).** 18 of
22 rows pass. Mammal habitat matches v2 to ≤1e-14; every plant climate and
habitat row passes, with band-width ratios of 0.88–1.05. Only birds fail:

- **Birds, all four rows.** The published bird results (December 2025)
  were fitted on a `Stratified.Rdata` that was rebuilt in place on
  2026-08-19; the test dataset is built from the rebuilt one. v2's own
  code on the test data matches a 2026-08 v2 re-run to 1.5e-12 and the
  published files only to 40%, and the harness matches v2's code to
  2.5e-15. Not a harness fault; see `docs/taxon_quirks.md`.

Assumptions, stated because they carry the targets:

- The calibration covers the plant climate stage only; the same targets
  are applied to plant habitat and to birds, on the assumption that v2's
  self-agreement is similar there. No second v2 run exists to check it.
- The review's strawman asked for a grid-prediction correlation; v2's
  reference holds no grid predictions, and the rank correlation of the
  coefficient medians that first stood in for it is no longer gated. No
  test compares the whole model's predictions.
- The negligible-term fraction (1e-6) and the 90th-percentile typical
  size are judgement calls, not calibrated; they only decide which terms
  the band ratio and Spearman read.

## Before this gate can be closed

1. **Agree the parity targets above**, or change them in
   `utils/parity_targets.R`.
2. **Run the full species queues at 100 draws** and commit the report
   and record. That run is days of compute (every species of four plant
   taxa, mammals and birds); run it on a machine that can be left.
3. **Get references that can be matched exactly.** The harness now
   matches v2's own code to numerical precision, but the published lichen,
   mite and vascular plant models were fitted on bootstrap draws v2 did
   not keep, and the published bird results on a different vintage of
   `Stratified.Rdata`. Re-running v2 on the stored draws (as `_setup/03`
   did for bryophytes), or finding the bird data those results used, would
   make those gates numerical. Until then they stay distributional.

The review, `docs/reviews/2026-09-28_alignment_review.md`, has the
evidence for each and an ordered plan.

## Resolved

- **`CMD` for mammals.** The mammal climate now comes from
  `abmi-camera-climate_2023.Rdata` on ABMI-DATA2, the file the v2
  climate pipeline fitted against. `read_camera_climate()` in the
  harmonizer joins it as v2 does: strip the year from the site key,
  strip the `CMU-` and `NWSAR-` project prefixes, keep one row per
  location. It **replaces** the species table's climate block rather
  than filling gaps, because the two are different extractions — at
  matched deployments they disagree by up to 531 mm of `MAP`. It
  matched 4,243 of 4,654 north deployments (91.2%) and all 1,168
  south; unmatched deployments keep `NA`, as v2 excludes them. The
  mammal climate stage now fits the full 9-model set, and the climate
  covariates all three taxa share went from two to five (`MAP`, `FFP`,
  `TD`, `CMD`, `EMT`).
- **A usable bryophyte reference.** The published file failed twice
  over: every draw is an error object (`could not find function
  "model.avg"`), and the bootstrap-id file holds 3 draws where the
  other taxa hold 100. `_setup/03_rerun_bryophyte_v2_reference.R`
  re-ran the frozen v2 functions: 134 of 134 species, 100 draws of 19
  climate terms each, no failures. Separately, v2's `COEFS.RData` holds
  complete bryophyte arrays, and `v2_results.csv` uses those.
- **The seed.** `boot_seed` in `run.R` seeds every resampled taxon from
  one number, with a derived seed per species. v2 is unseeded, so
  parity stays distributional, but this side of it now repeats.

### The plant age splines, scoped

- Assemble one frame per stand type from units where that type's cover
  exceeds 10%, carrying detection, age class, a weight that is cover
  times visits, and the site-level IVW prediction as an offset. Grassy
  sites join the upland types at age 0.5 and shrubby sites at age 1,
  each at half weight.
- Fit `gam(pCount ~ s(sqrt(age), k = 3, m = 2) + offset(p))` per type,
  intercept-only where there are 8 or fewer detections, plus two pooled
  variants, an all-types model and an intercept-only all-types model —
  nine fits.
- Choose among four groupings by summed AIC, corrected for the extra
  variance parameters.
- Predict at ages 0.5 and 1–8 with the type's grid effect as offset.
- Converge the cutblock trajectories onto the natural ones for age
  classes 2, 3 and 4, then apply the footprint pooling. v2 does it in
  that order.

`select_ivw_grid()` would also need to return the site-level prediction,
which it currently computes only on the grid.

## See also

- [`docs/taxon_quirks.md`](../../../docs/taxon_quirks.md) — every
  taxon-specific behaviour in the v2 pipelines and the harness's status
  against each.
- [`docs/reviews/2026-09-28_alignment_review.md`](../../../docs/reviews/2026-09-28_alignment_review.md)
  — the evidence behind the gaps above.
