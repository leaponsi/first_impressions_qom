# Data

## `imp/` — questionnaire data

- `raw_data_1st_imp.xlsx` — raw SoSciSurvey export (one row per
  observer, wide format). Read by `code/impressions/01_questionnaire_long.Rmd`.
- `01_long.csv` — reshaped to one row per observer x video. Produced
  by `01_questionnaire_long.Rmd`, read by `02_merge_data.Rmd`.

## `movement/` — pose landmarks and extracted movement features

- `landmarks/P/`, `landmarks/SZ/` — raw MediaPipe Pose landmark
  exports per stimulus participant (`landmarks_<id>_POSE.csv`), one
  file per video. `P` = healthy control stimuli, `SZ` = patient
  stimuli. Read by `code/movement/01_cleaning.ipynb`.
- `01_clean_signals.csv` ... `05_qom.csv` — successive outputs of the
  movement pipeline (`code/movement/01_cleaning.ipynb` through
  `05_qom.ipynb`); see `code/README.md` for what each step does.
  `05_qom.csv` (quantity-of-motion per signal, per stimulus) is the
  one the R pipeline reads next.

## `stimuli_participants.csv`

Clinical and demographic data for the 40 filmed stimulus participants
(semicolon-delimited). Stimulus participants are identified only by
an anonymised code (`P1`, `P2`, ..., `SZ1`, ...) — no name-derived
identifier is included. Read by `code/impressions/02_merge_data.Rmd`.

## `merged/` — analysis-ready tables

Produced by `code/impressions/02_merge_data.Rmd`, read by
`code/Statistics/statistical_analysis.Rmd`. Each is at a different
grouping level so statistical tests aren't run on pseudo-replicated
data — see `code/README.md` for why there are three:

- `data_complete.csv` — one row per observer x video (evaluation level).
- `data_stimuli.csv` — one row per video (stimulus level).
- `data_observers.csv` — one row per observer.
