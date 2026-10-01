# First impressions and body movement in schizophrenia

This repository contains the data and analysis code for a study of
first impressions formed about individuals with schizophrenia (SZ) and
matched healthy controls (P), and their relationship to the observed
quantity of body movement (hands and head) extracted from short video
stimuli.

## Repository structure

```
.
├── code/
│   ├── movement/        Python notebooks: raw pose landmarks -> movement features
│   ├── impressions/     R Markdown: questionnaire cleaning + merge into analysis tables
│   └── Statistics/      R Markdown: the statistical analysis itself
├── data/                Raw and processed data (see data/README.md)
├── results/             Tables and figures, organised by hypothesis (see results/README.md)
├── run_movement.py      Runs the movement pipeline (step 1)
└── run_statistics.Rmd   Runs the questionnaire + statistics pipeline (step 2)

```

See `code/README.md` for how the pipeline chains together in detail,
and `data/README.md` for what each data file is.

## How to reproduce the results

Run the two entry points **in order**, from the repository root:

1. **`run_movement.py`** — open it in VS Code and click "Run" (or run
   `python run_movement.py` in a terminal). Needs Python with Jupyter
   installed. Produces the movement features
   (`data/movement/05_qom.csv`) from the raw pose landmarks.
2. **`run_statistics.Rmd`** — open it in RStudio and click "Run All"
   (or "Knit"). Needs R. Produces the merged analysis tables
   (`data/merged/*.csv`) and all the tables and figures in `results/`.

Step 2 depends on step 1's output, so don't run them out of order.

## Requirements

**Python** (for `code/movement/`): `pandas`, `numpy`, `scipy`,
`matplotlib`, `jupyter`.

**R** (for `code/impressions/` and `code/Statistics/`): `dplyr`,
`tidyr`, `readr`, `readxl`, `stringr`, `purrr`, `tibble`, `ggplot2`,
`lme4`, `lmerTest`, `emmeans`, `performance`, `broom`, `broom.mixed`,
`car`, `effectsize`, `psych`, `flextable`, `gt`, `officer`, `scales`,
`patchwork`.

