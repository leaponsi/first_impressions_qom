################################################################################
######################## First impression - questionnaire 2 ####################
################################################################################

### Library
library(readxl)
library(dplyr)
library(stringr)
library(openxlsx)
library(tidyr)
library(ggplot2)

### Set directory 
PRG_PATH = dirname(rstudioapi::getSourceEditorContext()$path) 
PATH = dirname(PRG_PATH)
DAT_PATH = file.path(PATH, "DAT")
LIB_PATH = file.path(PRG_PATH, "LIB")
RES_PATH = file.path(PATH, "RES")

### Open the file 
PATH = file.path(DAT_PATH, "data_questionnaire_2.xlsx")
data = read_xlsx(PATH)

#################### Step 1 - organize questionnaire data ######################
### Result file 
n_videos = 10
result_1st_imp_2 = data.frame(matrix(ncol = 0, nrow = nrow(data) * n_videos))

# Descriptive
result_1st_imp_2$CASE = rep(data$CASE, each = n_videos)
result_1st_imp_2$Age = rep(data$DE03x01, each = n_videos)
result_1st_imp_2$Gender = rep(ifelse(data$DE08 == 1, "F", "H"), each = n_videos)

# Video
vid_cols = grep("VI03_", colnames(data)) 
result_1st_imp_2$vid = as.vector(t(data[, vid_cols]))

# Num
result_1st_imp_2$num_video = rep(1:n_videos, times = nrow(data))

# Type 
result_1st_imp_2$Type = ifelse(substr(result_1st_imp_2$vid, 1, 1) == "P", "Patient", "Healthy")

# CAMI
# Higher score indicates more stigmatizing attitudes
cami_scores = rowSums(data[, grep("C201_", colnames(data))], na.rm = TRUE)
result_1st_imp_2$CAMI = rep(cami_scores, each = n_videos)
rm(cami_scores)

# MAKS
# Higher score better knowledge 
maks_score_1 = rowSums(data[, grep("MA01_", colnames(data))], na.rm = TRUE)
result_1st_imp_2$MAKS_1 = rep(maks_score_1, each = n_videos)
rm(maks_score_1)

result_1st_imp_2$depression_maks = rep(data$MA02_05, each = n_videos)
result_1st_imp_2$schizophrenie_maks = rep(data$MA02_06, each = n_videos)
result_1st_imp_2$bipolaire_maks = rep(data$MA02_07, each = n_videos)
result_1st_imp_2$dependance_maks = rep(data$MA02_08, each = n_videos)

# RIBS
# 4 = score minimum (0 everywhere) / 8 = score maximum --> higher score = more contact 
RIBS_1_scores = rowSums(data[, grep("RI01_", colnames(data))], na.rm = TRUE)
result_1st_imp_2$contact_RIBS = rep(RIBS_1_scores, each = n_videos)
# higher score more positive intention
RIBS_2_scores = rowSums(data[, grep("RI02_", colnames(data))], na.rm = TRUE)
result_1st_imp_2$intention_RIBS = rep(RIBS_2_scores, each = n_videos)
rm(RIBS_1_scores, RIBS_2_scores)

# 1st imp 
im_columns = list(
  Sympathique = c("IM01_01", "IM07_01", "IM13_01", "IM19_01", "IM25_01", "IM31_01", "IM37_01", "IM43_01", "IM49_01", "IM55_01"),
  Bizarre = c("IM02_01", "IM08_01", "IM14_01", "IM20_01", "IM26_01", "IM32_01", "IM38_01", "IM44_01", "IM50_01", "IM56_01"),
  Intelligente = c("IM03_01", "IM09_01", "IM15_01", "IM21_01", "IM27_01", "IM33_01", "IM39_01", "IM45_01", "IM51_01", "IM57_01"),
  Appreciable = c("IM04_01", "IM10_01", "IM16_01", "IM22_01", "IM28_01", "IM34_01", "IM40_01", "IM46_01", "IM52_01", "IM58_01"),
  Confiance = c("IM05_01", "IM11_01", "IM17_01", "IM23_01", "IM29_01", "IM35_01", "IM41_01", "IM47_01", "IM53_01", "IM59_01"),
  Dominante = c("IM06_01", "IM12_01", "IM18_01", "IM24_01", "IM30_01", "IM36_01", "IM42_01", "IM48_01", "IM54_01", "IM60_01")
)

