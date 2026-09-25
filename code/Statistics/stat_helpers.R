# stat_helpers.R
#
# Statistical-test functions, linear-mixed-model fitting/extraction,
# diagnostics and random-effect helpers used throughout
# 03_statistical_analysis.Rmd. Kept in a separate file (the same pattern
# as style_helpers.R for formatting) so the notebook itself stays focused
# on running and reporting the analyses rather than defining them.
#
# Sourced from 03_statistical_analysis.Rmd's `packages-constants` chunk:
#   source("stat_helpers.R")

# ============================================================================
# Statistical-test functions
# ============================================================================

# ---- Auto-selected two-group test (SAMPL: report assumptions + effect size)
auto_group_test <- function(data, outcome, group_var = "stim_group",
                            alpha_normality = 0.05) {

  d <- data |>
    select(all_of(c(outcome, group_var))) |>
    filter(!is.na(.data[[outcome]]), !is.na(.data[[group_var]]))

  if (!is.numeric(d[[outcome]]))
    stop(sprintf("'%s' is not numeric.", outcome))

  d[[group_var]] <- droplevels(as.factor(d[[group_var]]))
  if (nlevels(d[[group_var]]) != 2)
    stop("Exactly two groups are required.")

  groups <- levels(d[[group_var]])
  desc <- d |>
    group_by(.data[[group_var]]) |>
    summarise(n      = dplyr::n(),
              mean   = mean(.data[[outcome]]),
              sd     = sd(.data[[outcome]]),
              median = median(.data[[outcome]]),
              q1     = quantile(.data[[outcome]], 0.25),
              q3     = quantile(.data[[outcome]], 0.75),
              .groups = "drop")

  # Shapiro per group
  norm <- d |>
    group_by(.data[[group_var]]) |>
    summarise(p_shapiro = if (dplyr::n() >= 3 && dplyr::n() <= 5000)
                shapiro.test(.data[[outcome]])$p.value else NA_real_,
              .groups = "drop")
  normality_ok <- all(norm$p_shapiro > alpha_normality, na.rm = TRUE)

  # Levene
  fml <- as.formula(paste(outcome, "~", group_var))
  lev <- tryCatch(car::leveneTest(fml, data = d, center = median),
                  error = function(e) NULL)
  p_levene   <- if (!is.null(lev)) lev$`Pr(>F)`[1] else NA_real_
  vars_equal <- !is.na(p_levene) && p_levene > 0.05

  # Test choice
  if (normality_ok && vars_equal) {
    test_name <- "Student t-test"
    tt <- t.test(fml, data = d, var.equal = TRUE)
    es <- effectsize::cohens_d(fml, data = d, pooled_sd = TRUE)
    stat <- unname(tt$statistic); df_val <- unname(tt$parameter); pval <- tt$p.value
    es_name <- "Cohen's d"; es_val <- es$Cohens_d
    es_lo <- es$CI_low; es_hi <- es$CI_high
    diff_est <- unname(tt$estimate[1] - tt$estimate[2])
    diff_lo  <- tt$conf.int[1]; diff_hi <- tt$conf.int[2]
  } else if (normality_ok && !vars_equal) {
    test_name <- "Welch t-test"
    tt <- t.test(fml, data = d, var.equal = FALSE)
    es <- effectsize::cohens_d(fml, data = d, pooled_sd = FALSE)
    stat <- unname(tt$statistic); df_val <- unname(tt$parameter); pval <- tt$p.value
    es_name <- "Cohen's d"; es_val <- es$Cohens_d
    es_lo <- es$CI_low; es_hi <- es$CI_high
    diff_est <- unname(tt$estimate[1] - tt$estimate[2])
    diff_lo  <- tt$conf.int[1]; diff_hi <- tt$conf.int[2]
  } else {
    test_name <- "Wilcoxon rank-sum"
    wt <- suppressWarnings(wilcox.test(fml, data = d, exact = FALSE,
                                       conf.int = TRUE))
    es <- effectsize::rank_biserial(fml, data = d)
    stat <- unname(wt$statistic); df_val <- NA_real_; pval <- wt$p.value
    es_name <- "Rank-biserial r"; es_val <- es$r_rank_biserial
    es_lo <- es$CI_low; es_hi <- es$CI_high
    diff_est <- unname(wt$estimate)
    diff_lo  <- wt$conf.int[1]; diff_hi <- wt$conf.int[2]
  }

  tibble(
    outcome      = outcome,
    g1           = groups[1],
    n_g1         = desc$n[1],  mean_g1 = desc$mean[1], sd_g1 = desc$sd[1],
    median_g1    = desc$median[1], q1_g1 = desc$q1[1], q3_g1 = desc$q3[1],
    g2           = groups[2],
    n_g2         = desc$n[2],  mean_g2 = desc$mean[2], sd_g2 = desc$sd[2],
    median_g2    = desc$median[2], q1_g2 = desc$q1[2], q3_g2 = desc$q3[2],
    shapiro_p_g1 = norm$p_shapiro[1],
    shapiro_p_g2 = norm$p_shapiro[2],
    normality_ok = normality_ok,
    levene_p     = p_levene,
    vars_equal   = vars_equal,
    test         = test_name,
    statistic    = stat,
    df           = df_val,
    p_value      = pval,
    diff_est     = diff_est,
    diff_ci_lo   = diff_lo,
    diff_ci_hi   = diff_hi,
    es_name      = es_name,
    es           = es_val,
    es_ci_lo     = es_lo,
    es_ci_hi     = es_hi
  )
}

