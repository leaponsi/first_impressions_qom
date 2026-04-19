# RECOMMENDED DOCSTRINGS FOR R FUNCTIONS

These docstrings should be added to improve code documentation. They follow R roxygen2 format.

## FILE: sources/stat_helpers.R

```r
#' Create Formatted Table for Display
#'
#' Wraps knitr::kable for consistent formatting of result tables.
#'
#' @param x Data frame to display
#' @param title Optional caption for the table
#' @param note Optional footer note
#'
#' @return kable object for display in notebooks
nice_table <- function(x, title = NULL, note = NULL) { ... }


#' Safe Sum Handling Missing Values
#'
#' Computes sum of a vector while handling NaN gracefully.
#' Returns NA_real_ if all values are NA, otherwise returns sum with na.rm = TRUE.
#'
#' @param x Numeric vector (may contain NAs)
#'
#' @return Numeric scalar (sum or NA_real_ if all NA)
safe_sum <- function(x) { ... }


#' Compare Two Groups on a Continuous Variable
#'
#' Tests for group differences using either t-test (if normality + equal variance 
#' assumptions hold) or Wilcoxon rank-sum test (non-parametric alternative).
#'
#' First checks assumptions:
#'   - Shapiro-Wilk normality test (p > 0.05 = normal)
#'   - Levene's test for equal variance (p > 0.05 = equal)
#'
#' Uses t-test if both assumptions met, otherwise Wilcoxon rank-sum (non-parametric).
#'
#' @param data Data frame containing group and value columns
#' @param value_col Name of the numeric variable to compare (string)
#' @param group_col Name of the grouping variable (string, must have exactly 2 unique groups)
#'
#' @return Data frame with test results and descriptive statistics:
#'   - variable, test (test name used)
#'   - group_1, n_1, mean_sd_1, median_1
#'   - group_2, n_2, mean_sd_2, median_2
#'   - statistic, p_value
compare_continuous_groups <- function(data, value_col, group_col) { ... }


#' Compare Two Groups on a Categorical Variable
#'
#' Performs Fisher's exact test for contingency table. Robust to small cell counts
#' (does not require minimum expected frequencies like chi-square).
#'
#' @param data Data frame containing group and value columns
#' @param value_col Name of the categorical variable to compare (string)
#' @param group_col Name of the grouping variable (string)
#'
#' @return Data frame with test results and contingency table counts:
#'   - variable, test
#'   - group_1, counts_1 (formatted as "category: count; category: count; ...")
#'   - group_2, counts_2
#'   - statistic (NA for Fisher's test)
#'   - p_value
compare_categorical_groups <- function(data, value_col, group_col) { ... }


#' Compute Cliff's Delta Effect Size
#'
#' Non-parametric effect size measure for comparing two independent groups.
#' Computed as the proportion of concordant pairs minus discordant pairs via 
#' the sign of all pairwise comparisons.
#'
#' Ranges from -1 (all x < y, maximum effect) to +1 (all x > y, maximum effect).
#'
#' @param x First group (numeric vector, may contain NAs)
#' @param y Second group (numeric vector, may contain NAs)
#'
#' @return Numeric scalar in range [-1, 1]. NA if either group is empty.
#'
#' @seealso label_cliffs_delta() for interpretation
compute_cliffs_delta <- function(x, y) { ... }


#' Label Cliff's Delta Effect Size
#'
#' Maps absolute Cliff's delta value to qualitative effect size label
#' using conventional thresholds:
#'   - negligible: |delta| < 0.147
#'   - small: 0.147 <= |delta| < 0.330
#'   - medium: 0.330 <= |delta| < 0.474
#'   - large: |delta| >= 0.474
#'
#' @param delta Numeric value in range [-1, 1]
#'
#' @return Character string: "negligible", "small", "medium", "large", or NA_character_
#'
#' @seealso compute_cliffs_delta()
label_cliffs_delta <- function(delta) { ... }


#' Extract Fixed Effects from Mixed Model
#'
#' Extracts and formats fixed-effects coefficients from lme4 model objects
#' (lmer or glmer). Reformats column names for clarity and adds model identifier.
#'
#' @param model lme4 model object (lmer or glmer)
#' @param model_name Character string identifying the model (e.g., "First impression")
#'
#' @return Data frame with columns:
#'   - Model: the provided model_name
#'   - Predictor: coefficient name
#'   - Estimate: fixed effect estimate
#'   - SE: standard error
#'   - df: degrees of freedom
#'   - t: t-statistic
#'   - p: p-value (Pr(>|t|))
extract_fixed_effects <- function(model, model_name) { ... }
```

