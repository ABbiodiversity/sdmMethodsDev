# Prediction grid QA: kgrid22_bf7hfi2021_1km_v1

Checked 2026-10-27 03:31 by `1_code/_prediction_grid/02_qa_prediction_grid.R` on the local build in `2_pipeline/shared/prediction_grid/kgrid22_bf7hfi2021_1km_v1`. Design: [prediction_design.md](prediction_design.md) §1.8.

**Result:** 33 pass, 5 note, 0 fail. A fail means the grid doesn't match its sources or the lattice. A note records a fact users need.

## Checks

| group | check | status | value |
| --- | --- | --- | --- |
| Cells | Cell count is 664,762 | pass | 664,762 |
| Cells | LinkID unique, no NA | pass | 0 duplicates, 0 NA |
| Cells | LinkID and order identical to kgrid_2.2 | pass | compared in full |
| Cells | LinkID == Row_Col | pass | compared in full |
| Lattice | check_alignment() against ab_grid() | pass | crs TRUE; extent TRUE; resolution TRUE; origin TRUE |
| Lattice | CRS is EPSG:3400 | pass | 3400 |
| Lattice | Extent and resolution | pass | 170616.2 865616.2 5425532.4 6659532.4 |
| Lattice | Cells equal the non-NA ab_grid() cells | pass | 664,762 lattice cells |
| Lattice | Easting/Northing fall in their cell | pass | compared in full |
| Attributes | 39 kgrid columns identical | pass | all identical |
| Attributes | Region and ID labels identical | pass | all identical |
| Attributes | UTMX/UTMY equal Easting/Northing | pass | compared in full |
| Attributes | PET equals Eref | pass | compared in full |
| Weights | wN + wS = 1 | pass | max \|wN + wS - 1\| = 2.22e-16 |
| Weights | Cells with fractional wN (by NrName) | note | Boreal 63,211; Parkland 60,807 |
| Attributes | NA values by column | note | HTV 4 |
| Attributes | kgrid TD equals MWMT - MCMT (0.1 C) | pass | max difference 0.1 C |
| Land cover | veg_current rows sum to 1 | pass | max \|sum - 1\| = 7.77e-16 |
| Land cover | veg_current has no negative or NA values | pass | min 4.35e-12 |
| Land cover | veg_reference rows sum to 1 | pass | max \|sum - 1\| = 6.66e-16 |
| Land cover | veg_reference has no negative or NA values | pass | min 1.51e-13 |
| Land cover | soil_current rows sum to 1 | pass | max \|sum - 1\| = 6.66e-16 |
| Land cover | soil_current has no negative or NA values | pass | min 1.94e-11 |
| Land cover | soil_reference rows sum to 1 | pass | max \|sum - 1\| = 4.44e-16 |
| Land cover | soil_reference has no negative or NA values | pass | min 1.01e-11 |
| Land cover | Backfill area per cell equals AreaKm2 | note | 20 cells differ by more than 0.001 km2; max \|difference\| = 0.74 km2. Proportions use the backfill area, as in v2.0 |
| Land cover | veg_current equals raw backfill (all cells) | pass | classes in lookup order; max difference 2.22e-16 |
| Land cover | veg_reference equals raw backfill (all cells) | pass | classes in lookup order; max difference 1.33e-15 |
| Land cover | soil_current equals raw backfill (all cells) | pass | classes in lookup order; max difference 1.44e-15 |
| Land cover | soil_reference equals raw backfill (all cells) | pass | classes in lookup order; max difference 2.22e-15 |
| Land cover | veg_current equals v2.0 function, 200 random cells | pass | max difference 3.33e-16 |
| Land cover | veg_reference equals v2.0 function, 200 random cells | pass | max difference 2.22e-16 |
| Land cover | soil_current equals v2.0 function, 200 random cells | pass | max difference 2.22e-16 |
| Land cover | soil_reference equals v2.0 function, 200 random cells | pass | max difference 1.11e-16 |
| Land cover | north reference classes are a subset of current | pass | 89 current, 57 reference classes |
| Land cover | south reference classes are a subset of current | pass | 22 current, 9 reference classes |
| Training ranges | Largest share of cells outside the training range, by taxon | note | bird TD 0.33%; bryophyte bio15 1.2%; lichen PAS 0.48%; mammal_north HTV 2%; mammal_south MSP 2.9%; mite PAS 0.48%; vascular_plant PAS 0.48% |
| Training ranges | Grid covariates with no training values | note | bird has 5 of 31; mammal_north has 28 of 31; mammal_south has 29 of 31 |

