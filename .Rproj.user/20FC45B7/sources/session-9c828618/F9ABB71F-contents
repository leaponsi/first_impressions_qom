################################################################################
#################### First impression - stimulus participant ###################
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

### Open the function 
source(file.path(LIB_PATH, "open_open_face.R"))

### Define participants' id 
participant_id_range_scz = c("P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10", "P11", "P12", "P13", "P14", "P15", "P16", "P17", "P18", "P19", "P20")
participant_id_range_hc = c("H1", "H2", "H3", "H4","H5", "H6", "H7", "H8", "H9", "H10","H11", "H12", "H13", "H14", "H15", "H16", "H17", "H18", "H19", "H20")

### Open csv files OF using the function open_open_face.R
file_list_of = open_open_face(participant_id_range_scz, participant_id_range_hc)

### SCZ - file_list_of[[2]]
# Compute mean confidence score 
confidence_values_contagion_scz = c()

for (i in 1:length(file_list_of[[1]])) {
  if (!is.null(file_list_of[[1]][[i]]) && "confidence" %in% names(file_list_of[[1]][[i]])) {
    confidence_values_contagion_scz = c(confidence_values_contagion_scz, file_list_of[[1]][[i]]$confidence)
  }
}

mean_confidence_contagion_scz = mean(confidence_values_contagion_scz)
sd_confidence_contagion_scz = sd(confidence_values_contagion_scz)

# Empty list to initiate the loop 
au_values = list(
  AU01_r = numeric(),
  AU02_r = numeric(),
  AU04_r = numeric(),
  AU05_r = numeric(),
  AU06_r = numeric(),
  AU07_r = numeric(),
  AU09_r = numeric(),
  AU10_r = numeric(),
  AU12_r = numeric(),
  AU14_r = numeric(),
  AU15_r = numeric(),
  AU17_r = numeric(),
  AU20_r = numeric(),
  AU23_r = numeric(),
  AU25_r = numeric(),
  AU26_r = numeric(),
  AU45_r = numeric(),
  expressivity_pos = numeric()
)

# Data frame to store the data
result_scz = data.frame(
  CASE = numeric(), 
  mean_AU01_r = numeric(),
  mean_AU02_r = numeric(),
  mean_AU04_r = numeric(),
  mean_AU05_r = numeric(),
  mean_AU06_r = numeric(),
  mean_AU07_r = numeric(),
  mean_AU09_r = numeric(),
  mean_AU10_r = numeric(),
  mean_AU12_r = numeric(),
  mean_AU14_r = numeric(),
  mean_AU15_r = numeric(),
  mean_AU17_r = numeric(),
  mean_AU20_r = numeric(),
  mean_AU23_r = numeric(),
  mean_AU25_r = numeric(),
  mean_AU26_r = numeric(),
  mean_AU45_r = numeric(),
  mean_expressivity_pos = numeric()
)

