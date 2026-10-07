# Taxon-specific modelling quirks

![Status](https://img.shields.io/badge/Status-Reference-blue)
![Languages](https://img.shields.io/badge/Languages-R-blue)

Every taxon-specific behaviour in the three v2 pipelines, and where
the harness stands on each. Verified against the frozen snapshots in
`0_data/v2_scripts/`, not from memory.

## Why this list exists

The harness treats the taxon as configuration: all three pipelines
run the same sequence, and only the contents differ. That claim is
only as good as the list of differences it has to absorb. A quirk
that is not on this list is a quirk the framework will silently get
wrong, and a cross-taxa comparison will attribute the difference to
the method under test rather than to the plumbing.

Read the **Status** column as: OK reproduced in the harness,
PART partially, GAP not implemented.

## The response variable is a different thing in each taxon

This is the deepest difference and the one most easily forgotten,
because all three end up fitting something that looks binomial.

| Taxon | What is recorded | What is modelled |
| --- | --- | --- |
| Birds | Point-count integers, 0-300 | The count itself, Poisson |
| Mammals | Camera density, 0-233.02, continuous, 17,788 `NA` | Presence, then abundance given presence |
| Plants | Cover or abundance | Detection, `> 0` becomes 1 |

So a detection probability from the plant pipeline, a presence
probability from the mammal pipeline and an expected count from the
bird pipeline are three different quantities. The prediction grid is
what makes them comparable, and only because every engine can be
projected onto it.

## Habitat composition is encoded two ways

A survey unit sits in a mixture of habitat types. There are two ways
to turn that mixture into columns, and the taxa split unevenly.

**Birds assign the unit to a class.** The habitat group is a single
factor term, `vegc` in the north and `soilc` in the south. R expands
it into dummies and holds one level back as the reference, so a
habitat effect is a contrast on the log scale. The stored level
order is load-bearing: a level absent from one bootstrap draw must
not renumber the rest.

**Mammals and plants give the unit a mixture.** Each habitat type is
its own numeric column holding a cover proportion. Nothing is a
factor, so R picks no reference; the modeller picks one by leaving
types out of the formula, and the omitted types are absorbed into
the intercept.

Mammals and plants then differ in how deliberate that choice is, and
in how the grid is shaped.

| | Habitat columns | Reference | Grid row |
| --- | --- | --- | --- |
| Birds | One factor | R picks, constant | n/a, factor levels |
| Mammals | Cover proportions | Named per candidate: `Crop` in 3 of 17, `Alien` in 14 | Built on the fly, strictly one-hot |
| Plants | Cover proportions | Implied by omission, constant | Stored matrix, **not** one-hot |

The plant grid rows are the subtle one. A white spruce row sets both
`WhiteSpruce` and its lumped parent `Upland` to 1, which is how a
single stored grid serves candidate models written at different
resolutions. All 43 rows of the vegetation grid do this.

So "the effect of white spruce" is three quantities: a log-scale
contrast for birds, an inverse-variance-averaged logit-scale
prediction for plants, and a calibrated probability for mammals.

## Birds

| Quirk | What v2 does | Status |
| --- | --- | --- |
| QPAD offset | A log-offset per survey and species, from `bird_offsets.csv`. It must appear **inside** the formula as `offset(offset)`, not as a `predict()` argument | OK |
| Poisson counts | Fitted on raw counts, no binarization | OK |
| Climate selection | `model.avg(climate.list, rank = "AICc")`, full average, null model included in the set | OK |
| Climate candidate set | 25 models: the null, eight climate combinations, and each of the eight with `Easting + Northing + Easting:Northing` and again with `I(Easting^2) + I(Northing^2)` added (`06.ModelClimate.R`) | OK `climate_bird_v2`, with `Easting`/`Northing` aliased from `sites.csv` |
| Climate scope | Fitted on every survey in the draw, province-wide; the region filter applies only to landcover | OK `scope = "province"` |
| Carrying climate forward | The averaged prediction on the response scale, `exp(link)`, joins the landcover model as a covariate | OK `carry_scale = "exp"`, `carry_offset = TRUE` |
| Landcover weights | `weights = vegw` in the north and `soilw` in the south (`07.ModelLandcover.R`) | OK region `weight_column` |
| Landcover selection | Staged forward BIC over named groups, not a flat candidate set | OK |
| The BIC rule | Within each stage, keep models with `Delta_BIC <= 2` and `K > 1`, then take the **smallest** of those. Not the lowest BIC. Always advance to that model | OK `always_advance = TRUE`; every candidate starts from `count ~ climate` (`base_terms`). Matches v2's code to 4e-13 |
| The groups | North has six: Hab, Age, CC, Contrast, ARU, Water. South has four: Hab, Contrast, ARU, Water | OK |
| Age terms | 13 candidates in the Age group alone, built from `wtAge`, `wtAge2` and `wtAge05` crossed with `isCon`, `isUpCon`, `isBogFen`, `isMix`, `isPine` and `isWSpruce` | OK |
| Bootstrap ids | Precomputed and keyed on `surveyid`, not on row index | OK, each survey once per draw (`unique_ids`), as v2's `%in%` selects |
| Factor levels | `vegc` 22, `soilc` 17, `method` 4, `block` 60. Stored order matters, since a level absent from one bootstrap sample must not renumber the rest | OK. Until 2026-09-29 `method` was loaded as `method_veg` and `method_soil` and missed the lookup, so it fell back to alphabetical order with `1SPM` as reference instead of `PC`; `apply_factor_levels()` now follows the suffixes |
| Column suffixes | Six columns arrive suffixed `_veg` or `_soil` and are rewritten by `term_map()` | OK |
| No coordinates | 0 of 215,758 rows in `sites.csv` carry latitude or longitude | GAP blocks spatial resampling and every spatial term |
| Reference output | The packaged `Birds2024.RData` is absent from the drive's `Results/`; only the per-draw CSVs and an archived copy survive. The parity reference is ABMIexploreR's packaged bird coefficients (`_setup/08`), which match it to ~1e-15 | OK compared. `modules/birds/standardize.R` ports the translation onto the standardized template and reproduces the packaged values exactly. Note the package labels draws 2 to 100 in file-listing order (`b2` is draw 10) |

**The published bird results come from a different data vintage.**
Run on the current `Stratified.Rdata`, v2's own climate code gives
coefficients up to 28% away from the published per-draw files (AMRO,
draw 1), while the harness matches that same v2 code to 2.5e-15, and
its landcover stage matches v2's to 4e-13. The published
`Birds2024.RData` was therefore fitted on data that differs from the
archived `Stratified.Rdata` the test dataset is built from, so bird
parity against it can only be approximate. Locating the data those
results were fitted on would make it exact.

Confirmed 2026-09-30 from the bird drive's file dates and a direct
check:

| Date | On the bird drive |
| --- | --- |
| 2025-12-12 / 15 | Per-draw climate and landcover csvs in `Results/Archive/`, packaged by v2's `08.PackageCoefficients.R` |
| 2026-01-16 | `Results/Archive/Birds2024.RData`, packaged from them |
| 2026-02 to 03 | New WildTrax pulls; `Data/Archive/2025/Wrangled.Rdata` rebuilt |
| 2026-08-19 | `Data/Archive/2025/Stratified.Rdata` rebuilt, in place |
| 2026-08-25 | A v2 re-run begins in `Results/ClimateModels/` (ALFL only so far) |

v2's own climate code, run on the test dataset's draw 1 for ALFL,
matches the 2026-08-25 re-run to 1.5e-12 and the 2025-12-12 archive
only to 40%. The published results were fitted on a
`Stratified.Rdata` that was overwritten on the bird drive.

**Resolved 2026-10-02.** A copy of the pre-rebuild file was
recovered and is kept at
`work_abmi/1_projects/active/sdmMethodsDev/remote/birds_data_v2/Stratified.Rdata`,
which `SDM_BIRD_DATA` now defaults to in `_setup/01` and `02`.
Its draws hold 58,210 surveys (the rebuilt file's hold 58,035), and
v2's own climate code run on it reproduces the published AMRO draw-1
coefficients to 2e-15. With the test dataset re-harmonized from it,
and the offset fix below, the harness reproduces v2's published
per-draw bird coefficients, climate and landcover, north and south,
to ~1e-10 (AMRO and YEWA, draws 1–5).

**The climate carry excludes the offset.** v2's `06.ModelClimate.R`
carries `exp(predict(model.avg, type = "link", full = TRUE))` into the
landcover stage. MuMIn builds that prediction from the averaged
coefficients, so the QPAD offset is not in it: v2's stored AMRO
draw-1 prediction averages 0.118, `exp(link)` gives 0.118, and
`exp(link + offset)` gives 0.315. The bird spec carried the offset
until 2026-10-02 (`carry_offset = TRUE`), which cut the landcover
`Climate` coefficient about threefold and shifted every habitat term
to compensate. It is now `FALSE`.

**The offset trap.** Passing the offset as an argument rather than
in the formula does not error. `predict()` recycles it, silently. It
moved bird AUC from 0.736 to 0.746, small enough to look like noise
and large enough to change a conclusion.

**An integer-overflow trap at bird scale.** `sum()` over a logical
vector returns an integer. At 16,745 positives by 199,013 negatives
the AUC denominator is 3.3e9, which overflows to `NA`. Every bird
AUC would have been silently invalid. Fixed with `as.numeric()`.

## Mammals

| Quirk | What v2 does | Status |
| --- | --- | --- |
| Hurdle structure | Binomial presence times Gamma abundance given presence, on a log link. Their product is total abundance | OK, the generic `hurdle` rule fits both halves through the stage's engine; v2's table-building is the `mammal_v2_habitat_tables()` post-process step (hurdle.R) |
| Lure correction | Estimated **only** from numbered ABMI grid sites, which are the ones with matched lured and unlured deployments. Applied as `sign(Count) / lure_ratio`, then rescaled to a maximum of 1 | OK |
| Abundance winsorizing | Capped at the 99th percentile of abundance given presence, before fitting | OK |
| Season | Separate summer and winter models, with `wt_summer` and `wt_winter` passed as `glm` weights | OK |
| Effort filter | Deployments with `seas_days > 10` only, and `seas_days` is aliased to the summer or winter day count per season | OK |
| Bears | Excluded from winter models outright | OK |
| Candidate set | 17 models, each with a **reference category** rather than a factor. Models 1, 2 and 10 use `Crop`; the other 14 use `Alien` | OK |
| Coefficient extraction | One-hot prediction onto the prediction matrix at `seas_days = 100` and `Climate = 0`, on the probability scale | OK |
| `Climate` is special | Taken from its own slope coefficient, never from a one-hot prediction, because it is a slope and not a habitat-type logit | OK |
| Presence calibration | Additive logit shift, observed mean minus fitted mean on the logit scale, applied to habitat coefficients and explicitly **not** to `Climate` | OK |
| Abundance calibration | Multiplicative, observed mean over predicted mean, applied to the **product** and to neither half. Deliberate: an additive shift on the log scale can give the log of a negative number for sparse habitat types | OK |
| Abundance scale | The stored abundance coefficients are exponentiated before saving, so they are on the **response** scale despite the source comment calling them log-scale | OK |
| GAM age splines | A binomial spline in the square root of stand age, basis dimension 4, with the site-level prediction as an offset and cover times season weight as the weight. Five stand types plus three pooled frames, so eight fits | OK |
| Age groupings | Three strategies compared by summed AIC, corrected by -8, -4 and 0 for the extra variance parameters | OK the mammal version weighs each spline against its null by AICc weight; ported as written |
| Cutblock convergence | Fixed recovery weights, not fitted. Conifer 0.500, 0.849, 0.960 and deciduous or mixedwood 0.705, 0.912, 0.970 at age classes 2, 3 and 4. Applied to total abundance only, never to presence | OK |
| No bootstrapping | The habitat stage fits once, so like-for-like comparison is iteration 1 rather than a distribution | OK handled in the gate: the harness bootstraps, and mammals are compared at iteration 1 |
| Climate is external | Fitted by a separate pipeline and read back as a single covariate, not fitted alongside habitat | OK `climate_source = "precomputed"` reads the prediction and drops deployments without one |
| Seasons in the reference | The published `.all` tables average the summer and winter fits | OK `run.R` runs both seasons and the gate averages them |
| South habitat | A separate south candidate set on soil types | OK v2's 30 candidates, spread over the full soil set; needs the SpTable pAspen (see below) |
| Regions overlap | North and south are separate models sharing 512 deployments | OK |
| Climate extraction | From `abmi-camera-climate_2023.Rdata`, a different extraction from the one in the species table. At matched deployments the two disagree by up to 531 mm of `MAP` | OK |

**The mammal south needs the SpTable's own pAspen.** The
harmonizer used to replace it with the camera climate file's
pAspen, a different extraction that differs by up to 0.92 at
matched deployments, so every south candidate with pAspen
disagreed with v2. `_setup/01` now keeps the SpTable column; the
existing dataset was patched to match. With it, the south hurdle
matches v2 to 1e-15.

**Mammals have age splines too.** Earlier notes recorded splines as
a plant-only quirk. Section 6.5 of the north basic-models script
fits them and section 6.11 runs the cutblock convergence. The mammal
version differs from the plant one in basis dimension, 4 against 3,
in the number of fits, 8 against 9, and in the number of groupings
compared, 3 against 4. It is a second implementation rather than the
same code applied twice, so implementing one will not give the
other.

## Plants: bryophytes, lichens, mites, vascular plants

| Quirk | What v2 does | Status |
| --- | --- | --- |
| Binarization | Cover or abundance to detection | OK |
| Engine | `arm::bayesglm` with default Cauchy priors and `maxit = 250`. Load-bearing, not cosmetic: a rare species separates completely against a 30-term habitat formula, and a plain `glm` returns coefficients in the tens | OK |
| Climate candidate set | 58 models, built as a cross-product. 14 base models, a bioclim version of each adding `bio9` and `bio15`, and three spatial versions of ten of them | OK |
| Climate selection | Full model averaging | OK |
| Habitat selection | Inverse-variance weighting **on the prediction grid**. What v2 calls the habitat coefficients are grid predictions weighted by their own precision, not regression coefficients | OK |
| Carrying climate forward | The averaged coefficient vector applied to the data and passed through the logistic, so the habitat stage sees a probability. Not the best model's link prediction | OK |
| Footprint pooling | `HardLin` borrows from `UrbInd` by inverse-variance weighting on the logit scale. `EnSoftLin`, `EnSeismic` and `TrSoftLin` borrow from a young-regeneration composite with **fixed** weights 0.049, 0.0893, 0.434 and 0.396 over three cutblock regeneration classes and young black spruce | OK |
| GAM age splines | A binomial spline in the square root of stand age, basis dimension 3, nine fits, intercept-only where detections are too few. Overwrites **45 of the 87** vegetation effects | OK `plant_age_splines()`; matches v2 to 2e-12 |
| Cutblock convergence | Moves cutblock age classes 2, 3 and 4 part of the way to the natural stand of the same age, with fixed weights, before the footprint pooling | OK `plant_cutblock_convergence()` |
| `Protocol` | Fitted for **bryophytes and lichens only**. Mites and vascular plants pass the protocol flag as false | OK |
| Climate scope | Fitted on every site in the draw, province-wide; the region filter applies only to the habitat stage | OK `scope = "province"`; north and south share one fit per draw |
| Bootstrap | Spatial-block over the whole province, once per species, redrawing until 20 detections are reached | OK drawn once per species over the province; `bootstrap = "v2_ids"` replays v2's stored draws |
| Derived climate | Products of stored columns are computed on load and never stored | OK by design |

**Why the derived products are not stored.** `fwrite` writes 15
significant digits. Round-tripping a covariate and its square
separately leaves the stored square inconsistent with the square of
the stored input, by enough to move a coefficient. They are
recomputed on load instead.

**The published plant models were not fitted on the stored draws.**
Replaying v2's stored bootstrap ids (`bootstrap = "v2_ids"`, from
`_setup/07`) reproduces v2 exactly when the reference was fitted on
them: the regenerated bryophyte reference matches to 4e-11 on every
draw tested. Against the published lichen models only draw 1, the
full data, matches (5e-12); for draws 2 to 6 no row among the 100
published ones matches, so those models were fitted on draws that
were not kept. Plant parity against `v2_results.csv` stays
distributional until v2 is re-run on the stored draws, as `_setup/03`
did for bryophytes.

**The bryophyte reference has two independent defects.** Every
species and draw in the published bryophyte model file is an error
object reading `could not find function "model.avg"`, because MuMIn
was missing from the cluster workers' library path. Separately, the
bryophyte bootstrap-id file holds only 3 draws where the other three
plant taxa hold 100. Both sit upstream of the modelling, so the file
cannot be salvaged, only regenerated.
`1_code/_setup/03_rerun_bryophyte_v2_reference.R` does that for the
climate stage, and has been run: 134 of 134 species, 100 draws each,
no failures. Separately, ABMIexploreR publishes complete bryophyte
arrays (matching v2's `COEFS.RData` to ~1e-15), and `_setup/08` builds
the bryophyte rows of `v2_results.csv` from them, so the gate compares
bryophytes.

## Shared across all three

Not taxon quirks, but they shape what parity can mean.

- **Nothing is seeded.** No v2 pipeline seeds its RNG, so v2 does
  not reproduce against itself. Parity is therefore distributional:
  the v2 value is scored on whether it falls inside the run's p10 to
  p90 band, plus a standardized difference. Asking for matching
  numbers would be asking for something v2 cannot do. The harness
  seeds from `boot_seed` in `run.R`, so its own side repeats.
- **Global-environment coupling.** Cluster workers see variables by
  export, not by scope. A loop variable inside a closure is
  invisible to a worker, which is why the protocol flag had to be
  exported by name before the vegetation bootstraps would run.
- **Positional covariate indexing.** Columns are selected by number,
  with a different range per taxon. Any upstream column change moves
  every covariate silently.
- **Hard-coded 100 bootstraps and 14 cores** throughout.

## What this costs cross-taxa work

The climate covariates all three taxa share number **five**: `TD`,
`MAP`, `FFP`, `EMT` and `CMD`. It was two before the mammal camera
climate was integrated. Birds lack `MAT` and `PET`, which is what
holds it at five.

That is the ceiling on any bioclimatic experiment stated in shared
terms. An experiment needing `MAT` can run on plants and mammals but
not on birds, and that has to be a stated scope rather than a
surprise at the comparison step.

## See also

- `docs/framework_design.md`, the architecture and the parity ledger
- `v2_coverage` in each spec under `1_code/modules/`, the per-stage
  summary of this table that the report prints
- `1_code/experiments/exp_000_parity_v2/README.md`, what the gate
  compares and what blocks it
- `0_data/v2_scripts/README.md`, provenance of the frozen snapshots
