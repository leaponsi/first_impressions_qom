read_stimuli_participants <- function(path = "../data/stimuli_participants.csv") {
  readr::read_delim(
    path,
    delim = ";",
    show_col_types = FALSE,
    name_repair = "unique"
  ) |>
    dplyr::transmute(
      participant_id = Participant,
      stimuli_group = Group,
      stimuli_type = dplyr::case_when(
        Group == "CT" ~ "Healthy",
        Group == "SZ" ~ "Patient",
        TRUE ~ as.character(Group)
      ),
      stimuli_genre = Genre,
      stimuli_age = as.numeric(Age),
      stimuli_education = as.numeric(Education)
    ) |>
    dplyr::mutate(
      stimuli_group = factor(stimuli_group, levels = c("CT", "SZ")),
      stimuli_genre = factor(stimuli_genre)
    )
}

build_stimuli_descriptives <- function(stimuli_info) {
  stimuli_info |>
    dplyr::group_by(stimuli_group) |>
    dplyr::summarise(
      n = dplyr::n(),
      mean_age = mean(stimuli_age, na.rm = TRUE),
      sd_age = sd(stimuli_age, na.rm = TRUE),
      mean_education = mean(stimuli_education, na.rm = TRUE),
      sd_education = sd(stimuli_education, na.rm = TRUE),
      female_n = sum(stimuli_genre == "F", na.rm = TRUE),
      male_n = sum(stimuli_genre == "H", na.rm = TRUE),
      .groups = "drop"
    )
}

build_stimuli_manip_check <- function(stimuli_info) {
  dplyr::bind_rows(
    compare_continuous_groups(stimuli_info, "stimuli_age", "stimuli_group"),
    compare_continuous_groups(stimuli_info, "stimuli_education", "stimuli_group"),
    compare_categorical_groups(stimuli_info, "stimuli_genre", "stimuli_group")
  ) |>
    dplyr::mutate(
      variable = dplyr::recode(
        variable,
        stimuli_age = "Age",
        stimuli_education = "Education",
        stimuli_genre = "Gender"
      )
    )
}
