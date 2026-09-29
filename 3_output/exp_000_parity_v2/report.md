# exp_000_parity_v2

Generated 2026-09-29 04:40:24

## What this gate covers

| Taxon | Climate | Habitat |
| --- | --- | --- |
| Plants | v2 58-model set | fitted, less the age splines |
| Birds | v2 8-model set | v2 staged landcover groups |
| Mammals | 4 of 9 models (`CMD` missing) | not reproduced |

For plants, v2 overwrites 45 of the 87 vegetation effects with
GAM splines over stand age, and settles the cutblock age
classes 3 and 4 by a convergence step. Neither is implemented,
so those terms will not match and are reported separately:
`reachable_in_band_pct` is the share of the terms the harness
actually fits, and is the number to read the gate on.

Parity here is **distributional, not numerical**. v2 seeds no
random draw, so two v2 runs give different coefficients;
matching numbers is not something v2 can do even against
itself. Each term is scored on whether the v2 value falls
inside this run's 10th-to-90th percentile band across draws.

## What ran

| taxon | region | species | draws | has_coefficients | has_grid |
| --- | --- | --- | --- | --- | --- |
| bird | north | 2 | 5 | TRUE | FALSE |
| bird | south | 2 | 5 | TRUE | FALSE |
| bryophyte | north | 2 | 5 | TRUE | FALSE |
| bryophyte | south | 2 | 5 | TRUE | FALSE |
| lichen | north | 2 | 5 | TRUE | FALSE |
| lichen | south | 2 | 5 | TRUE | FALSE |
| mammal | north | 2 | 5 | TRUE | FALSE |
| mammal | south | 0 | 0 | FALSE | FALSE |
| mite | north | 2 | 5 | TRUE | TRUE |
| mite | south | 2 | 5 | TRUE | TRUE |
| vascular_plant | north | 2 | 5 | TRUE | TRUE |
| vascular_plant | south | 2 | 5 | TRUE | FALSE |

## Climate-stage parity

| taxon | region | terms_compared | species | in_band_pct | reachable_terms | reachable_in_band_pct | median_standardized_difference |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lichen | north | 82 | 2 | 41.5 | 66 | 47.0 | 0.852 |
| mammal | north |  0 | 0 | NA |  0 | NA | NA |
| mite | north | 80 | 2 | 10.0 | 64 |  9.4 | 2.486 |
| vascular_plant | north | 80 | 2 | 16.2 | 64 | 17.2 | 2.275 |
| lichen | south | 38 | 2 | 18.4 | 38 | 18.4 | 2.492 |
| mite | south | 36 | 2 | 47.2 | 36 | 47.2 | 1.160 |
| vascular_plant | south | 36 | 2 | 27.8 | 36 | 27.8 | 1.641 |

## Model fit

| taxon | region | species | median_auc |
| --- | --- | --- | --- |
| bird | north | 2 | 0.714 |
| bryophyte | north | 2 | 0.663 |
| lichen | north | 2 | 0.805 |
| mammal | north | 2 | 0.727 |
| mite | north | 2 | 0.748 |
| vascular_plant | north | 2 | 0.833 |
| bird | south | 2 | 0.694 |
| bryophyte | south | 2 | 0.705 |
| lichen | south | 2 | 0.838 |
| mite | south | 2 | 0.806 |
| vascular_plant | south | 2 | 0.853 |

## Known gaps in the reference

- **Bryophytes have no usable v2 reference.** Every species
  and every draw in `bryophyte-species-models.Rdata` is an
  error object: `could not find function "model.avg"`. MuMIn
  was not available to the cluster workers on the run that
  produced it. Lichens, mites and vascular plants are
  complete. That file has to be re-run before bryophytes can
  be gated.
- **No bird reference is reachable**, so birds cannot be
  compared, only run.
- **Mammal climate has no bootstrap distribution.** The v2
  mammal climate pipeline fits once and averages by AICc
  weight, so its reference is a single value per term and the
  band test is one-sided.

## Before this gate can be closed

1. Agree a numeric parity target per taxon. Without one,
   "did it pass" has no answer.
2. Re-run the bryophyte v2 models.
3. Source `CMD` for mammals, so their climate stage can fit
   the full nine-model set rather than four of them.
4. Reproduce the habitat stages.