# Initiate the loop 
for (i in 1:length(file_list_of[[1]])) {
  # Mean score for each AU
  au_values$AU01_r[i] = mean(file_list_of[[1]][[i]]$AU01_r, na.rm = TRUE)
  au_values$AU02_r[i] = mean(file_list_of[[1]][[i]]$AU02_r, na.rm = TRUE)
  au_values$AU04_r[i] = mean(file_list_of[[1]][[i]]$AU04_r, na.rm = TRUE)
  au_values$AU05_r[i] = mean(file_list_of[[1]][[i]]$AU05_r, na.rm = TRUE)
  au_values$AU06_r[i] = mean(file_list_of[[1]][[i]]$AU06_r, na.rm = TRUE)
  au_values$AU07_r[i] = mean(file_list_of[[1]][[i]]$AU07_r, na.rm = TRUE)
  au_values$AU09_r[i] = mean(file_list_of[[1]][[i]]$AU09_r, na.rm = TRUE)
  au_values$AU10_r[i] = mean(file_list_of[[1]][[i]]$AU10_r, na.rm = TRUE)
  au_values$AU12_r[i] = mean(file_list_of[[1]][[i]]$AU12_r, na.rm = TRUE)
  au_values$AU14_r[i] = mean(file_list_of[[1]][[i]]$AU14_r, na.rm = TRUE)
  au_values$AU15_r[i] = mean(file_list_of[[1]][[i]]$AU15_r, na.rm = TRUE)
  au_values$AU17_r[i] = mean(file_list_of[[1]][[i]]$AU17_r, na.rm = TRUE)
  au_values$AU20_r[i] = mean(file_list_of[[1]][[i]]$AU20_r, na.rm = TRUE)
  au_values$AU23_r[i] = mean(file_list_of[[1]][[i]]$AU23_r, na.rm = TRUE)
  au_values$AU25_r[i] = mean(file_list_of[[1]][[i]]$AU25_r, na.rm = TRUE)
  au_values$AU26_r[i] = mean(file_list_of[[1]][[i]]$AU26_r, na.rm = TRUE)
  au_values$AU45_r[i] = mean(file_list_of[[1]][[i]]$AU45_r, na.rm = TRUE)
  
  # Positive expressivity
  expressivity_pos_value = mean((file_list_of[[1]][[i]]$AU06_r + file_list_of[[1]][[i]]$AU12_r) / 2 - file_list_of[[1]][[i]]$AU04_r, na.rm = TRUE)
  
  # Add into the dataframe
  result_scz = rbind(result_scz, data.frame(
    CASE = participant_id_range_scz[i],
    mean_AU01_r = au_values$AU01_r[i],
    mean_AU02_r = au_values$AU02_r[i],
    mean_AU04_r = au_values$AU04_r[i],
    mean_AU05_r = au_values$AU05_r[i],
    mean_AU06_r = au_values$AU06_r[i],
    mean_AU07_r = au_values$AU07_r[i],
    mean_AU09_r = au_values$AU09_r[i],
    mean_AU10_r = au_values$AU10_r[i],
    mean_AU12_r = au_values$AU12_r[i],
    mean_AU14_r = au_values$AU14_r[i],
    mean_AU15_r = au_values$AU15_r[i],
    mean_AU17_r = au_values$AU17_r[i],
    mean_AU20_r = au_values$AU20_r[i],
    mean_AU23_r = au_values$AU23_r[i],
    mean_AU25_r = au_values$AU25_r[i],
    mean_AU26_r = au_values$AU26_r[i],
    mean_AU45_r = au_values$AU45_r[i],
    mean_expressivity_pos = expressivity_pos_value
  ))
}

### Healthy - file_list_of[[1]]
# Similar modifications for the Healthy data
confidence_values_contagion_hc = c()

for (i in 1:length(file_list_of[[2]])) {
  if (!is.null(file_list_of[[2]][[i]]) && "confidence" %in% names(file_list_of[[2]][[i]])) {
    confidence_values_contagion_hc = c(confidence_values_contagion_hc, file_list_of[[2]][[i]]$confidence)
  }
}

mean_confidence_contagion_hc = mean(confidence_values_contagion_hc)
sd_confidence_contagion_hc = sd(confidence_values_contagion_hc)

# Empty list to initiate the loop 
au_values = list(
  AU01_r = numeric(),
  AU02_r = numeric(),
  AU04_r = numeric(),
  AU05_r = numeric(),
  AU06_r = numeric(),
  AU07_r = numeric(),
  AU09_r = numeric(),
  AU10_r = numeric(),
  AU12_r = numeric(),
  AU14_r = numeric(),
  AU15_r = numeric(),
  AU17_r = numeric(),
  AU20_r = numeric(),
  AU23_r = numeric(),
  AU25_r = numeric(),
  AU26_r = numeric(),
  AU45_r = numeric(),
  expressivity_pos = numeric()
)

# Data frame to store the data
result_hc = data.frame(
  CASE = numeric(), 
  mean_AU01_r = numeric(),
  mean_AU02_r = numeric(),
  mean_AU04_r = numeric(),
  mean_AU05_r = numeric(),
  mean_AU06_r = numeric(),
  mean_AU07_r = numeric(),
  mean_AU09_r = numeric(),
  mean_AU10_r = numeric(),
  mean_AU12_r = numeric(),
  mean_AU14_r = numeric(),
  mean_AU15_r = numeric(),
  mean_AU17_r = numeric(),
  mean_AU20_r = numeric(),
  mean_AU23_r = numeric(),
  mean_AU25_r = numeric(),
  mean_AU26_r = numeric(),
  mean_AU45_r = numeric(),
  mean_expressivity_pos = numeric()
)

