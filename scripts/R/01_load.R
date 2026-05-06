# =============================================================================
# 01_load.R — Load all raw MINSAL data files. No transformations.
#
# Produces (in pipeline_env):
#   raw_stats_list      — named list of 12 data.frames (one per year sheet)
#   raw_dotacion_snss   — SNSS bed capacity (wide, years 2010-2025)
#   raw_establecimientos — DEIS hospital registry
# =============================================================================

library(here)
library(readxl)

if (!exists("OUT_DIR", inherits = FALSE)) OUT_DIR <- here("scripts", "R", "_outputs")

DATA_DIR <- here("data")

# ── Helper: read one stats sheet ─────────────────────────────────────────────
# skip=2 skips the blank row + title row; row 3 becomes the header.
read_stats_sheet <- function(path, sheet) {
  df <- read_excel(path, sheet = sheet, skip = 2,
                   col_types = "text",   # read everything as text first
                   .name_repair = "minimal")
  # Drop entirely-empty trailing columns (artefact of Excel formatting)
  df <- df[, colSums(!is.na(df)) > 0, drop = FALSE]
  df
}

# ── 1. Monthly hospital statistics 2014–2023 (10 sheets) ─────────────────────
path_2014_2023 <- file.path(DATA_DIR,
  "Consolidado Estadísticas Hospitalarias 2014-2023.xlsx")

sheets_main <- as.character(2014:2023)
raw_stats_list <- setNames(
  lapply(sheets_main, function(yr)
    read_stats_sheet(path_2014_2023, sheet = yr)),
  sheets_main
)
message("Loaded ", length(raw_stats_list), " sheets from 2014-2023 file.")

# ── 2. Monthly statistics 2024 (Jan–Oct) ────────────────────────────────────
path_2024 <- file.path(DATA_DIR, "Estadísticas Hospitalarias Octubre 2024.xlsx")
raw_stats_list[["2024"]] <- read_stats_sheet(path_2024, sheet = "Corte_Octubre")
message("Loaded 2024 sheet (Jan–Oct).")

# ── 3. Monthly statistics 2025 (Jan–Nov) ────────────────────────────────────
path_2025 <- file.path(DATA_DIR,
  "Estadísticas Hospitalarias Noviembre 2025.xlsx")
raw_stats_list[["2025"]] <- read_stats_sheet(path_2025, sheet = "Corte_Noviembre")
message("Loaded 2025 sheet (Jan–Nov).")

message("raw_stats_list: ", length(raw_stats_list), " year frames, years ",
        paste(names(raw_stats_list), collapse = ", "))

# ── 4. SNSS bed capacity 2010–2025 ───────────────────────────────────────────
path_dotacion <- file.path(DATA_DIR,
  "Dotación de camas 2010-2025 Establecimientos Pertenecientes al SNSS_01-12-2025.xlsx")
# skip=2: row 1 = title, row 2 = "Fuente: DEIS", row 3 = header
raw_dotacion_snss <- read_excel(path_dotacion, sheet = "2010-2025",
                                skip = 2, col_types = "text",
                                .name_repair = "minimal")
raw_dotacion_snss <- raw_dotacion_snss[,
  colSums(!is.na(raw_dotacion_snss)) > 0, drop = FALSE]
message("Loaded SNSS bed capacity: ", nrow(raw_dotacion_snss),
        " rows x ", ncol(raw_dotacion_snss), " cols.")

# ── 5. DEIS hospital registry ────────────────────────────────────────────────
path_estab <- file.path(DATA_DIR,
  "Establecimientos DEIS MINSAL 20-08-2024.xlsx")
# skip=1: row 1 = "BASE_ESTABLECIMIENTO_2024-08-20" title, row 2 = header
raw_establecimientos <- read_excel(
  path_estab,
  sheet = "BASE_ESTABLECIMIENTO_2024-08-20",
  skip = 1,
  col_types = "text",
  .name_repair = "minimal"
)
# Trim all column names (some have trailing/extra spaces)
names(raw_establecimientos) <- trimws(names(raw_establecimientos))
raw_establecimientos <- raw_establecimientos[,
  colSums(!is.na(raw_establecimientos)) > 0, drop = FALSE]
message("Loaded DEIS registry: ", nrow(raw_establecimientos),
        " rows x ", ncol(raw_establecimientos), " cols.")

# ── Save raw snapshots ────────────────────────────────────────────────────────
saveRDS(raw_stats_list,      file.path(OUT_DIR, "raw_stats_list.rds"))
saveRDS(raw_dotacion_snss,   file.path(OUT_DIR, "raw_dotacion_snss.rds"))
saveRDS(raw_establecimientos, file.path(OUT_DIR, "raw_establecimientos.rds"))

message("01_load.R complete.")
