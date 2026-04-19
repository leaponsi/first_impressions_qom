# Libraries
library(dplyr)

#' Organize and Reshape Questionnaire Data
#'
#' Cleans raw questionnaire data by filtering on attention check (AC03_01 > 90),
#' then reshapes it from wide format (1 row per observer) to long format
#' (1 row per observer × video). Extracts impression ratings, behavioral intentions,
#' and computes total scores.
#'
#' @param data Raw questionnaire data (from data_1st_imp.xlsx)
#'
#' @return data.frame in long format with columns:
#'   - CASE: observer ID
#'   - Age, Gender, Pro_Sante: observer demographics
#'   - vid: video filename
#'   - num_video: video number (1-10)
#'   - Type: "Healthy" or "Patient" (stimulus participant type)
#'   - Impression ratings: Sympathique, Bizarre, Intelligente, etc.
#'   - Behavioral intentions: Conversation, Temps, Voisin, Assis
#'   - Derived: Bizarre_inversed, Total_score
organize_data <- function(data) {
  # Filter on attention check: only observers with AC03_01 > 90
  data <- data |>
    dplyr::filter(AC03_01 > 90)

  n_videos <- 10

  result <- data.frame(matrix(ncol = 0, nrow = nrow(data) * n_videos))

  # Observer demographic information
  result$CASE <- rep(data$CASE, each = n_videos)
  result$Age <- rep(as.numeric(data$DE03x01), each = n_videos)
  result$Gender <- rep(ifelse(data$DE08 == 1, "F", "M"), each = n_videos)
  result$Pro_Sante <- rep(data$DE12, each = n_videos)

  # Video column extraction and numbering
  vid_cols <- grep("VI03_", colnames(data))
  result$vid <- as.vector(t(data[, vid_cols]))
  result$num_video <- rep(1:n_videos, times = nrow(data))

  # Stimulus participant type (extracted from video name)
  result$Type <- ifelse(grepl("Video_P", result$vid), "Healthy", "Patient")

  # Impression ratings (6 dimensions)
  im_columns <- list(
    Sympathique = c("IM01_01","IM07_01","IM13_01","IM19_01","IM25_01","IM31_01","IM37_01","IM43_01","IM49_01","IM55_01"),
    Bizarre = c("IM02_01","IM08_01","IM14_01","IM20_01","IM26_01","IM32_01","IM38_01","IM44_01","IM50_01","IM56_01"),
    Intelligente = c("IM03_01","IM09_01","IM15_01","IM21_01","IM27_01","IM33_01","IM39_01","IM45_01","IM51_01","IM57_01"),
    Appreciable = c("IM04_01","IM10_01","IM16_01","IM22_01","IM28_01","IM34_01","IM40_01","IM46_01","IM52_01","IM58_01"),
    Confiance = c("IM05_01","IM11_01","IM17_01","IM23_01","IM29_01","IM35_01","IM41_01","IM47_01","IM53_01","IM59_01"),
    Dominante = c("IM06_01","IM12_01","IM18_01","IM24_01","IM30_01","IM36_01","IM42_01","IM48_01","IM54_01","IM60_01")
  )
  
  for (col in names(im_columns)) {
    result[[col]] <- as.vector(t(data[, im_columns[[col]]]))
  }

  # Behavioral intentions (4 dimensions)
  bi_columns <- list(
    Conversation = c("BI01_01","BI05_01","BI09_01","BI13_01","BI17_01","BI21_01","BI25_01","BI29_01","BI33_01","BI37_01"),
    Temps = c("BI02_01","BI06_01","BI10_01","BI14_01","BI18_01","BI22_01","BI26_01","BI30_01","BI34_01","BI38_01"),
    Voisin = c("BI03_01","BI07_01","BI11_01","BI15_01","BI19_01","BI23_01","BI27_01","BI31_01","BI35_01","BI39_01"),
    Assis = c("BI04_01","BI08_01","BI12_01","BI16_01","BI20_01","BI24_01","BI28_01","BI32_01","BI36_01","BI40_01")
  )

  for (col in names(bi_columns)) {
    result[[col]] <- as.vector(t(data[, bi_columns[[col]]]))
  }

  # Compute derived scores: "Bizarre" is inverted (102 - value) to align with other positive impressions
  # Total score combines all impression and behavioral dimensions
  result <- result |>
    dplyr::mutate(
      Bizarre_inversed = 102 - Bizarre,
      Total_score = Sympathique + Bizarre_inversed + Intelligente + Appreciable +
        Confiance + Dominante + Conversation + Temps + Voisin + Assis
    )

  return(result)
}