## Covariates outside the training range

Training ranges come from `covariates.csv` in the pinned test dataset (2026-10-05). Up to five covariates per taxon with the largest share of grid cells outside the range. Every grid covariate the taxon stores is listed, whether or not its models use it. Mammal north and south are compared only with the cells their model predicts (`wN > 0`, `wS > 0`). The full table is `qa_covariate_ranges.csv` in the version folder.

| taxon | covariate | cells | train | grid | % cells outside |
| --- | --- | --- | --- | --- | --- |
| bird | TD | province | 19.4 to 39.7 | 18.1 to 39.8 | 0.33 |
| bird | FFP | province | 41 to 135 | 34 to 135 | 0.036 |
| bird | EMT | province | -51.3 to -35.3 | -51.7 to -35.2 | 0.036 |
| bird | MAP | province | 284 to 1,904 | 278 to 2,822 | 0.034 |
| bird | CMD | province | 0 to 496 | 0 to 497 | 1.5e-04 |
| bryophyte | bio15 | province | 21.85 to 84.29 | 11.72 to 88.4 | 1.2 |
| bryophyte | EXT | province | 27.1 to 40.1 | 23.3 to 40.6 | 1.1 |
| bryophyte | PAS | province | 44 to 770 | 31 to 1,840 | 0.9 |
| bryophyte | CMI | province | -37.5 to 110.1 | -42.34 to 256.6 | 0.73 |
| bryophyte | AHM | province | 6.7 to 49.9 | 2.7 to 51.8 | 0.73 |
| lichen | PAS | province | 44 to 902 | 31 to 1,840 | 0.48 |
| lichen | DD_18 | province | 4,458 to 7,746 | 4,315 to 8,110 | 0.41 |
| lichen | EXT | province | 26.2 to 40.1 | 23.3 to 40.6 | 0.39 |
| lichen | MAT | province | -3.3 to 6 | -4.3 to 6.5 | 0.35 |
| lichen | SHM | province | 13.5 to 95.6 | 6.4 to 97.7 | 0.31 |
| mammal_north | HTV | wN > 0 | 0 to 57 | 0 to 100 | 2 |
| mammal_north | DD_18 | wN > 0 | 4,854 to 7,582 | 4,751 to 8,110 | 1.5 |
| mammal_north | MAT | wN > 0 | -2.9 to 4.7 | -4.3 to 5 | 1.3 |
| mammal_north | TD | wN > 0 | 19.7 to 39.7 | 18.1 to 39.8 | 0.71 |
| mammal_north | bFFP | wN > 0 | 139 to 189 | 136 to 191 | 0.62 |
| mammal_south | MSP | wS > 0 | 214 to 364 | 199 to 411 | 2.9 |
| mammal_south | CMD | wS > 0 | 157 to 442 | 104 to 497 | 2.2 |
| mammal_south | EMT | wS > 0 | -46.4 to -36.5 | -47.4 to -35.3 | 1.5 |
| mammal_south | Eref | wS > 0 | 513 to 714 | 492 to 761 | 1.4 |
| mammal_south | PET | wS > 0 | 513 to 716 | 492 to 761 | 1.3 |
| mite | PAS | province | 44 to 902 | 31 to 1,840 | 0.48 |
| mite | DD_18 | province | 4,458 to 7,746 | 4,315 to 8,110 | 0.41 |
| mite | EXT | province | 26.2 to 40.1 | 23.3 to 40.6 | 0.39 |
| mite | MAT | province | -3.3 to 6 | -4.3 to 6.5 | 0.35 |
| mite | SHM | province | 13.5 to 95.6 | 6.4 to 97.7 | 0.31 |
| vascular_plant | PAS | province | 44 to 902 | 31 to 1,840 | 0.48 |
| vascular_plant | DD_18 | province | 4,458 to 7,746 | 4,315 to 8,110 | 0.41 |
| vascular_plant | EXT | province | 26.2 to 40.1 | 23.3 to 40.6 | 0.39 |
| vascular_plant | MAT | province | -3.3 to 6 | -4.3 to 6.5 | 0.35 |
| vascular_plant | SHM | province | 13.5 to 95.6 | 6.4 to 97.7 | 0.31 |