for (col in names(im_columns)) {
  result_1st_imp_2[[col]] <- as.vector(t(data[, im_columns[[col]]]))
}

rm(im_columns)

# Behavioral intention 
bi_columns = list(
  Conversation = c("BI01_01", "BI05_01", "BI09_01", "BI13_01", "BI17_01", "BI21_01", "BI25_01", "BI29_01", "BI33_01", "BI37_01"),
  Temps = c("BI02_01", "BI06_01", "BI10_01", "BI14_01", "BI18_01", "BI22_01", "BI26_01", "BI30_01", "BI34_01", "BI38_01"),
  Voisin = c("BI03_01", "BI07_01", "BI11_01", "BI15_01", "BI19_01", "BI23_01", "BI27_01", "BI31_01", "BI35_01", "BI39_01"),
  Assis = c("BI04_01", "BI08_01", "BI12_01", "BI16_01", "BI20_01", "BI24_01", "BI28_01", "BI32_01", "BI36_01", "BI40_01")
)

for (col in names(bi_columns)) {
  result_1st_imp_2[[col]] = as.vector(t(data[, bi_columns[[col]]]))
}

rm(bi_columns)

####################### Step 2 - Add stimuli information #######################

###Open the stimuli data 
PATH = file.path(DAT_PATH, "questionnaire.xlsx")
data_stimuli = read_xlsx(PATH)
setwd(RES_PATH)
load("result_hc.rdata")
load("result_scz.rdata")

### Add the stimuli info 
stimuli_id = sub("_.mp4$", "", result_1st_imp_2$vid)
stimuli_id = sub("_$", "", stimuli_id)

# Age
result_1st_imp_2$stimuli_age = data_stimuli$Age[match(stimuli_id, data_stimuli$ID)]

# Sexe
result_1st_imp_2$stimuli_sexe = data_stimuli$Sexe[match(stimuli_id, data_stimuli$ID)]

# Med 
result_1st_imp_2$stimuli_med = data_stimuli$`Med (mg)`[match(stimuli_id, data_stimuli$ID)]