# Initiate the loop 
for (i in 1:length(file_list_of[[2]])) {
  # Score of each AU
  au_values$AU01_r[i] = mean(file_list_of[[2]][[i]]$AU01_r, na.rm = TRUE)
  au_values$AU02_r[i] = mean(file_list_of[[2]][[i]]$AU02_r, na.rm = TRUE)
  au_values$AU04_r[i] = mean(file_list_of[[2]][[i]]$AU04_r, na.rm = TRUE)
  au_values$AU05_r[i] = mean(file_list_of[[2]][[i]]$AU05_r, na.rm = TRUE)
  au_values$AU06_r[i] = mean(file_list_of[[2]][[i]]$AU06_r, na.rm = TRUE)
  au_values$AU07_r[i] = mean(file_list_of[[2]][[i]]$AU07_r, na.rm = TRUE)
  au_values$AU09_r[i] = mean(file_list_of[[2]][[i]]$AU09_r, na.rm = TRUE)
  au_values$AU10_r[i] = mean(file_list_of[[2]][[i]]$AU10_r, na.rm = TRUE)
  au_values$AU12_r[i] = mean(file_list_of[[2]][[i]]$AU12_r, na.rm = TRUE)
  au_values$AU14_r[i] = mean(file_list_of[[2]][[i]]$AU14_r, na.rm = TRUE)
  au_values$AU15_r[i] = mean(file_list_of[[2]][[i]]$AU15_r, na.rm = TRUE)
  au_values$AU17_r[i] = mean(file_list_of[[2]][[i]]$AU17_r, na.rm = TRUE)
  au_values$AU20_r[i] = mean(file_list_of[[2]][[i]]$AU20_r, na.rm = TRUE)
  au_values$AU23_r[i] = mean(file_list_of[[2]][[i]]$AU23_r, na.rm = TRUE)
  au_values$AU25_r[i] = mean(file_list_of[[2]][[i]]$AU25_r, na.rm = TRUE)
  au_values$AU26_r[i] = mean(file_list_of[[2]][[i]]$AU26_r, na.rm = TRUE)
  au_values$AU45_r[i] = mean(file_list_of[[2]][[i]]$AU45_r, na.rm = TRUE)
  
  # Positive expressivity
  expressivity_pos_value = mean((file_list_of[[2]][[i]]$AU06_r + file_list_of[[2]][[i]]$AU12_r) / 2 - file_list_of[[2]][[i]]$AU12_r, na.rm = TRUE)
  
  # Add into the dataframe
  result_hc = rbind(result_hc, data.frame(
    CASE = participant_id_range_hc[i],
    mean_AU01_r = au_values$AU01_r[i],
    mean_AU02_r = au_values$AU02_r[i],
    mean_AU04_r = au_values$AU04_r[i],
    mean_AU05_r = au_values$AU05_r[i],
    mean_AU06_r = au_values$AU06_r[i],
    mean_AU07_r = au_values$AU07_r[i],
    mean_AU09_r = au_values$AU09_r[i],
    mean_AU10_r = au_values$AU10_r[i],
    mean_AU12_r = au_values$AU12_r[i],
    mean_AU14_r = au_values$AU14_r[i],
    mean_AU15_r = au_values$AU15_r[i],
    mean_AU17_r = au_values$AU17_r[i],
    mean_AU20_r = au_values$AU20_r[i],
    mean_AU23_r = au_values$AU23_r[i],
    mean_AU25_r = au_values$AU25_r[i],
    mean_AU26_r = au_values$AU26_r[i],
    mean_AU45_r = au_values$AU45_r[i],
    mean_expressivity_pos = expressivity_pos_value
  ))
}

######################## Save for statistical analyses #########################
setwd(RES_PATH)
file_name = paste0("result_hc", ".rdata")
save(result_hc, file = file_name)
file_name = paste0("result_scz", ".rdata")
save(result_scz, file = file_name)
