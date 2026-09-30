# R/03_analysis.R
# ============================================================
# Analysis — functions to build daily progress data
# Provides:
#   build_progress_daily_source()
#   build_progress_daily()
#   build_hospital_summary()
#   build_hospital_monthly()
# 
# Automatically builds objects when sourced (Option A)
# ============================================================

library(dplyr)
library(tidyr)
library(lubridate)
library(glue)

# ── Helper functions ────────────────────────────────────────

get_daily_source_counts <- function(redcap_clean) {
  redcap_clean |>
    filter(has_entry_date, !is.na(document_source)) |>
    count(hosp_id, entry_date, document_source, name = "records_entered")
}

get_all_hospitals <- function(redcap_clean) {
  redcap_clean |>
    filter(!is.na(hosp_id), hosp_id != "") |>
    distinct(hosp_id)
}

get_all_workdays <- function(project_calendar) {
  project_calendar |>
    select(work_date = date, year_month, month_abbr, year)
}

get_all_sources <- function(redcap_clean) {
  tibble(document_source = levels(redcap_clean$document_source))
}

build_full_spine_source <- function(redcap_clean, project_calendar) {
  all_hospitals <- get_all_hospitals(redcap_clean)
  all_workdays  <- get_all_workdays(project_calendar)
  all_sources   <- get_all_sources(redcap_clean)
  
  all_hospitals |>
    cross_join(all_workdays) |>
    cross_join(all_sources)
}

#' Build source-level daily records for stacked bar plots
#' @param redcap_clean data frame from 01_extract_redcap.R
#' @param project_calendar data frame from 02_calendar_dimension.R
#' @return tibble with columns: hosp_id, work_date, year_month, month_abbr, year, document_source, records_entered, had_entry
build_progress_daily_source <- function(redcap_clean, project_calendar) {
  
  # 1. Ensure document_source is a factor
  if (!is.factor(redcap_clean$document_source)) {
    redcap_clean$document_source <- factor(redcap_clean$document_source)
  }
  
  # 2. Daily counts per hospital + source
  daily_counts <- redcap_clean |>
    filter(has_entry_date, !is.na(document_source)) |>
    count(hosp_id, entry_date, document_source, name = "records_entered")
  
  # 3. All hospitals
  all_hospitals <- redcap_clean |>
    filter(!is.na(hosp_id), hosp_id != "") |>
    distinct(hosp_id)
  
  # 4. All workdays (rename date → work_date)
  all_workdays <- project_calendar |>
    select(work_date = date, year_month, month_abbr, year)
  
  # 5. All source levels – with a fallback if levels are missing
  src_levels <- levels(redcap_clean$document_source)
  if (length(src_levels) == 0) {
    stop("No levels found for document_source. Ensure it is a factor with defined levels.")
  }
  all_sources <- tibble(document_source = src_levels)
  
  # 6. Full spine
  full_spine <- all_hospitals |>
    cross_join(all_workdays) |>
    cross_join(all_sources)
  
  # 7. Join and fill zeros
  result <- full_spine |>
    left_join(daily_counts,
              by = c("hosp_id", "work_date" = "entry_date", "document_source")) |>
    mutate(
      records_entered = replace_na(records_entered, 0L),
      had_entry = records_entered > 0
    ) |>
    arrange(hosp_id, work_date, document_source)
  
  # Optional: warn if the result is empty
  if (nrow(result) == 0) {
    warning("build_progress_daily_source() returned 0 rows – check your calendar or hospital list.")
  }
  
  return(result)
}

#' Build total daily records (aggregated over sources)
build_progress_daily <- function(progress_daily_source) {
  progress_daily_source |>
    group_by(hosp_id, work_date, year_month, month_abbr, year) |>
    summarise(
      records_entered = sum(records_entered, na.rm = TRUE),
      had_entry       = any(had_entry, na.rm = TRUE),
      .groups = "drop"
    )
}

#' Build hospital summary
build_hospital_summary <- function(progress_daily) {
  progress_daily |>
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
      peak_day_date       = work_date[which.max(records_entered)],
      last_entry_date = if (any(had_entry)) {
        max(work_date[had_entry], na.rm = TRUE)
      } else {
        as.Date(NA)
      },
      days_since_entry = if (any(had_entry)) {
        as.integer(Sys.Date() - max(work_date[had_entry], na.rm = TRUE))
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
}

#' Build monthly summary per hospital
build_hospital_monthly <- function(progress_daily) {
  progress_daily |>
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
}

# ── AUTOMATIC BUILD (Option A) ──────────────────────────────
# This runs when the script is sourced – even in non-interactive mode.
# It builds all required objects if the inputs exist.

if (exists("redcap_clean") && exists("project_calendar")) {
  
  progress_daily_source <- build_progress_daily_source(redcap_clean, project_calendar)
  progress_daily        <- build_progress_daily(progress_daily_source)
  hospital_summary      <- build_hospital_summary(progress_daily)
  hospital_monthly      <- build_hospital_monthly(progress_daily)
  
  message(glue(
    "✅ Built progress_daily_source: {nrow(progress_daily_source)} rows\n",
    "   progress_daily: {nrow(progress_daily)} rows\n",
    "   hospital_summary: {nrow(hospital_summary)} hospitals"
  ))
  
} else {
  message("⚠️  Objects 'redcap_clean' and/or 'project_calendar' not found. Run 01_extract_redcap.R and 02_calendar_dimension.R first.")
}