# =============================================================================
# preprocessing.py — Signal preprocessing functions
# Movement analysis: SZ vs controls (P)
#
# Functions covered:
#   1. parse_participant_info() — extract group and ID from filename
#   2. build_wide_df()         — reshape long CSV to wide format
#   3. safe_signal()           — compute a relative signal, returns None if
#                                any landmark column is missing
#   4. build_signals()         — compute all 10 movement signals
#   5. lowpass_filter()        — Butterworth low-pass filter (via filtfilt)
#   6. preprocess_signals()    — interpolate → filter → center all signals
# =============================================================================

import os
import re
import numpy as np
import pandas as pd
from scipy.signal import butter, filtfilt

from config import LM, ALL_SIGNAL_NAMES, CUTOFF, FS, ORDER


# =============================================================================
# 1. PARTICIPANT INFO
# =============================================================================

def parse_participant_info(filepath):
    """
    Extract group and participant ID from a POSE filename.

    Expected format: landmarks_<GROUP><ID>_POSE.csv
    Examples:
        landmarks_SZ4_POSE.csv  → {group: "SZ", participant: "4", participant_id: "SZ4"}
        landmarks_P12_POSE.csv  → {group: "P",  participant: "12", participant_id: "P12"}

    Parameters
    ----------
    filepath : str
        Full or relative path to the CSV file.

    Returns
    -------
    dict with keys: group, participant, participant_id

    Raises
    ------
    ValueError if the filename does not match the expected pattern.
    """
    fname = os.path.basename(filepath)
    match = re.match(r"landmarks_([A-Za-z]+)(\d+)_POSE\.csv", fname)
    if not match:
        raise ValueError(f"Unexpected filename format: {fname}")
    return {
        "group":          match.group(1),
        "participant":    match.group(2),
        "participant_id": match.group(1) + match.group(2),
    }


# =============================================================================
# 2. WIDE DATAFRAME
# =============================================================================

def build_wide_df(df_long):
    """
    Reshape the long-format CSV (one row per landmark per frame) into a
    wide-format DataFrame (one row per frame, columns = landmark coordinates).
    Also computes derived anatomical reference points.

    Derived points (only if the required landmarks are present):
        mid_shoulders : midpoint between left and right shoulder
        mid_hips      : midpoint between left and right hip
        torso_center  : midpoint between mid_shoulders and mid_hips
        image_center  : fixed point at (0.5, 0.5) — normalized image center

    Parameters
    ----------
    df_long : pd.DataFrame
        Raw CSV loaded with pd.read_csv(). Must contain columns:
        'frame', 'index', 'x', 'y', 'z'.

    Returns
    -------
    pd.DataFrame in wide format with one row per frame.
    """
    df_long = df_long.copy()
    df_long["lm"] = df_long["index"].map(LM)

    df_w = df_long.pivot(index="frame", columns="lm", values=["x", "y", "z"])
    df_w.columns = [f"{b}_{a}" for a, b in df_w.columns]
    df_w = df_w.reset_index()

    # Midpoint between shoulders (x and y)
    if all(c in df_w.columns for c in ["left_shoulder_x", "right_shoulder_x",
                                        "left_shoulder_y", "right_shoulder_y"]):
        df_w["mid_shoulders_x"] = (df_w["left_shoulder_x"] + df_w["right_shoulder_x"]) / 2
        df_w["mid_shoulders_y"] = (df_w["left_shoulder_y"] + df_w["right_shoulder_y"]) / 2

    # Midpoint between hips (x and y)
    if all(c in df_w.columns for c in ["left_hip_x", "right_hip_x",
                                        "left_hip_y", "right_hip_y"]):
        df_w["mid_hips_x"] = (df_w["left_hip_x"] + df_w["right_hip_x"]) / 2
        df_w["mid_hips_y"] = (df_w["left_hip_y"] + df_w["right_hip_y"]) / 2

    # Torso center: midpoint between mid_shoulders and mid_hips
    if all(c in df_w.columns for c in ["mid_shoulders_x", "mid_hips_x",
                                        "mid_shoulders_y", "mid_hips_y"]):
        df_w["torso_center_x"] = (df_w["mid_shoulders_x"] + df_w["mid_hips_x"]) / 2
        df_w["torso_center_y"] = (df_w["mid_shoulders_y"] + df_w["mid_hips_y"]) / 2

    # Fixed image center reference (normalized coordinates: 0 to 1)
    df_w["image_center_x"] = 0.5
    df_w["image_center_y"] = 0.5

    return df_w


# =============================================================================
# 3. SAFE SIGNAL
# =============================================================================

def safe_signal(df, col_a, col_b):
    """
    Compute col_a - col_b if both columns exist in df, otherwise return None.

    This prevents KeyError crashes when a participant has missing landmarks.
    The calling function (build_signals) silently skips None signals.

    Parameters
    ----------
    df : pd.DataFrame
        Wide-format DataFrame (output of build_wide_df).
    col_a : str
        Name of the first column (minuend).
    col_b : str
        Name of the second column (subtrahend).

    Returns
    -------
    pd.Series or None
    """
    if col_a in df.columns and col_b in df.columns:
        return df[col_a] - df[col_b]
    return None


# =============================================================================
# 4. BUILD SIGNALS
# =============================================================================

