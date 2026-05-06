# =============================================================================
# 04_tables.R — Summary statistics tables → LaTeX.
#
# Consumes: panel_group_month.rds
# Produces: summary_stats.tex, correlations_g1.tex
# =============================================================================

library(here)
library(dplyr)
library(tidyr)
library(knitr)

if (!exists("OUT_DIR", inherits = FALSE)) OUT_DIR <- here("scripts","R","_outputs")

panel_l2 <- readRDS(file.path(OUT_DIR, "panel_group_month.rds"))

# ── Period labels ─────────────────────────────────────────────────────────────
panel_l2 <- panel_l2 %>%
  mutate(periodo = case_when(
    year %in% 2014L:2019L ~ "Pre-COVID (2014-2019)",
    year %in% 2020L:2022L ~ "COVID (2020-2022)",
    year >= 2023L          ~ "Post-COVID (2023-2025)",
    TRUE                   ~ NA_character_
  ))

# ── Helper: summary stats for one indicator ───────────────────────────────────
summarise_var <- function(df, var) {
  df %>%
    group_by(grupo, periodo) %>%
    summarise(
      mean = mean(.data[[var]], na.rm = TRUE),
      sd   = sd(.data[[var]],   na.rm = TRUE),
      p10  = quantile(.data[[var]], 0.10, na.rm = TRUE),
      p50  = quantile(.data[[var]], 0.50, na.rm = TRUE),
      p90  = quantile(.data[[var]], 0.90, na.rm = TRUE),
      N    = sum(!is.na(.data[[var]])),
      .groups = "drop"
    ) %>%
    mutate(indicator = var)
}

INDICATORS <- c("occ","sp_6m","z_occ","dotacion","brecha_cap","bce",
                "rot","los","rigidez","ici","egr_x_cama")

summary_long <- map_dfr(INDICATORS, ~ summarise_var(panel_l2, .x))

# ── Wide table: one row per indicator × periodo, columns = groups ─────────────

make_group_table <- function(grp_label) {
  summary_long %>%
    filter(grupo == grp_label) %>%
    arrange(indicator, periodo) %>%
    transmute(
      Indicator = indicator,
      Period    = periodo,
      Mean      = sprintf("%.3f", mean),
      SD        = sprintf("%.3f", sd),
      p10       = sprintf("%.3f", p10),
      Median    = sprintf("%.3f", p50),
      p90       = sprintf("%.3f", p90),
      N         = as.character(N)
    )
}

write_tex_table <- function(df, caption, label, path) {
  tex <- kable(df, format = "latex", booktabs = TRUE,
               caption = caption, label = label,
               linesep = "")
  writeLines(as.character(tex), path)
}

write_tex_table(
  make_group_table("g1"),
  caption = "Summary statistics — Group 1 (Codes 401--406, general cancer-relevant)",
  label   = "tab:summary_g1",
  path    = file.path(OUT_DIR, "summary_g1.tex")
)

write_tex_table(
  make_group_table("g2"),
  caption = "Summary statistics — Group 2 (Codes 405--406, high-complexity)",
  label   = "tab:summary_g2",
  path    = file.path(OUT_DIR, "summary_g2.tex")
)

write_tex_table(
  make_group_table("g3"),
  caption = "Summary statistics — Group 3 (Codes 401--412, broad clinical)",
  label   = "tab:summary_g3",
  path    = file.path(OUT_DIR, "summary_g3.tex")
)

message("Wrote summary tables (g1, g2, g3).")

# ── Correlation matrix — Group 1 ─────────────────────────────────────────────
cor_vars <- c("occ","sp_6m","z_occ","los","rot","rigidez","brecha_cap","bce","ici")

cor_mat <- panel_l2 %>%
  filter(grupo == "g1") %>%
  select(all_of(cor_vars)) %>%
  cor(use = "pairwise.complete.obs") %>%
  round(3L)

cor_tex <- kable(cor_mat, format = "latex", booktabs = TRUE,
                 caption = "Pairwise correlations among capacity indicators --- Group 1",
                 label = "tab:correlations_g1")
writeLines(as.character(cor_tex), file.path(OUT_DIR, "correlations_g1.tex"))

message("Wrote correlations_g1.tex")
message("04_tables.R complete.")
