# =============================================================================
# config.py — Centralized project configuration (Python pipeline only)
# Movement analysis: SZ vs controls (P)
#
# This is the only file to modify if paths or parameters change.
# All other Python scripts import it via: from sources.config import *
#
# Note: R analyses use their own path management (see main.Rmd / load_data.R)
# =============================================================================

import os

# =============================================================================
# 1. PATHS
# =============================================================================

# Project root: parent folder of this file (sources/)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Data folders
DATA_DIR = os.path.join(ROOT, "data")
DATA_SZ  = os.path.join(DATA_DIR, "SZ")  # schizophrenia stimuli
DATA_P   = os.path.join(DATA_DIR, "P")   # control stimuli

# Output folder and main output file
RESULTS_DIR  = os.path.join(ROOT, "results")
FILE_METRICS = os.path.join(RESULTS_DIR, "metrics.csv")

# Create results/ folder if it does not exist
os.makedirs(RESULTS_DIR, exist_ok=True)

# =============================================================================
# 2. GROUPS AND FILE NAMING
# =============================================================================

# Group → folder and file prefix mapping
GROUPS = {
    "SZ": {"dir": DATA_SZ, "prefix": "SZ"},
    "P":  {"dir": DATA_P,  "prefix": "P"},
}

# Glob pattern to find all POSE files across both groups
# Usage: glob.glob(POSE_GLOB)
POSE_GLOB = os.path.join(DATA_DIR, "*/landmarks_*_POSE.csv")

# =============================================================================
# 3. LOW-PASS FILTER PARAMETERS
# =============================================================================

CUTOFF = 5    # cutoff frequency (Hz) — removes noise above 5 Hz
FS     = 30   # sampling frequency (fps) — video recorded at 30 frames/sec

# Filter order passed to scipy's butter().
# Note: filtfilt() applies the filter twice (forward + backward pass) to
# achieve zero phase shift, which effectively doubles the order.
# ORDER = 2 here produces an effective 4th-order filter.
ORDER  = 2

# =============================================================================
# 4. MOVEMENT SIGNALS TO COMPUTE
# =============================================================================

# Reference list of all expected signals per participant.
# A missing signal (absent landmark) will be marked NA in the output CSV.
ALL_SIGNAL_NAMES = [
    "left_hand_vertical",
    "right_hand_vertical",
    "left_hand_horizontal",
    "right_hand_horizontal",
    "swaying",
    "sideways",
    "head_horizontal",
    "head_vertical",
    "left_foot_horizontal",
    "right_foot_horizontal",
]

# =============================================================================
# 5. MEDIAPIPE LANDMARK INDEX → NAME MAPPING
# =============================================================================

LM = {
    0:  "nose",
    1:  "left_eye_inner",  2:  "left_eye",  3:  "left_eye_outer",
    4:  "right_eye_inner", 5:  "right_eye", 6:  "right_eye_outer",
    7:  "left_ear",        8:  "right_ear",
    9:  "mouth_left",      10: "mouth_right",
    11: "left_shoulder",   12: "right_shoulder",
    13: "left_elbow",      14: "right_elbow",
    15: "left_wrist",      16: "right_wrist",
    17: "left_pinky",      18: "right_pinky",
    19: "left_index",      20: "right_index",
    21: "left_thumb",      22: "right_thumb",
    23: "left_hip",        24: "right_hip",
    25: "left_knee",       26: "right_knee",
    27: "left_ankle",      28: "right_ankle",
    29: "left_heel",       30: "right_heel",
    31: "left_foot_index", 32: "right_foot_index",
}