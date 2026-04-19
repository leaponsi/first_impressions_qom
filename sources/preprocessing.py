"""
preprocessing.py
----------------

Reusable functions and constants for preprocessing MediaPipe pose CSV files
for the pons.lea project.

The pipeline is intentionally split into small, explicit functions so that
each step of the preprocessing notebook corresponds to one function call.
No classes, no nested functions: everything is flat and pedagogical.

Typical chronological use (see notebooks/preprocessing.ipynb):

    1.  list_participant_files   -> list CSV files in data/P and data/SZ
    2.  parse_participant_from_filename
    3.  read_long_csv            -> read one CSV in long format
    4.  build_long_dataframe     -> stack all participants in long format
    5.  invert_y_axis
    6.  interpolate_coordinates
    7.  long_to_wide
    8.  add_derived_points
    9.  compute_median_shoulder_width
    10. build_movement_signals
    11. normalize_movement_signals
    12. filter_movement_signals
    13. center_filtered_signals
    14. save_outputs
"""

from __future__ import annotations

import glob
import re
from pathlib import Path

import numpy as np
import pandas as pd

from scipy.signal import butter, filtfilt


# =============================================================================
# Constants
# =============================================================================

# MediaPipe Pose landmark dictionary (index -> human-readable name)
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

# Landmarks kept for preprocessing (x, y) -- trunk + head + hands
LANDMARKS_OF_INTEREST = [
    "nose",
    "left_shoulder", "right_shoulder",
    "left_wrist", "right_wrist",
    "left_hip", "right_hip",
]

# Names of the relative movement signals we compute
MOVEMENT_SIGNALS = [
    "left_hand_vertical", "right_hand_vertical",
    "left_hand_horizontal", "right_hand_horizontal",
    "swaying", "sideways",
    "head_horizontal", "head_vertical",
]

# Identity columns used across all output DataFrames
ID_COLS = ["group", "participant", "participant_id", "frame"]


# =============================================================================
# Step 2. File discovery and identity parsing
# =============================================================================

def list_participant_files(data_dir):
    """
    List all POSE CSV files inside data/P and data/SZ, sorted alphabetically.

    Parameters
    ----------
    data_dir : str or Path
        Path to the `data/` folder of the pons.lea project.

    Returns
    -------
    tuple (p_files, sz_files, all_files)
        Each element is a list of absolute file path strings.
    """
    data_dir = Path(data_dir)
    p_files = sorted(glob.glob(str(data_dir / "P" / "landmarks_*_POSE.csv")))
    sz_files = sorted(glob.glob(str(data_dir / "SZ" / "landmarks_*_POSE.csv")))
    all_files = p_files + sz_files
    return p_files, sz_files, all_files


def parse_participant_from_filename(filepath):
    """
    Extract participant identity from a MediaPipe pose CSV filename.

    Expected filename pattern: landmarks_<GROUP><NUMBER>_POSE.csv
    Example: landmarks_SZ12_POSE.csv -> group="SZ", participant=12, participant_id="SZ12"

    Parameters
    ----------
    filepath : str or Path
        Full path to the CSV file.

    Returns
    -------
    dict with keys: group, participant, participant_id
    """
    name = Path(filepath).stem  # e.g. "landmarks_SZ12_POSE"
    match = re.match(r"landmarks_(P|SZ)(\d+)_POSE", name)
    if match is None:
        raise ValueError(f"Filename does not match expected pattern: {name}")
    group = match.group(1)
    participant = int(match.group(2))
    participant_id = f"{group}{participant}"
    return {"group": group, "participant": participant, "participant_id": participant_id}


def build_participant_table(all_files):
    """
    Build a small summary DataFrame of all participants found on disk.

    Parameters
    ----------
    all_files : list of str or Path

    Returns
    -------
    tuple (participants_df, participant_rows)
        participants_df : pd.DataFrame with columns group, participant, participant_id, filepath
        participant_rows : list of dicts (same info), convenient for iteration
    """
    participant_rows = []
    for f in all_files:
        info = parse_participant_from_filename(f)
        info["filepath"] = f
        participant_rows.append(info)
    participants_df = pd.DataFrame(participant_rows)
    return participants_df, participant_rows


# =============================================================================
# Step 3. Reading CSVs in long format
# =============================================================================

def read_long_csv(filepath):
    """
    Read a MediaPipe long-format CSV and replace the numeric landmark index
    by its human-readable name.

    Parameters
    ----------
    filepath : str or Path
        Path to a landmarks CSV with columns: frame, index, x, y, z.

    Returns
    -------
    pd.DataFrame with columns: frame, landmark, x, y, z
    """
    df = pd.read_csv(filepath)
    df["landmark"] = df["index"].map(LM)
    df = df[["frame", "landmark", "x", "y", "z"]]
    return df


