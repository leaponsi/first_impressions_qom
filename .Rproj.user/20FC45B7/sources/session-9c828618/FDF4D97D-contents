# =============================================================================
# load_data.R — Load and prepare all data for R analyses
#
# Produces three data frames used by all subsequent scripts:
#   df_metrics      : one row per stimulus participant (40 rows)
#                     movement metrics from Python pipeline
#   df_observers    : one row per observer x video (long format)
#                     first impression scores, condition 1 only
#   df_stimulus     : one row per stimulus participant (40 rows)
#                     mean first impression scores joined with movement metrics
# =============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)

# Project root (works from any script sourced via main.Rmd)
ROOT         <- here::here()
DATA_PATH    <- file.path(ROOT, "data")
RESULTS_PATH <- file.path(ROOT, "results")

# =============================================================================
# 1. MOVEMENT METRICS (from Python pipeline)
# =============================================================================

df_metrics <- read.csv(file.path(RESULTS_PATH, "metrics.csv"),
                       stringsAsFactors = FALSE)

df_metrics <- df_metrics %>%
  mutate(
    group          = as.factor(group),
    participant_id = as.character(participant_id)
  )

cat("df_metrics loaded:", nrow(df_metrics), "participants\n")
cat("Groups:", table(df_metrics$group), "\n")

# =============================================================================
# 2. FIRST IMPRESSIONS — CONDITION 1 ONLY (no diagnostic label)
# =============================================================================

data_raw <- read_xlsx(file.path(DATA_PATH, "data_1st_imp.xlsx"))

# Remove observers who failed the attention check
data_raw <- data_raw %>%
  filter(AC03_01 > 90)

cat("Observers retained after attention check:", nrow(data_raw), "\n")

# --- Reshape to long format: one row per observer x video ---
n_videos <- 10

df_observers <- data.frame(matrix(ncol = 0, nrow = nrow(data_raw) * n_videos))

# Observer metadata
df_observers$CASE      <- rep(data_raw$CASE, each = n_videos)
df_observers$Age       <- rep(data_raw$DE03x01, each = n_videos)
df_observers$Gender    <- rep(ifelse(data_raw$DE08 == 1, "F", "M"), each = n_videos)
df_observers$num_video <- rep(1:n_videos, times = nrow(data_raw))

# Video identity
vid_cols             <- grep("VI03_", colnames(data_raw))
df_observers$vid     <- as.vector(t(data_raw[, vid_cols]))

# Extract participant_id from filename (e.g. "Video_SZ2.mp4" → "SZ2")
df_observers <- df_observers %>%
  mutate(
    participant_id = str_extract(vid, "(?<=Video_)[A-Za-z0-9]+(?=\\.mp4)")
  )

# Stimulus type (SZ or P)
df_observers$Type <- ifelse(
  grepl("Video_P", df_observers$vid), "HC", "SZ"
)

# --- First impression items ---
im_columns <- list(
  Attractive    = c("IM01_01","IM07_01","IM13_01","IM19_01","IM25_01",
                    "IM31_01","IM37_01","IM43_01","IM49_01","IM55_01"),
  Awkward       = c("IM02_01","IM08_01","IM14_01","IM20_01","IM26_01",
                    "IM32_01","IM38_01","IM44_01","IM50_01","IM56_01"),
  Intelligent   = c("IM03_01","IM09_01","IM15_01","IM21_01","IM27_01",
                    "IM33_01","IM39_01","IM45_01","IM51_01","IM57_01"),
  Likeable      = c("IM04_01","IM10_01","IM16_01","IM22_01","IM28_01",
                    "IM34_01","IM40_01","IM46_01","IM52_01","IM58_01"),
  Trustworthy   = c("IM05_01","IM11_01","IM17_01","IM23_01","IM29_01",
                    "IM35_01","IM41_01","IM47_01","IM53_01","IM59_01"),
  Dominant      = c("IM06_01","IM12_01","IM18_01","IM24_01","IM30_01",
                    "IM36_01","IM42_01","IM48_01","IM54_01","IM60_01")
)

for (col in names(im_columns)) {
  df_observers[[col]] <- as.vector(t(data_raw[, im_columns[[col]]]))
}

# --- Behavioral intention items ---
bi_columns <- list(
  Conversation = c("BI01_01","BI05_01","BI09_01","BI13_01","BI17_01",
                   "BI21_01","BI25_01","BI29_01","BI33_01","BI37_01"),
  Time         = c("BI02_01","BI06_01","BI10_01","BI14_01","BI18_01",
                   "BI22_01","BI26_01","BI30_01","BI34_01","BI38_01"),
  LiveNearby   = c("BI03_01","BI07_01","BI11_01","BI15_01","BI19_01",
                   "BI23_01","BI27_01","BI31_01","BI35_01","BI39_01"),
  SitNext      = c("BI04_01","BI08_01","BI12_01","BI16_01","BI20_01",
                   "BI24_01","BI28_01","BI32_01","BI36_01","BI40_01")
)

for (col in names(bi_columns)) {
  df_observers[[col]] <- as.vector(t(data_raw[, bi_columns[[col]]]))
}

# --- Composite scores ---
# Awkward is reversed (higher = less awkward = more positive)
df_observers <- df_observers %>%
  mutate(
    Awkward_r        = 102 - Awkward,
    Score_impression = Attractive + Awkward_r + Intelligent + Likeable +
      Trustworthy + Dominant,
    Score_intention  = Conversation + Time + LiveNearby + SitNext,
    Total_score      = Score_impression + Score_intention
  )

# Factor conversions
df_observers <- df_observers %>%
  mutate(
    CASE           = as.factor(CASE),
    Type           = as.factor(Type),
    participant_id = as.character(participant_id),
    num_video      = as.numeric(num_video)
  )

cat("df_observers ready:", nrow(df_observers), "rows\n")

# =============================================================================
# 3. STIMULUS-LEVEL DATA: mean scores per video + movement metrics
# =============================================================================

# All items for stimulus-level aggregation
all_items <- c("Attractive", "Awkward_r", "Intelligent", "Likeable",
               "Trustworthy", "Dominant",
               "Conversation", "Time", "LiveNearby", "SitNext",
               "Score_impression", "Score_intention", "Total_score")

df_stimulus <- df_observers %>%
  group_by(participant_id, Type) %>%
  summarise(across(all_of(all_items), mean, na.rm = TRUE),
            n_observers = n(),
            .groups = "drop")

# Join with movement metrics
df_stimulus <- df_stimulus %>%
  left_join(df_metrics, by = "participant_id")

cat("df_stimulus ready:", nrow(df_stimulus), "rows\n")
cat("Matched with metrics:", sum(!is.na(df_stimulus$n_frames)), "/ ", nrow(df_stimulus), "\n")
