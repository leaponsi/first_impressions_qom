nice_table <- function(x, title = NULL, note = NULL) {
  caption <- if (is.null(title)) NULL else paste(title, collapse = " - ")
  knitr::kable(x, caption = caption)
}

safe_sum <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  sum(x, na.rm = TRUE)
}

compare_continuous_groups <- function(data, value_col, group_col) {
  df <- data |>
    dplyr::transmute(
      group = .data[[group_col]],
      value = as.numeric(.data[[value_col]])
    ) |>
    dplyr::filter(!is.na(group), !is.na(value))

  groups <- unique(as.character(df$group))
  g1 <- df$value[df$group == groups[1]]
  g2 <- df$value[df$group == groups[2]]

  shapiro_ok_g1 <- length(g1) >= 3 && stats::shapiro.test(g1)$p.value > .05
  shapiro_ok_g2 <- length(g2) >= 3 && stats::shapiro.test(g2)$p.value > .05
  levene_p <- tryCatch(
    car::leveneTest(value ~ group, data = df)$`Pr(>F)`[1],
    error = function(e) NA_real_
  )

  if (isTRUE(shapiro_ok_g1) && isTRUE(shapiro_ok_g2) && !is.na(levene_p) && levene_p > .05) {
    test_res <- stats::t.test(value ~ group, data = df, var.equal = TRUE)
    test_name <- "Student t-test"
    statistic <- unname(test_res$statistic)
  } else {
    test_res <- stats::wilcox.test(value ~ group, data = df, exact = FALSE)
    test_name <- "Wilcoxon rank-sum"
    statistic <- unname(test_res$statistic)
  }

  tibble::tibble(
    variable = value_col,
    test = test_name,
    group_1 = groups[1],
    n_1 = length(g1),
    mean_sd_1 = sprintf("%.2f (%.2f)", mean(g1), sd(g1)),
    median_1 = stats::median(g1),
    group_2 = groups[2],
    n_2 = length(g2),
    mean_sd_2 = sprintf("%.2f (%.2f)", mean(g2), sd(g2)),
    median_2 = stats::median(g2),
    statistic = statistic,
    p_value = test_res$p.value
  )
}

compare_categorical_groups <- function(data, value_col, group_col) {
  df <- data |>
    dplyr::transmute(
      group = .data[[group_col]],
      value = .data[[value_col]]
    ) |>
    dplyr::filter(!is.na(group), !is.na(value))

  tab <- table(df$group, df$value)
  test_res <- stats::fisher.test(tab)

  counts <- as.data.frame.matrix(tab) |>
    tibble::rownames_to_column("group")

  tibble::tibble(
    variable = value_col,
    test = "Fisher's exact test",
    group_1 = counts$group[1],
    counts_1 = paste(names(counts)[-1], as.integer(counts[1, -1]), collapse = "; "),
    group_2 = counts$group[2],
    counts_2 = paste(names(counts)[-1], as.integer(counts[2, -1]), collapse = "; "),
    statistic = NA_real_,
    p_value = test_res$p.value
  )
}

compute_cliffs_delta <- function(x, y) {
  x <- x[!is.na(x)]
  y <- y[!is.na(y)]

  if (length(x) == 0 || length(y) == 0) {
    return(NA_real_)
  }

  comparisons <- outer(x, y, FUN = function(a, b) sign(a - b))
  mean(comparisons)
}

label_cliffs_delta <- function(delta) {
  if (is.na(delta)) {
    return(NA_character_)
  }

  abs_delta <- abs(delta)
  dplyr::case_when(
    abs_delta < 0.147 ~ "negligible",
    abs_delta < 0.330 ~ "small",
    abs_delta < 0.474 ~ "medium",
    TRUE ~ "large"
  )
}

extract_fixed_effects <- function(model, model_name) {
  coef(summary(model)) |>
    as.data.frame() |>
    tibble::rownames_to_column("Predictor") |>
    dplyr::rename(
      SE = `Std. Error`,
      t = `t value`,
      p = `Pr(>|t|)`
    ) |>
    dplyr::mutate(Model = model_name) |>
    dplyr::select(Model, Predictor, Estimate, SE, df, t, p)
}
