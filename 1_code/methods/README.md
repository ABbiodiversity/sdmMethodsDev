# Methods

Every method a spec can name lives here, one file each. A file
defines its method and registers it under a name; a spec names it;
the harness looks it up. Adding a method is adding a file. No
harness file changes.

```r
source("1_code/harness/harness.R")
load_framework()
list_methods()          # everything registered, with what it needs
list_methods("engine")  # one kind
```

| Folder | Kind | Registered with | Named in a spec as |
| --- | --- | --- | --- |
| `engines/` | How a model is fitted | `register_engine()` | `stage$engine` |
| `selection/` | How a candidate set becomes one result | `register_selection()` | `stage$selection` |
| `resampling/` | Which survey units each draw fits | `register_resampler()` | `resample$scheme` |
| `metrics/` | How a prediction is scored | `register_metric()` | scored for every run |

Files whose names start with `_` are shared helpers and load first
(`engines/_glm_family.R`). `_templates/` holds a copy-and-fill
skeleton for an engine and a selection rule; it is not loaded.

## What is registered

| Kind | Name | What it does | Needs |
| --- | --- | --- | --- |
| engine | `glm` | `stats::glm` (v2 mammals, birds) | |
| engine | `bayesglm` | `arm::bayesglm`, weakly informative priors (v2 plants) | |
| engine | `gbm` | Boosted regression trees, `gbm::gbm.fit`; no coefficients, information criterion or standard errors, so use the `single` rule | |
| selection | `single` | Fit the first candidate; no ranking | |
| selection | `aic_best` | Keep the lowest-scoring candidate | ic |
| selection | `aic_average` | Average coefficients by Akaike weight (v2 climate) | ic, coefficients |
| selection | `staged_bic` | Forward selection through groups (v2 bird landcover) | ic, coefficients |
| selection | `ivw_grid` | Inverse-variance average onto the habitat grid (v2 plant habitat) | coefficients, se |
| selection | `aic_best_grid` | Best candidate, predicted onto the grid (v2 mammal abundance) | ic, se |
| selection | `aic_best_onehot` | Best candidate, one habitat type at a time (v2 mammal presence) | ic, coefficients, se |
| resampler | `precomputed` | Replay draws stored with the dataset (v2 birds; plant `v2_ids`) | |
| resampler | `spatial_block` | Bootstrap within coarse spatial blocks (v2 plants, mammals) | |
| resampler | `spatial_cv` | Spatial block cross-validation; each draw holds out one fold | |
| metric | `auc`, `deviance_explained`, `rmse`, `spearman`, `calibration_slope`, `prevalence`, `n` | Scored in-sample and out-of-bag for every draw | |

`validate_spec()` checks a spec against this table before any data
is read. A rule paired with an engine that lacks what it needs, an
unregistered name, or a misspelt field stops the run with a
sentence saying which.

## The engine contract

An engine is a list:

| Element | Required | Contract |
| --- | --- | --- |
| `name`, `description` | yes | The registered name, and one line for `list_methods()` |
| `capabilities` | yes | A subset of `"coefficients"`, `"ic"`, `"se"`, `"converged"` |
| `fit(formula, data, family, weights, offset, control)` | yes | Returns `list(fit, ok, message)`. **Never raises**: a failure returns `ok = FALSE` and the message, because candidate sets hold models that cannot be fitted for every species and draw |
| `predict(fit, newdata, type, se)` | yes | `type` is `"link"` or `"response"`. Returns one number per row, or `NULL` when it cannot. With `se = TRUE` (only if declared), `list(fit, se.fit)`. An offset in the formula, `+ offset(offset)`, must be applied to new data |
| `coef(fit)` | with `coefficients` | A data frame of `term`, `estimate`, `se` |
| `ic(fit, type)` | with `ic` | AIC, AICc or BIC; `Inf` for a failed fit |
| `converged(fit)`, `nobs(fit)` | no | Assumed converged, and observations read with `stats::nobs`, when absent |

The harness passes the offset in the formula, never as an
argument: an offset argument is not carried onto new data by
`predict()`, so every prediction outside the draw would be wrong.

`family` arrives as a name (`"binomial"`, `"poisson"`) or a family
object (`Gamma(link = "log")`). An engine with its own vocabulary,
such as `gbm`'s `distribution = "bernoulli"`, translates it.

### Testing an engine

```r
check_engine(engine_mine())
```

`check_engine()` fits small synthetic binomial and Poisson data,
with weights, an offset and a factor, and checks every part of the
contract the engine declares. Every row should read `TRUE` before
the engine meets the dataset.

### Which rules an engine can use

An engine without an information criterion or coefficients - a
boosted regression tree, a random forest - can still run any
stage, using the `single` rule: one formula, fitted as given. To
compare it with v2 on a stage v2 fits with model averaging,
replace that stage's engine, selection and models together. The
v2 post-processing steps that read coefficients (the plant
stand-age splines, say) then do not apply, and the stage should
drop them; see `docs/getting_started.md`.

A stage carried into the next one (`carry_as`) is carried from the
stage's final model: its averaged coefficients where it has them,
its prediction otherwise.

## The other contracts

**Selection rule.** A function taking `models` (formulas, or named
groups of them), `base`, `data`, `engine`, `family`, `weights`,
`offset`, `ic` and `control`, returning `selection_result()`. Any
further argument is a setting, filled from the stage field of the
same name. Fit candidates with `fit_candidates()`; read
coefficients with `engine_coef()`. A rule that combines candidates
passes `predict` (see `combined_predictor()`) so metrics and grid
predictions use the combined model. Register with the capabilities
it `requires`.

**Resampler.** A function of `frame`, `iterations`, `seed` and
`context` (data directory, taxon, species, spec), plus any setting
from the spec's `resample` list, returning one character vector of
survey unit ids per draw: the units that draw fits. Units left out
are scored out-of-bag. Draw under `with_seed(seed, ...)` so a
species' draws depend only on its seed.

**Metric.** A function of `observed` and `predicted`, both on the
response scale, returning one number. Return `NA` rather than
stopping when the metric does not apply to a draw.

## Checklist for a new method

- [ ] One file in the right folder, from `_templates/` where there
      is one, with the standard header.
- [ ] Registered with a one-line description and, for a rule, what
      it `requires`.
- [ ] `check_engine()` passes, for an engine.
- [ ] `Rscript 1_code/tests/run_tests.R` passes.
- [ ] Tried on one species and a few draws (`species = "one_each"`,
      `n_bootstraps = 5`) before a full run.
