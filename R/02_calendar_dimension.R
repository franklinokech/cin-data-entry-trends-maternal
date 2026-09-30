# R/02_calendar_dimension.R
# ============================================================
# Build a date calendar dimension
# - Covers full project period
# - Weekends REMOVED (data entry = working days only)
# - Kenya public holidays REMOVED
# ============================================================

library(dplyr)
library(lubridate)
library(tibble)
library(stringr)
library(glue)

build_calendar <- function(
    start_date,
    end_date         = Sys.Date(),
    exclude_weekends = TRUE,
    exclude_holidays = TRUE
) {

  # ── Kenya Public Holidays ─────────────────────────────────
  # Add or update as needed
  kenya_holidays <- as_date(c(
    # 2024
    "2024-01-01",   # New Year's Day
    "2024-04-19",   # Good Friday
    "2024-04-22",   # Easter Monday
    "2024-05-01",   # Labour Day
    "2024-06-01",   # Madaraka Day
    "2024-10-10",   # Huduma Day
    "2024-10-20",   # Mashujaa Day
    "2024-12-12",   # Jamhuri Day
    "2024-12-25",   # Christmas Day
    "2024-12-26",   # Boxing Day
    # 2025
    "2025-01-01",   # New Year's Day
    "2025-04-18",   # Good Friday
    "2025-04-21",   # Easter Monday
    "2025-05-01",   # Labour Day
    "2025-06-01",   # Madaraka Day
    "2025-10-10",   # Huduma Day
    "2025-10-20",   # Mashujaa Day
    "2025-12-12",   # Jamhuri Day
    "2025-12-25",   # Christmas Day
    "2025-12-26",   # Boxing Day
    # 2026
    "2026-01-01",   # New Year's Day
    "2026-04-03",   # Good Friday
    "2026-04-06",   # Easter Monday
    "2026-05-01",   # Labour Day
    "2026-06-01",   # Madaraka Day
    "2026-10-10",   # Huduma Day
    "2026-10-20",   # Mashujaa Day
    "2026-12-12",   # Jamhuri Day
    "2026-12-25",   # Christmas Day
    "2026-12-26"    # Boxing Day
  ))

  # ── Generate full date sequence ───────────────────────────
  all_dates <- tibble(
    date = seq.Date(
      from = as_date(start_date),
      to   = as_date(end_date),
      by   = "day"
    )
  ) |>
    mutate(
      year             = year(date),
      month_num        = month(date),
      month_name       = month(date, label = TRUE, abbr = FALSE),
      month_abbr       = month(date, label = TRUE, abbr = TRUE),
      week_num         = isoweek(date),
      day_of_month     = mday(date),
      day_of_week      = wday(date, label = TRUE, abbr = FALSE),
      day_abbr         = wday(date, label = TRUE, abbr = TRUE),
      day_num          = wday(date),          # 1 = Sun, 7 = Sat
      quarter          = quarter(date),
      is_weekend       = day_num %in% c(1, 7),
      is_holiday       = date %in% kenya_holidays,
      is_workday       = !is_weekend & !is_holiday,
      year_month       = format(date, "%Y-%m"),
      year_week        = paste0(year, "-W", str_pad(week_num, 2, pad = "0")),
      date_label       = format(date, "%d %b %Y")
    )

  # ── Filter to working days only ───────────────────────────
  calendar <- if (exclude_weekends && exclude_holidays) {
    all_dates |> filter(is_workday)
  } else if (exclude_weekends) {
    all_dates |> filter(!is_weekend)
  } else {
    all_dates
  }

  # ── Add cumulative working day index ─────────────────────
  calendar <- calendar |>
    arrange(date) |>
    mutate(
      workday_index    = row_number(),
      workdays_in_month = ave(
        rep(1L, n()),
        year_month,
        FUN = function(x) length(x)
      ) |> as.integer(),
      workday_of_month = ave(
        seq_len(n()),
        year_month,
        FUN = seq_along
      ) |> as.integer()
    )

  message(glue(
    "Calendar: {min(calendar$date)} to {max(calendar$date)} | ",
    "{nrow(calendar)} working days | ",
    "{nrow(all_dates) - nrow(calendar)} days excluded"
  ))

  return(calendar)
}

# ── Build calendar for your project ──────────────────────────
# !! Change start_date to your actual project start date !!
project_calendar <- build_calendar(
  start_date       = "2026-06-01",
  end_date         = Sys.Date(),
  exclude_weekends = TRUE,
  exclude_holidays = TRUE
)
