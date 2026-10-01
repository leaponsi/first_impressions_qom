# Code

Three stages, run in this order (see `run_movement.py` and
`run_statistics.Rmd` at the repository root to run all of it at once):

```
movement/ (Python)              impressions/ (R)
  01_cleaning                     01_questionnaire_long
  02_filtering                    02_merge_data  <-- also reads movement/05_qom.csv
  03_movements                          |
  04_extrema                            v
  05_qom  ---------------------->  Statistics/ (R)
                                     statistical_analysis
```

## `movement/` — pose landmarks to movement features

Python notebooks, run with Jupyter. Shared paths and constants are in
`config.py`.

| Notebook         | Reads                                          | Writes                              |
|-------------------|------------------------------------------------|--------------------------------------|
| `01_cleaning`      | `data/movement/landmarks/{P,SZ}/landmarks_*_POSE.csv` | `data/movement/01_clean_signals.csv` |
| `02_filtering`     | `01_clean_signals.csv`                         | `02_filtered_signals.csv`            |
| `03_movements`     | `02_filtered_signals.csv`                      | `03_normalized_signals.csv`          |
| `04_extrema`       | `03_normalized_signals.csv`                    | `04_extrema.csv`                     |
| `05_qom`           | `03_normalized_signals.csv`, `04_extrema.csv`  | `05_qom.csv`                         |

`05_qom.csv` (quantity-of-motion per signal, per stimulus) is the file
the R pipeline reads next.

## `impressions/` — questionnaire cleaning and merge

R Markdown, run with `rmarkdown::render()` (e.g. in RStudio).
`questionnaire_preprocessing.R` defines `organize_data()`, used by the
first notebook.

| Notebook                  | Reads                                                                 | Writes                                   |
|-----------------------------|------------------------------------------------------------------------|--------------------------------------------|
| `01_questionnaire_long`     | `data/imp/raw_data_1st_imp.xlsx` (raw SoSciSurvey export)             | `data/imp/01_long.csv`                     |
| `02_merge_data`              | `01_long.csv`, `data/movement/05_qom.csv`, `data/stimuli_participants.csv` | `data/merged/{data_complete,data_stimuli,data_observers}.csv` |

`02_merge_data` produces the three analysis-ready tables, each at a
different grouping level so statistical tests aren't run on
pseudo-replicated data:

- **`data_complete`** — one row per observer x video (evaluation
  level). Used for the linear mixed models on first impressions.
- **`data_stimuli`** — one row per video (stimulus level). Used for
  movement descriptives/PCA and group comparisons on movement.
- **`data_observers`** — one row per observer. Used for the
  observer-panel descriptive table.

## `Statistics/` — statistical analysis

`statistical_analysis.Rmd` reads the three `data/merged/*.csv` tables
and produces every table and figure under `results/` (see
`results/README.md`). It sources two helper files, kept separate for
readability:

- **`style_helpers.R`** — formatting/journal-style layer: colours,
  labels, number/CI formatting, the PLOS-style theme and table/figure
  saving helpers.
- **`stat_helpers.R`** — the analysis layer: the auto-selected
  two-group tests, LMM fitting/extraction, LMM diagnostics,
  random-effect variance reporting, and the cluster bootstrap.

Rendering this notebook also creates a `statistical_analysis_files/`
(and, for the bootstrap chunk, a `statistical_analysis_cache/`) folder
next to it — these are just knitr's intermediate HTML build artifacts,
not analysis output (the real tables/figures are in `results/`); they
are gitignored and `run_statistics.Rmd` deletes them automatically
after each render.

## Requirements

See the root `README.md`.