def build_long_dataframe(participant_rows, landmarks_of_interest=None):
    """
    Read every participant's CSV, filter to landmarks of interest,
    attach participant identity, and concatenate in long format.

    Parameters
    ----------
    participant_rows : list of dicts
        As returned by build_participant_table.
    landmarks_of_interest : list of str, optional
        Defaults to LANDMARKS_OF_INTEREST.

    Returns
    -------
    pd.DataFrame in long format with columns:
        frame, landmark, x, y, z, group, participant, participant_id
    """
    if landmarks_of_interest is None:
        landmarks_of_interest = LANDMARKS_OF_INTEREST

    long_frames = []
    for row in participant_rows:
        df_long = read_long_csv(row["filepath"])
        df_long = df_long[df_long["landmark"].isin(landmarks_of_interest)].copy()
        df_long["group"] = row["group"]
        df_long["participant"] = row["participant"]
        df_long["participant_id"] = row["participant_id"]
        long_frames.append(df_long)

    df_all_long = pd.concat(long_frames, ignore_index=True)
    return df_all_long


# =============================================================================
# Step 4. Y-axis inversion
# =============================================================================

def invert_y_axis(df_long):
    """
    Invert the y axis so that higher y means "up" (instead of MediaPipe's
    image convention where y=0 is the top of the image).

    Applies y = 1 - y in place on a copy of df_long and returns it.

    Parameters
    ----------
    df_long : pd.DataFrame with a 'y' column

    Returns
    -------
    pd.DataFrame (modified copy)
    """
    df = df_long.copy()
    df["y"] = 1 - df["y"]
    return df


# =============================================================================
# Step 5. Interpolation of missing coordinates
# =============================================================================

def count_complete_landmark_signals(df_long):
    """
    Count participants with 100% complete x and y time series for each landmark.
    """
    rows = []

    for landmark, sub in df_long.groupby("landmark", sort=False):
        per_participant = sub.groupby("participant_id").apply(
            lambda g: g["x"].notna().all() and g["y"].notna().all()
        )

        rows.append({
            "landmark": landmark,
            "n_participants_total": sub["participant_id"].nunique(),
            "n_participants_complete_100pct": int(per_participant.sum()),
        })

    return pd.DataFrame(rows).sort_values("landmark").reset_index(drop=True)

def interpolate_coordinates(df_long, max_missing_prop=0.10, max_gap=90):
    """
    Interpolate missing x and y values participant by participant and
    landmark by landmark, after first restoring missing frame x landmark rows.

    Rule:
        - interpolate only if missing proportion <= max_missing_prop
        - and longest consecutive gap <= max_gap
        - otherwise, set the whole landmark time series to NaN

    Parameters
    ----------
    df_long : pd.DataFrame
        Long-format DataFrame with columns: participant_id, landmark, frame, x, y.
    max_missing_prop : float, optional
        Maximum allowed proportion of missing frames for interpolation.
    max_gap : int, optional
        Maximum allowed length of a consecutive missing segment.

    Returns
    -------
    pd.DataFrame
        Long-format DataFrame with strict interpolation policy applied.
    """
    df = df_long.copy()
    out = []

    for pid, sub in df.groupby("participant_id", sort=False):
        sub = sub.copy()
        group_val = sub["group"].iloc[0]
        participant_val = sub["participant"].iloc[0]

        frames = np.sort(sub["frame"].unique())
        landmarks = np.sort(sub["landmark"].dropna().unique())

        full_index = pd.MultiIndex.from_product(
            [[pid], frames, landmarks],
            names=["participant_id", "frame", "landmark"]
        )

        sub_full = (
            sub.set_index(["participant_id", "frame", "landmark"])
            .reindex(full_index)
            .reset_index()
        )

        sub_full["group"] = group_val
        sub_full["participant"] = participant_val

        sub_full = sub_full.sort_values(
            ["participant_id", "landmark", "frame"]
        ).reset_index(drop=True)

        landmark_out = []
        for landmark, lm_sub in sub_full.groupby("landmark", sort=False):
            lm_sub = lm_sub.copy().sort_values("frame")

            missing_mask = lm_sub["x"].isna() | lm_sub["y"].isna()
            n_missing = int(missing_mask.sum())
            n_frames = len(lm_sub)
            prop_missing = n_missing / n_frames if n_frames > 0 else np.nan

            max_consecutive_gap = 0
            current_gap = 0
            for is_missing in missing_mask.to_numpy():
                if is_missing:
                    current_gap += 1
                    max_consecutive_gap = max(max_consecutive_gap, current_gap)
                else:
                    current_gap = 0

            if n_missing == 0:
                pass
            elif prop_missing <= max_missing_prop and max_consecutive_gap <= max_gap:
                lm_sub[["x", "y"]] = (
                    lm_sub[["x", "y"]]
                    .interpolate(method="linear", limit_direction="both")
                    .ffill()
                    .bfill()
                )
            else:
                lm_sub["x"] = np.nan
                lm_sub["y"] = np.nan

            landmark_out.append(lm_sub)

        sub_full = pd.concat(landmark_out, ignore_index=True)
        out.append(sub_full)

    df_interp = pd.concat(out, ignore_index=True)
    df_interp = df_interp.sort_values(
        ["participant_id", "landmark", "frame"]
    ).reset_index(drop=True)

    return df_interp


