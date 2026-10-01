# Results

All tables and figures are produced by
`code/Statistics/statistical_analysis.Rmd` and organised by hypothesis:

| Folder           | Content                                                                 |
|-------------------|--------------------------------------------------------------------------|
| `descriptive/`    | Purely descriptive tables — no hypothesis test (participant/observer characteristics, impression score descriptives, etc.). |
| `H1/`             | Group -> first impression (does diagnostic group predict first impressions?). |
| `H2/`             | Group -> movement (does movement differ between groups?).              |
| `H3/`             | Movement -> first impression (does movement predict first impressions?). |
| `H4/`             | Group and movement jointly (movement effect adjusting for group, and attenuation of the group effect). |
| `supplementary/`  | Scale reliability (Cronbach's alpha), the movement PCA construction, and exploratory/symptom correlations. |

Tables are exported as `.docx`; figures as `.png`/`.tif`. File names
are numbered in the order they appear in the manuscript (e.g.
`table_06_lmm_total_score.docx`, `Fig1_total_impression_score.png`).

Re-running `run_statistics.Rmd` regenerates everything here from
scratch — nothing in this folder should be edited by hand.