auto_group_test_multi <- function(data, outcomes, group_var = "stim_group",
                                  bh_correction = TRUE) {
  res <- map_dfr(outcomes,
                 ~ auto_group_test(data, .x, group_var))
  if (bh_correction)
    res$p_value_BH <- p.adjust(res$p_value, method = "BH")
  res
}

# ---- Linear mixed models ---------------------------------------------------
fit_lmm <- function(data, outcome, fixed_term, random = "(1 | obs_id) + (1 | vid)") {
  fml <- as.formula(sprintf("%s ~ %s + %s", outcome, fixed_term, random))
  lmerTest::lmer(fml, data = data, REML = TRUE)
}

extract_lmm_results <- function(model, target_term) {
  fe <- summary(model)$coefficients |>
    as.data.frame() |>
    tibble::rownames_to_column("term") |>
    as_tibble() |>
    rename(estimate = Estimate, se = `Std. Error`,
           df = df, statistic = `t value`, p_value = `Pr(>|t|)`)
  ci <- tryCatch(confint(model, method = "Wald", parm = "beta_"),
                 error = function(e) NULL)
  if (!is.null(ci)) {
    ci_df <- as.data.frame(ci) |> tibble::rownames_to_column("term") |>
      as_tibble() |> rename(ci_lo = `2.5 %`, ci_hi = `97.5 %`)
    fe <- left_join(fe, ci_df, by = "term")
  }
  row <- fe |> filter(str_detect(term, target_term)) |> slice(1)
  r2  <- tryCatch(performance::r2(model), error = function(e) NULL)
  r2m <- if (!is.null(r2)) as.numeric(r2$R2_marginal)    else NA_real_
  r2c <- if (!is.null(r2)) as.numeric(r2$R2_conditional) else NA_real_
  f2  <- if (!is.na(r2m) && r2m < 1) r2m / (1 - r2m)      else NA_real_
  tibble(
    term     = row$term  %||% NA_character_,
    estimate = row$estimate %||% NA_real_,
    se       = row$se       %||% NA_real_,
    df       = row$df       %||% NA_real_,
    statistic = row$statistic %||% NA_real_,
    ci_lo    = row$ci_lo    %||% NA_real_,
    ci_hi    = row$ci_hi    %||% NA_real_,
    p_value  = row$p_value  %||% NA_real_,
    r2_marg  = r2m,
    r2_cond  = r2c,
    f2       = f2
  )
}

# ---- All fixed effects of an LMM (used for the multi-predictor model) ------
lmm_fixed_table <- function(model, drop_intercept = TRUE) {
  co <- summary(model)$coefficients |>
    as.data.frame() |>
    tibble::rownames_to_column("term") |>
    as_tibble() |>
    rename(estimate = Estimate, se = `Std. Error`,
           df = df, statistic = `t value`, p_value = `Pr(>|t|)`)
  ci <- tryCatch(confint(model, method = "Wald", parm = "beta_"),
                 error = function(e) NULL)
  if (!is.null(ci)) {
    ci_df <- as.data.frame(ci) |> tibble::rownames_to_column("term") |>
      as_tibble() |> rename(ci_lo = `2.5 %`, ci_hi = `97.5 %`)
    co <- left_join(co, ci_df, by = "term")
  } else {
    co$ci_lo <- NA_real_; co$ci_hi <- NA_real_
  }
  if (drop_intercept) co <- co |> filter(term != "(Intercept)")
  co
}