# =============================================================================
# Step 6. Long to wide conversion
# =============================================================================

def long_to_wide(df_long):
    """
    Pivot a long-format pose DataFrame to wide format.

    One row per (participant, frame), one column per landmark coordinate
    (e.g. 'nose_x', 'left_wrist_y').

    Parameters
    ----------
    df_long : pd.DataFrame
        Must contain: group, participant, participant_id, frame, landmark, x, y.

    Returns
    -------
    pd.DataFrame in wide format, sorted by (participant_id, frame).
    """
    df_wide = df_long.pivot_table(
        index=["group", "participant", "participant_id", "frame"],
        columns="landmark",
        values=["x", "y"],
    )
    df_wide.columns = [f"{landmark}_{coord}" for coord, landmark in df_wide.columns]
    df_wide = df_wide.reset_index()
    df_wide = df_wide.sort_values(["participant_id", "frame"]).reset_index(drop=True)
    return df_wide


# =============================================================================
# Step 7. Derived points and image center
# =============================================================================

def add_derived_points(df_wide):
    """
    Add mid_shoulders, mid_hips, torso_center and image_center coordinates
    as explicit *_x and *_y columns in the wide DataFrame.

    Parameters
    ----------
    df_wide : pd.DataFrame

    Returns
    -------
    pd.DataFrame (modified copy)
    """
    df = df_wide.copy()

    # Mid-shoulders
    df["mid_shoulders_x"] = (df["left_shoulder_x"] + df["right_shoulder_x"]) / 2
    df["mid_shoulders_y"] = (df["left_shoulder_y"] + df["right_shoulder_y"]) / 2

    # Mid-hips
    df["mid_hips_x"] = (df["left_hip_x"] + df["right_hip_x"]) / 2
    df["mid_hips_y"] = (df["left_hip_y"] + df["right_hip_y"]) / 2

    # Torso center
    df["torso_center_x"] = (df["mid_shoulders_x"] + df["mid_hips_x"]) / 2
    df["torso_center_y"] = (df["mid_shoulders_y"] + df["mid_hips_y"]) / 2

    # Image center (fixed reference in normalized coordinates)
    df["image_center_x"] = 0.5
    df["image_center_y"] = 0.5

    return df


# =============================================================================
# Step 8. Shoulder width and its per-participant median
# =============================================================================

def compute_median_shoulder_width(df_wide):
    """
    Compute per-frame shoulder width (2D Euclidean distance between left
    and right shoulders) and the median shoulder width for each participant.

    Parameters
    ----------
    df_wide : pd.DataFrame

    Returns
    -------
    tuple (df_wide_with_width, median_shoulder_width)
        df_wide_with_width : pd.DataFrame with an added 'shoulder_width' column
        median_shoulder_width : pd.Series indexed by participant_id
    """
    df = df_wide.copy()
    df["shoulder_width"] = np.sqrt(
        (df["left_shoulder_x"] - df["right_shoulder_x"]) ** 2
        + (df["left_shoulder_y"] - df["right_shoulder_y"]) ** 2
    )
    median_shoulder_width = (
        df.groupby("participant_id")["shoulder_width"].median().rename("median_shoulder_width")
    )
    return df, median_shoulder_width


# =============================================================================
# Step 9. Relative movement signals
# =============================================================================

def safe_diff(df, col_a, col_b):
    """
    Return df[col_a] - df[col_b] if both columns exist, otherwise a NaN
    Series aligned with df. Keeps the pipeline robust to missing landmarks.
    """
    if col_a in df.columns and col_b in df.columns:
        return df[col_a] - df[col_b]
    return pd.Series(np.nan, index=df.index)


