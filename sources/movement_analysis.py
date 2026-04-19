"""
movement_analysis.py
====================

Movement feature extraction for the `pons.lea` project.

This module operates on a preprocessed movement-signals CSV (typically the
output of the preprocessing pipeline) and produces a tidy, participant-level
table of movement features suitable for statistical analysis.

Three features are computed for each signal:

- **QoM** (Quantity of Motion): the total number of local extrema (maxima
  plus minima) detected in the signal, divided by the signal duration in
  seconds. It quantifies how often the participant reverses the direction
  of a movement.

- **amplitude_sum**: the sum of absolute differences between successive
  extrema, ordered in time, divided by the signal duration in seconds. It
  quantifies the cumulative "excursion" of the movement across reversals.

- **mean_speed**: the mean absolute frame-to-frame difference of the
  signal. It quantifies the average instantaneous speed of the movement.
  This feature is already a time average, so it is not further normalized
  by duration.

Left- and right-hand signals are first analysed independently, then
averaged to produce two aggregated movement types (`hand_horizontal` and
`hand_vertical`). Trunk and head signals are carried through unchanged.

The module exposes eight flat functions and a small set of constants; no
classes, no nested functions. A companion notebook
(`notebooks/movement_analysis.ipynb`) orchestrates these functions and
performs visual checks.

Expected input DataFrame columns
--------------------------------
group, participant, participant_id, frame,
left_hand_horizontal, right_hand_horizontal,
left_hand_vertical,   right_hand_vertical,
swaying, sideways,
head_horizontal, head_vertical
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
from scipy.signal import find_peaks


# =============================================================================
# Constants
# =============================================================================

#: All signals analysed individually (left/right hands kept separate).
BASE_SIGNALS = [
    "left_hand_horizontal", "right_hand_horizontal",
    "left_hand_vertical",   "right_hand_vertical",
    "swaying", "sideways",
    "head_horizontal", "head_vertical",
]

#: Final movement types reported in the output CSV (hands are aggregated).
MOVEMENT_TYPES = [
    "hand_horizontal",
    "hand_vertical",
    "swaying",
    "sideways",
    "head_horizontal",
    "head_vertical",
]

#: Mapping from aggregated movement type to the base signals to average.
#: Only the two hand types are aggregated; all other types map 1-to-1 to a
#: base signal of the same name.
HAND_AGGREGATION = {
    "hand_horizontal": ["left_hand_horizontal", "right_hand_horizontal"],
    "hand_vertical":   ["left_hand_vertical",   "right_hand_vertical"],
}

#: Feature columns, in their canonical output order.
FEATURE_COLS = ["QoM", "amplitude_sum", "mean_speed"]

#: Identity columns carried through every output table.
ID_COLS = ["participant_id", "participant", "group"]


# =============================================================================
# Step 1. Local extrema detection
# =============================================================================

def detect_extrema(signal, distance, prominence, width, height):
    """
    Detect local maxima and minima of a one-dimensional signal.

    Maxima are detected by applying ``scipy.signal.find_peaks`` to the raw
    signal; minima are detected by applying ``find_peaks`` to the negated
    signal. NaN values are handled by temporary linear interpolation so
    that ``find_peaks`` receives a finite input; the stored signal is not
    modified.

    Parameters
    ----------
    signal : array-like
        One-dimensional input signal. May contain NaNs.
    distance : int or None
        Minimum separation between two successive peaks, in frames.
        Forwarded to ``find_peaks``.
    prominence : float or None
        Minimum vertical prominence a peak must have to be kept.
        Forwarded to ``find_peaks``.
    width : float or None
        Minimum peak width in frames. Forwarded to ``find_peaks``.
    height : float or None
        Minimum absolute height a peak must reach. Forwarded to
        ``find_peaks``.

    Returns
    -------
    idx_max : numpy.ndarray
        Frame indices of the detected maxima (empty if none).
    idx_min : numpy.ndarray
        Frame indices of the detected minima (empty if none).
    """
    s = np.asarray(signal, dtype=float)
    if s.size == 0 or np.all(np.isnan(s)):
        return np.array([], dtype=int), np.array([], dtype=int)

    idx_max, _ = find_peaks(
        s, distance=distance, prominence=prominence,
        width=width, height=height,
    )
    idx_min, _ = find_peaks(
        -s, distance=distance, prominence=prominence,
        width=width, height=height,
    )
    return idx_max, idx_min


# =============================================================================
# Steps 2-4. Individual feature primitives
# =============================================================================

def compute_total_extrema(idx_max, idx_min):
    """
    Count the total number of extrema.

    Parameters
    ----------
    idx_max, idx_min : array-like
        Indices of detected maxima and minima.

    Returns
    -------
    int
        ``len(idx_max) + len(idx_min)``.
    """
    return int(len(idx_max) + len(idx_min))


def compute_amplitude_sum(signal, idx_max, idx_min):
    """
    Sum the absolute differences between successive extrema.

    Maxima and minima indices are merged, sorted chronologically, and used
    to index the signal. The function then returns the sum of the absolute
    first differences of these extremum values.

    Returns 0.0 if fewer than two extrema are available.
    """
    s = np.asarray(signal, dtype=float)
    all_idx = np.sort(np.concatenate([idx_max, idx_min]))

    if all_idx.size < 2:
        return 0.0

    values = s[all_idx]
    return float(np.sum(np.abs(np.diff(values))))


def compute_mean_speed(signal):
    """
    Compute the mean absolute frame-to-frame velocity of a signal.

    The "velocity" here is the first difference of the signal; its
    magnitude is averaged over all frames. Because the result is already a
    time average, it should not be further divided by duration.

    Parameters
    ----------
    signal : array-like
        One-dimensional input signal.

    Returns
    -------
    float
        Mean of ``|diff(signal)|``, or NaN if the signal is empty,
        entirely NaN, or shorter than two frames.
    """
    s = np.asarray(signal, dtype=float)
    if s.size < 2 or np.all(np.isnan(s)):
        return np.nan
    velocity = np.diff(s)
    return float(np.nanmean(np.abs(velocity)))


# =============================================================================
# Step 5. Combined per-signal metrics (with duration normalization)
# =============================================================================

def compute_signal_metrics(signal, fps, distance, prominence, width, height):
    """
    Compute all three movement features for a single one-dimensional signal.

    ``QoM`` and ``amplitude_sum`` are normalized by the signal duration in
    seconds so that recordings of slightly different lengths remain
    comparable across participants. ``mean_speed`` is returned as-is since
    it is already a time average.

    Parameters
    ----------
    signal : array-like
        One-dimensional input signal.
    fps : float
        Sampling rate in frames per second. Used to convert frame counts
        into seconds.
    distance, prominence, width, height
        Peak-detection parameters forwarded to :func:`detect_extrema`.

    Returns
    -------
    dict
        Dictionary with keys:

        - ``n_maxima``, ``n_minima``, ``n_extrema`` (int): intermediate
          counts, useful for inspection.
        - ``QoM`` (float): ``n_extrema / duration_seconds``.
        - ``amplitude_sum`` (float): raw amplitude sum divided by
          ``duration_seconds``.
        - ``mean_speed`` (float): mean absolute frame-to-frame velocity.
    """
    s = np.asarray(signal, dtype=float)
    n_frames = s.size
    duration_seconds = n_frames / fps if n_frames > 0 else np.nan

    idx_max, idx_min = detect_extrema(s, distance, prominence, width, height)
    n_max = len(idx_max)
    n_min = len(idx_min)
    n_ext = n_max + n_min

    # QoM: extrema per second
    if duration_seconds and duration_seconds > 0:
        qom = n_ext / duration_seconds
    else:
        qom = np.nan

    # amplitude_sum: raw sum divided by duration
    amp_raw = compute_amplitude_sum(s, idx_max, idx_min)
    if np.isnan(amp_raw) or not duration_seconds or duration_seconds <= 0:
        amp = np.nan
    else:
        amp = amp_raw / duration_seconds

    # mean_speed: already time-averaged, not further normalized
    speed = compute_mean_speed(s)

    return {
        "n_maxima": n_max,
        "n_minima": n_min,
        "n_extrema": n_ext,
        "QoM": qom,
        "amplitude_sum": amp,
        "mean_speed": speed,
    }


# =============================================================================
# Step 6. Loop over all participants and all base signals
# =============================================================================

def compute_per_signal_features(df, fps, distance, prominence, width, height,
                                base_signals=None):
    """
    Compute movement features for every (participant, base signal) pair.

    The function iterates over participants and over the eight base
    signals, calling :func:`compute_signal_metrics` for each combination.
    It is robust to missing or all-NaN signals, which are silently skipped.

    Parameters
    ----------
    df : pandas.DataFrame
        Preprocessed signals with columns ``group``, ``participant``,
        ``participant_id``, ``frame`` and the base signal columns.
    fps : float
        Sampling rate in frames per second.
    distance, prominence, width, height
        Peak-detection parameters forwarded to
        :func:`compute_signal_metrics`.
    base_signals : list of str, optional
        Signals to process. Defaults to :data:`BASE_SIGNALS`.

    Returns
    -------
    pandas.DataFrame
        Long-format table with one row per (participant, signal) and
        columns ``participant_id``, ``participant``, ``group``, ``signal``,
        ``n_maxima``, ``n_minima``, ``n_extrema``, ``QoM``,
        ``amplitude_sum``, ``mean_speed``.
    """
    if base_signals is None:
        base_signals = BASE_SIGNALS

    per_signal_rows = []

    for pid, sub in df.groupby("participant_id", sort=False):
        sub = sub.sort_values("frame")
        group_val = sub["group"].iloc[0]
        part_val = sub["participant"].iloc[0]

        for signal_name in base_signals:
            # Skip signals that are not present in the DataFrame at all.
            if signal_name not in sub.columns:
                continue

            values = sub[signal_name].to_numpy()

            # Skip signals that are entirely missing for this participant.
            if np.all(np.isnan(values)):
                continue

            metrics = compute_signal_metrics(
                values, fps=fps,
                distance=distance, prominence=prominence,
                width=width, height=height,
            )

            per_signal_rows.append({
                "participant_id": pid,
                "participant":    part_val,
                "group":          group_val,
                "signal":         signal_name,
                **metrics,
            })

    return pd.DataFrame(per_signal_rows)


# =============================================================================
# Step 7. Aggregate left/right hands and assemble the final long table
# =============================================================================

def aggregate_hand_signals(per_signal_df,
                           movement_types=None,
                           hand_aggregation=None):
    """
    Aggregate the per-signal table into the final movement-feature table.

    For aggregated movement types (``hand_horizontal`` and
    ``hand_vertical``), the function averages the features of the
    corresponding left and right base signals. Since QoM and
    amplitude_sum are already duration-normalized, averaging them is
    dimensionally consistent. For every other movement type, the features
    are copied unchanged from the matching base signal.

    Parameters
    ----------
    per_signal_df : pandas.DataFrame
        Output of :func:`compute_per_signal_features`.
    movement_types : list of str, optional
        Movement types to include. Defaults to :data:`MOVEMENT_TYPES`.
    hand_aggregation : dict, optional
        Mapping from aggregated type to list of base signals. Defaults to
        :data:`HAND_AGGREGATION`.

    Returns
    -------
    pandas.DataFrame
        Final table with columns ``participant_id``, ``participant``,
        ``group``, ``movement_type``, ``QoM``, ``amplitude_sum``,
        ``mean_speed``.
    """
    if movement_types is None:
        movement_types = MOVEMENT_TYPES
    if hand_aggregation is None:
        hand_aggregation = HAND_AGGREGATION

    aggregated_rows = []

    for pid, sub in per_signal_df.groupby("participant_id", sort=False):
        group_val = sub["group"].iloc[0]
        part_val = sub["participant"].iloc[0]

        for movement_type in movement_types:
            if movement_type in hand_aggregation:
                # Aggregated type: mean of left and right metrics.
                component_signals = hand_aggregation[movement_type]
                components = sub[sub["signal"].isin(component_signals)]
                if components.empty:
                    continue
                agg = {col: components[col].mean() for col in FEATURE_COLS}
            else:
                # Non-aggregated type: copy features from the matching signal.
                match = sub[sub["signal"] == movement_type]
                if match.empty:
                    continue
                agg = {col: match[col].iloc[0] for col in FEATURE_COLS}

            aggregated_rows.append({
                "participant_id": pid,
                "participant":    part_val,
                "group":          group_val,
                "movement_type":  movement_type,
                **agg,
            })

    features_df = pd.DataFrame(
        aggregated_rows,
        columns=ID_COLS + ["movement_type"] + FEATURE_COLS,
    )
    return features_df


# =============================================================================
# Step 8. Write the final features CSV
# =============================================================================

def save_features(features_df, data_dir,
                  filename="all_participants_movement_features.csv"):
    """
    Write the final features DataFrame to ``data_dir / filename``.

    The target directory is created if it does not exist.

    Parameters
    ----------
    features_df : pandas.DataFrame
        Output of :func:`aggregate_hand_signals`.
    data_dir : str or pathlib.Path
        Directory in which to save the CSV file.
    filename : str, optional
        Name of the output file. Defaults to
        ``"all_participants_movement_features.csv"``.

    Returns
    -------
    pathlib.Path
        Absolute path of the written file.
    """
    data_dir = Path(data_dir)
    data_dir.mkdir(parents=True, exist_ok=True)
    output_path = data_dir / filename
    features_df.to_csv(output_path, index=False)
    return output_path