def build_signals(df_w):
    """
    Compute all 10 body-relative movement signals from the wide DataFrame.

    Each signal is a relative distance between two anatomical points,
    making the values independent of the participant's position in the frame.

    Signals computed:
        left/right_hand_vertical   : wrist y − shoulder y
        left/right_hand_horizontal : wrist x − shoulder x
        swaying                    : mid_shoulders x − mid_hips x
        sideways                   : torso_center x − image_center x
        head_horizontal            : nose x − mid_shoulders x
        head_vertical              : nose y − mid_shoulders y
        left/right_foot_horizontal : foot_index x − image_center x

    Parameters
    ----------
    df_w : pd.DataFrame
        Wide-format DataFrame (output of build_wide_df).

    Returns
    -------
    dict {signal_name: pd.Series}
        Only signals for which both landmark columns exist are included.
        Missing signals are silently omitted (logged by the batch pipeline).
    """
    candidates = {
        "left_hand_vertical":    ("left_wrist_y",       "left_shoulder_y"),
        "right_hand_vertical":   ("right_wrist_y",      "right_shoulder_y"),
        "left_hand_horizontal":  ("left_wrist_x",       "left_shoulder_x"),
        "right_hand_horizontal": ("right_wrist_x",      "right_shoulder_x"),
        "swaying":               ("mid_shoulders_x",    "mid_hips_x"),
        "sideways":              ("torso_center_x",     "image_center_x"),
        "head_horizontal":       ("nose_x",             "mid_shoulders_x"),
        "head_vertical":         ("nose_y",             "mid_shoulders_y"),
        "left_foot_horizontal":  ("left_foot_index_x",  "image_center_x"),
        "right_foot_horizontal": ("right_foot_index_x", "image_center_x"),
    }

    signals = {}
    for name, (col_a, col_b) in candidates.items():
        s = safe_signal(df_w, col_a, col_b)
        if s is not None:
            signals[name] = s

    return signals


# =============================================================================
# 5. LOW-PASS FILTER
# =============================================================================

def lowpass_filter(data, cutoff=CUTOFF, fs=FS, order=ORDER):
    """
    Apply a zero-phase Butterworth low-pass filter to a 1D signal.

    Uses scipy's filtfilt(), which applies the filter forward then backward
    to eliminate phase distortion. This doubles the effective filter order:
    the ORDER parameter in config.py is set to 2 to achieve an effective
    4th-order filter.

    Parameters
    ----------
    data : array-like
        Input signal (1D).
    cutoff : float
        Cutoff frequency in Hz (default: CUTOFF from config).
    fs : float
        Sampling frequency in Hz (default: FS from config).
    order : int
        Filter order passed to butter() — effective order is 2× this value
        due to filtfilt() (default: ORDER from config).

    Returns
    -------
    np.ndarray
        Filtered signal, same length as input.

    Raises
    ------
    ValueError if cutoff is not strictly between 0 and fs/2.
    """
    data = np.asarray(data, dtype=float)
    nyquist = 0.5 * fs
    normalized_cutoff = cutoff / nyquist

    if not 0 < normalized_cutoff < 1:
        raise ValueError(
            f"cutoff ({cutoff} Hz) must be strictly between 0 and fs/2 ({nyquist} Hz)."
        )

    b, a = butter(N=order, Wn=normalized_cutoff, btype="low", analog=False)
    return filtfilt(b, a, data)


# =============================================================================
# 6. SHOULDER WIDTH NORMALIZATION
# =============================================================================

def normalize_signals(signals, df_w):
    """
    Divide all signals by the participant's shoulder width.

    Why normalize by shoulder width:
        MediaPipe coordinates are normalized to [0, 1] relative to the image
        frame. A participant filmed close to the camera occupies more of the
        image than one filmed farther away, so the same physical gesture
        produces different numerical values depending on camera distance.
        Dividing by shoulder width converts signals from "normalized pixels"
        to "proportion of shoulder width", making values comparable across
        participants regardless of filming distance.

    Why the median and not the mean:
        MediaPipe occasionally produces outlier detections on individual frames.
        The median is robust to these outliers — a handful of bad frames do not
        distort the estimate, whereas the mean would be pulled toward them.

    Parameters
    ----------
    signals : dict {str: pd.Series}
        Raw signals (output of build_signals).
    df_w : pd.DataFrame
        Wide-format DataFrame (output of build_wide_df).

    Returns
    -------
    dict {str: pd.Series}
        Signals divided by shoulder width.
        If shoulder columns are missing, signals are returned unchanged
        (shoulder_width defaults to 1.0 — no normalization applied).
    """
    if "left_shoulder_x" in df_w.columns and "right_shoulder_x" in df_w.columns:
        shoulder_width = (df_w["left_shoulder_x"] - df_w["right_shoulder_x"]).abs().median()
        if shoulder_width <= 0:
            shoulder_width = 1.0
    else:
        shoulder_width = 1.0

    return {name: s / shoulder_width for name, s in signals.items()}


# =============================================================================
# 7. PREPROCESS SIGNALS
# =============================================================================

def preprocess_signals(signals):
    """
    Apply the full preprocessing pipeline to all available signals:
        1. Interpolate missing values (linear), then forward/backward fill
           edge NaNs that interpolation cannot handle.
        2. Apply the low-pass filter (lowpass_filter).
        3. Center by subtracting the signal mean, removing the static
           postural offset and keeping only oscillations around zero.

    Call normalize_signals() before this function to express signals in
    units of shoulder width.

    Parameters
    ----------
    signals : dict {str: pd.Series}
        Signals to preprocess (typically the output of normalize_signals).

    Returns
    -------
    dict {str: np.ndarray}
        Preprocessed signals, ready for extrema detection and metric
        computation.
    """
    result = {}
    for name, s in signals.items():
        s_interp   = s.interpolate().bfill().ffill()
        s_filtered = lowpass_filter(s_interp)
        s_centered = s_filtered - np.mean(s_filtered)
        result[name] = s_centered
    return result