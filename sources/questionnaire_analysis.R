extract_participant_id <- function(video_name) {
  stringr::str_extract(video_name, "(P|SZ)\\d+")
}

# Build total scores (Bizarre is reversed first so every item goes in the
# same direction), extract the stimulus participant id from the video name,
# and set factor levels for the categorical variables used in the models.
prepare_questionnaire_scores <- function(data) {
  data |>
    dplyr::mutate(
      Bizarre_inversed = 102 - Bizarre,
      FirstImpression_total   = Sympathique + Bizarre_inversed + Intelligente +
        Appreciable + Confiance + Dominante,
      InteractionIntent_total = Conversation + Temps + Voisin + Assis,
      Global_total            = FirstImpression_total + InteractionIntent_total,
      participant_id = extract_participant_id(vid),
      CASE     = factor(CASE),
      video_id = factor(vid),
      Type     = factor(Type, levels = c("Healthy", "Patient"))
    )
}
