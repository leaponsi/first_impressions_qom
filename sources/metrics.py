# =============================================================================
# metrics.py — Movement metric functions
# Movement analysis: SZ vs controls (P)
#
# Functions covered:
#   1. get_local_extrema()    — detect local minima and maxima in a signal
#   2. compute_extrema_metrics() — expansiveness and quantity of motion
#                                  per signal (Botler et al.)
#   3. motion_sum_for_marker()   — 3D movement quantity index per landmark
#                                  (Précloux et al., 2026)
#   4. flatten_metrics()         — reshape nested metrics dict into one flat
#                                  row per participant, ready for CSV export
# =============================================================================

import numpy as np
import pandas as pd

from .config import ALL_SIGNAL_NAMES, FS


# =============================================================================
# 1. LOCAL EXTREMA DETECTION
# =============================================================================

def get_local_extrema(signal):
    """
    Detect local minima and maxima in a 1D signal using the first derivative.

    A local maximum is a point where the derivative changes from positive to
    non-positive (the signal was rising then stopped rising).
    A local minimum is a point where the derivative changes from negative to
    non-negative (the signal was falling then stopped falling).

    This approach requires the signal to be smoothed beforehand (e.g. with
    lowpass_filter) to avoid detecting noise fluctuations as extrema.

    Parameters
    ----------
    signal : array-like
        Preprocessed (filtered and centered) 1D signal.

    Returns
    -------
    min_idx : np.ndarray
        Indices of local minima.
    max_idx : np.ndarray
        Indices of local maxima.
    """
    signal = np.asarray(signal, dtype=float)
    d = np.diff(signal)

    max_idx, min_idx = [], []
    for i in range(1, len(d)):
        if d[i - 1] > 0 and d[i] <= 0:
            max_idx.append(i)
        elif d[i - 1] < 0 and d[i] >= 0:
            min_idx.append(i)

    return np.array(min_idx), np.array(max_idx)


# =============================================================================
# 2. EXTREMA-BASED METRICS (Botler et al.)
# =============================================================================

def compute_extrema_metrics(signal, frames):
    """
    Compute expansiveness and quantity of motion from a preprocessed signal.

    Definitions follow Lozano-Goupil et al. (2025, Psychological Reports):
        "Both timeseries of changing landmark distances were used to extract
        the amplitude between successive local maxima and local minima.
        The sum of all [...] amplitudes served as an estimate of [...]
        expansiveness [...] Moreover, the sum of number of local minima and
        maxima served as an estimate of [...] quantity of motion, without
        including the influence of motion amplitude."

        - Turning points : local minima and maxima of the signal.
        - Amp_i          : absolute amplitude between two successive turning
                           points (one minimum and the next maximum, or vice
                           versa).
        - Delta_T_i      : time interval (in frames) between two successive
                           turning points.
        - Expansiveness  : sum of all Amp_i — estimates the overall distance
                           traveled by the body part, regardless of how often
                           it moves.
        - Quantity of motion (QoM) : total number of turning points
                           (n_minima + n_maxima) — estimates how frequently
                           the body part changes direction, regardless of how
                           large the movements are.

    Note: expansiveness and QoM are intentionally independent metrics.
    A person can have high expansiveness with few large movements, or high
    QoM with many small movements. Both dimensions are needed to fully
    characterize motor behavior.

    Parameters
    ----------
    signal : array-like
        Preprocessed (filtered, centered, normalized) 1D signal.
    frames : array-like
        Frame indices corresponding to the signal values (df_w["frame"]).

    Returns
    -------
    dict with keys:
        expansiveness      : float — sum of amplitudes between successive extrema
        quantity_of_motion : int   — total number of turning points
        n_minima           : int   — number of local minima
        n_maxima           : int   — number of local maxima
        mean_amplitude     : float — mean Amp_i (nan if no extrema found)
        mean_delta_t_frames: float — mean Delta_T_i in frames (nan if < 2 extrema)
        mean_delta_t_s     : float — mean Delta_T_i in seconds (nan if < 2 extrema)
        _amplitudes        : list  — individual Amp_i values (not exported to CSV)
        _delta_t           : list  — individual Delta_T_i values in frames
                                     (not exported to CSV)
    """
    signal = np.asarray(signal, dtype=float)
    frames = np.asarray(frames)

    min_idx, max_idx = get_local_extrema(signal)

    # Merge and sort all extrema by their position in time
    all_idx = np.sort(np.concatenate([min_idx, max_idx]))

    amplitudes, delta_t = [], []
    for i in range(1, len(all_idx)):
        i0, i1 = all_idx[i - 1], all_idx[i]
        amplitudes.append(abs(signal[i1] - signal[i0]))
        delta_t.append(int(frames[i1] - frames[i0]))

    return {
        "expansiveness":       float(np.sum(amplitudes)),
        "quantity_of_motion":  int(len(min_idx) + len(max_idx)),
        "n_minima":            int(len(min_idx)),
        "n_maxima":            int(len(max_idx)),
        "mean_amplitude":      float(np.mean(amplitudes))      if amplitudes else np.nan,
        "mean_delta_t_frames": float(np.mean(delta_t))         if delta_t    else np.nan,
        "mean_delta_t_s":      float(np.mean(delta_t)) / FS    if delta_t    else np.nan,
        "_amplitudes":         amplitudes,
        "_delta_t":            delta_t,
    }


