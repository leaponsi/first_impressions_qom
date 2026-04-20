# -----------------------------------------------------------------------------
# Movement statistics helpers
#
# Three global metrics per participant, computed by z-scoring each metric
# within each movement (so every movement contributes equally, on the same
# scale) and then averaging the z-scores across movements:
#   mean_QoM, mean_amplitude_sum, mean_mean_speed
# This protects against the bias that would arise from raw averaging when a
# participant has fewer than 6 movements recorded (e.g. P10 and SZ4).
#
# Four functions:
#   build_participant_metrics()          -> wide table, 1 row per participant,
#                                           3 global metrics + group
#   build_movement_descriptives()        -> M (SD) and N per group, per metric
#   build_movement_correlation_matrix()  -> 3 x 3 correlation matrix
#                                           (Pearson if all vars normal,
#                                            Spearman otherwise)
#   build_movement_group_differences()   -> CT vs SZ test per metric
#                                           (Welch t-test if both groups normal,
#                                            Wilcoxon otherwise)
# -----------------------------------------------------------------------------

# Global metric names (after averaging across the 6 movements)
GLOBAL_METRICS <- c("mean_QoM", "mean_amplitude_sum", "mean_mean_speed")

# Small helper: "M (SD)"
fmt_msd <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_character_)
  sprintf("%.3f (%.3f)", mean(x), sd(x))
}

# Normality check used to pick parametric vs non-parametric test
is_normal <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) < 3 || length(x) > 5000) return(FALSE)
  stats::shapiro.test(x)$p.value > .05
}

# 0. Participant-level table: z-score each metric within each movement,
#    then average the z-scores across the 6 movements.
#    This weights each movement equally and avoids a bias when some
#    movements are missing (hand_* missing for P10 and SZ4).
build_participant_metrics <- function(features_df) {
  features_df |>
    dplyr::group_by(movement_type) |>
    dplyr::mutate(
      z_QoM           = as.numeric(scale(QoM)),
      z_amplitude_sum = as.numeric(scale(amplitude_sum)),
      z_mean_speed    = as.numeric(scale(mean_speed))
    ) |>
    dplyr::ungroup() |>
    dplyr::group_by(participant_id, group) |>
    dplyr::summarise(
      mean_QoM           = mean(z_QoM,           na.rm = TRUE),
      mean_amplitude_sum = mean(z_amplitude_sum, na.rm = TRUE),
      mean_mean_speed    = mean(z_mean_speed,    na.rm = TRUE),
      n_movements_used   = dplyr::n(),
      .groups = "drop"
    )
}

# 1. Descriptive table: M (SD) and N per group, per global metric
build_movement_descriptives <- function(features_df) {
  p_metrics <- build_participant_metrics(features_df)

  rows <- list()
  for (met in GLOBAL_METRICS) {
    x_ct <- p_metrics[[met]][p_metrics$group == "P"]
    x_sz <- p_metrics[[met]][p_metrics$group == "SZ"]

    rows[[length(rows) + 1]] <- tibble::tibble(
      Metric = met,
      CT     = fmt_msd(x_ct),
      SZ     = fmt_msd(x_sz),
      N_CT   = sum(!is.na(x_ct)),
      N_SZ   = sum(!is.na(x_sz))
    )
  }

  dplyr::bind_rows(rows)
}

# 2. Correlation matrix of the 3 global metrics
# Method chosen once for the whole matrix: Spearman if any metric is
# non-normal, Pearson otherwise.
build_movement_correlation_matrix <- function(features_df) {
  p_metrics <- build_participant_metrics(features_df)
  mat <- as.matrix(p_metrics[, GLOBAL_METRICS])

  all_normal <- all(apply(mat, 2, is_normal))
  method     <- if (all_normal) "pearson" else "spearman"

  cor_mat <- stats::cor(mat, method = method, use = "pairwise.complete.obs")

  attr(cor_mat, "method") <- method
  cor_mat
}

# 3. Group comparisons CT vs SZ on the 3 global metrics
build_movement_group_differences <- function(features_df) {
  p_metrics <- build_participant_metrics(features_df)

  rows <- list()
  for (met in GLOBAL_METRICS) {
    x_ct <- p_metrics[[met]][p_metrics$group == "P"]
    x_sz <- p_metrics[[met]][p_metrics$group == "SZ"]
    x_ct <- x_ct[!is.na(x_ct)]
    x_sz <- x_sz[!is.na(x_sz)]

    if (is_normal(x_ct) && is_normal(x_sz)) {
      test_res  <- stats::t.test(x_ct, x_sz, var.equal = FALSE)
      test_name <- "Welch t-test"
      stat_val  <- unname(test_res$statistic)
    } else {
      test_res  <- stats::wilcox.test(x_ct, x_sz, exact = FALSE)
      test_name <- "Wilcoxon rank-sum"
      stat_val  <- unname(test_res$statistic)
    }

    rows[[length(rows) + 1]] <- tibble::tibble(
      Metric    = met,
      CT        = fmt_msd(x_ct),
      SZ        = fmt_msd(x_sz),
      Test      = test_name,
      Statistic = stat_val,
      p         = test_res$p.value
    )
  }

  dplyr::bind_rows(rows)
}

