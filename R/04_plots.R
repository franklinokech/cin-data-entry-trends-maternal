# R/04_plots.R
# Simplified with median reference line

library(ggplot2)
library(dplyr)
library(scales)
library(lubridate)
library(glue)

# ── Brand colours ──────────────────────────────────────────────────────────────
KEMRI_BLUE  <- "#003087"
KEMRI_TEAL  <- "#00A499"
KEMRI_LBLUE <- "#6CACE4"
KEMRI_DGREY <- "#333333"
KEMRI_LGREY <- "#F2F2F2"
KEMRI_ORANGE <- "#E8772E"  # For reference line

# ── Base theme ─────────────────────────────────────────────────────────────────
theme_kemri <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      text               = element_text(family = "Liberation Sans",
                                        colour = KEMRI_DGREY),
      plot.title         = element_text(size = rel(1.25), face = "bold",
                                        colour = KEMRI_BLUE,
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
      legend.position    = "none",
      plot.margin        = margin(12, 16, 8, 12)
    )
}

# ── Human-friendly x-axis date labels ─────────────────────────────────────────
fmt_date_axis <- function(x) {
  paste0(
    substr(weekdays(x, abbreviate = TRUE), 1, 3), " ",
    day(x), " ",
    substr(month(x, label = TRUE, abbr = TRUE), 1, 3)
  )
}

# ── Per-hospital daily bar chart with median reference line ──────────────────
plot_daily_bars <- function(data,
                            hospital_id,
                            window     = 30,
                            bar_colour = KEMRI_TEAL) {

  # ── Slice to window ─────────────────────────────────────────────────────────
  df <- data |>
    arrange(work_date) |>
    slice_tail(n = window) |>
    mutate(
      x_pos = row_number()
    )

  if (nrow(df) == 0) {
    message(glue("plot_daily_bars: no rows for {hospital_id}"))
    return(NULL)
  }

  max_n       <- max(df$records_entered, na.rm = TRUE)
  safe_max    <- if (max_n == 0L) 1L else max_n
  n_bars      <- nrow(df)
  total_recs  <- sum(df$records_entered, na.rm = TRUE)
  active_days <- sum(df$records_entered > 0, na.rm = TRUE)
  
  # ── Calculate median ────────────────────────────────────────────────────────
  median_val <- median(df$records_entered, na.rm = TRUE)

  # ── Dynamic label size ──────────────────────────────────────────────────────
  txt_size <- dplyr::case_when(
    n_bars <= 14 ~ 3.6,
    n_bars <= 21 ~ 3.1,
    n_bars <= 31 ~ 2.7,
    TRUE         ~ 2.3
  )

  # ── Label position & ghost bars ─────────────────────────────────────────────
  df <- df |>
    mutate(
      bar_height = ifelse(records_entered == 0,
                          safe_max * 0.018,
                          records_entered),
      bar_fill   = ifelse(records_entered == 0, "#E0E0E0", bar_colour),
      lbl_text   = ifelse(records_entered > 0,
                          as.character(records_entered), ""),
      inside     = (records_entered / safe_max) >= 0.14,
      lbl_vjust  = ifelse(inside,  1.6, -0.40),
      lbl_colour = ifelse(inside, "white", KEMRI_DGREY)
    )

  # ── Subtitle ────────────────────────────────────────────────────────────────
  date_from    <- format(min(df$work_date), "%d %b %Y")
  date_to      <- format(max(df$work_date), "%d %b %Y")
  subtitle_txt <- glue(
    "{total_recs} records across {active_days} of {n_bars} working days  ",
    "({date_from} \u2013 {date_to})  |  Median: {median_val}"
  )

  # ── Plot ────────────────────────────────────────────────────────────────────
  ggplot(df, aes(x = x_pos)) +

    # bars
    geom_col(
      aes(y = bar_height, fill = I(bar_fill)),
      width = 0.82
    ) +

    # count labels (non-zero bars only)
    geom_text(
      data = filter(df, records_entered > 0),
      aes(y      = records_entered,
          label  = lbl_text,
          vjust  = lbl_vjust,
          colour = I(lbl_colour)),
      size     = txt_size,
      fontface = "bold"
    ) +

    # median reference line
    geom_hline(
      yintercept = median_val,
      color = KEMRI_ORANGE,
      size = 0.8,
      linetype = "dashed",
      alpha = 0.7
    ) +

    # x-axis labels
    scale_x_continuous(
      breaks = df$x_pos,
      labels = fmt_date_axis(df$work_date),
      expand = expansion(add = 0.6)
    ) +

    # y-axis
    scale_y_continuous(
      breaks = scales::breaks_pretty(n = 5),
      labels = scales::label_number(accuracy = 1),
      expand = expansion(mult = c(0, 0.20))
    ) +

    labs(
      title    = glue("Daily Data Entry \u2014 {hospital_id}"),
      subtitle = subtitle_txt,
      y        = "Records entered"
    ) +

    theme_kemri()
}