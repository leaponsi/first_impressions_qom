# =============================================================================
# stats_movement.R — Compare movement metrics between SZ and HC
#
# For each movement signal and metric (expansiveness_per_s, QoM_per_s):
#   1. Normality check (Shapiro-Wilk, only reliable with n >= 3)
#   2. Group comparison: Welch t-test if normal, Mann-Whitney U if not
#   3. Effect size: Cohen's d (parametric) or rank-biserial r (non-parametric)
#   4. Summary table exported to results/
#   5. Boxplots faceted by signal
# =============================================================================

library(dplyr)
library(tidyr)
library(ggplot2)
library(effectsize)  # cohen_d, rank_biserial
library(purrr)

# Signals and metrics to test
SIGNALS <- c(
  "left_hand_vertical", "right_hand_vertical",
  "left_hand_horizontal", "right_hand_horizontal",
  "swaying", "sideways",
  "head_horizontal", "head_vertical",
  "left_foot_horizontal", "right_foot_horizontal"
)

METRICS <- c("expansiveness_per_s", "quantity_of_motion_per_s")

# =============================================================================
# 1. STATISTICAL TESTS
# =============================================================================

run_comparison <- function(df, signal, metric) {
  col     <- paste0(signal, "_", metric)
  avail   <- paste0(signal, "_available")

  if (!col %in% colnames(df)) return(NULL)

  # Only keep participants where signal is available
  d <- df %>%
    filter(.data[[avail]] == 1) %>%
    select(participant_id, group, value = all_of(col)) %>%
    filter(!is.na(value))

  sz <- d$value[d$group == "SZ"]
  hc <- d$value[d$group == "P"]

  if (length(sz) < 3 | length(hc) < 3) return(NULL)

  # Normality (Shapiro-Wilk)
  sw_sz <- shapiro.test(sz)$p.value
  sw_hc <- shapiro.test(hc)$p.value
  normal <- sw_sz > 0.05 & sw_hc > 0.05

  if (normal) {
    # Welch t-test (does not assume equal variances)
    test    <- t.test(sz, hc)
    method  <- "Welch t-test"
    stat    <- test$statistic
    p_value <- test$p.value
    es      <- cohens_d(sz, hc)$Cohens_d
    es_name <- "Cohen's d"
  } else {
    # Mann-Whitney U
    test    <- wilcox.test(sz, hc, exact = FALSE)
    method  <- "Mann-Whitney U"
    stat    <- test$statistic
    p_value <- test$p.value
    es      <- rank_biserial(sz, hc)$r_rank_biserial
    es_name <- "r (rank-biserial)"
  }

  data.frame(
    signal      = signal,
    metric      = metric,
    n_sz        = length(sz),
    n_hc        = length(hc),
    mean_sz     = round(mean(sz), 4),
    mean_hc     = round(mean(hc), 4),
    method      = method,
    statistic   = round(stat, 3),
    p_value     = round(p_value, 4),
    p_signif    = case_when(
      p_value <= 0.001 ~ "***",
      p_value <= 0.01  ~ "**",
      p_value <= 0.05  ~ "*",
      TRUE             ~ "ns"
    ),
    effect_size = round(es, 3),
    es_type     = es_name,
    stringsAsFactors = FALSE
  )
}

results_movement <- map_dfr(SIGNALS, function(sig) {
  map_dfr(METRICS, function(met) {
    run_comparison(df_metrics, sig, met)
  })
})

# Multiple comparisons correction (Benjamini-Hochberg FDR)
results_movement <- results_movement %>%
  mutate(p_adjusted = round(p.adjust(p_value, method = "BH"), 4),
         p_adj_signif = case_when(
           p_adjusted <= 0.001 ~ "***",
           p_adjusted <= 0.01  ~ "**",
           p_adjusted <= 0.05  ~ "*",
           TRUE                ~ "ns"
         ))

print(results_movement %>%
        select(signal, metric, mean_sz, mean_hc,
               method, p_value, p_signif, p_adjusted, p_adj_signif, effect_size))

# Export
write.csv(results_movement,
          file.path(RESULTS_PATH, "stats_movement.csv"),
          row.names = FALSE)
cat("Exported: results/stats_movement.csv\n")

# =============================================================================
# 2. BOXPLOTS — one facet per signal, two panels (expansiveness / QoM)
# =============================================================================

plot_metric <- function(metric, ylabel) {
  cols_to_plot <- paste0(SIGNALS, "_", metric)
  cols_exist   <- cols_to_plot[cols_to_plot %in% colnames(df_metrics)]

  df_long <- df_metrics %>%
    select(participant_id, group, all_of(cols_exist)) %>%
    pivot_longer(cols = all_of(cols_exist),
                 names_to = "signal", values_to = "value") %>%
    mutate(signal = str_remove(signal, paste0("_", metric)),
           group  = factor(group, levels = c("P", "SZ")))

  # Add significance labels from results table
  sig_labels <- results_movement %>%
    filter(metric == !!metric) %>%
    select(signal, p_adj_signif)

  df_long <- df_long %>%
    left_join(sig_labels, by = "signal")

  ggplot(df_long, aes(x = group, y = value, fill = group)) +
    geom_boxplot(width = 0.5, outlier.size = 1.5, alpha = 0.7) +
    facet_wrap(~signal, scales = "free_y", ncol = 2) +
    scale_fill_manual(values = c("P" = "#5B9BD5", "SZ" = "#ED7D31"),
                      labels = c("P" = "HC", "SZ" = "SZ")) +
    geom_text(data = df_long %>%
                group_by(signal, p_adj_signif) %>%
                summarise(y = max(value, na.rm = TRUE) * 1.05, .groups = "drop"),
              aes(x = 1.5, y = y, label = p_adj_signif),
              inherit.aes = FALSE, size = 4) +
    labs(x = NULL, y = ylabel, fill = "Group") +
    theme_minimal(base_size = 10) +
    theme(strip.text = element_text(size = 8),
          legend.position = "bottom")
}

p_exp <- plot_metric("expansiveness_per_s",   "Expansiveness / s (relative amplitude)")
p_qom <- plot_metric("quantity_of_motion_per_s", "Quantity of motion / s")

ggsave(file.path(RESULTS_PATH, "movement_expansiveness.png"),
       p_exp, width = 10, height = 14, dpi = 150)
ggsave(file.path(RESULTS_PATH, "movement_qom.png"),
       p_qom, width = 10, height = 14, dpi = 150)

cat("Figures saved to results/\n")