# =============================================================================
# 3. 3D MOVEMENT QUANTITY INDEX (Précloux et al., 2026)
# =============================================================================

def motion_sum_for_marker(df_w, marker_name):
    """
    Compute the 3D Movement Quantity Index (MQI) for a single landmark.

    The MQI is the sum of Euclidean distances between consecutive positions
    of the landmark across all frames, using the raw (x, y, z) coordinates
    before any filtering or normalization.

    This differs from the extrema-based metrics in two ways:
        - It uses 3D coordinates (includes depth z estimated by MediaPipe).
        - It operates on raw coordinates, not on relative body signals.

    Parameters
    ----------
    df_w : pd.DataFrame
        Wide-format DataFrame (output of build_wide_df). Raw coordinates are
        used intentionally here — the MQI is defined on unprocessed positions.
    marker_name : str
        Landmark name as defined in config.LM (e.g. "left_wrist", "nose").

    Returns
    -------
    float
        Total 3D path length of the landmark in normalized image units.
        Returns np.nan if any of the x/y/z columns are missing.
    """
    lc = {c.lower(): c for c in df_w.columns}
    try:
        cx = lc[f"{marker_name.lower()}_x"]
        cy = lc[f"{marker_name.lower()}_y"]
        cz = lc[f"{marker_name.lower()}_z"]
    except KeyError:
        return np.nan

    x = pd.to_numeric(df_w[cx], errors="coerce")
    y = pd.to_numeric(df_w[cy], errors="coerce")
    z = pd.to_numeric(df_w[cz], errors="coerce")

    step = np.sqrt(x.diff()**2 + y.diff()**2 + z.diff()**2)
    return float(step.fillna(0).sum())


# =============================================================================
# 4. FLATTEN METRICS TO ONE ROW PER PARTICIPANT
# =============================================================================

def flatten_metrics(metrics_dict, participant_info, n_frames, df_w):
    """
    Reshape the nested metrics dictionary into a single flat row (dict),
    ready to be appended to a list and converted to a pd.DataFrame for
    CSV export and subsequent statistical analysis in R.

    All metrics are computed in two versions:
        - Raw total (e.g. expansiveness): useful for comparing overall behavior.
        - Per-second normalized (e.g. expansiveness_per_s): corrects for
          differences in recording duration across participants.

    Missing signals (absent landmarks) produce NaN values in all
    corresponding columns, and are flagged with a dedicated _available
    column (0 = missing, 1 = present) so that R can distinguish between
    a true zero and a missing value.

    The MQI (Précloux et al., 2026) is computed here for key landmarks
    directly from the raw wide DataFrame.

    Parameters
    ----------
    metrics_dict : dict {signal_name: dict}
        Output of {name: compute_extrema_metrics(...) for name in signals}.
    participant_info : dict
        Output of parse_participant_info() — contains group, participant,
        participant_id.
    n_frames : int
        Total number of frames for this participant.
    df_w : pd.DataFrame
        Wide-format DataFrame — used to compute MQI on raw coordinates.

    Returns
    -------
    dict
        One flat row with all metrics for this participant.
    """
    n_seconds = n_frames / FS
    row = {}

    # --- Participant metadata ---
    row.update(participant_info)
    row["n_frames"]  = n_frames
    row["n_seconds"] = round(n_seconds, 2)

    # --- Extrema-based metrics (one block per signal) ---
    for sig_name in ALL_SIGNAL_NAMES:
        p = sig_name  # column name prefix

        row[f"{p}_available"] = int(sig_name in metrics_dict)

        if sig_name not in metrics_dict:
            # Signal absent: fill all columns with NaN
            for col in [
                "expansiveness", "expansiveness_per_s",
                "quantity_of_motion", "quantity_of_motion_per_s",
                "n_minima", "n_maxima",
                "mean_amplitude", "mean_delta_t_frames", "mean_delta_t_s",
            ]:
                row[f"{p}_{col}"] = np.nan
            continue

        m = metrics_dict[sig_name]
        row[f"{p}_expansiveness"]              = round(m["expansiveness"], 6)
        row[f"{p}_expansiveness_per_s"]        = round(m["expansiveness"] / n_seconds, 6)
        row[f"{p}_quantity_of_motion"]         = m["quantity_of_motion"]
        row[f"{p}_quantity_of_motion_per_s"]   = round(m["quantity_of_motion"] / n_seconds, 4)
        row[f"{p}_n_minima"]                   = m["n_minima"]
        row[f"{p}_n_maxima"]                   = m["n_maxima"]
        row[f"{p}_mean_amplitude"]             = round(m["mean_amplitude"], 6)      if not np.isnan(m["mean_amplitude"])      else np.nan
        row[f"{p}_mean_delta_t_frames"]        = round(m["mean_delta_t_frames"], 2) if not np.isnan(m["mean_delta_t_frames"]) else np.nan
        row[f"{p}_mean_delta_t_s"]             = round(m["mean_delta_t_s"], 4)      if not np.isnan(m["mean_delta_t_s"])      else np.nan

    # --- MQI 3D (Précloux et al., 2026) for key landmarks ---
    # Computed on raw coordinates (before filtering/normalization),
    # as defined in the original method.
    mqi_markers = ["left_wrist", "right_wrist", "nose",
                   "left_foot_index", "right_foot_index"]
    for marker in mqi_markers:
        val = motion_sum_for_marker(df_w, marker)
        row[f"MQI_{marker}"] = round(val, 6) if not np.isnan(val) else np.nan

    return row