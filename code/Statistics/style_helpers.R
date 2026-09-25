# =============================================================================
# style_helpers.R
#
# Presentation / formatting helpers shared by 03_statistical_analysis.Rmd:
# colours, labels, number/CI formatting, the PLOS-One-style ggplot theme and
# flextable style, and the save_table()/save_figure() writers.
#
# This file is meant to be the one you edit often: journal styling (colours,
# fonts, table look), display labels, and *where* a given table/figure gets
# written (via the `outdir` argument of save_table()/save_figure()) all live
# here or are passed in from the calling chunk. The statistical analyses
# themselves (model fitting, bootstrap, diagnostics) live in
# 03_statistical_analysis.Rmd and should not need to change when this file
# changes.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(stringr); library(ggplot2)
  library(flextable); library(officer)
})

# ---- Colours (PLOS-One-style figures) --------------------------------------
GROUP_COLOURS <- c(
  "P"  = "#f6a7a7",   # healthy controls - pink
  "SZ" = "#9caffe"    # patients          - blue
)

# ---- Display labels for the movement features -------------------------------
MOVEMENT_LABELS <- c(
  move_hands_horizontal_qom_rate = "Hands, horizontal (QoM)",
  move_hands_vertical_qom_rate   = "Hands, vertical (QoM)",
  move_head_horizontal_qom_rate  = "Head, horizontal (QoM)",
  move_head_vertical_qom_rate    = "Head, vertical (QoM)"
)

# ---- p-values (APA-style, 3 decimals, "<.001" when very small) -------------
fmt_p <- function(p, digits = 3) {
  vapply(p, function(x) {
    if (is.na(x))     return("—")
    if (x < 0.001)    return("<.001")
    sub("^0", "", sprintf(paste0("%.", digits, "f"), x))
  }, character(1))
}

# ---- Generic numbers --------------------------------------------------------
fmt_num <- function(x, digits = 2) {
  ifelse(is.na(x), "—", sprintf(paste0("%.", digits, "f"), x))
}

# ---- 95 % CI ----------------------------------------------------------------
fmt_ci <- function(lo, hi, digits = 2) {
  ifelse(is.na(lo) | is.na(hi), "—",
         sprintf("[%s, %s]", fmt_num(lo, digits), fmt_num(hi, digits)))
}

# ---- mean (SD) per SAMPL ----------------------------------------------------
fmt_msd <- function(m, s, digits = 2) {
  ifelse(is.na(m), "—",
         sprintf("%s (%s)", fmt_num(m, digits), fmt_num(s, digits)))
}

# ---- median [Q1, Q3] for non-normal data ------------------------------------
fmt_med_iqr <- function(x, digits = 2) {
  if (all(is.na(x))) return("—")
  q <- quantile(x, c(0.25, 0.5, 0.75), na.rm = TRUE)
  sprintf("%s [%s, %s]",
          fmt_num(q[2], digits), fmt_num(q[1], digits), fmt_num(q[3], digits))
}

# ---- Normalise emmeans CI column names (version-proof) ----------------------
normalize_emm_ci <- function(df) {
  nms <- names(df)
  if ("asymp.LCL" %in% nms && !"lower.CL" %in% nms) df$lower.CL <- df$asymp.LCL
  if ("asymp.UCL" %in% nms && !"upper.CL" %in% nms) df$upper.CL <- df$asymp.UCL
  df
}

# ---- Significance stars (used only inside figures, not in tables) ----------
p_stars <- function(p) {
  dplyr::case_when(
    is.na(p)   ~ "",
    p < 0.001  ~ "***",
    p < 0.01   ~ "**",
    p < 0.05   ~ "*",
    TRUE       ~ "ns"
  )
}

# ---- Strip the move_ / imp_ / stim_ prefix for display ---------------------
pretty_label <- function(x) {
  out <- ifelse(x %in% names(MOVEMENT_LABELS),
                unname(MOVEMENT_LABELS[x]),
                NA_character_)
  generic <- x %>%
    stringr::str_remove("^(move_|imp_|stim_)") %>%
    stringr::str_replace_all("_", " ") %>%
    stringr::str_to_sentence()
  ifelse(is.na(out), generic, out)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# ---- PLOS-One-style minimal theme ------------------------------------------
theme_plos <- function(base_size = 11, base_family = "") {
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.3),
      axis.line.x        = element_line(colour = "grey25", linewidth = 0.4),
      axis.line.y        = element_line(colour = "grey25", linewidth = 0.4),
      axis.ticks         = element_line(colour = "grey25", linewidth = 0.3),
      axis.title         = element_text(size = base_size, colour = "grey15"),
      axis.text          = element_text(colour = "grey20", size = base_size - 1),
      plot.title         = element_text(size = base_size + 1, hjust = 0,
                                        colour = "grey10", margin = margin(b = 6)),
      plot.subtitle      = element_text(size = base_size - 1, hjust = 0,
                                        colour = "grey35", margin = margin(b = 8)),
      plot.caption       = element_text(size = base_size - 2, hjust = 0,
                                        colour = "grey30", lineheight = 1.2,
                                        margin = margin(t = 8)),
      strip.background   = element_rect(fill = "white", colour = NA),
      strip.text         = element_text(face = "bold", size = base_size,
                                        colour = "grey15"),
      legend.position    = "bottom",
      legend.title       = element_text(size = base_size - 1),
      legend.text        = element_text(size = base_size - 1),
      plot.background    = element_rect(fill = "white", colour = NA),
      panel.background   = element_rect(fill = "white", colour = NA),
      plot.margin        = margin(10, 12, 10, 10)
    )
}