# ---- Standardised mean-difference (Cohen's d) for a two-group LMM ----------
lmm_cohens_d <- function(model, spec = "stim_group", ref = "P") {
  out <- tibble(d = NA_real_, d_lo = NA_real_, d_hi = NA_real_)
  es_df <- tryCatch({
    emm <- emmeans::emmeans(model, specs = spec)
    # Total SD = sqrt of all variance components (observer + video + residual),
    # so d is comparable to a conventional Cohen's d rather than inflated by the
    # residual SD alone.
    vc  <- as.data.frame(lme4::VarCorr(model))
    sig <- sqrt(sum(vc$vcov[is.na(vc$var2)]))
    edf <- tryCatch(stats::df.residual(model), error = function(e) Inf)
    as.data.frame(emmeans::eff_size(emm, sigma = sig, edf = edf))
  }, error = function(e) NULL)
  if (is.null(es_df) || nrow(es_df) == 0) return(out)

  lo_col <- intersect(c("lower.CL", "asymp.LCL"), names(es_df))[1]
  hi_col <- intersect(c("upper.CL", "asymp.UCL"), names(es_df))[1]
  con <- as.character(es_df$contrast[1])
  d   <- es_df$effect.size[1]
  lo  <- es_df[[lo_col]][1]
  hi  <- es_df[[hi_col]][1]

  if (grepl(paste0("^\\s*", ref, "\\b"), con)) {
    d_new  <- -d; lo_new <- -hi; hi_new <- -lo
    d <- d_new; lo <- lo_new; hi <- hi_new
  }
  tibble(d = d, d_lo = lo, d_hi = hi)
}

run_lmm_set <- function(data, outcomes, fixed_term, target_term,
                        bh_correction = TRUE, save_diagnostics = TRUE,
                        diag_dir = RESULTS_H1, diag_prefix = "diag") {
  res <- map_dfr(outcomes, function(out) {
    m  <- fit_lmm(data, out, fixed_term)
    if (save_diagnostics) {
      dp <- file.path(diag_dir,
                      sprintf("%s_%s.png", diag_prefix, out))
      tryCatch({
        g <- performance::check_model(m)
        ggsave(dp, g, width = 10, height = 8, dpi = 200, bg = "white")
      }, error = function(e) NULL)
    }
    bind_cols(tibble(outcome = out),
              extract_lmm_results(m, target_term))
  })
  if (bh_correction)
    res$p_value_BH <- p.adjust(res$p_value, method = "BH")
  res
}

# ---- Spearman with Fisher-z 95 % CI ----------------------------------------
spearman_with_ci <- function(x, y) {
  d <- tibble(x = x, y = y) |> tidyr::drop_na()
  n <- nrow(d)
  if (n < 4) return(tibble(n = n, rho = NA_real_, ci_lo = NA_real_,
                           ci_hi = NA_real_, p_value = NA_real_))
  ct <- suppressWarnings(cor.test(d$x, d$y, method = "spearman",
                                  exact = FALSE))
  r <- unname(ct$estimate)
  z <- atanh(r); se <- 1 / sqrt(n - 3)
  lo <- tanh(z - 1.96 * se); hi <- tanh(z + 1.96 * se)
  tibble(n = n, rho = r, ci_lo = lo, ci_hi = hi, p_value = ct$p.value)
}

spearman_multi <- function(data, y, xs, bh_correction = TRUE) {
  res <- map_dfr(xs, function(x_var) {
    out <- spearman_with_ci(data[[x_var]], data[[y]])
    bind_cols(tibble(y = y, x = x_var), out)
  })
  if (bh_correction)
    res$p_value_BH <- p.adjust(res$p_value, method = "BH")
  res
}

# ============================================================================
# LMM diagnostics and random-effect helpers
# ============================================================================

