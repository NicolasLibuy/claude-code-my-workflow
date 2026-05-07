# =============================================================================
# 00_run_all.R — Pipeline orchestrator
# Run from repo root: Rscript scripts/R/00_run_all.R
#
# Reproducibility contract:
#   - Fixed seed set once here; propagated to all scripts via pipeline_env.
#   - All paths via here::here() — no setwd().
#   - sessionInfo() written to _outputs/ for environment verification.
# =============================================================================

suppressPackageStartupMessages({
  if (!requireNamespace("here", quietly = TRUE))
    stop("Install 'here' first: install.packages('here')")
  library(here)
})

PROJECT_SEED <- 20260506L
set.seed(PROJECT_SEED)

OUT_DIR <- here("scripts", "R", "_outputs")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

pipeline_env <- new.env(parent = globalenv())
pipeline_env$PROJECT_SEED <- PROJECT_SEED
pipeline_env$OUT_DIR      <- OUT_DIR

pipeline <- c(
  "01_load.R",
  "02_clean.R",
  "03_analyze.R",
  "04_tables.R",
  "05_figures.R",
  "06_indicator_slides.R"
)

message("Healthcare capacity pipeline — seed ", PROJECT_SEED)

timings <- vapply(pipeline, function(script) {
  path <- here("scripts", "R", script)
  if (!file.exists(path)) stop("Missing script: ", path)
  t0 <- Sys.time()
  source(path, local = pipeline_env)
  elapsed <- as.numeric(Sys.time() - t0, units = "secs")
  message(sprintf("  %s  %.1f s", script, elapsed))
  elapsed
}, numeric(1))

writeLines(capture.output(sessionInfo()),
           file.path(OUT_DIR, "sessionInfo.txt"))

outputs <- list.files(OUT_DIR, full.names = FALSE)
message("\nComplete. Total: ", sprintf("%.1f s", sum(timings)),
        " | Outputs in ", OUT_DIR)
for (f in outputs) message("  - ", f)
invisible(list(timings = timings, outputs = outputs))
