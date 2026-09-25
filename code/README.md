# Pipeline d'analyse — Premières impressions × Mouvement

## Structure

```
project/
├── functions_analysis.R         # toutes les fonctions réutilisables
├── 00_prepare_data.Rmd          # nettoyage, fusion, exports CSV
├── 01_descriptives.Rmd          # Cronbach + tableaux descriptifs
├── 02_first_impressions_models.Rmd   # LMM sur impressions
├── 03_movement_descriptives_and_links.Rmd  # descriptifs mouvement + LMM
├── 04_group_comparisons_movement.Rmd # P vs SZ sur mouvements significatifs
├── 05_SZ_clinical_links.Rmd     # corrélations cliniques SZ
│
├── data/
│   ├── raw/                     # data_imp.csv, all_participants_features.csv,
│   │                              stimuli_participants.csv
│   └── processed/               # data_complete.csv, data_stimuli.csv, etc.
│
└── outputs/
    ├── tables/                  # tous les CSV + HTML des tableaux
    ├── plots/                   # PNG 300 dpi
    └── models/                  # (optionnel) résumés modèles
```

## Ordre d'exécution

Les notebooks doivent être tournés dans l'ordre :

1. `00_prepare_data.Rmd`   → produit `data_complete.csv`, `data_stimuli.csv`,
                              `data_observers.csv`, `data_dictionary.csv`
2. `01_descriptives.Rmd`
3. `02_first_impressions_models.Rmd`
4. `03_movement_descriptives_and_links.Rmd` → produit
   `outputs/tables/03_significant_features.txt` (utilisé par le notebook 04)
5. `04_group_comparisons_movement.Rmd`      → produit
   `outputs/tables/04_movement_group_tests.csv` (utilisé par le notebook 05)
6. `05_SZ_clinical_links.Rmd`

Chaque Rmd commence par `source("functions_analysis.R")`.

## Niveau d'analyse — règles à respecter

| Analyse                                  | Base à utiliser         | Pourquoi                                    |
|------------------------------------------|-------------------------|---------------------------------------------|
| Descriptifs stimuli / mouvements         | `data_stimuli.csv`      | 1 ligne par stimulus, pas de doublons       |
| Tests P vs SZ sur les mouvements         | `data_stimuli.csv`      | idem                                        |
| Descriptifs observateurs                 | `data_observers.csv`    | 1 ligne par observateur, pas de doublons    |
| LMM impressions ~ groupe                 | `data_complete.csv`     | exploite la structure obs × vid             |
| LMM impressions ~ feature de mouvement   | `data_complete.csv`     | idem                                        |
| Corrélations cliniques (SZ)              | `data_stimuli.csv` filtré SZ | 1 ligne par patient                    |

## Tailles d'effet — règle

- **Tests t / Wilcoxon simples** (notebooks 01, 04) → Cohen's d ou rank-biserial.
  Cohen's d est acceptable ici car ce sont deux groupes indépendants
  sans structure hiérarchique.
- **Modèles mixtes** (notebooks 02, 03) → **pas** de Cohen's d. On rapporte
  R² marginal, R² conditionnel, et f².

## Couleurs

- P  = `#F4B6C2` (rose clair)
- SZ = `#A6CEE3` (bleu clair)

Définis dans `GROUP_COLORS` dans `functions_analysis.R`.

## Mouvements gardés (8)

- `move_hands_horizontal_qom_rate`
- `move_hands_vertical_qom_rate`
- `move_head_horizontal_qom_rate`
- `move_head_vertical_qom_rate`
- `move_hands_horizontal_expansiveness_rate`
- `move_hands_vertical_expansiveness_rate`
- `move_head_horizontal_expansiveness_rate`
- `move_head_vertical_expansiveness_rate`

**Variables totales (`hands_total`, `head_total`) exclues.**

## Items d'impression utilisés pour l'alpha + score total (10)

- imp_sympathique, imp_bizarre_inversed, imp_intelligente, imp_appreciable,
  imp_confiance, imp_dominante, imp_conversation, imp_temps, imp_voisin,
  imp_assis.

`imp_bizarre` (non inversé) est gardé dans le CSV pour traçabilité mais
n'est utilisé ni dans l'alpha ni dans le score.

## Packages requis

```r
install.packages(c(
  "dplyr","tidyr","readr","stringr","purrr","tibble","ggplot2",
  "lme4","lmerTest","emmeans","performance","broom","broom.mixed",
  "car","effectsize","psych","gt","gtsummary","scales"
))
```
