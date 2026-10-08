<img src="docs/images/abmi_logo.png" alt="ABMI Logo" width="300" style="margin-top: 40px;">

# SDMs Methods Development
![In Development](https://img.shields.io/badge/Status-In%20Development-yellow)
![Lifecycle](https://img.shields.io/badge/Lifecycle-Experimental-orange)
![Languages](https://img.shields.io/badge/Languages-R-blue)

<img src="docs/images/science_centre_logo_unofficial.png" alt="ABMI Science Centre (Unofficial)" width="185">

> [!IMPORTANT]
> This repository is developed by and for the Science Centre at the Alberta Biodiversity Monitoring
Institute (ABMI). It is intended for internal use.
>

The ABMI Science Centre's shared R&D repository for Species Models 3.0.
It holds a frozen cross-taxa test dataset, one modelling pipeline that
runs every taxon's v2.0 model as a configuration, and a v2 parity check
(`exp_000`) that later experiments are compared against.



**Why this exists**
Species Models are produced one taxon at a time, each by its taxon lead. That
works for production, but it confines R&D to one taxon: a method that improves
plant models may or may not improve bird models, and testing it three times in
three codebases duplicates effort.

This R&D repository is designed to streamline model R&D accross all taxa. It is for testing new methods; it does not produce the final species models or reporting products.

## Repository structure

```
sdmMethodsDev/
├── 0_data/                 # gitignored except v2_scripts/ and *.R
│   ├── test_dataset/       # _setup/ output; runs read the published copy
│   ├── v2_results/         # the v2 parity reference, from _setup/06
│   ├── external/           # downloaded sources (ABMIexploreR), from _setup/06
│   ├── covariates/         # reserved; empty
│   └── v2_scripts/         # v2 scripts as received by toxon leads; reference only
├── 1_code/
│   ├── harness/            # the shared pipeline; names no taxon or method
│   ├── methods/            # engines, selection rules, resampling, metrics
│   ├── modules/            # one v2 spec per taxon; _shared/ for common code
│   ├── experiments/        # one folder per question; _template/, _shared/
│   ├── _setup/             # 00-08: build, check and publish the dataset
│   ├── tests/              # contract tests and the store comparison
│   └── _scratch.R          # dated workspace for exploration
├── 2_pipeline/             # result stores and intermediates; gitignored
├── 3_output/<exp_id>/      # per-experiment outputs; summaries committed
└── docs/                   # getting started, design, taxon quirks, vignettes
```

## How it works

**One pipeline, taxon as configuration**

The three v2.0 pipelines differ in nearly every detail but share one sequence:
pick survey units, fit candidate models, choose among or average them,
predict and score. What differs is the contents of each step. Here those
contents are data, in a **spec** per taxon, and one **harness** runs any spec.
How a model is fitted, selected, resampled or scored is a **method**, looked
up by the name the spec gives.


```mermaid
%% ----------------------------
%% Taxon as configuration, not codebase
%% ----------------------------
%%{init: {"themeVariables": {"edgeLabelBackground": "#ffffff"}}}%%
flowchart TD

    subgraph fw["framework: one pipeline, taxon as configuration"]
        direction TB
        PARAM["response · family · offset · regions · stages · resampling"]
        PARAM --> SP["plant-group specs<br/>bryophytes · lichens · mites · vascular plants"]
        PARAM --> SM["mammal specs<br/>summer · winter"]
        PARAM --> SB["bird spec"]
        SP --> H["1_code/harness/"]
        SM --> H
        SB --> H
        MT["1_code/methods/<br/>engines · selection rules · resampling · metrics"]
        MT -.->|"looked up by name"| H
        H -->|"the same result files<br/>for every taxon and method"| R["result stores"]
    end

    %% ----------------------------
    %% Styles
    %% ----------------------------

    %% Containers
    style fw fill:none,stroke:#2D415B,stroke-width:1px

    %% Configuration
    style PARAM fill:#ffffff,stroke:#2D415B,stroke-width:1px,stroke-dasharray: 5 5
    style SP fill:#A3B4C7,stroke:#2D415B,stroke-width:1px
    style SM fill:#A3B4C7,stroke:#2D415B,stroke-width:1px
    style SB fill:#A3B4C7,stroke:#2D415B,stroke-width:1px
    style MT fill:#A3B4C7,stroke:#2D415B,stroke-width:1px,stroke-dasharray: 5 5

    %% Shared pipeline
    style H fill:#A4A88780,stroke:#C8A02C,stroke-width:4px
    style R fill:#E8A396,stroke:#2D415B,stroke-width:4px
```

**Everything is compared with one v2 baseline**

`1_code\experiments\exp_000_parity_v2` runs taxon specs that mirror the v2 modelling methods and produce coeefients in parity with the v2 modelling outputs. Results from the `exp_000_parity_v2` thus serve as a baseline that future experiments can be compared to. I.e.:

exp_000 runs every taxon's v2 spec and checks it against the published
v2.0 output. Every later experiment changes one thing and is compared
with exp_000, so a difference is a difference in method rather than in
plumbing. Because the dataset is frozen, results stay comparable.

```mermaid
%% ----------------------------
%% Everything comparable to one v2 baseline
%% ----------------------------
%%{init: {"themeVariables": {"edgeLabelBackground": "#ffffff"}}}%%
flowchart TD

    subgraph fw["framework: everything comparable to one v2 baseline"]
        direction TB
        D["0_data/test_dataset/"] --> M["1_code/modules/[taxon]/<br/>v2 specs"]
        V2["0_data/v2_results/<br/>published v2.0"]
        M --> E0["exp_000_parity_v2"]
        M --> E1["exp_001"]
        M --> E2["exp_002"]
        V2 -->|"parity check"| E0
        E0 --> O0["3_output/exp_000_parity_v2/"]
        E1 --> O1["3_output/exp_001/"]
        E2 --> O2["3_output/exp_002/"]
        O0 --> C["compare_experiments()"]
        O1 --> C
        O2 --> C
    end

    %% ----------------------------
    %% Styles
    %% ----------------------------

    %% Container
    style fw fill:none,stroke:#2D415B,stroke-width:1px

    %% Highlighted borders
    style D fill:#A4A88780,stroke:#B8860B,stroke-width:4px
    style M fill:#A4A88780,stroke:#B8860B,stroke-width:4px
    style V2 fill:#ffffff,stroke:#2D415B,stroke-width:1px,stroke-dasharray: 5 5
    style E0 fill:#A3B4C7,stroke:#B8860B,stroke-width:4px
    style E1 fill:#A3B4C7,stroke:#2D415B,stroke-width:1px
    style E2 fill:#A3B4C7,stroke:#2D415B,stroke-width:1px
    style O0 fill:#ffffff,stroke:#B8860B,stroke-width:4px,stroke-dasharray: 5 5
    style O1 fill:#ffffff,stroke:#2D415B,stroke-width:1px,stroke-dasharray: 5 5
    style O2 fill:#ffffff,stroke:#2D415B,stroke-width:1px,stroke-dasharray: 5 5
    style C fill:#E8A396,stroke:#2D415B,stroke-width:4px
```


## Getting started

New to the repository? Work through the
[getting-started guide](https://abbiodiversity.github.io/sdmMethodsDev/getting_started.html):
prerequisites and data access, running the v2 baseline (exp_000),
starting an experiment, adding a taxon module, and checking that a
change broke nothing.


## Related resources

- [sciCentRverse](https://github.com/ABbiodiversity/sciCentRverse): Science Centre R functions
- [sciSpatialR](https://github.com/ABbiodiversity/sciSpatialR): Science Centre spatial catalogue

## Contact

For any questions regarding the contents of this repository or data access, please contact Brendan Casey at brendan.casey@ualberta.ca.
