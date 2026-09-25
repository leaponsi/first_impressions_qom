"""
Configuration partagée par les trois notebooks du pipeline.

Contient :
    - Les chemins du projet (PROJECT_DIR, DATA_DIR, ...).
    - Les paramètres globaux (FPS, CUTOFF_HZ, FILTER_ORDER).
    - Les listes de constantes (LM, LANDMARKS_OF_INTEREST, COORD_COLS, ...).
"""

from pathlib import Path

# -----------------------------------------------------------------------------
# Chemins du projet
# -----------------------------------------------------------------------------

CONFIG_DIR = Path(__file__).resolve().parent
PROJECT_DIR = CONFIG_DIR.parent.parent

DATA_DIR = PROJECT_DIR / "data"
RESULTS_DIR = PROJECT_DIR / "results"


# -----------------------------------------------------------------------------
# Paramètres du filtre Savitzky-Golay passe-bas
# -----------------------------------------------------------------------------
# Voir notebook 02_filtering pour la justification détaillée.
#   - FPS : fréquence d'échantillonnage des vidéos.
#   - SG_POLYORDER : ordre du polynôme local (N=4 recommandé en biomécanique
#     par Crenna et al., IMEKO 2015).
#   - SG_WINDOW_LENGTH : longueur de la fenêtre (impair, = 2M+1).
#     Calibré directement sur la réponse en fréquence (cf. notebook 02).
#     Pour FPS=30 Hz et N=4, window=11 donne une coupure -3 dB ≈ 4,85 Hz,
#     soit la valeur la plus proche de la cible 5 Hz parmi les fenêtres
#     impaires possibles.
FPS = 30.0
SG_POLYORDER = 4
SG_WINDOW_LENGTH = 11


# -----------------------------------------------------------------------------
# Dictionnaire des landmarks MediaPipe Pose
# -----------------------------------------------------------------------------
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

# Landmarks utiles pour l'analyse (on ne garde que ceux-là).
LANDMARKS_OF_INTEREST = [
    "nose",
    "left_shoulder", "right_shoulder",
    "left_wrist", "right_wrist"
]

# Colonnes de coordonnées (x, y) après pivot wide.
COORD_COLS = [
    "nose_x", "nose_y",
    "left_shoulder_x", "left_shoulder_y",
    "right_shoulder_x", "right_shoulder_y",
    "left_wrist_x", "left_wrist_y",
    "right_wrist_x", "right_wrist_y"
]

# Signaux de mouvement final.
MOVEMENT_SIGNALS = [
    "left_hand_vertical",
    "right_hand_vertical",
    "left_hand_horizontal",
    "right_hand_horizontal",
    "head_horizontal",
    "head_vertical",
]

# Colonnes d'identification (sans `participant` qui était redondant
# avec `participant_id`).
ID_COLS = ["group", "participant_id", "frame"]