# ---- Numerical assumption checks for an lmer model -------------------------
# Returns residual normality (Shapiro), homoscedasticity (auxiliary
# Breusch-Pagan-type regression of squared residuals on fitted values),
# random-effect BLUP normality, singularity and convergence flags.
check_lmm_assumptions <- function(model) {
  res <- stats::residuals(model)
  fit <- stats::fitted(model)

  shap_res <- tryCatch(
    if (length(res) >= 3 && length(res) <= 5000)
      shapiro.test(res)$p.value else NA_real_,
    error = function(e) NA_real_)

  # Breusch-Pagan-type homoscedasticity test
  bp_p <- tryCatch({
    aux <- stats::lm(I(res^2) ~ fit)
    fst <- summary(aux)$fstatistic
    if (!is.null(fst))
      stats::pf(fst[1], fst[2], fst[3], lower.tail = FALSE) else NA_real_
  }, error = function(e) NA_real_)
  bp_p <- unname(bp_p)

  re <- tryCatch(lme4::ranef(model), error = function(e) NULL)
  shap_re <- list()
  if (!is.null(re)) {
    for (g in names(re)) {
      b <- re[[g]][[1]]
      shap_re[[g]] <- tryCatch(
        if (length(b) >= 3 && length(b) <= 5000)
          shapiro.test(b)$p.value else NA_real_,
        error = function(e) NA_real_)
    }
  }

  singular <- tryCatch(lme4::isSingular(model), error = function(e) NA)
  conv_msgs <- tryCatch(model@optinfo$conv$lme4$messages,
                        error = function(e) NULL)
  non_conv  <- !is.null(conv_msgs) && length(conv_msgs) > 0

  list(
    resid_normal_p    = shap_res,
    homosced_p        = bp_p,
    homosced_violated = !is.na(bp_p) && bp_p < 0.05,
    re_normal_p       = shap_re,
    singular          = isTRUE(singular),
    non_convergence   = non_conv
  )
}

# ---- One formatted diagnostics row -----------------------------------------
fmt_diag_row <- function(diag, label_value, label_name = "Model") {
  re_obs <- diag$re_normal_p[["obs_id"]] %||% NA_real_
  re_vid <- diag$re_normal_p[["vid"]]    %||% NA_real_
  flag <- function(p) ifelse(is.na(p), "?", ifelse(p > 0.05, "ok", "!"))
  summary_code <- paste(c(
    paste0("R:", flag(diag$resid_normal_p)),
    paste0("H:", flag(diag$homosced_p)),
    paste0("RE-obs:", flag(re_obs)),
    paste0("RE-vid:", flag(re_vid)),
    if (isTRUE(diag$singular))        "singular"  else NULL,
    if (isTRUE(diag$non_convergence)) "non-conv." else NULL
  ), collapse = "; ")
  tibble::tibble(
    !!label_name := label_value,
    `Residual normality (Shapiro p)` = fmt_p(diag$resid_normal_p),
    `Homoscedasticity (BP p)`        = fmt_p(diag$homosced_p),
    `RE obs normality (p)`           = fmt_p(re_obs),
    `RE vid normality (p)`           = fmt_p(re_vid),
    `Summary`                        = summary_code
  )
}

# ---- Random-effect variance partition --------------------------------------
# Variance and SD of each random intercept and of the residual, plus the
# proportion of the total (residual + random) variance they each capture.
re_variance_table <- function(model) {
  vc <- as.data.frame(lme4::VarCorr(model))
  vc <- vc[is.na(vc$var2), , drop = FALSE]      # keep variances, drop covariances
  total <- sum(vc$vcov)
  tibble::tibble(
    grp      = vc$grp,
    Component = ifelse(vc$grp == "Residual", "Residual (within-evaluation)",
                       paste0(vc$grp, " (random intercept)")),
    Variance = vc$vcov,
    SD       = vc$sdcor,
    prop     = vc$vcov / total
  )
}

# Formatted RE-variance flextable for a single model, with ICC + R2 context.
fmt_re_table <- function(model, title, footnote = NULL) {
  rv <- re_variance_table(model)
  icc <- sum(rv$prop[rv$grp != "Residual"])
  r2  <- tryCatch(performance::r2(model), error = function(e) NULL)
  r2m <- if (!is.null(r2)) as.numeric(r2$R2_marginal)    else NA_real_
  r2c <- if (!is.null(r2)) as.numeric(r2$R2_conditional) else NA_real_

  disp <- rv |>
    transmute(
      `Random component`               = Component,
      Variance                         = fmt_num(Variance, 3),
      SD                               = fmt_num(SD, 3),
      `% of residual+random variance`  = sprintf("%.1f%%", prop * 100)
    )

  fn <- c(
    sprintf(paste0("ICC = %.3f: proportion of the residual (unexplained) ",
                   "variance captured jointly by the observer and video ",
                   "random intercepts."), icc),
    sprintf(paste0("Marginal R2 = %s (fixed effects); conditional R2 = %s ",
                   "(fixed + random). The random structure adds %s of ",
                   "explained variance beyond the fixed effects."),
            fmt_num(r2m, 3), fmt_num(r2c, 3), fmt_num(r2c - r2m, 3))
  )
  if (!is.null(footnote)) fn <- c(footnote, fn)
  plos_table(disp, title = title, footnote = fn)
}

