# =============================================================================
# 02_clean.R — Reshape, harmonize, and join all MINSAL data sources.
#
# Consumes: raw_stats_list, raw_dotacion_snss, raw_establecimientos
# Produces: base_panel (hospital × service × year-month, codes 401-412)
#           Saved to _outputs/base_panel.rds
# =============================================================================

library(here)
library(dplyr)
library(tidyr)
library(purrr)

if (!exists("raw_stats_list",      inherits = FALSE)) stop("Run 00_run_all.R")
if (!exists("raw_dotacion_snss",   inherits = FALSE)) stop("Run 00_run_all.R")
if (!exists("raw_establecimientos",inherits = FALSE)) stop("Run 00_run_all.R")
if (!exists("OUT_DIR",             inherits = FALSE)) OUT_DIR <- here("scripts","R","_outputs")

# ── Constants ─────────────────────────────────────────────────────────────────

MES_MAP <- c(Ene=1L,Feb=2L,Mar=3L,Abr=4L,May=5L,Jun=6L,
             Jul=7L,Ago=8L,Sep=9L,Oct=10L,Nov=11L,Dic=12L)

KEEP_GLOSAS <- c(
  "Dias Cama Disponibles",
  "Dias Cama Ocupados",
  "Dias de Estada",
  "Numero de Egresos",
  "Promedio Cama Disponibles"
)

GLOSA_NAMES <- c(
  "Dias Cama Disponibles"  = "dias_cama_disp",
  "Dias Cama Ocupados"     = "dias_cama_ocup",
  "Dias de Estada"         = "dias_estada",
  "Numero de Egresos"      = "num_egresos",
  "Promedio Cama Disponibles" = "prom_cama_disp"
)

# Relevant service codes (Groups 1–3 union = 401-412)
ALL_RELEVANT_CODES <- 401L:412L

# ── Part A: Monthly stats → long panel ───────────────────────────────────────

clean_stats_frame <- function(df_raw, yr) {
  # Identify month columns present in this sheet
  month_cols <- intersect(names(MES_MAP), names(df_raw))
  if (length(month_cols) == 0L)
    stop("No month columns found in year ", yr)

  # Coerce key id columns to integer (read as text in 01_load.R)
  df <- df_raw %>%
    mutate(
      cod_ss            = suppressWarnings(as.integer(`Cód. SS/SEREMI`)),
      cod_estab         = suppressWarnings(as.integer(`Cód. Estab.`)),
      cod_nivel_cuidado = suppressWarnings(as.integer(`Cód. Nivel Cuidado`))
    ) %>%
    # Drop aggregate rows: Cód. Estab == 0 or Cód. Nivel Cuidado == 0
    filter(!is.na(cod_estab), cod_estab != 0L,
           !is.na(cod_nivel_cuidado), cod_nivel_cuidado != 0L) %>%
    # Keep only capacity glosas
    filter(Glosa %in% KEEP_GLOSAS) %>%
    # Keep only relevant service codes
    filter(cod_nivel_cuidado %in% ALL_RELEVANT_CODES) %>%
    select(cod_ss, cod_estab,
           nombre_estab = `Nombre Establecimiento`,
           cod_nivel_cuidado,
           nombre_nivel = `Nombre Nivel Cuidado`,
           Glosa,
           all_of(month_cols))

  if (nrow(df) == 0L) {
    warning("Year ", yr, ": zero rows after filtering — check column names.")
    return(NULL)
  }

  df %>%
    # Pivot months → long
    pivot_longer(all_of(month_cols), names_to = "mes_abr", values_to = "valor") %>%
    mutate(
      year  = as.integer(yr),
      month = MES_MAP[mes_abr],
      valor = suppressWarnings(as.numeric(valor))
    ) %>%
    select(-mes_abr) %>%
    # Pivot glosa → wide (one column per variable)
    pivot_wider(
      id_cols    = c(cod_ss, cod_estab, nombre_estab, cod_nivel_cuidado,
                     nombre_nivel, year, month),
      names_from  = Glosa,
      values_from = valor
    ) %>%
    # Rename glosa columns to snake_case (explicit — any_of() is a selector, not a renamer)
    rename(
      dias_cama_disp = `Dias Cama Disponibles`,
      dias_cama_ocup = `Dias Cama Ocupados`,
      dias_estada    = `Dias de Estada`,
      num_egresos    = `Numero de Egresos`,
      prom_cama_disp = `Promedio Cama Disponibles`
    )
}

message("Reshaping monthly stats...")
stats_long <- imap(raw_stats_list, clean_stats_frame) %>%
  compact() %>%     # drop NULLs from any failed years
  bind_rows()

message("stats_long: ", nrow(stats_long), " rows | years ",
        paste(sort(unique(stats_long$year)), collapse = ", "))

# ── Part B: SNSS bed capacity → long ─────────────────────────────────────────

message("Reshaping SNSS bed capacity...")

