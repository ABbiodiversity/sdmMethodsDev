# exp_000_parity_v2

![Status](https://img.shields.io/badge/Status-Climate%20and%20habitat-yellow)
![Languages](https://img.shields.io/badge/Languages-R-blue)

The validation gate. Runs each taxon's v2 spec through the harness and
compares the result against the published v2 output.

## Question

Does the framework, configured as v2, reproduce the v2 results?

Everything downstream depends on the answer. Later experiments are
compared against this one, so a difference here is a difference in the
plumbing, not in the method being tested.

## What it covers today

| Taxon | Climate | Habitat |
| --- | --- | --- |
| Plants (×4) | ✅ 58-model v2 set, AICc-averaged | ⚠️ IVW on the prediction grid + the v2 coefficient adjustment; **no age splines** |
| Birds | ✅ 8-model set, AICc-averaged | ✅ v2 staged landcover groups, BIC |
| Mammals | ✅ full 9-model set | ⚠️ presence r = 0.985, abundance r = 0.79; **no age splines or cutblock convergence** |

**Plants — what the age splines cost.** v2 refits the five aged stand
types (white spruce, pine, deciduous, mixedwood, black spruce × nine age
classes) with GAM splines over stand age, overwriting **45 of the 87**
vegetation effects, and settles the cutblock age classes 3 and 4 with a
separate convergence step. Neither is implemented. Those terms are
flagged in `parity_climate.csv` and excluded from
`reachable_in_band_pct`, which is the number to read the gate on.

**Mammals have age splines and cutblock convergence too.** Section
6.5 of the north basic-models script fits GAM splines over stand
age, and section 6.11 converges the cutblock classes onto their
natural equivalents with fixed recovery weights. Neither is
implemented. The mammal version is a separate implementation from
the plant one, with a different basis dimension, a different
number of fits and different groupings, so building the plant one
will not cover it. See [`taxon_quirks.md`](../../../docs/taxon_quirks.md).

**Mammals — both halves of the hurdle.** Selected with
`mammal_spec(part = "presence" | "abundance")`, each compared against its
own reference. The abundance half fits the units where the species was
seen, with the same 17 candidates minus `Climate` plus a
sampling-effort null, reported on the response scale — `Coef.agp.all` is
stored that way despite the source comment calling it log-scale. Their
product, `Coef.mean.all`, is not assembled: v2 calibrates the product
rather than the halves.

**`CMD` — resolved.** The mammal climate now comes from
`abmi-camera-climate_2023.Rdata` on ABMI-DATA2, which is the file the v2
climate pipeline actually fitted against. `read_camera_climate()` in the
harmonizer joins it the way v2 does: strip the year from the site key,
strip the `CMU-`/`NWSAR-` project prefixes, keep one row per location.

It **replaces** the SpTable's climate block rather than filling gaps in
it. The two are different extractions — at matched deployments they
disagree by up to 531 mm of `MAP` — so taking `CMD` from one and `MAP`
from the other would have left the block internally inconsistent in a
way nothing downstream would catch.

Matched 4,243 of 4,654 north deployments (91.2%) and all 1,168 south.
Unmatched deployments keep `NA`, as v2 excludes them.

Two consequences beyond mammals:

- The mammal climate stage now runs the **full 9-model v2 set**, and
  presence parity rose from r = 0.980 to **r = 0.985**.
- The climate covariates **all three taxa share** went from two
  (`MAP`, `FFP`) to five (`+ TD`, `CMD`, `EMT`). Cross-taxa bioclimatic
  experiments were severely constrained by that and are much less so
  now. Birds still lack `MAT` and `PET`, which is what holds it at five.

**Bryophytes: reference regenerated, now gatable.** The published
`bryophyte-species-models.Rdata` was unusable for two independent
reasons. Every species and every draw in it is an error object
reading `could not find function "model.avg"`, because MuMIn was not
on the cluster workers' library path. Separately,
`bryophyte-bootstrap-ids.Rdata` held **only 3 bootstrap columns**
where lichen, mite and vascular plant each hold 100, so draws 4-100
would have failed with `subscript out of bounds` whatever else was
fixed. Both defects sat upstream of the modelling.

`1_code/_setup/03_rerun_bryophyte_v2_reference.R` regenerated both,
running the frozen v2 functions unmodified and writing to
`2_pipeline/v2_reference/` rather than over the network copy, which
is someone else's artefact. The regenerated ids are a fresh seeded
draw and not the missing part of the stored ones, because v2's
bootstrap is unseeded and a partial set cannot be extended.

Result: 134 of 134 species usable, 0 failed draws, 100 draws by 19
terms each, all finite. Ids took 8.7 minutes and the climate models
1.3 hours on 14 workers.

`02_compare_to_v2.R` now searches `2_pipeline/v2_reference/` before
the published directory, so bryophytes resolve to the regenerated
file and the other three plant taxa to the published one. Every
parity row carries `reference_object` and `reference_source`, so it
says what it was measured against.

**No bird reference is reachable.** Birds can be run but not compared.

**Mammal climate has no bootstrap distribution.** The v2 mammal climate
pipeline fits once and averages by AICc weight, so its reference is a
single value per term and the band test is one-sided.

## Before this gate can be closed

1. **Agree a numeric parity target, per taxon.** Without one, "did it
   pass" has no answer. This is the blocking item.
2. Implement the plant age splines and the cutblock convergence, or
   agree the gate is read on the reachable terms only. They overwrite
   45 of the 87 vegetation effects, so this is the largest single gap.
3. Implement the mammal age splines and cutblock convergence.
4. Assemble mammal total abundance from the two halves.
5. Re-run the bryophyte **habitat** stage. The regenerated
   reference holds the climate stage only, so bryophyte habitat
   terms are still uncompared.

Resolved: `CMD` for mammals, sourced from
`abmi-camera-climate_2023.Rdata` and integrated by the harmonizer.
The bryophyte climate reference, regenerated and wired into the
gate.

### The plant age splines, scoped

- Assemble one frame per stand type from units where that type's cover
  exceeds 10%, carrying detection, age class, a weight that is cover
  times visits, and the site-level IVW prediction as an offset. Grassy
  sites join the upland types at age 0.5 with half weight.
- Fit `gam(pCount ~ s(sqrt(age), k = 3, m = 2) + offset(p))` per type,
  intercept-only where there are 8 or fewer detections, plus three
  pooled variants and an all-types model — nine fits.
- Choose among four groupings by summed AIC, corrected for the extra
  variance parameters.
- Predict at ages 0.5 and 1-8 with the type's grid effect as offset.
- Converge the cutblock trajectories onto the natural ones, which is
  what settles `CC*3` and `CC*4`.

`select_ivw_grid()` would also need to return the site-level prediction,
which it currently computes only on the grid.

## See also

[`docs/taxon_quirks.md`](../../../docs/taxon_quirks.md) enumerates
every taxon-specific behaviour in the v2 pipelines and the
harness's status against each.
