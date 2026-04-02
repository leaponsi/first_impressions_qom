# =============================================================================
# regression.R — First impression scores ~ movement metrics
#
# Level of analysis: stimulus (40 rows)
# Each row = one stimulus participant, with:
#   - mean first impression scores averaged across all observers who saw them
#   - movement metrics from the Python pipeline
#
# Approach:
#   1. Correlations (Pearson or Spearman) between each metric and each score
#   2. Linear regressions: score ~ metric (univariate, one per combination)
#   3. Summary table of significant predictors
#   4. Correlation heatmap
# =============================================================================

library(dplyr)
library(tidyr)
library(ggplot2)
library(ggcorrplot)
library(purrr)

# Movement metrics to include as predictors
# Using per-second versions for comparability across recording durations
PREDICTORS <- c(
  "left_hand_vertical_expansiveness_per_s",
  "right_hand_vertical_expansiveness_per_s",
  "left_hand_horizontal_expansiveness_per_s",
  "right_hand_horizontal_expansiveness_per_s",
  "swaying_expansiveness_per_s",
  "sideways_expansiveness_per_s",
  "head_horizontal_expansiveness_per_s",
  "head_vertical_expansiveness_per_s",
  "left_hand_vertical_quantity_of_motion_per_s",
  "right_hand_vertical_quantity_of_motion_per_s",
  "left_hand_horizontal_quantity_of_motion_per_s",
  "right_hand_horizontal_quantity_of_motion_per_s",
  "swaying_quantity_of_motion_per_s",
  "head_horizontal_quantity_of_motion_per_s",
  "head_vertical_quantity_of_motion_per_s"
)

# Outcome variables
OUTCOMES <- c(
  "Total_score", "Score_impression", "Score_intention",
  "Attractive", "Awkward_r", "Intelligent", "Likeable",
  "Trustworthy", "Dominant",
  "Conversation", "Time", "LiveNearby", "SitNext"
)

# Keep only predictors that exist in df_stimulus
PREDICTORS <- PREDICTORS[PREDICTORS %in% colnames(df_stimulus)]
OUTCOMES   <- OUTCOMES[OUTCOMES %in% colnames(df_stimulus)]

# =============================================================================
# 1. UNIVARIATE CORRELATIONS
# =============================================================================

run_correlation <- function(df, predictor, outcome) {
  d <- df %>%
    select(all_of(c(predictor, outcome))) %>%
    filter(complete.cases(.))

  if (nrow(d) < 10) return(NULL)

  x <- d[[predictor]]
  y <- d[[outcome]]

  # Choose Pearson or Spearman based on normality
  sw_x <- shapiro.test(x)$p.value
  sw_y <- shapiro.test(y)$p.value

  method  <- ifelse(sw_x > 0.05 & sw_y > 0.05, "pearson", "spearman")
  ct      <- cor.test(x, y, method = method)

  data.frame(
    predictor   = predictor,
    outcome     = outcome,
    method      = method,
    r           = round(ct$estimate, 3),
    p_value     = round(ct$p.value, 4),
    stringsAsFactors = FALSE
  )
}

results_corr <- map_dfr(PREDICTORS, function(pred) {
  map_dfr(OUTCOMES, function(out) {
    run_correlation(df_stimulus, pred, out)
  })
})

# FDR correction
results_corr <- results_corr %>%
  mutate(
    p_adjusted = round(p.adjust(p_value, method = "BH"), 4),
    p_signif   = case_when(
      p_adjusted <= 0.001 ~ "***",
      p_adjusted <= 0.01  ~ "**",
      p_adjusted <= 0.05  ~ "*",
      TRUE                ~ "ns"
    )
  ) %>%
  arrange(p_adjusted)

cat("=== Significant correlations (FDR-corrected p < 0.05) ===\n")
print(results_corr %>% filter(p_signif != "ns"))

write.csv(results_corr,
          file.path(RESULTS_PATH, "regression_correlations.csv"),
          row.names = FALSE)
cat("Exported: results/regression_correlations.csv\n")

# =============================================================================
# 2. UNIVARIATE REGRESSIONS (significant correlations only)
# =============================================================================

sig_pairs <- results_corr %>%
  filter(p_signif != "ns") %>%
  select(predictor, outcome)

if (nrow(sig_pairs) > 0) {
  run_regression <- function(df, predictor, outcome) {
    formula <- as.formula(paste(outcome, "~", predictor))
    m <- lm(formula, data = df)
    s <- summary(m)
    data.frame(
      predictor = predictor,
      outcome   = outcome,
      beta      = round(coef(m)[2], 4),
      R2        = round(s$r.squared, 3),
      p_value   = round(coef(summary(m))[2, 4], 4),
      stringsAsFactors = FALSE
    )
  }

  results_lm <- map2_dfr(sig_pairs$predictor, sig_pairs$outcome,
                          ~run_regression(df_stimulus, .x, .y))
  print(results_lm)

  write.csv(results_lm,
            file.path(RESULTS_PATH, "regression_lm.csv"),
            row.names = FALSE)
}

# =============================================================================
# 3. CORRELATION HEATMAP (predictors × main outcomes)
# =============================================================================

main_outcomes <- c("Total_score", "Score_impression", "Score_intention")

corr_matrix <- results_corr %>%
  filter(outcome %in% main_outcomes) %>%
  select(predictor, outcome, r) %>%
  pivot_wider(names_from = outcome, values_from = r) %>%
  tibble::column_to_rownames("predictor") %>%
  as.matrix()

# Shorten predictor names for readability
rownames(corr_matrix) <- rownames(corr_matrix) %>%
  str_remove("_expansiveness_per_s") %>%
  str_remove("_quantity_of_motion_per_s") %>%
  paste0(ifelse(grepl("quantity", rownames(corr_matrix) %>%
                         paste0(., "_placeholder")), " (QoM)", " (Exp)"))

# Fix rownames properly
rn <- results_corr %>%
  filter(outcome %in% main_outcomes) %>%
  pull(predictor) %>% unique()

rownames(corr_matrix) <- rn %>%
  str_replace("_expansiveness_per_s$", " [Exp]") %>%
  str_replace("_quantity_of_motion_per_s$", " [QoM]")

p_heatmap <- ggcorrplot(
  corr_matrix,
  method    = "square",
  lab       = TRUE,
  lab_size  = 3,
  colors    = c("#ED7D31", "white", "#5B9BD5"),
  title     = "Correlations: movement metrics × first impression scores",
  ggtheme   = theme_minimal()
)

ggsave(file.path(RESULTS_PATH, "regression_heatmap.png"),
       p_heatmap, width = 8, height = 10, dpi = 300)

cat("Heatmap saved to results/\n")
