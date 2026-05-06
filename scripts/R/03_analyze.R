# =============================================================================
# 03_analyze.R — Compute all capacity indicators.
#
# Consumes: base_panel (from 02_clean.R)
# Produces:
#   panel_service_month.rds  — Level 1: hospital × service × month
#   panel_group_month.rds    — Level 2: hospital × group × month (g1/g2/g3)
#   panel_group_month.csv    — CSV copy for Stata/other linkage
# =============================================================================

library(here)
library(dplyr)
library(tidyr)
library(purrr)
library(slider)

if (!exists("base_panel", inherits = FALSE)) stop("Run 00_run_all.R")
if (!exists("OUT_DIR",    inherits = FALSE)) OUT_DIR <- here("scripts","R","_outputs")

# ── Group definitions ─────────────────────────────────────────────────────────

GROUP1_CODES <- 401L:406L   # General cancer-relevant (medical + medico-surgical + ICU adults)
GROUP2_CODES <- c(405L, 406L) # High-complexity only (ICU + intermediate adults)
GROUP3_CODES <- 401L:412L   # Broad clinical (adult + pediatric, excl. neo/obs/psych/pensionado)

EPS <- 1e-6  # denominator floor to avoid Inf

# ── Shared indicator computation function ─────────────────────────────────────
# Applied identically at service level (Level 1) and group level (Level 2).

compute_indicators <- function(df, baseline_key) {
  # baseline_key: character vector of grouping vars for z-score baseline
  # (cod_estab + cod_nivel_cuidado for L1; cod_estab + grupo for L2)

  df <- df %>%
    mutate(
      # ── Raw derived indicators ──────────────────────────────────────────
      # All computed from raw components; never from pre-reported ratios.
      occ        = dias_cama_ocup / pmax(dias_cama_disp, EPS),
      occ_sat85  = as.integer(occ > 0.85),
      occ_sat90  = as.integer(occ > 0.90),
      occ_sat95  = as.integer(occ > 0.95),
      los        = dias_estada   / pmax(num_egresos,    EPS),
      rot        = num_egresos   / pmax(prom_cama_disp, EPS),
      egr_x_cama = num_egresos   / pmax(dotacion,       EPS),
      rigidez    = occ * los,
      brecha_cap = dotacion - prom_cama_disp,
      bce        = (dotacion - prom_cama_disp) / pmax(dotacion, EPS),
      ici        = dias_cama_ocup / pmax(dotacion, EPS),
      # Set to NA where denominator was effectively 0
      occ        = if_else(dias_cama_disp <= 0, NA_real_, occ),
      los        = if_else(num_egresos    <= 0, NA_real_, los),
      rot        = if_else(prom_cama_disp <= 0, NA_real_, rot),
      egr_x_cama = if_else(dotacion       <= 0, NA_real_, egr_x_cama),
      bce        = if_else(dotacion       <= 0, NA_real_, bce),
      ici        = if_else(dotacion       <= 0, NA_real_, ici)
    )

  # ── z-score of occupancy (2014–2019 pre-COVID baseline, same calendar month)
  baseline_vars <- c(baseline_key, "month")
  baseline_stats <- df %>%
    filter(year %in% 2014L:2019L) %>%
    group_by(across(all_of(baseline_vars))) %>%
    summarise(occ_base_mean = mean(occ, na.rm = TRUE),
              occ_base_sd   = sd(occ,   na.rm = TRUE),
              .groups = "drop")

  df <- df %>%
    left_join(baseline_stats, by = baseline_vars) %>%
    mutate(
      z_occ = (occ - occ_base_mean) /
               if_else(occ_base_sd > EPS, occ_base_sd, NA_real_)
    ) %>%
    select(-occ_base_mean, -occ_base_sd)

  # ── Rolling saturation (3-month and 6-month trailing windows) ─────────────
  df <- df %>%
    arrange(across(all_of(c(baseline_key, "year", "month")))) %>%
    group_by(across(all_of(baseline_key))) %>%
    mutate(
      sp_3m = slide_dbl(occ_sat90, mean, .before = 2L, .complete = FALSE,
                        na.rm = TRUE),
      sp_6m = slide_dbl(occ_sat90, mean, .before = 5L, .complete = FALSE,
                        na.rm = TRUE)
    ) %>%
    ungroup()

  df
}

