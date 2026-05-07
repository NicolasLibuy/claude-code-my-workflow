# =============================================================================
# 06_indicator_slides.R — Per-indicator figures for capacity_measures.tex
#
# Consumes: panel_group_month.rds
# Produces: fig_los_trends, fig_rot_trends, fig_rigidez_trends,
#           fig_brecha_cap_trends, fig_bce_dist, fig_ici_trends,
#           fig_zocc_dist, fig_egr_x_cama_trends  (PDF + SVG each)
# =============================================================================

library(here)
library(dplyr)
library(tidyr)
library(ggplot2)

if (!exists("OUT_DIR", inherits = FALSE)) OUT_DIR <- here("scripts", "R", "_outputs")

has_svg <- requireNamespace("svglite", quietly = TRUE)

panel_l2 <- readRDS(file.path(OUT_DIR, "panel_group_month.rds"))

# ── Palette & theme (mirrors 05_figures.R) ────────────────────────────────────

primary_blue <- "#012169"
primary_gold <- "#B9975B"
neutral_gray <- "#525252"
light_bg     <- "#E8EDF5"

GRUPO_LABELS <- c(g1 = "Group 1 (401–406)",
                  g2 = "Group 2 (405–406)",
                  g3 = "Group 3 (401–412)")
GRUPO_COLORS <- c(g1 = primary_blue, g2 = "#C41E3A", g3 = primary_gold)

PERIODO_LABELS <- c(
  "Pre-COVID (2014–2019)",
  "COVID (2020–2022)",
  "Post-COVID (2023–2025)"
)

theme_hcc <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title       = element_text(face = "bold", color = primary_blue,
                                      size = base_size + 1),
      plot.subtitle    = element_text(color = neutral_gray, size = base_size - 1),
      axis.title       = element_text(color = neutral_gray),
      axis.text        = element_text(color = neutral_gray),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      panel.grid.minor = element_blank(),
      strip.text       = element_text(face = "bold", color = primary_blue)
    )
}

