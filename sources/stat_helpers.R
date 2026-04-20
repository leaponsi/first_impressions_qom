safe_sum <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  sum(x, na.rm = TRUE)
}


compute_cliffs_delta <- function(x, y) {
  x <- x[!is.na(x)]
  y <- y[!is.na(y)]
  if (length(x) == 0 || length(y) == 0) return(NA_real_)
  mean(outer(x, y, FUN = function(a, b) sign(a - b)))
}

label_cliffs_delta <- function(delta) {
  if (is.na(delta)) return(NA_character_)
  a <- abs(delta)
  dplyr::case_when(
    a < 0.147 ~ "negligible",
    a < 0.330 ~ "small",
    a < 0.474 ~ "medium",
    TRUE      ~ "large"
  )
}

extract_fixed_effects <- function(model, model_name) {
  coef(summary(model)) |>
    as.data.frame() |>
    tibble::rownames_to_column("Predictor") |>
    dplyr::rename(SE = `Std. Error`, t = `t value`, p = `Pr(>|t|)`) |>
    dplyr::mutate(Model = model_name) |>
    dplyr::select(Model, Predictor, Estimate, SE, df, t, p)
}
