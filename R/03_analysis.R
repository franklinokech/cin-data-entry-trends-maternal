# R/03_analysis.R
# ============================================================
# Analysis — joins calendar spine with REDCap extract
# Produces:
#   progress_daily    (hosp_id × working_day, one row per pair)
#   hospital_summary  (one row per hospital)
#   hospital_monthly  (one row per hospital × month)
# ============================================================

library(dplyr)
library(tidyr)
library(lubridate)
library(glue)

# ── Guard: upstream objects must exist ───────────────────────
stopifnot(
  exists("redcap_clean"),    # from 01_extract_redcap.R
  exists("project_calendar") # from 02_calendar_dimension.R
)

# ============================================================
# 3.1  DAILY COUNTS per hospital from REDCap
# ============================================================

daily_counts <- redcap_clean |>
  filter(has_entry_date) |>
  count(hosp_id, entry_date, name = "records_entered")

# ============================================================
# 3.2  FULL SPINE  — every hospital × every working day
# ============================================================

all_hospitals <- redcap_clean |>
  filter(!is.na(hosp_id), hosp_id != "") |>
  distinct(hosp_id)

# ── CHANGED: rename date → work_date here so all downstream
#             objects use a consistent, unambiguous name
all_workdays <- project_calendar |>
  select(
    work_date  = date,        # ← rename at selection
    year_month,
    month_abbr,
    year
  )

full_spine <- all_hospitals |>
  cross_join(all_workdays)


# ============================================================
# 3.3  BUILD progress_daily
# ============================================================

progress_daily <- full_spine |>
  left_join(
    daily_counts,
    by = c("hosp_id", "work_date" = "entry_date")   # ← was "date" = "entry_date"
  ) |>
  mutate(
    records_entered = replace_na(records_entered, 0L),
    had_entry       = records_entered > 0
  ) |>
  arrange(hosp_id, work_date)                        # ← was date


# ============================================================
# 3.4  HOSPITAL-LEVEL SUMMARY
# ============================================================

hospital_summary <- progress_daily |>
  group_by(hosp_id) |>
  summarise(
    total_records       = sum(records_entered),
    total_workdays      = n(),
    days_with_entry     = sum(had_entry),
    days_no_entry       = sum(!had_entry),

    entry_rate_pct      = round(days_with_entry / total_workdays * 100, 1),

    avg_records_per_day = round(
      ifelse(days_with_entry > 0,
             sum(records_entered[records_entered > 0]) / days_with_entry,
             0),
      1
    ),
    avg_all_days        = round(mean(records_entered), 1),

    peak_day_count      = max(records_entered),
    peak_day_date       = work_date[which.max(records_entered)],  # ← was date

    last_entry_date = if (any(had_entry)) {
      max(work_date[had_entry], na.rm = TRUE)                     # ← was date
    } else {
      as.Date(NA)
    },
    days_since_entry = if (any(had_entry)) {
      as.integer(Sys.Date() - max(work_date[had_entry], na.rm = TRUE))  # ← was date
    } else {
      NA_integer_
    },

    .groups = "drop"
  ) |>
  mutate(
    active_days          = days_with_entry,
    working_days_elapsed = total_workdays,

    status = case_when(
      is.na(days_since_entry) ~ "Never Entered",
      days_since_entry <= 3   ~ "Active",
      days_since_entry <= 7   ~ "Slow",
      days_since_entry <= 14  ~ "Stalled",
      TRUE                    ~ "Inactive"
    ),
    status = factor(
      status,
      levels = c("Active", "Slow", "Stalled", "Inactive", "Never Entered")
    ),
    status_color = case_when(
      status == "Active"        ~ "#00A499",
      status == "Slow"          ~ "#6CACE4",
      status == "Stalled"       ~ "#FFA500",
      status == "Inactive"      ~ "#CC0000",
      status == "Never Entered" ~ "#888888"
    )
  ) |>
  arrange(desc(total_records))


# ============================================================
# 3.5  MONTHLY SUMMARY per hospital
# ============================================================

hospital_monthly <- progress_daily |>
  group_by(hosp_id, year_month, month_abbr, year) |>
  summarise(
    records_entered = sum(records_entered),
    workdays        = n(),
    active_days     = sum(had_entry),
    .groups         = "drop"
  ) |>
  mutate(
    completion_pct = round(active_days / workdays * 100, 1),
    month          = as.Date(paste0(year_month, "-01"))
  ) |>
  arrange(hosp_id, month)