save_fig <- function(p, stem, width = 12, height = 5) {
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

# Shared COVID shading annotators
covid_rect <- annotate("rect",
  xmin = as.Date("2020-03-01"), xmax = as.Date("2022-10-01"),
  ymin = -Inf, ymax = Inf, fill = light_bg, alpha = 0.55)

covid_label <- function(y_pos) {
  annotate("text", x = as.Date("2021-05-01"), y = y_pos,
           label = "COVID\n2020–2022", color = neutral_gray, size = 3)
}

# Helper: build trend data (national monthly mean by group, for any indicator)
trend_data <- function(var) {
  panel_l2 %>%
    filter(!is.na(.data[[var]])) %>%
    mutate(date = as.Date(sprintf("%d-%02d-01", year, month))) %>%
    group_by(grupo, date) %>%
    summarise(mean_val = mean(.data[[var]], na.rm = TRUE), .groups = "drop") %>%
    mutate(grupo = factor(grupo, levels = names(GRUPO_LABELS),
                          labels = GRUPO_LABELS))
}

# Helper: period label
add_periodo <- function(df) {
  df %>% mutate(periodo = case_when(
    year %in% 2014L:2019L ~ PERIODO_LABELS[1],
    year %in% 2020L:2022L ~ PERIODO_LABELS[2],
    year >= 2023L          ~ PERIODO_LABELS[3],
    TRUE                   ~ NA_character_
  ) %>% factor(levels = PERIODO_LABELS))
}

# ── Helper: generic trend figure ─────────────────────────────────────────────

trend_fig <- function(var, y_label, title, subtitle = NULL,
                      hline = NULL, covid_y = NULL, width = 12, height = 5) {
  dat <- trend_data(var)
  y_range <- range(dat$mean_val, na.rm = TRUE)
  cy <- if (!is.null(covid_y)) covid_y else y_range[1] + 0.05 * diff(y_range)

  p <- ggplot(dat, aes(x = date, y = mean_val, color = grupo)) +
    covid_rect +
    covid_label(cy) +
    geom_line(linewidth = 0.7, alpha = 0.9)

  if (!is.null(hline))
    p <- p + geom_hline(yintercept = hline, linetype = "dashed",
                        color = neutral_gray, linewidth = 0.4)

  p <- p +
    scale_color_manual(values = unname(GRUPO_COLORS)) +
    labs(title = title, subtitle = subtitle, x = NULL, y = y_label) +
    theme_hcc()

  save_fig(p, paste0("fig_", var, "_trends"), width = width, height = height)
  invisible(p)
}

# Helper: generic density-by-period figure
dist_fig <- function(var, x_label, title, subtitle = NULL,
                     xlim = NULL, width = 9, height = 5) {
  dat <- panel_l2 %>%
    filter(!is.na(.data[[var]])) %>%
    add_periodo() %>%
    filter(!is.na(periodo)) %>%
    mutate(grupo = factor(grupo, levels = names(GRUPO_LABELS),
                          labels = GRUPO_LABELS))

  p <- ggplot(dat, aes(x = .data[[var]], fill = periodo, color = periodo)) +
    geom_density(alpha = 0.30, linewidth = 0.55) +
    facet_wrap(~grupo, ncol = 1) +
    scale_fill_manual(values  = c("#012169", "#C41E3A", "#B9975B")) +
    scale_color_manual(values = c("#012169", "#C41E3A", "#B9975B")) +
    labs(title = title, subtitle = subtitle, x = x_label, y = "Density") +
    theme_hcc()

  if (!is.null(xlim)) p <- p + scale_x_continuous(limits = xlim)

  save_fig(p, paste0("fig_", var, "_dist"), width = width, height = height)
  invisible(p)
}

# ── Figure: LOS ──────────────────────────────────────────────────────────────
trend_fig("los",
  y_label  = "Mean length of stay (days)",
  title    = "Average length of hospital stay by service group, Chile 2014–2025",
  subtitle = "SNSS public hospitals | days of stay per discharge",
  covid_y  = 1)

# ── Figure: Rotation ─────────────────────────────────────────────────────────
trend_fig("rot",
  y_label  = "Discharges per available bed",
  title    = "Bed rotation index by service group, Chile 2014–2025",
  subtitle = "SNSS public hospitals | discharges per average available bed per month",
  covid_y  = 0.5)

# ── Figure: Rigidez ──────────────────────────────────────────────────────────
trend_fig("rigidez",
  y_label  = "Rigidity index (occ × LOS)",
  title    = "Operational rigidity index by service group, Chile 2014–2025",
  subtitle = "SNSS public hospitals | higher = harder to free bed capacity",
  covid_y  = 1)

# ── Figure: Brecha cap (Group 1 only — absolute units) ───────────────────────
brecha_dat <- panel_l2 %>%
  filter(!is.na(brecha_cap), grupo == "g1") %>%
  mutate(date = as.Date(sprintf("%d-%02d-01", year, month))) %>%
  group_by(date) %>%
  summarise(mean_val = mean(brecha_cap, na.rm = TRUE), .groups = "drop")

fig_brecha <- ggplot(brecha_dat, aes(x = date, y = mean_val)) +
  covid_rect +
  covid_label(min(brecha_dat$mean_val, na.rm = TRUE) * 0.95) +
  geom_line(linewidth = 0.7, color = primary_blue, alpha = 0.9) +
  geom_hline(yintercept = 0, linetype = "dashed",
             color = neutral_gray, linewidth = 0.4) +
  labs(
    title    = "Capacity gap (Δ installed − available beds), Group 1",
    subtitle = "SNSS public hospitals | positive = installed beds not in operation",
    x = NULL, y = "Mean beds (installed − operational)"
  ) +
  theme_hcc()

save_fig(fig_brecha, "fig_brecha_cap_trends", width = 12, height = 5)

# ── Figure: BCE distribution by period ───────────────────────────────────────
dist_fig("bce",
  x_label  = "Effective capacity gap (BCE)",
  title    = "Distribution of relative capacity gap (BCE) by period",
  subtitle = "(dotación − prom. camas disp.) / dotación",
  xlim     = c(-0.5, 1))

# ── Figure: ICI ──────────────────────────────────────────────────────────────
trend_fig("ici",
  y_label  = "Occupied bed-days per installed bed",
  title    = "Intensity of use over installed capacity (ICI), Chile 2014–2025",
  subtitle = "SNSS public hospitals | occupied days / dotación",
  covid_y  = 0.1)

# ── Figure: z_occ distribution by period ─────────────────────────────────────
dist_fig("z_occ",
  x_label  = "Standardised occupancy (z-score)",
  title    = "Distribution of standardised occupancy (z-occ) by period",
  subtitle = "Baseline: 2014–2019, same calendar month, by hospital-group",
  xlim     = c(-4, 6))

# ── Figure: Egr × cama ───────────────────────────────────────────────────────
trend_fig("egr_x_cama",
  y_label  = "Discharges per installed bed",
  title    = "Discharges per installed bed (egr\\_x\\_cama), Chile 2014–2025",
  subtitle = "SNSS public hospitals | numéro de egresos / dotación",
  covid_y  = 0.1)

message("06_indicator_slides.R complete.")
