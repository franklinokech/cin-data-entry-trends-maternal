# R/01_extract_redcap.R
# ============================================================
# Extract mothers_details form from REDCap
# Variables: record_id, hosp_id, datetime_entry
# ============================================================

library(REDCapR)
library(tidyverse)

library(dotenv)
library(here)
library(glue)

# ── Credentials (use environment variables - never hardcode) ──
dotenv::load_dot_env()
REDCAP_URI   <- Sys.getenv("REDCAP_URI")    # e.g. "https://redcap.kemri-wellcome.org/api/"
REDCAP_TOKEN <- Sys.getenv("REDCAP_TOKEN")  # Your project API token
REDCAP_TOKEN_PUMWANI <- Sys.getenv("REDCAP_TOKEN_PUMWANI")  # Pumwani token

# ── Date filters from environment ────────────────────────────
START_DATE <- Sys.getenv("START_DATE")  # e.g. "2024-01-01"
END_DATE   <- Sys.getenv("END_DATE")    # e.g. "2024-12-31"

# Convert to POSIXct
start_dt <- if(START_DATE != "") as.POSIXct(START_DATE, tz = "Africa/Nairobi") else as.POSIXct(NA)
end_dt   <- if(END_DATE != "") as.POSIXct(END_DATE, tz = "Africa/Nairobi") else as.POSIXct(NA)

# ── Extract mothers_details from MAIN project ──────────────
redcap_raw_main <- redcap_read(
  redcap_uri               = REDCAP_URI,
  token                    = REDCAP_TOKEN,
  forms                    = "mothers_details",
  raw_or_label             = "label",
  raw_or_label_headers     = "raw",
  export_survey_fields     = FALSE,
  export_data_access_groups = FALSE,
  guess_type = FALSE,
  datetime_range_begin     = start_dt,
  datetime_range_end       = end_dt
)$data

# ── Extract mothers_details from PUMWANI project ──────────
redcap_raw_pumwani <- redcap_read(
  redcap_uri               = "https://hsu.kemri-wellcome.org/redcap/api/",
  token                    = REDCAP_TOKEN_PUMWANI,
  forms                    = "mothers_details",
  raw_or_label             = "label",
  raw_or_label_headers     = "raw",
  export_survey_fields     = FALSE,
  export_data_access_groups = FALSE,
  guess_type = FALSE,
  datetime_range_begin     = start_dt,
  datetime_range_end       = end_dt
)$data

# ── Combine both datasets ──────────────────────────────────
redcap_raw <- bind_rows(redcap_raw_main, redcap_raw_pumwani)

# ── Clean & parse dates ─────────────────────────────────────
redcap_clean <- redcap_raw |>
  rename(
    entry_datetime = datetime_entry        # rename for clarity
  ) |>
  mutate(
    # Parse datetime — adjust format to match your REDCap config
    entry_datetime = ymd_hms(entry_datetime, tz = "Africa/Nairobi", quiet = TRUE),

    # Extract date component only
    entry_date     = as_date(entry_datetime),

    # Extract time component
    entry_time     = format(entry_datetime, "%H:%M"),

    # Clean hospital ID — remove leading/trailing spaces
    hosp_id        = str_squish(hosp_id),

    # Flag incomplete records (datetime is NA)
    has_entry_date = !is.na(entry_date)
  ) |>
  filter(!is.na(record_id)) |>            # remove empty rows
  select(
    record_id,
    hosp_id,
    entry_datetime,
    entry_date,
    entry_time,
    has_entry_date
  )

message(glue(
  "Clean records: {nrow(redcap_clean)} | ",
  "Records with valid dates: {sum(redcap_clean$has_entry_date)}"
))

# Show date range of extracted data
if(nrow(redcap_clean) > 0) {
  message(glue(
    "Date range: {min(redcap_clean$entry_date, na.rm = TRUE)} to {max(redcap_clean$entry_date, na.rm = TRUE)}"
  ))
}