# PANSS
result_1st_imp_2$stimuli_PANSS_1 = data_stimuli$Panss_1[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_1 = data_stimuli$Panss_1[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_2 = data_stimuli$Panss_2[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_3 = data_stimuli$Panss_3[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_4 = data_stimuli$Panss_4[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_5 = data_stimuli$Panss_5[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_6 = data_stimuli$Panss_6[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_7 = data_stimuli$Panss_7[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_8 = data_stimuli$Panss_8[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_9 = data_stimuli$Panss_9[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_10 = data_stimuli$Panss_10[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_11 = data_stimuli$Panss_11[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_12 = data_stimuli$Panss_12[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_13 = data_stimuli$Panss_13[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_14 = data_stimuli$Panss_14[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_15 = data_stimuli$Panss_15[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_16 = data_stimuli$Panss_16[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_17 = data_stimuli$Panss_17[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_18 = data_stimuli$Panss_18[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_19 = data_stimuli$Panss_19[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_20 = data_stimuli$Panss_20[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_21 = data_stimuli$Panss_21[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_22 = data_stimuli$Panss_22[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_23 = data_stimuli$Panss_23[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_24 = data_stimuli$Panss_24[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_25 = data_stimuli$Panss_25[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_26 = data_stimuli$Panss_26[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_27 = data_stimuli$Panss_27[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_28 = data_stimuli$Panss_28[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_29 = data_stimuli$Panss_29[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_30 = data_stimuli$Panss_30[match(stimuli_id, data_stimuli$ID)]

result_1st_imp_2$stimuli_PANSS_tot = data_stimuli$`PANSS TOT`[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_pos = data_stimuli$`PANSS +`[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_neg = data_stimuli$`PANSS -`[match(stimuli_id, data_stimuli$ID)]
result_1st_imp_2$stimuli_PANSS_gen = data_stimuli$`PANSS GEN`[match(stimuli_id, data_stimuli$ID)]

# Diagnostic length 
result_1st_imp_2$stimuli_diagnostic = data_stimuli$`Durée maladie`[match(stimuli_id, data_stimuli$ID)]

# Expensivity vertical & horizontal & expressivity 
expressivity_hc = data.frame(CASE = result_hc$CASE, mean_expressivity_pos = result_hc$mean_expressivity_pos)
expressivity_scz = data.frame(CASE = result_scz$CASE, mean_expressivity_pos = result_scz$mean_expressivity_pos)
expressivity = rbind(expressivity_hc, expressivity_scz)
rm(expressivity_hc, expressivity_scz)
result_1st_imp_2$stimuli_expressivity = expressivity$mean_expressivity_pos[match(stimuli_id, expressivity$CASE)]
rm(expressivity)

# AU : 
au_hc = data.frame(CASE = result_hc$CASE, 
                   mean_AU01_r = result_hc$mean_AU01_r, 
                   mean_AU02_r = result_hc$mean_AU02_r, 
                   mean_AU04_r = result_hc$mean_AU04_r, 
                   mean_AU05_r = result_hc$mean_AU05_r, 
                   mean_AU06_r = result_hc$mean_AU06_r, 
                   mean_AU07_r = result_hc$mean_AU07_r, 
                   mean_AU09_r = result_hc$mean_AU09_r, 
                   mean_AU10_r = result_hc$mean_AU10_r, 
                   mean_AU12_r = result_hc$mean_AU12_r, 
                   mean_AU14_r = result_hc$mean_AU14_r, 
                   mean_AU15_r = result_hc$mean_AU15_r, 
                   mean_AU17_r = result_hc$mean_AU17_r, 
                   mean_AU20_r = result_hc$mean_AU20_r, 
                   mean_AU23_r = result_hc$mean_AU23_r, 
                   mean_AU25_r = result_hc$mean_AU25_r, 
                   mean_AU26_r = result_hc$mean_AU26_r, 
                   mean_AU45_r = result_hc$mean_AU45_r)

au_scz = data.frame(CASE = result_scz$CASE, 
                    mean_AU01_r = result_scz$mean_AU01_r, 
                    mean_AU02_r = result_scz$mean_AU02_r, 
                    mean_AU04_r = result_scz$mean_AU04_r, 
                    mean_AU05_r = result_scz$mean_AU05_r, 
                    mean_AU06_r = result_scz$mean_AU06_r, 
                    mean_AU07_r = result_scz$mean_AU07_r, 
                    mean_AU09_r = result_scz$mean_AU09_r, 
                    mean_AU10_r = result_scz$mean_AU10_r, 
                    mean_AU12_r = result_scz$mean_AU12_r, 
                    mean_AU14_r = result_scz$mean_AU14_r, 
                    mean_AU15_r = result_scz$mean_AU15_r, 
                    mean_AU17_r = result_scz$mean_AU17_r, 
                    mean_AU20_r = result_scz$mean_AU20_r, 
                    mean_AU23_r = result_scz$mean_AU23_r, 
                    mean_AU25_r = result_scz$mean_AU25_r, 
                    mean_AU26_r = result_scz$mean_AU26_r, 
                    mean_AU45_r = result_scz$mean_AU45_r)

au_data = rbind(au_hc, au_scz)
rm(au_hc, au_scz)

result_1st_imp_2$stimuli_AU01_r = au_data$mean_AU01_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU02_r = au_data$mean_AU02_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU04_r = au_data$mean_AU04_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU05_r = au_data$mean_AU05_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU06_r = au_data$mean_AU06_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU07_r = au_data$mean_AU07_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU09_r = au_data$mean_AU09_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU10_r = au_data$mean_AU10_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU12_r = au_data$mean_AU12_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU14_r = au_data$mean_AU14_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU15_r = au_data$mean_AU15_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU17_r = au_data$mean_AU17_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU20_r = au_data$mean_AU20_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU23_r = au_data$mean_AU23_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU25_r = au_data$mean_AU25_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU26_r = au_data$mean_AU26_r[match(stimuli_id, au_data$CASE)]
result_1st_imp_2$stimuli_AU45_r = au_data$mean_AU45_r[match(stimuli_id, au_data$CASE)]

rm(au_data)

# as.numeric for age 
result_1st_imp_2$Age = as.numeric(result_1st_imp_2$Age)

### Save the file to RES_path 
setwd(RES_PATH)
file_name = paste0("result_1st_imp_2", ".rdata")
save(result_1st_imp_2, file = file_name)
