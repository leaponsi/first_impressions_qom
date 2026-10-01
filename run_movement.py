"""
run_movement.py - runs the Python / movement part of the pipeline only.

RUN THIS FIRST (before run_statistics.Rmd): the R pipeline needs
data/movement/05_qom.csv, which this script produces.

Just open this file in VS Code and click the "Run" (triangle) button in
the top-right corner - no terminal commands to type.

Steps (in order), all in code/movement/:
  01_cleaning -> 02_filtering -> 03_movements -> 04_extrema -> 05_qom
Reads   data/movement/landmarks/{P,SZ}/landmarks_*_POSE.csv
Writes  data/movement/0{1..5}_*.csv

Requirement: the same Python you use for the notebooks, with Jupyter
installed ("jupyter --version" should work in a terminal).
"""

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent
MOVEMENT_DIR = REPO_ROOT / "code" / "movement"

NOTEBOOKS = [
    "01_cleaning",
    "02_filtering",
    "03_movements",
    "04_extrema",
    "05_qom",
]


def run_notebook(name, cwd):
    cmd = [
        "jupyter", "nbconvert",
        "--to", "notebook",
        "--execute",
        "--inplace",
        "--ExecutePreprocessor.timeout=1800",
        f"{name}.ipynb",
    ]
    print(f"\n--- Running: {' '.join(cmd)}  (in {cwd}) ---")
    try:
        result = subprocess.run(cmd, cwd=cwd)
    except FileNotFoundError as e:
        sys.exit(f"\n*** ERROR: could not run 'jupyter' ({e}). Is it installed and on PATH? ***")
    if result.returncode != 0:
        sys.exit(f"\n*** ERROR: {name}.ipynb failed (exit code {result.returncode}). Stopping here. ***")


def main():
    print("=" * 74)
    print(" Movement pipeline (Python notebooks)")
    print("=" * 74)
    for nb in NOTEBOOKS:
        run_notebook(nb, MOVEMENT_DIR)

    print("\n" + "=" * 74)
    print(" Done. Processed data written to data/movement/.")
    print(" Next: open run_statistics.Rmd in RStudio and run it (needs R).")
    print("=" * 74)


if __name__ == "__main__":
    main()
