# -----------------------------------------------------------------------------
# Movement metrics <-> First impression
#
# The three global movement metrics (mean_QoM, mean_amplitude_sum,
# mean_mean_speed) correlate r > .92 with each other. They measure
# essentially the same underlying dimension ("how much this person moves").
# We combine them into a single composite score `movement_global` (mean of
# the three already-z-scored metrics) to avoid multicollinearity and keep
# one clean test.
#
# Three functions:
#   build_metric_impression_correlations_per_metric()
#     -> 3 Spearman correlations (one per raw metric). Used to justify the
#        composite: if the 3 correlations look alike, merging is legitimate.
#
#   build_metric_impression_regression()
#     -> Simple linear regression at the stimulus level (n = 40):
#          FirstImpression_total ~ movement_global
#        Returns intercept, slope, R², F, p.
#
#   fit_metric_impression_model()
#     -> Linear mixed model at the observation level:
#          FirstImpression_total ~ Type + movement_global + num_video +
#                                  (1|CASE) + (1|video_id)
# -----------------------------------------------------------------------------

# Build the composite: mean of the 3 z-scored metrics per participant
build_participant_composite <- function(features_df) {
  build_participant_metrics(features_df) |>
    dplyr::mutate(
      movement_global = rowMeans(
        dplyr::across(c(mean_QoM, mean_amplitude_sum, mean_mean_speed)),
        na.rm = TRUE
      )
    )
}

# 1. Stimulus-level regression (composite ~ FirstImpression) ----------------
# Simple linear regression at the stimulus level (n = 40).
# Returns a tibble with intercept, slope, R2, F, df, p.
build_metric_impression_regression <- function(questionnaire_df, features_df) {
  q <- prepare_questionnaire_scores(questionnaire_df)
  p <- build_participant_composite(features_df)

  stim <- q |>
    dplyr::group_by(participant_id, Type) |>
    dplyr::summarise(
      FirstImpression_total = mean(FirstImpression_total, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::inner_join(p, by = "participant_id")

  model <- stats::lm(FirstImpression_total ~ movement_global, data = stim)
  s     <- summary(model)

  intercept <- stats::coef(s)["(Intercept)",   ]
  slope     <- stats::coef(s)["movement_global", ]

  tibble::tibble(
    Predictor = c("Intercept", "Movement composite (+1 SD)"),
    B         = c(intercept["Estimate"], slope["Estimate"]),
    SE        = c(intercept["Std. Error"], slope["Std. Error"]),
    t         = c(intercept["t value"], slope["t value"]),
    p         = c(intercept["Pr(>|t|)"], slope["Pr(>|t|)"])
  ) |>
    dplyr::mutate(
      R2       = s$r.squared,
      R2_adj   = s$adj.r.squared,
      F_stat   = s$fstatistic[["value"]],
      df_num   = s$fstatistic[["numdf"]],
      df_den   = s$fstatistic[["dendf"]],
      n        = stats::nobs(model)
    )
}

# 1bis. Three separate correlations (one per raw metric)
# Used to show that the 3 metrics relate to FirstImpression in a very
# similar way, which justifies merging them into a composite.
build_metric_impression_correlations_per_metric <- function(questionnaire_df, features_df) {
  q <- prepare_questionnaire_scores(questionnaire_df)
  p <- build_participant_metrics(features_df)

  stim <- q |>
    dplyr::group_by(participant_id, Type) |>
    dplyr::summarise(
      FirstImpression_total = mean(FirstImpression_total, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::inner_join(p, by = "participant_id")

  rows <- list()
  for (met in GLOBAL_METRICS) {
    test_res <- suppressWarnings(
      stats::cor.test(
        stim[[met]], stim$FirstImpression_total,
        method = "spearman", exact = FALSE
      )
    )
    rows[[length(rows) + 1]] <- tibble::tibble(
      Metric = met,
      n      = nrow(stim),
      r      = unname(test_res$estimate),
      p      = test_res$p.value
    )
  }
  dplyr::bind_rows(rows)
}

# 2. Mixed model with the composite as predictor -----------------------------
# Returns a list with:
#   coefficients : tibble of fixed effects (for the main APA table)
#   fit          : tibble with marginal and conditional R² (Nakagawa)
fit_metric_impression_model <- function(questionnaire_df, features_df) {
  q_scores  <- prepare_questionnaire_scores(questionnaire_df)
  composite <- build_participant_composite(features_df) |>
    dplyr::select(participant_id, movement_global)

  data <- dplyr::inner_join(q_scores, composite, by = "participant_id")

  # Treatment coding: Healthy is the reference, so the Type coefficient
  # reads directly as "Patient - Healthy".
  options(contrasts = c("contr.treatment", "contr.poly"))

  model <- lme4::lmer(
    FirstImpression_total ~ Type + movement_global + num_video +
      (1 | CASE) + (1 | video_id),
    data = data, REML = FALSE
  )

  # Fixed effects table
  fe <- as.data.frame(coef(summary(model)))
  fe <- tibble::rownames_to_column(fe, "Predictor")

  keep <- c("TypePatient"     = "Patient vs Healthy",
            "movement_global" = "Movement composite (+1 SD)",
            "num_video"       = "Presentation order")

  fe <- fe[fe$Predictor %in% names(keep), ]
  fe$Predictor <- keep[fe$Predictor]

  coefficients <- tibble::tibble(
    Predictor = fe$Predictor,
    B         = fe$Estimate,
    SE        = fe$`Std. Error`,
    df        = fe$df,
    t         = fe$`t value`,
    p         = fe$`Pr(>|t|)`
  )

  # R² (Nakagawa): marginal = fixed effects only,
  #                conditional = fixed + random effects
  r2_vals <- performance::r2(model)

  fit <- tibble::tibble(
    Index           = c("Marginal R²", "Conditional R²", "N observations"),
    Value           = c(sprintf("%.3f", r2_vals$R2_marginal),
                        sprintf("%.3f", r2_vals$R2_conditional),
                        as.character(stats::nobs(model)))
  )

  list(coefficients = coefficients, fit = fit)
}