---

## FILE: sources/movement_statistics.R

```r
#' Aggregate Movement Metrics Across Movement Types
#'
#' Computes participant-level total movement metrics by summing across all
#' individual movement types (hand_horizontal, hand_vertical, swaying, etc.).
#'
#' IMPORTANT: Uses safe_sum() which returns NA if ALL movement types are NA.
#' This means a participant has valid metrics only if at least one movement
#' type is non-NA.
#'
#' Also computes z-scores (standardized versions) for use in mixed models.
#'
#' @param features_df Data frame with columns: participant_id, participant, group,
#'                    movement_type, QoM, amplitude_sum, mean_speed
#'
#' @return Data frame with columns:
#'   - participant_id, participant, group
#'   - total_QoM, total_amplitude_sum, total_mean_speed (summed across types)
#'   - n_available_movement_types (count of non-NA combinations)
#'   - z_total_QoM, z_total_amplitude_sum, z_total_mean_speed (standardized)
aggregate_movement_totals <- function(features_df) { ... }


#' Prepare Combined Analysis Dataset
#'
#' Joins questionnaire data, movement features, and stimulus demographics
#' at the participant × video level.
#'
#' Combines:
#'   1. Questionnaire scores (observer ratings)
#'   2. Movement totals (aggregated metrics per stimulus participant)
#'   3. Stimulus info (demographics of video actors)
#'   4. Movement features wide (individual movement type metrics)
#'
#' @param questionnaire_df Questionnaire data (long: 1 row per observer × video)
#' @param features_df Movement features (long: 1 row per participant × movement_type)
#' @param stimuli_df Stimulus participant info (1 row per stimulus participant)
#'
#' @return Data frame combining all sources at observer × video level
#'
#' @seealso aggregate_movement_totals()
prepare_analysis_dataset <- function(questionnaire_df, features_df, stimuli_df) { ... }


#' Test Group Differences on Movement Metrics
#'
#' Tests whether P (healthy) and SZ (schizophrenia) groups differ on each
#' movement metric × movement type combination using Wilcoxon rank-sum
#' (non-parametric) and Cliff's delta (effect size).
#'
#' Applies Holm correction for multiple comparisons.
#'
#' @param features_df Movement features (long format)
#'
#' @return Data frame with one row per metric × movement type combination:
#'   - movement_type, metric (QoM, amplitude_sum, mean_speed)
#'   - n_P, n_SZ, mean_P, mean_SZ, median_P, median_SZ
#'   - p_value, p_adj (Holm-corrected), sig (significance stars)
#'   - cliffs_delta, effect_size (negligible/small/medium/large)
#'
#' @seealso compute_cliffs_delta()
build_movement_group_differences <- function(features_df) { ... }


#' Create Stimulus-Level Analysis Dataset
#'
#' Aggregates questionnaire and movement data at the level of individual
#' stimulus videos (averaging across all observers who rated each video).
#'
#' @param questionnaire_df Observer ratings (long: 1 row per observer × video)
#' @param features_df Movement features (stimulus participant level)
#' @param stimuli_df Stimulus demographics
#'
#' @return Data frame with 1 row per stimulus video, containing:
#'   - FirstImpression_total, InteractionIntent_total, Global_total (averaged)
#'   - Movement metrics (total_QoM, total_amplitude, etc.)
#'
#' @seealso prepare_analysis_dataset()
build_stimulus_level_dataset <- function(questionnaire_df, features_df, stimuli_df) { ... }


#' Compute Correlations Between Movement Metrics and Impression Scores
#'
#' Calculates Spearman correlations between each movement metric and each
#' impression/behavioral score at the stimulus video level (one observation
#' per stimulus video, aggregated across all observers).
#'
#' Uses Spearman (rank-based) to avoid assumptions about normality.
#' Applies Holm correction for multiple comparisons.
#'
#' @param questionnaire_df Observer ratings
#' @param features_df Movement features
#' @param stimuli_df Stimulus demographics
#'
#' @return Data frame with correlations:
#'   - metric (movement metric name)
#'   - score (impression/behavioral score: FirstImpression_total, etc.)
#'   - n (sample size = number of stimulus videos with data)
#'   - rho (Spearman correlation coefficient)
#'   - p_value, p_adj (Holm-corrected), sig (significance stars)
#'   Sorted by p_adj ascending, then by |rho| descending.
build_metric_impression_correlations <- function(questionnaire_df, features_df, stimuli_df) { ... }


#' Fit Mixed Models Linking Movement Metrics to Impression Ratings
#'
#' Fits three linear mixed-effects models to test whether aggregated movement
#' metrics (total_QoM, total_amplitude, total_mean_speed) predict:
#'   1. FirstImpression_total
#'   2. InteractionIntent_total
#'   3. Global_total
#'
#' Fixed effects: Type (stimulus group: Healthy/Patient), num_video (presentation order),
#' and three standardized (z-scored) movement metrics.
#'
#' Random effects: intercepts for observer (CASE) and video (video_id).
#'
#' Specifies REML = FALSE (ML estimation) for model comparison.
#'
#' @param questionnaire_df Observer ratings
#' @param features_df Movement features
#' @param stimuli_df Stimulus demographics
#'
#' @return List with elements:
#'   - data: filtered analysis dataset used for modeling
#'   - models: list of three lmer objects (first_impression, interaction_intention, global)
#'   - fixed_effects: data frame of fixed-effect estimates, SEs, t-stats, p-values
#'   - anovas: data frame of Type III ANOVA results from car::Anova()
fit_total_movement_models <- function(questionnaire_df, features_df, stimuli_df) { ... }
```