# Column names from raw_dotacion_snss (after skip=2 in 01_load.R):
# [1] "Nombre Servicio de Salud"  [2] "Código Establecimiento"
# [3] "Tipo de Establecimiento"   [4] "Nombre Establecimiento"
# [5] "Cod. Área Funcional"       [6] "Área Funcional"
# [7..] year columns: "2010", "2011", ..., "2014*", ..., "2025"
# Trailing columns with NAs: drop them.

dot_raw <- raw_dotacion_snss

# Standardise column names defensively by position for the first 6 cols
names(dot_raw)[1:6] <- c("nombre_ss","cod_estab_dot","tipo_estab",
                          "nombre_estab_dot","cod_area","nombre_area")

# Identify year columns: "2010", "2011", ..., "2014*", ..., "2025"
year_cols <- names(dot_raw)[7:ncol(dot_raw)]
year_cols <- year_cols[grepl("^[0-9]{4}\\*?$", year_cols)]

# Fix "2014*" → "2014" in the year column names
names(dot_raw) <- gsub("\\*$", "", names(dot_raw))
year_cols      <- gsub("\\*$", "", year_cols)

# Fill down the 4 merged-cell identifier columns
dot_long <- dot_raw %>%
  fill(nombre_ss, cod_estab_dot, tipo_estab, nombre_estab_dot,
       .direction = "down") %>%
  # Convert cod_estab and cod_area to integer
  mutate(
    cod_estab_dot = suppressWarnings(as.integer(cod_estab_dot)),
    cod_area      = suppressWarnings(as.integer(cod_area))
  ) %>%
  # Exclude: Total País (cod_estab_dot is NA) and hospital totals (cod_area == 100)
  filter(!is.na(cod_estab_dot), !is.na(cod_area), cod_area != 100L) %>%
  # Keep only relevant functional areas
  filter(cod_area %in% ALL_RELEVANT_CODES) %>%
  # Pivot years → long
  pivot_longer(
    cols      = all_of(year_cols),
    names_to  = "year",
    names_transform = list(year = as.integer),
    values_to = "dotacion"
  ) %>%
  mutate(dotacion = suppressWarnings(as.numeric(dotacion))) %>%
  select(cod_estab = cod_estab_dot, cod_area, year, dotacion) %>%
  # Deduplicate: SNSS Excel can have multiple sub-rows per (estab, area, year)
  group_by(cod_estab, cod_area, year) %>%
  summarise(dotacion = mean(dotacion, na.rm = TRUE), .groups = "drop")

message("dot_long: ", nrow(dot_long), " rows | years ",
        paste(sort(unique(dot_long$year)), collapse = ", "))

# ── Part C: DEIS registry → slim crosswalk ───────────────────────────────────

message("Building DEIS crosswalk...")

estab_slim <- raw_establecimientos %>%
  transmute(
    cod_estab     = suppressWarnings(as.integer(`Código Vigente`)),
    cod_estab_old = trimws(`Código Antiguo`),
    cod_region    = suppressWarnings(as.integer(`Código Región`)),
    nombre_region = `Nombre Región`,
    cod_ss_deis   = suppressWarnings(
                      as.integer(`Código Dependencia Jerárquica (SEREMI / Servicio de Salud)`)),
    nombre_ss_deis = `Nombre Dependencia Jerárquica (SEREMI / Servicio de Salud)`,
    cod_comuna    = suppressWarnings(as.integer(`Código Comuna`)),
    nombre_comuna = `Nombre Comuna`,
    lat           = suppressWarnings(as.numeric(`LATITUD      [Grados decimales]`)),
    lon           = suppressWarnings(as.numeric(`LONGITUD [Grados decimales]`)),
    tipo_snss     = `Pertenencia al SNSS`,
    complejidad   = `Nivel de Complejidad`
  ) %>%
  filter(!is.na(cod_estab))

message("estab_slim: ", nrow(estab_slim), " facilities")

# ── Part D: Join stats + dotacion + establecimientos ─────────────────────────

message("Joining data sources...")

base_panel <- stats_long %>%
  left_join(
    dot_long,
    by = c("cod_estab", "cod_nivel_cuidado" = "cod_area", "year")
  ) %>%
  left_join(
    estab_slim,
    by = "cod_estab"
  )

# ── Coverage report ───────────────────────────────────────────────────────────

n_total      <- nrow(base_panel)
n_dot_match  <- sum(!is.na(base_panel$dotacion))
n_deis_match <- sum(!is.na(base_panel$cod_comuna))

message(sprintf(
  "Join coverage: dotacion %d/%d (%.1f%%) | DEIS commune %d/%d (%.1f%%)",
  n_dot_match,  n_total, 100 * n_dot_match  / n_total,
  n_deis_match, n_total, 100 * n_deis_match / n_total
))

# Unique hospitals in panel
n_hospitals <- n_distinct(base_panel$cod_estab)
n_months    <- n_distinct(paste(base_panel$year, base_panel$month))
message(sprintf("Panel: %d hospitals | %d year-months | %d total rows",
                n_hospitals, n_months, n_total))

saveRDS(base_panel, file.path(OUT_DIR, "base_panel.rds"))
message("Saved base_panel.rds — 02_clean.R complete.")
