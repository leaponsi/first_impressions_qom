# =============================================================================
# stats_impressions.R — First impression scores: SZ vs HC
#
# Uses linear mixed models (lmer) with observer (CASE) as random effect
# to account for the fact that each observer rated multiple stimuli.
#
# Models:
#   1. Total score       : Total_score ~ Type + num_video + (1|CASE)
#   2. Impression score  : Score_impression ~ Type + num_video + (1|CASE)
#   3. Intention score   : Score_intention ~ Type + num_video + (1|CASE)
#   4. Item by item      : Score ~ Type * Impression + num_video + (1|CASE)
# =============================================================================

library(lme4)
library(lmerTest)   # adds p-values to lmer output
library(emmeans)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggpubr)

# =============================================================================
# 1. TOTAL SCORE
# =============================================================================

model_total <- lmer(
  Total_score ~ Type + num_video + (1 | CASE),
  data = df_observers
)

cat("=== Model: Total score ===\n")
print(summary(model_total))
print(anova(model_total))

# Effect of Type (SZ vs HC)
emm_total <- emmeans(model_total, ~ Type)
cat("\nEmmeans — Total score by Type:\n")
print(summary(emm_total))
print(pairs(emm_total, adjust = "bonferroni"))

# =============================================================================
# 2. IMPRESSION SUBSCORE
# =============================================================================

model_imp <- lmer(
  Score_impression ~ Type + num_video + (1 | CASE),
  data = df_observers
)

cat("\n=== Model: Impression subscore ===\n")
print(anova(model_imp))

emm_imp <- emmeans(model_imp, ~ Type)
print(pairs(emm_imp, adjust = "bonferroni"))

# =============================================================================
# 3. BEHAVIORAL INTENTION SUBSCORE
# =============================================================================

model_int <- lmer(
  Score_intention ~ Type + num_video + (1 | CASE),
  data = df_observers
)

cat("\n=== Model: Behavioral intention subscore ===\n")
print(anova(model_int))

emm_int <- emmeans(model_int, ~ Type)
print(pairs(emm_int, adjust = "bonferroni"))

# =============================================================================
# 4. ITEM BY ITEM
# =============================================================================

# Reshape to long format
all_items <- c("Attractive", "Awkward_r", "Intelligent", "Likeable",
               "Trustworthy", "Dominant",
               "Conversation", "Time", "LiveNearby", "SitNext")

df_long_items <- df_observers %>%
  pivot_longer(cols = all_of(all_items),
               names_to  = "Item",
               values_to = "Score") %>%
  mutate(Item = as.factor(Item))

model_items <- lmer(
  Score ~ Type * Item + num_video + (1 | CASE),
  data = df_long_items
)

cat("\n=== Model: Item x Type interaction ===\n")
print(anova(model_items))

# Pairwise SZ vs HC for each item separately
emm_items <- emmeans(model_items, ~ Type | Item)
contrasts_items <- pairs(emm_items, adjust = "bonferroni")
cat("\nPairwise contrasts SZ vs HC by item:\n")
print(summary(contrasts_items))

# Export contrasts table
contrasts_df <- as.data.frame(summary(contrasts_items))
write.csv(contrasts_df,
          file.path(RESULTS_PATH, "stats_impressions_by_item.csv"),
          row.names = FALSE)

# =============================================================================
# 5. FIGURES
# =============================================================================

# --- Total score by Type ---
p_total <- ggplot(df_observers, aes(x = Type, y = Total_score, fill = Type)) +
  stat_summary(fun = mean, geom = "bar", width = 0.6) +
  stat_summary(fun.data = mean_cl_boot, geom = "errorbar", width = 0.2) +
  scale_fill_manual(values = c("HC" = "#5B9BD5", "SZ" = "#ED7D31")) +
  scale_x_discrete(labels = c("HC" = "Healthy controls", "SZ" = "Schizophrenia")) +
  labs(x = NULL, y = "Total first impression score") +
  theme_minimal() +
  theme(legend.position = "none")

ggsave(file.path(RESULTS_PATH, "impressions_total.png"),
       p_total, width = 5, height = 5, dpi = 300)

# --- By item ---
item_labels <- c(
  Attractive  = "Attractive",  Awkward_r   = "Awkward (r)",
  Intelligent = "Intelligent", Likeable    = "Likeable",
  Trustworthy = "Trustworthy", Dominant    = "Dominant",
  Conversation = "Conversation", Time      = "Time",
  LiveNearby  = "Live nearby", SitNext    = "Sit next"
)

p_items <- ggplot(df_long_items, aes(x = Item, y = Score, fill = Type)) +
  stat_summary(fun = mean, geom = "bar",
               position = position_dodge(width = 0.8), width = 0.7) +
  stat_summary(fun.data = mean_cl_boot, geom = "errorbar",
               position = position_dodge(width = 0.8), width = 0.2) +
  scale_fill_manual(values = c("HC" = "#5B9BD5", "SZ" = "#ED7D31"),
                    labels = c("HC" = "Healthy controls",
                               "SZ" = "Schizophrenia")) +
  scale_x_discrete(labels = item_labels) +
  labs(x = NULL, y = "Mean score", fill = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")

ggsave(file.path(RESULTS_PATH, "impressions_by_item.png"),
       p_items, width = 10, height = 6, dpi = 300)

cat("Figures saved to results/\n")
