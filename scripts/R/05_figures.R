# =============================================================================
# 05_figures.R — Publication-ready figures → PDF + SVG.
#
# Consumes: panel_group_month.rds, panel_service_month.rds
# Produces: fig_occ_trends, fig_sp6m_dist, fig_top5_hospitals (PDF + SVG)
# =============================================================================

library(here)
library(dplyr)
library(tidyr)
library(ggplot2)

if (!exists("OUT_DIR", inherits = FALSE)) OUT_DIR <- here("scripts","R","_outputs")
if (exists("PROJECT_SEED", inherits = FALSE)) set.seed(PROJECT_SEED)

has_svg <- requireNamespace("svglite", quietly = TRUE)

panel_l2 <- readRDS(file.path(OUT_DIR, "panel_group_month.rds"))

# ── Project theme & palette ───────────────────────────────────────────────────

primary_blue  <- "#012169"
primary_gold  <- "#B9975B"
neutral_gray  <- "#525252"
light_bg      <- "#E8EDF5"

GRUPO_LABELS <- c(g1 = "Group 1: Codes 401–406",
                  g2 = "Group 2: Codes 405–406",
                  g3 = "Group 3: Codes 401–412")
GRUPO_COLORS <- c(g1 = primary_blue, g2 = "#C41E3A", g3 = primary_gold)

theme_hcc <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title       = element_text(face = "bold", color = primary_blue, size = base_size + 1),
      plot.subtitle    = element_text(color = neutral_gray, size = base_size - 1),
      axis.title       = element_text(color = neutral_gray),
      axis.text        = element_text(color = neutral_gray),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      panel.grid.minor = element_blank(),
      strip.text       = element_text(face = "bold", color = primary_blue)
    )
}

save_fig <- function(p, stem, width = 10, height = 5) {
  pdf_path <- file.path(OUT_DIR, paste0(stem, ".pdf"))
  svg_path <- file.path(OUT_DIR, paste0(stem, ".svg"))
  ggsave(pdf_path, p, width = width, height = height,
         bg = "transparent", device = grDevices::pdf)
  message("Wrote ", pdf_path)
  if (has_svg) {
    ggsave(svg_path, p, width = width, height = height,
           bg = "transparent", device = svglite::svglite)
    message("Wrote ", svg_path)
  }
}

# ── Figure 1: National average occupancy by month and group ───────────────────

occ_trend <- panel_l2 %>%
  mutate(date = as.Date(sprintf("%d-%02d-01", year, month))) %>%
  group_by(grupo, date) %>%
  summarise(mean_occ = mean(occ, na.rm = TRUE), .groups = "drop") %>%
  mutate(grupo = factor(grupo, levels = names(GRUPO_LABELS),
                        labels = GRUPO_LABELS))

fig1 <- ggplot(occ_trend, aes(x = date, y = mean_occ, color = grupo)) +
  geom_line(linewidth = 0.7, alpha = 0.9) +
  # COVID window shading
  annotate("rect",
           xmin = as.Date("2020-03-01"), xmax = as.Date("2022-10-01"),
           ymin = -Inf, ymax = Inf,
           fill = "#E8EDF5", alpha = 0.5) +
  annotate("text", x = as.Date("2021-05-01"), y = 0.05,
           label = "COVID\n2020–2022", color = neutral_gray, size = 3) +
  geom_hline(yintercept = 0.85, linetype = "dashed",
             color = neutral_gray, linewidth = 0.4) +
  geom_hline(yintercept = 0.90, linetype = "dotted",
             color = "#C41E3A", linewidth = 0.4) +
  scale_color_manual(values = unname(GRUPO_COLORS)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(NA, NA)) +
  labs(
    title    = "Hospital bed occupancy rate by service group, Chile 2014–2025",
    subtitle = "SNSS public hospitals | dashed = 85% threshold | dotted = 90% threshold",
    x = NULL, y = "Mean occupancy rate"
  ) +
  theme_hcc()

save_fig(fig1, "fig_occ_trends", width = 12, height = 5)

# ── Figure 2: Distribution of 6-month persistent saturation by group ──────────

sp6m_data <- panel_l2 %>%
  filter(!is.na(sp_6m)) %>%
  mutate(grupo = factor(grupo, levels = names(GRUPO_LABELS),
                        labels = GRUPO_LABELS))

fig2 <- ggplot(sp6m_data, aes(x = sp_6m, fill = grupo, color = grupo)) +
  geom_density(alpha = 0.25, linewidth = 0.6) +
  facet_wrap(~grupo, ncol = 1) +
  scale_fill_manual(values  = unname(GRUPO_COLORS)) +
  scale_color_manual(values = unname(GRUPO_COLORS)) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(0, 1)) +
  labs(
    title    = "Distribution of 6-month persistent saturation (sp_6m)",
    subtitle = "Fraction of prior 6 months with occupancy > 90%",
    x = "sp_6m", y = "Density"
  ) +
  theme_hcc() +
  theme(legend.position = "none")

save_fig(fig2, "fig_sp6m_dist", width = 9, height = 7)

# ── Figure 3: Top-5 most occupied hospitals (Group 1), full time series ────────

top5 <- panel_l2 %>%
  filter(grupo == "g1") %>%
  group_by(cod_estab, nombre_estab) %>%
  summarise(mean_occ = mean(occ, na.rm = TRUE), .groups = "drop") %>%
  slice_max(mean_occ, n = 5L) %>%
  pull(cod_estab)

top5_data <- panel_l2 %>%
  filter(grupo == "g1", cod_estab %in% top5) %>%
  mutate(
    date        = as.Date(sprintf("%d-%02d-01", year, month)),
    hosp_label  = paste0(cod_estab, "\n", substr(nombre_estab, 1, 30))
  )

fig3 <- ggplot(top5_data, aes(x = date, y = occ, color = hosp_label)) +
  geom_line(linewidth = 0.6, alpha = 0.85) +
  annotate("rect",
           xmin = as.Date("2020-03-01"), xmax = as.Date("2022-10-01"),
           ymin = -Inf, ymax = Inf, fill = light_bg, alpha = 0.5) +
  geom_hline(yintercept = 0.90, linetype = "dashed",
             color = neutral_gray, linewidth = 0.4) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title    = "Monthly occupancy rate — 5 highest-utilisation hospitals (Group 1)",
    subtitle = "Group 1: Codes 401–406 | dashed = 90% saturation threshold",
    x = NULL, y = "Occupancy rate", color = NULL
  ) +
  theme_hcc() +
  theme(legend.position = "right", legend.text = element_text(size = 8))

save_fig(fig3, "fig_top5_hospitals", width = 12, height = 5)

message("05_figures.R complete.")