# ── Level 1: hospital × service × month ──────────────────────────────────────

message("Building Level 1 panel (hospital × service × month)...")

panel_l1 <- base_panel %>%
  mutate(
    in_g1 = cod_nivel_cuidado %in% GROUP1_CODES,
    in_g2 = cod_nivel_cuidado %in% GROUP2_CODES,
    in_g3 = cod_nivel_cuidado %in% GROUP3_CODES
  )

panel_l1 <- compute_indicators(panel_l1,
                                baseline_key = c("cod_estab", "cod_nivel_cuidado"))

message(sprintf("panel_l1: %d rows | %d hospitals | %d services",
                nrow(panel_l1),
                n_distinct(panel_l1$cod_estab),
                n_distinct(panel_l1$cod_nivel_cuidado)))

saveRDS(panel_l1, file.path(OUT_DIR, "panel_service_month.rds"))
message("Saved panel_service_month.rds")

# ── Level 2: hospital × group × month ────────────────────────────────────────

message("Building Level 2 panel (hospital × group × month)...")

group_defs <- list(g1 = GROUP1_CODES, g2 = GROUP2_CODES, g3 = GROUP3_CODES)

build_group_panel <- function(codes, label) {
  base_panel %>%
    filter(cod_nivel_cuidado %in% codes) %>%
    group_by(cod_estab, nombre_estab,
             cod_ss_deis, nombre_ss_deis,
             cod_region, nombre_region,
             cod_comuna, nombre_comuna,
             lat, lon, complejidad,
             year, month) %>%
    summarise(
      n_services     = n_distinct(cod_nivel_cuidado),
      dias_cama_disp = sum(dias_cama_disp, na.rm = TRUE),
      dias_cama_ocup = sum(dias_cama_ocup, na.rm = TRUE),
      dias_estada    = sum(dias_estada,    na.rm = TRUE),
      num_egresos    = sum(num_egresos,    na.rm = TRUE),
      prom_cama_disp = sum(prom_cama_disp, na.rm = TRUE),
      dotacion       = sum(dotacion,       na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      grupo    = label,
      # sum(all-NA, na.rm=TRUE) returns 0, not NA — treat 0 dotacion as missing
      dotacion = if_else(dotacion == 0, NA_real_, dotacion)
    )
}

panel_l2_raw <- imap_dfr(group_defs, build_group_panel)

panel_l2 <- compute_indicators(panel_l2_raw,
                                baseline_key = c("cod_estab", "grupo"))

message(sprintf("panel_l2: %d rows | %d hospitals | groups: %s",
                nrow(panel_l2),
                n_distinct(panel_l2$cod_estab),
                paste(sort(unique(panel_l2$grupo)), collapse = ", ")))

saveRDS(panel_l2, file.path(OUT_DIR, "panel_group_month.rds"))

# CSV export (for Stata/external linkage) — keep only key linkage columns + indicators
panel_l2_csv <- panel_l2 %>%
  select(cod_estab, nombre_estab, cod_ss_deis, nombre_ss_deis,
         cod_region, nombre_region, cod_comuna, nombre_comuna,
         complejidad, grupo, year, month, n_services,
         dias_cama_disp, dias_cama_ocup, dotacion, prom_cama_disp,
         num_egresos, dias_estada,
         occ, occ_sat85, occ_sat90, occ_sat95,
         z_occ, sp_3m, sp_6m,
         los, rot, egr_x_cama, rigidez,
         brecha_cap, bce, ici)

write.csv(panel_l2_csv, file.path(OUT_DIR, "panel_group_month.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

message("Saved panel_group_month.rds + panel_group_month.csv")
message("03_analyze.R complete.")
