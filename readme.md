# pons.lea — Body Movement Analysis and First Impression

A complete reproducible data analysis pipeline for analyzing first impressions and body movement.

## Repository Structure

-   **data/** - Input data (participant landmark CSVs, first impression ratings) and aggregated outputs
-   **sources/** - Reusable R and Python functions (preprocessing, statistical analysis, feature extraction)
-   **results/** - Analysis outputs (figures, tables)
-   **notebooks/** - Analysis notebooks for main steps of the project, inspect results and generate tables and figures (Jupyter/RM
-   **main.ipynb** - Python entry point (runs preprocessing + feature extraction)
-   **main.Rmd** - R entry point (runs all statistical analyses)
-   **pons.lea.html** - Final technical report
-   **main.Rproj** - RStudio project file
-   **LICENSE** - GPLv3

## Quick Start

### R Environment

RStudio project file (`main.Rproj`) configures the R environment automatically. Open `main.Rmd` in RStudio and render:

``` r
rmarkdown::render("main.Rmd")
```

Or use command line:

``` bash
Rscript -e "rmarkdown::render('main.Rmd')"
```

## Project Overview

**Research Question:** Are quantitative body movement metrics linked to observer first impressions?

**Data:** 40 csv (20 healthy controls + 20 patients) of MediaPipe Pose extraction; 91 observer participants first impression of the two groups.

**Key Results:** Movement metrics (Quantity of Motion, amplitude, speed) correlate with observer first impression ratings (R²=0.45).

## Running the Full Analysis

1.  **Python preprocessing** → `main.ipynb`
    -   Extracts pose landmarks from video data
    -   Preprocesses coordinates, filters signals, computes features
    -   Outputs: `all_participants_*.csv` files
2.  **R statistical analysis** → `main.Rmd`
    -   Loads preprocessed movement data + first impression ratings
    -   Performs group comparisons, correlations, regression modeling
    -   Outputs: Tables, figures to `results/`
3.  **Final report** → `REPORT.Rmd`
    -   Renders `REPORT.Rmd` to HTML
    -   Contains full methodology, results, and reproducibility notes
    -   \~2500 words, includes embedded tables/figures

## Dependencies

### Python 

-   numpy, pandas, scipy, matplotlib

### R 

-   tidyverse (dplyr, ggplot2, tidyr, readr)

-   lme4, lmerTest, emmeans (mixed models)

-   performance, rempsyc, flextable (diagnostics, tables)

## Key Files

| File                | Purpose                                               |
|-----------------------------|-------------------------------------------|
| `main.ipynb`        | Orchestrate Python preprocessing + feature extraction |
| `main.Rmd`          | Orchestrate R statistical analyses                    |
| `REPORT.Rmd`        | Generate final HTML technical report                  |
| `sources/*.py`      | Reusable Python functions (preprocessing, features)   |
| `sources/*.R`       | Reusable R functions (statistics, plotting)           |
| `notebooks/*.ipynb` | Detailed Python preprocessing/analysis steps          |
| `notebooks/*.Rmd`   | Detailed R analysis steps (questionnaire, movement)   |

## Reproducibility

All analyses are deterministic and scriptable. Rerunning `main.ipynb` and `main.Rmd` produces identical results (within floating-point precision).

## Contact

For questions or modifications, see the [GitHub repository](https://github.com/leaponsi/pons.lea.git) or modify scripts directly.