def build_movement_signals(df_wide):
    """
    Build relative movement signals from raw coordinates.

    Strict rule:
        a movement signal is computed for a participant only if all source
        coordinate columns required for that signal are complete (100% non-NaN)
        across the whole time series. Otherwise, the whole movement signal is
        set to NaN for that participant.
    """
    df = df_wide.copy()
    out = []

    for pid, sub in df.groupby("participant_id", sort=False):
        sub = sub.copy()

        def full_signal_required(col_a, col_b, out_col):
            if col_a in sub.columns and col_b in sub.columns:
                ok_a = sub[col_a].notna().all()
                ok_b = sub[col_b].notna().all()
                if ok_a and ok_b:
                    sub[out_col] = sub[col_a] - sub[col_b]
                else:
                    sub[out_col] = np.nan
            else:
                sub[out_col] = np.nan

        # Hands
        full_signal_required("left_wrist_y", "left_shoulder_y", "left_hand_vertical")
        full_signal_required("right_wrist_y", "right_shoulder_y", "right_hand_vertical")
        full_signal_required("left_wrist_x", "left_shoulder_x", "left_hand_horizontal")
        full_signal_required("right_wrist_x", "right_shoulder_x", "right_hand_horizontal")

        # Body
        full_signal_required("mid_shoulders_x", "mid_hips_x", "swaying")
        full_signal_required("torso_center_x", "image_center_x", "sideways")

        # Head
        full_signal_required("nose_x", "mid_shoulders_x", "head_horizontal")
        full_signal_required("nose_y", "mid_shoulders_y", "head_vertical")

        out.append(sub)

    return pd.concat(out, ignore_index=True)


def count_complete_movement_signals(df_wide, signals=None):
    """
    Count participants with 100% complete time series for each movement signal.
    """
    if signals is None:
        signals = MOVEMENT_SIGNALS

    rows = []

    for signal in signals:
        if signal not in df_wide.columns:
            continue

        per_participant = df_wide.groupby("participant_id")[signal].apply(
            lambda s: s.notna().all()
        )

        rows.append({
            "movement": signal,
            "n_participants_total": df_wide["participant_id"].nunique(),
            "n_participants_complete_100pct": int(per_participant.sum()),
        })

    return pd.DataFrame(rows).sort_values("movement").reset_index(drop=True)



# =============================================================================
# Step 10. Normalization of movement signals by median shoulder width
# =============================================================================

def normalize_movement_signals(df_wide, median_shoulder_width, signals=None):
    """
    Normalize each relative movement signal by the participant's median
    shoulder width. Creates new columns suffixed '_norm'; the raw signals
    are preserved.

    Parameters
    ----------
    df_wide : pd.DataFrame
    median_shoulder_width : pd.Series indexed by participant_id
    signals : list of str, optional
        Defaults to MOVEMENT_SIGNALS.

    Returns
    -------
    pd.DataFrame (modified copy)
    """
    if signals is None:
        signals = MOVEMENT_SIGNALS

    df = df_wide.copy()

    # Avoid division by zero
    safe_width = median_shoulder_width.replace(0, np.nan)

    width_per_row = df["participant_id"].map(safe_width)
    for col in signals:
        if col in df.columns:
            df[f"{col}_norm"] = df[col] / width_per_row
    return df


# =============================================================================
# Step 11. Butterworth low-pass filtering (zero-phase, per participant)
# =============================================================================

def design_butterworth(fps, cutoff_hz, order):
    """
    Design a Butterworth low-pass filter and return its (b, a) coefficients.

    Parameters
    ----------
    fps : float
        Sampling rate in frames per second.
    cutoff_hz : float
        Cutoff frequency in Hz.
    order : int
        Butterworth order (filtfilt effectively doubles it).

    Returns
    -------
    tuple (b, a)
    """
    nyquist = 0.5 * fps
    normal_cutoff = cutoff_hz / nyquist
    b, a = butter(order, normal_cutoff, btype="low", analog=False)
    return b, a


def filter_series_filtfilt(series, b, a):
    """
    Apply zero-phase Butterworth filtering to a single 1D signal.

    NaNs are preserved: they are temporarily filled with the series mean
    so filtfilt can run, then re-inserted at their original positions.
    If the series is too short or entirely NaN, it is returned unchanged.
    """
    values = series.values.astype(float)
    nan_mask = np.isnan(values)

    min_len = 3 * (max(len(a), len(b)) - 1)
    if len(values) <= min_len or nan_mask.all():
        return pd.Series(values, index=series.index)

    if nan_mask.any():
        values_filled = values.copy()
        values_filled[nan_mask] = np.nanmean(values_filled)
    else:
        values_filled = values

    filtered = filtfilt(b, a, values_filled)
    filtered[nan_mask] = np.nan
    return pd.Series(filtered, index=series.index)