# 4. Prepare plot data for group comparison figure
build_movement_plot_data <- function(features_df) {
  
  p_metrics <- build_participant_metrics(features_df)
  
  plot_data <- p_metrics |>
    dplyr::select(group, mean_QoM, mean_amplitude_sum, mean_mean_speed) |>
    tidyr::pivot_longer(
      cols = -group,
      names_to = "Metric",
      values_to = "Value"
    ) |>
    dplyr::mutate(
      group = dplyr::recode(group, "P" = "CT", "SZ" = "SZ"),
      Metric = dplyr::recode(
        Metric,
        mean_QoM = "QoM",
        mean_amplitude_sum = "Amplitude sum",
        mean_mean_speed = "Mean speed"
      )
    )
  
  return(plot_data)
}


# 5. Build annotation table for significance labels
build_movement_plot_annotations <- function(features_df) {
  
  group_diff <- build_movement_group_differences(features_df)
  
  annotation_df <- group_diff |>
    dplyr::mutate(
      Metric = dplyr::recode(
        Metric,
        mean_QoM = "QoM",
        mean_amplitude_sum = "Amplitude sum",
        mean_mean_speed = "Mean speed"
      ),
      p_label = dplyr::case_when(
        p < .001 ~ "***",
        p < .01  ~ "**",
        p < .05  ~ "*",
        TRUE     ~ "ns"
      )
    ) |>
    dplyr::select(Metric, p, p_label)
  
  return(annotation_df)
}


# 6. Plot group differences on global movement metrics
plot_movement_group_differences <- function(features_df) {
  
  plot_data <- build_movement_plot_data(features_df)
  annotation_df <- build_movement_plot_annotations(features_df)
  
  y_pos <- plot_data |>
    dplyr::group_by(Metric) |>
    dplyr::summarise(
      y = max(Value, na.rm = TRUE) + 0.20 * diff(range(Value, na.rm = TRUE)),
      y_line = max(Value, na.rm = TRUE) + 0.10 * diff(range(Value, na.rm = TRUE)),
      .groups = "drop"
    )
  
  annotation_df <- annotation_df |>
    dplyr::left_join(y_pos, by = "Metric") |>
    dplyr::mutate(
      x1 = 1,
      x2 = 2,
      x_text = 1.5
    )
  
  p <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = group, y = Value, fill = group, color = group)
  ) +
    ggplot2::geom_violin(
      width = 0.9,
      alpha = 0.25,
      trim = FALSE
    ) +
    ggplot2::geom_boxplot(
      width = 0.18,
      alpha = 0.70,
      outlier.shape = NA,
      color = "black"
    ) +
    ggplot2::geom_jitter(
      width = 0.08,
      alpha = 0.75,
      size = 2
    ) +
    ggplot2::geom_segment(
      data = annotation_df,
      ggplot2::aes(x = x1, xend = x2, y = y_line, yend = y_line),
      inherit.aes = FALSE,
      linewidth = 0.5,
      color = "black"
    ) +
    ggplot2::geom_text(
      data = annotation_df,
      ggplot2::aes(x = x_text, y = y, label = p_label),
      inherit.aes = FALSE,
      size = 5
    ) +
    ggplot2::facet_wrap(~ Metric, scales = "free_y") +
    ggplot2::scale_fill_manual(
      values = c("CT" = "orange", "SZ" = "steelblue")
    ) +
    ggplot2::scale_color_manual(
      values = c("CT" = "orange", "SZ" = "steelblue")
    ) +
    ggplot2::labs(
      x = NULL,
      y = "Standardized score"
    ) +
    ggplot2::theme_classic() +
    ggplot2::theme(
      legend.position = "none",
      strip.background = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", size = 11),
      axis.title.y = ggplot2::element_text(size = 11),
      axis.text = ggplot2::element_text(size = 10),
      axis.line = ggplot2::element_line(color = "black"),
      plot.margin = ggplot2::margin(10, 15, 10, 10)
    )
  
  return(p)
}