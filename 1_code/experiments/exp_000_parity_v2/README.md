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
| Plant group (×4) | Partial: v2's 58-model set, fitted per region where v2 fits once province-wide | Partial: IVW on the grid and footprint pooling; no age splines or cutblock convergence | Partial: drawn within region |
| Mammals | Partial: v2's full 9-model set, fitted as a stage where v2 reads a prediction | Partial: north only, one hurdle half per run; no age splines, convergence, total abundance or south sets | Partial: v2 does not bootstrap this stage |
| Birds | Partial: 9 of v2's 25 candidates; carried on the link scale | Partial: staged BIC, but unweighted and with a different advance rule | Reproduced: v2's stored draws |

If this table and the specs disagree, the specs are right; update this
table.

## What the gate compares today

`02_compare_to_v2.R` compares each taxon's **final** stage, because only
the final stage's coefficients are stored. It reads v2 from the network
drives rather than from `0_data/v2_results/v2_results.csv`. As a result:

- **Plant group:** lichens, mites and vascular plants are compared on
  their habitat terms. The climate stage is not compared.
- **Bryophytes:** not compared. The published model file is all error
  objects, and the gate does not search either usable reference: v2's
  `COEFS.RData`, which `v2_results.csv` is built from, or the climate
  reference `_setup/03` rebuilt in `2_pipeline/v2_reference/`.
- **Birds:** not compared. `_setup/04` packaged `Birds2024.RData`, but
  the gate sets the bird reference to `NULL`, and the harness stores raw
  `glm` names where v2's packaged coefficients use the standardized
  template.
- **Mammals:** no term joins. The reference read is the climate
  coefficients; the run's final stage is habitat. v2's references also
  average the two seasons, where a run fits one.

The report lists what its comparison could not reach, so this is
checkable run by run.

Earlier ad hoc checks put mammal presence at r = 0.985 and abundance at
r = 0.79 against v2 on iteration 1. They were not produced by the
committed gate and cannot be regenerated from it.

## Before this gate can be closed

1. **Agree a numeric parity target, per taxon and stage.** Without one,
   "did it pass" has no answer.
2. **Compare the right things:** store every stage's coefficients, read
   `0_data/v2_results/v2_results.csv`, average mammal seasons, and
   translate bird terms to the standardized template.
3. **Match v2 where the specs depart from it:** fit climate
   province-wide and draw the bootstrap once per species across the
   province; give birds v2's 25 climate candidates (which needs
   `Easting` and `Northing` added to the bird covariates), weights, carry
   scale and advance rule.
4. **Build the missing machinery:** plant age splines and cutblock
   convergence, the separate mammal versions, mammal total abundance and
   the mammal south sets.

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