def filter_movement_signals(df_wide, fps, cutoff_hz, order, signals=None):
    """
    Apply a zero-phase Butterworth low-pass filter to the normalized
    movement signals (columns suffixed '_norm'), participant by participant.

    For each signal `s`, creates a new column `s_filt` filtered from `s_norm`.

    Parameters
    ----------
    df_wide : pd.DataFrame
        Must already contain `{s}_norm` columns for every s in `signals`.
    fps, cutoff_hz, order : filter parameters.
    signals : list of str, optional
        Defaults to MOVEMENT_SIGNALS.

    Returns
    -------
    pd.DataFrame (modified copy)
    """
    if signals is None:
        signals = MOVEMENT_SIGNALS

    df = df_wide.copy()
    b, a = design_butterworth(fps, cutoff_hz, order)

    for signal in signals:
        norm_col = f"{signal}_norm"
        if norm_col not in df.columns:
            # Robustness: skip quietly if normalized column is missing
            continue
        df[f"{signal}_filt"] = (
            df.groupby("participant_id")[norm_col]
            .transform(lambda s: filter_series_filtfilt(s, b, a))
        )
    return df


# =============================================================================
# Step 12. Centering of filtered signals
# =============================================================================

def center_filtered_signals(df_wide, signals=None):
    """
    Center each filtered movement signal by subtracting its per-participant
    mean. For each signal `s`, creates a new column `s_filt_centered`.

    Parameters
    ----------
    df_wide : pd.DataFrame
        Must already contain `{s}_filt` columns for every s in `signals`.
    signals : list of str, optional
        Defaults to MOVEMENT_SIGNALS.

    Returns
    -------
    pd.DataFrame (modified copy)
    """
    if signals is None:
        signals = MOVEMENT_SIGNALS

    df = df_wide.copy()
    for signal in signals:
        filt_col = f"{signal}_filt"
        if filt_col not in df.columns:
            continue
        centered_col = f"{signal}_filt_centered"
        df[centered_col] = (
            df[filt_col] - df.groupby("participant_id")[filt_col].transform("mean")
        )
    return df


# =============================================================================
# Step 13. Output CSV files
# =============================================================================

def save_outputs(df_wide, data_dir, signals=None, rename_centered=True):
    """
    Save the two global CSV files into `data_dir`:

        - all_participants_raw_movements.csv
              identity cols + relative (normalized) signals + filtered signals
        - all_participants_preprocessed_movements.csv
              identity cols + filtered-and-centered signals (renamed without suffix)

    Parameters
    ----------
    df_wide : pd.DataFrame
        Output of center_filtered_signals.
    data_dir : str or Path
    signals : list of str, optional
        Defaults to MOVEMENT_SIGNALS.
    rename_centered : bool
        If True, the preprocessed file drops the '_filt_centered' suffix so
        columns are simply named e.g. 'left_hand_vertical'. If False, the
        suffix is kept.

    Returns
    -------
    tuple (raw_path, preproc_path) as Path objects.
    """
    if signals is None:
        signals = MOVEMENT_SIGNALS

    data_dir = Path(data_dir)
    data_dir.mkdir(parents=True, exist_ok=True)

    # --- Raw movements file: normalized relative signals + filtered signals ---
    raw_cols = (
        ID_COLS
        + [f"{s}_norm" for s in signals if f"{s}_norm" in df_wide.columns]
        + [f"{s}_filt" for s in signals if f"{s}_filt" in df_wide.columns]
    )
    df_raw_out = df_wide[raw_cols].copy()

    # --- Preprocessed movements file: filtered + centered signals ---
    centered_cols = [f"{s}_filt_centered" for s in signals if f"{s}_filt_centered" in df_wide.columns]
    df_preproc_out = df_wide[ID_COLS + centered_cols].copy()

    if rename_centered:
        # Drop the "_filt_centered" suffix for cleaner downstream column names
        df_preproc_out.columns = df_preproc_out.columns.str.replace(
            "_filt_centered", "", regex=False
        )

    raw_path = data_dir / "all_participants_raw_movements.csv"
    preproc_path = data_dir / "all_participants_preprocessed_movements.csv"

    df_raw_out.to_csv(raw_path, index=False)
    df_preproc_out.to_csv(preproc_path, index=False)

    return raw_path, preproc_path