# ---- Save TIFF + PNG (PLOS One: TIFF 300 dpi for submission) ---------------
# `outdir` is the results subfolder for this specific figure (e.g. the H1,
# H2, H3, H4, descriptive or supplementary folder) - passed explicitly by the
# calling chunk in 03_statistical_analysis.Rmd, since where each figure lands
# depends on which hypothesis/section it belongs to.
save_figure <- function(plot, basename, outdir, width = 5.2, height = 4.2, dpi = 300) {
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  tiff_path <- file.path(outdir, paste0(basename, ".tif"))
  png_path  <- file.path(outdir, paste0(basename, ".png"))
  ggsave(tiff_path, plot = plot, width = width, height = height,
         dpi = dpi, compression = "lzw", bg = "white")
  ggsave(png_path,  plot = plot, width = width, height = height,
         dpi = dpi, bg = "white")
  message("Saved: ", tiff_path, " and ", png_path)
  invisible(c(tiff = tiff_path, png = png_path))
}

# ---- Add significance bracket above two bars -------------------------------
add_signif_bracket <- function(p, x1, x2, y_top, p_value,
                               tick_height_ratio = 0.02,
                               star_size = 4.5) {
  star <- p_stars(p_value)
  y_drop <- y_top * (1 - tick_height_ratio)
  y_star <- y_top * 1.012
  p +
    annotate("segment", x = x1,   xend = x2, y = y_top, yend = y_top,
             colour = "grey20", linewidth = 0.4) +
    annotate("segment", x = x1,   xend = x1, y = y_top, yend = y_drop,
             colour = "grey20", linewidth = 0.4) +
    annotate("segment", x = x2,   xend = x2, y = y_top, yend = y_drop,
             colour = "grey20", linewidth = 0.4) +
    annotate("text",    x = (x1 + x2) / 2, y = y_star, label = star,
             size = star_size, vjust = 0, colour = "grey10")
}

# ---- PLOS-One-style flextable: bold title above, footnote(s) below ---------
plos_table <- function(df, title, footnote = NULL,
                       digits_cols = NULL) {
  ft <- flextable::flextable(df) |>
    flextable::theme_booktabs(bold_header = TRUE) |>
    flextable::set_caption(caption = title,
                           autonum  = officer::run_autonum(
                             seq_id  = "tab", pre_label = "Table ",
                             post_label = ". ", bkm = "table")) |>
    flextable::font(fontname = "Calibri", part = "all") |>
    flextable::fontsize(size = 10, part = "all") |>
    flextable::fontsize(size = 10, part = "header") |>
    flextable::bold(part = "header") |>
    flextable::align(align = "left",   part = "header") |>
    flextable::align(align = "center", part = "body") |>
    flextable::align(j = 1, align = "left", part = "all") |>
    flextable::padding(padding = 4, part = "all") |>
    flextable::border_inner_h(border = officer::fp_border(color = "grey85", width = 0.5)) |>
    flextable::hline_top(border    = officer::fp_border(color = "grey25", width = 1.2),
                         part = "header") |>
    flextable::hline_bottom(border = officer::fp_border(color = "grey25", width = 1.2),
                            part = "header") |>
    flextable::hline_bottom(border = officer::fp_border(color = "grey25", width = 1.2),
                            part = "body")

  if (!is.null(digits_cols)) {
    for (col in names(digits_cols)) {
      if (col %in% names(df))
        ft <- flextable::colformat_double(ft, j = col,
                                          digits = digits_cols[[col]])
    }
  }
  if (!is.null(footnote)) {
    ft <- flextable::add_footer_lines(ft, values = footnote)
    ft <- flextable::italic(ft, italic = TRUE, part = "footer")
    ft <- flextable::fontsize(ft, size = 9, part = "footer")
  }
  flextable::autofit(ft)
}

# ---- Export a flextable to .docx (PLOS expects cell-based Word tables) -----
# `outdir` is the results subfolder for this specific table - see save_figure().
save_table <- function(ft, basename, outdir) {
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  doc_path  <- file.path(outdir, paste0(basename, ".docx"))
  flextable::save_as_docx(ft, path = doc_path)
  invisible(doc_path)
}
