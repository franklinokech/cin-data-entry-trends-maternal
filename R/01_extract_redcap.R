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
# On a dev machine, .env is present and dotenv loads it into the R
# session. In the container, the environment variables are injected by
# docker-compose.yml and there is no .env file, so the load is skipped.
if (file.exists(".env")) {
  dotenv::load_dot_env()
}

REDCAP_URI           <- Sys.getenv("REDCAP_URI")
REDCAP_TOKEN         <- Sys.getenv("REDCAP_TOKEN")
REDCAP_TOKEN_PUMWANI <- Sys.getenv("REDCAP_TOKEN_PUMWANI")

# Fail fast if any required variable is missing
required <- c("REDCAP_URI", "REDCAP_TOKEN", "REDCAP_TOKEN_PUMWANI")
missing  <- required[!nzchar(Sys.getenv(required))]
if (length(missing)) {
  stop("Missing environment variables: ", paste(missing, collapse = ", "))
}

# ── Date filters from environment ────────────────────────────
START_DATE <- Sys.getenv("START_DATE")  # e.g. "2024-01-01"
END_DATE   <- Sys.getenv("END_DATE")    # e.g. "2024-12-31"

# Convert to POSIXct
start_dt <- if (START_DATE != "") as.POSIXct(START_DATE, tz = "Africa/Nairobi") else as.POSIXct(NA)
end_dt   <- if (END_DATE   != "") as.POSIXct(END_DATE,   tz = "Africa/Nairobi") else as.POSIXct(NA)

# ── Extract mothers_details from MAIN project ──────────────
redcap_raw_main <- redcap_read(
  redcap_uri                = REDCAP_URI,
  token                     = REDCAP_TOKEN,
  forms                     = "mothers_details",
  raw_or_label              = "label",
  raw_or_label_headers      = "raw",
  export_survey_fields      = FALSE,
  export_data_access_groups = FALSE,
  guess_type                = FALSE,
  datetime_range_begin      = start_dt,
  datetime_range_end        = end_dt
)$data

# ── Extract mothers_details from PUMWANI project ──────────
redcap_raw_pumwani <- redcap_read(
  redcap_uri                = REDCAP_URI,
  token                     = REDCAP_TOKEN_PUMWANI,
  forms                     = "mothers_details",
  raw_or_label              = "label",
  raw_or_label_headers      = "raw",
  export_survey_fields      = FALSE,
  export_data_access_groups = FALSE,
  guess_type                = FALSE,
  datetime_range_begin      = start_dt,
  datetime_range_end        = end_dt
)$data

# ── Combine both datasets ──────────────────────────────────
redcap_raw <- bind_rows(redcap_raw_main, redcap_raw_pumwani)

# ── Clean & parse dates ─────────────────────────────────────
redcap_clean <- redcap_raw |>
  rename(
    entry_datetime = datetime_entry
  ) |>
  mutate(
    entry_datetime  = ymd_hms(entry_datetime, tz = "Africa/Nairobi", quiet = TRUE),
    entry_date      = as_date(entry_datetime),
    entry_time      = format(entry_datetime, "%H:%M"),
    hosp_id         = str_squish(hosp_id),
    has_entry_date  = !is.na(entry_date),
    document_source = factor(
      document_source,
      levels = c("MAR", "Free Text", "Both MAR and Freetext")
    )
  ) |>
  filter(!is.na(record_id)) |>
  select(
    record_id,
    hosp_id,
    entry_datetime,
    entry_date,
    entry_time,
    has_entry_date,
    document_source
  )

message(glue(
  "Clean records: {nrow(redcap_clean)} | ",
  "Records with valid dates: {sum(redcap_clean$has_entry_date)}"
))

# Show date range of extracted data
if (nrow(redcap_clean) > 0) {
  message(glue(
    "Date range: {min(redcap_clean$entry_date, na.rm = TRUE)} to ",
    "{max(redcap_clean$entry_date, na.rm = TRUE)}"
  ))
}