# Compact one-row RE summary for sets of models (e.g. the 10 items).
re_proportions_row <- function(model, label, label_name = "Model") {
  rv <- re_variance_table(model)
  getp <- function(g) {
    v <- rv$prop[rv$grp == g]; if (length(v)) v[1] else NA_real_
  }
  obs_p <- getp("obs_id"); vid_p <- getp("vid"); res_p <- getp("Residual")
  tibble::tibble(
    !!label_name := label,
    `Observer var (%)` = sprintf("%.1f%%", obs_p * 100),
    `Video var (%)`    = sprintf("%.1f%%", vid_p * 100),
    `Residual var (%)` = sprintf("%.1f%%", res_p * 100),
    `ICC`              = fmt_num(obs_p + vid_p, 3)
  )
}

# ---- Sample-size / model-fit line for article-ready reporting ---------------
# Returns "N = n evaluations from k observers and m videos. AIC = ...; BIC = ..."
model_info_line <- function(model) {
  mf <- stats::model.frame(model)
  ng <- tryCatch(lme4::ngrps(model), error = function(e) c(obs_id = NA, vid = NA))
  n_obs_id <- if ("obs_id" %in% names(ng)) unname(ng["obs_id"]) else NA
  n_vid    <- if ("vid"    %in% names(ng)) unname(ng["vid"])    else NA
  sprintf(paste0("N = %d evaluations from %s observers and %s videos. ",
                 "AIC = %s; BIC = %s; REML deviance = %s."),
          nrow(mf), n_obs_id, n_vid,
          fmt_num(stats::AIC(model), 1), fmt_num(stats::BIC(model), 1),
          fmt_num(as.numeric(-2 * as.numeric(stats::logLik(model))), 1))
}

# ---- Cluster bootstrap for heteroscedasticity-robust LMM inference ----------
# Resamples whole clusters (stimuli / vid) with replacement and refits the
# model, giving robust SEs, percentile CIs and p-values. Works with CROSSED
# random effects (unlike CR2 sandwich estimators, which require nesting).
# Resampled clusters are relabelled so repeated draws form distinct RE levels.
cluster_bootstrap_lmm <- function(model, cluster = "vid", B = 1000, seed = 1) {
  set.seed(seed)
  data <- stats::model.frame(model)
  form <- stats::formula(model)
  if (!cluster %in% names(data)) return(NULL)

  idx_by   <- split(seq_len(nrow(data)), data[[cluster]])
  clusters <- names(idx_by)
  nclus    <- length(clusters)
  fe0      <- lme4::fixef(model)
  terms    <- names(fe0)
  boot     <- matrix(NA_real_, B, length(terms), dimnames = list(NULL, terms))
  ctrl     <- lme4::lmerControl(check.conv.singular = "ignore",
                                calc.derivs = FALSE)

  for (b in seq_len(B)) {
    samp <- sample(clusters, nclus, replace = TRUE)
    lens <- lengths(idx_by[samp])
    newd <- data[unlist(idx_by[samp], use.names = FALSE), , drop = FALSE]
    newd[[cluster]] <- factor(rep(seq_len(nclus), times = lens))  # distinct draws
    fit <- tryCatch(suppressWarnings(suppressMessages(
      lme4::lmer(form, data = newd, REML = TRUE, control = ctrl))),
      error = function(e) NULL)
    if (!is.null(fit)) {
      fb <- lme4::fixef(fit)
      boot[b, names(fb)] <- fb
    }
  }

  qs <- apply(boot, 2, stats::quantile, probs = c(.025, .975), na.rm = TRUE)
  tibble::tibble(
    term     = terms,
    estimate = unname(fe0[terms]),
    boot_se  = apply(boot, 2, stats::sd, na.rm = TRUE),
    ci_lo    = qs[1, ],
    ci_hi    = qs[2, ],
    p_value  = vapply(terms, function(tn) {
      v <- boot[, tn]; v <- v[!is.na(v)]
      if (!length(v)) NA_real_ else min(1, 2 * min(mean(v <= 0), mean(v >= 0)))
    }, numeric(1)),
    n_boot   = colSums(!is.na(boot))
  )
}
