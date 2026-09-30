# R/04_plots.R
# ============================================================
# Minimal plotting module for stacked daily data entry bars
# ============================================================

library(ggplot2)
library(dplyr)
library(scales)
library(lubridate)
library(glue)

# ── Brand colours ────────────────────────────────────────────
KEMRI_BLUE   <- "#003087"
KEMRI_TEAL   <- "#00A499"
KEMRI_LBLUE  <- "#6CACE4"
KEMRI_DGREY  <- "#333333"
KEMRI_LGREY  <- "#F2F2F2"
KEMRI_ORANGE <- "#E8772E"

# ── Base theme (no legend by default) ──────────────────────
theme_kemri <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      text               = element_text(family = "Liberation Sans", colour = KEMRI_DGREY),
      plot.title         = element_text(size = rel(1.25), face = "bold", colour = KEMRI_BLUE,
                                        margin = margin(b = 6)),
      plot.subtitle      = element_text(size = rel(0.90), colour = "#555555",
                                        margin = margin(b = 10)),
      plot.caption       = element_text(size = rel(0.72), colour = "#888888",
                                        hjust = 0, margin = margin(t = 8)),
      plot.background    = element_rect(fill = "white", colour = NA),
      panel.background   = element_rect(fill = "white", colour = NA),
      panel.grid.major.y = element_line(colour = KEMRI_LGREY, linewidth = 0.45),
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      axis.title.x       = element_blank(),
      axis.title.y       = element_text(size = rel(0.82), colour = KEMRI_DGREY,
                                        margin = margin(r = 6)),
      axis.text.x        = element_text(size = rel(0.76), colour = KEMRI_DGREY,
                                        angle = 45, hjust = 1, vjust = 1),
      axis.text.y        = element_text(size = rel(0.80), colour = KEMRI_DGREY),
      axis.ticks         = element_blank(),
      legend.position    = "none",   # default: off, turned on in stacked plot
      plot.margin        = margin(12, 16, 8, 12)
    )
}

# ── Human‑friendly x‑axis date labels ──────────────────────
fmt_date_axis <- function(x) {
  paste0(
    substr(weekdays(x, abbreviate = TRUE), 1, 3), " ",
    day(x), " ",
    substr(month(x, label = TRUE, abbr = TRUE), 1, 3)
  )
}

# ── Simplified stacked bar chart by document_source ──────
# ── Stacked bar chart, no gaps, one label per bar ────────────
plot_daily_stacked <- function(data,
                               hospital_id,
                               window = 30,
                               source_colours = c("MAR" = "#003087",
                                                  "Free Text" = "#6CACE4",
                                                  "Both MAR and Freetext" = "#00A499")) {

  # 1. Filter to hospital, keep last 'window' working days
  df <- data |>
    filter(hosp_id == hospital_id) |>
    arrange(work_date) |>
    slice_tail(n = window) |>
    mutate(work_date = as.Date(work_date))

  if (nrow(df) == 0) {
    message(glue("No data for {hospital_id} in the last {window} days"))
    return(NULL)
  }

  # 2. Assign a unique, sequential x_pos per date (no gaps)
  df <- df |>
    mutate(x_pos = as.numeric(factor(work_date, levels = unique(work_date))))

  # 3. Compute daily total for label
  df_plot <- df |>
    group_by(work_date, x_pos) |>
    mutate(total = sum(records_entered, na.rm = TRUE)) |>
    ungroup()

  # 4. Build plot
  ggplot(df_plot, aes(x = x_pos, y = records_entered)) +
    geom_col(aes(fill = document_source), width = 0.8, position = "stack") +
    geom_text(
      data = df_plot |> distinct(x_pos, total),
      aes(x = x_pos, y = total, label = ifelse(total > 0, total, "")),
      vjust = -0.4, size = 3.2, fontface = "bold", colour = "#333333"
    ) +
    scale_fill_manual(values = source_colours) +
    scale_x_continuous(
      breaks = df_plot |> distinct(x_pos) |> pull(x_pos),
      labels = fmt_date_axis(df_plot |> distinct(x_pos, work_date) |> arrange(x_pos) |> pull(work_date)),
      expand = expansion(add = 0.6)
    ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(
      title    = glue("Daily Data Entry by Source — {hospital_id}"),
      subtitle = glue(
        "{sum(df_plot$records_entered)} records over {n_distinct(df_plot$work_date)} days"
      ),
      y        = "Records entered",
      fill     = "Document source"
    ) +
    theme_kemri() +
    theme(
      legend.position = "bottom",
      legend.title    = element_text(size = rel(0.8)),
      legend.text     = element_text(size = rel(0.75)),
      axis.text.x     = element_text(angle = 45, hjust = 1, vjust = 1)
    )
}