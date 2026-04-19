#' Extract Stimulus Participant ID from Video Filename
#'
#' Extracts the participant ID (e.g., "P12", "SZ05") from a video filename
#' using regex pattern matching.
#'
#' @param video_name Character string with video filename
#'
#' @return Character string with participant ID (e.g., "P12", "SZ05")
extract_participant_id <- function(video_name) {
  stringr::str_extract(video_name, "(P|SZ)\\d+")
}

#' Compute Impression and Interaction Intent Scores
#'
#' Calculates total scores from questionnaire items:
#' - FirstImpression_total: sum of 6 impression dimensions (Bizarre is inverted first)
#' - InteractionIntent_total: sum of 4 behavioral intention items
#' - Global_total: sum of both components
#' Also extracts participant ID from video name and converts factors as needed.
#'
#' @param data Data frame with column "vid" (video name) and questionnaire items
#'
#' @return Data frame with added computed scores and factors
prepare_questionnaire_scores <- function(data) {
  data |>
    dplyr::mutate(
      Bizarre_inversed = 102 - Bizarre,
      FirstImpression_total = Sympathique + Bizarre_inversed + Intelligente +
        Appreciable + Confiance + Dominante,
      InteractionIntent_total = Conversation + Temps + Voisin + Assis,
      Global_total = FirstImpression_total + InteractionIntent_total,
      participant_id = extract_participant_id(vid),
      CASE = factor(CASE),
      video_id = factor(vid),
      Type = factor(Type, levels = c("Healthy", "Patient"))
    )
}