---

## FILE: sources/stimuli_manip_check.R

```r
#' Load and Prepare Stimulus Participant Information
#'
#' Reads stimulus participant demographics from CSV (semicolon-delimited),
#' applies consistent variable naming, and converts Group to factor.
#'
#' @param path Path to stimuli_participants.csv file (default: "../data/stimuli_participants.csv")
#'
#' @return Data frame with columns:
#'   - participant_id: unique stimulus participant identifier
#'   - stimuli_group: factor with levels c("CT", "SZ") [CT = control/healthy]
#'   - stimuli_type: character ("Healthy" or "Patient")
#'   - stimuli_genre: factor (F/M for gender)
#'   - stimuli_age: numeric age in years
#'   - stimuli_education: numeric education level
read_stimuli_participants <- function(path = "../data/stimuli_participants.csv") { ... }


#' Build Descriptive Statistics for Stimulus Participants
#'
#' Computes group-level summaries (CT vs SZ) for demographic variables.
#'
#' @param stimuli_info Data frame from read_stimuli_participants()
#'
#' @return Data frame with one row per group (CT, SZ), columns:
#'   - stimuli_group, n
#'   - mean_age, sd_age
#'   - mean_education, sd_education
#'   - female_n, male_n
build_stimuli_descriptives <- function(stimuli_info) { ... }


#' Test Stimulus Group Matching (Manipulation Check)
#'
#' Verifies that CT (control/healthy) and SZ (schizophrenia) stimulus groups
#' are statistically comparable on age, education, and gender.
#'
#' Uses:
#'   - Wilcoxon rank-sum for age and education
#'   - Fisher's exact test for gender
#'
#' @param stimuli_info Data frame from read_stimuli_participants()
#'
#' @return Data frame combining results of three tests:
#'   - Age: group comparison on stimuli_age
#'   - Education: group comparison on stimuli_education
#'   - Gender: group comparison on stimuli_genre (F vs H)
#'   Each test row includes descriptive stats, test name, and p-value.
build_stimuli_manip_check <- function(stimuli_info) { ... }
```

---

## USAGE INSTRUCTIONS

To apply these docstrings:

1. Copy each function's docstring from above
2. Insert it immediately before the `function_name <- function(...)` line
3. Ensure proper indentation (roxygen2 comments start with `#'`)

**Example**:

```r
# BEFORE
aggregate_movement_totals <- function(features_df) {
  features_df |> ...
}

# AFTER
#' Aggregate Movement Metrics Across Movement Types
#'
#' Computes participant-level total movement metrics by summing across...
#'
#' @param features_df Data frame with columns: ...
#'
#' @return Data frame with columns: ...
aggregate_movement_totals <- function(features_df) {
  features_df |> ...
}
```

---

## KEY DOCUMENTATION NOTES

### aggregation_movement_totals() - Important Design Decision

The function uses `safe_sum()` to aggregate across movement types:

```r
total_QoM = safe_sum(QoM),
```

This means:
- ✅ Captures overall quantity of motion across all body parts
- ⚠️ Participants with incomplete movement type data will have NA totals
- ⚠️ Does NOT average, so participants with more valid movement types get higher totals

**Consider documenting why this approach was chosen** over alternatives:
- Could use `mean()` instead: average across valid movement types
- Could use `sum() / n_available`: normalized sum
- Current approach: raw sum (assumes all 6 movement types captured)

---

## TIME ESTIMATE

Adding docstrings to all functions: **15-20 minutes**

These are medium-complexity functions with 2-3 key parameters and clear purposes, so docstrings can be concise but comprehensive.
