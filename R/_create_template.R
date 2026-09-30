# create_branded_template.R
# Corrected version with proper placeholder types

library(officer)
library(magrittr)

# Ensure assets/ exists
if (!dir.exists("assets")) dir.create("assets", recursive = TRUE)

# Define KEMRI brand colors
kemri_colors <- list(
  primary = "#003366",      # Dark blue
  secondary = "#4A90D9",    # Light blue
  accent = "#F68B1F",       # Orange
  text = "#333333",         # Dark gray
  white = "#FFFFFF",
  light_gray = "#F5F5F5",
  dark_gray = "#666666"
)

# Create a blank PowerPoint template
ppt <- read_pptx() |>
  
  # ---- TITLE SLIDE ----
  add_slide(layout = "Title Slide") |>
  ph_with(
    value = "KEMRI Wellcome Trust",
    location = ph_location_type(type = "ctrTitle")
  ) |>
  ph_with(
    value = "Data Management Unit",
    location = ph_location_type(type = "subTitle")
  ) |>
  ph_with(
    value = format(Sys.Date(), "%d %B %Y"),
    location = ph_location_type(type = "dt")  # Date
  ) |>
  ph_with(
    value = "Slide 1",
    location = ph_location_type(type = "sldNum")  # Slide number
  ) |>
  
  # ---- CONTENT SLIDE ----
  add_slide(layout = "Title and Content") |>
  ph_with(
    value = "Slide Title",
    location = ph_location_type(type = "title")
  ) |>
  ph_with(
    value = "• Key point one\n• Key point two\n• Key point three",
    location = ph_location_type(type = "body")
  ) |>
  ph_with(
    value = format(Sys.Date(), "%d %B %Y"),
    location = ph_location_type(type = "dt")
  ) |>
  ph_with(
    value = "Slide 2",
    location = ph_location_type(type = "sldNum")
  ) |>
  
  # ---- TWO COLUMN ----
  add_slide(layout = "Two Content") |>
  ph_with(
    value = "Two Column Layout",
    location = ph_location_type(type = "title")
  ) |>
  ph_with(
    value = "Left column content",
    location = ph_location_left()
  ) |>
  ph_with(
    value = "Right column content",
    location = ph_location_right()
  ) |>
  ph_with(
    value = format(Sys.Date(), "%d %B %Y"),
    location = ph_location_type(type = "dt")
  ) |>
  ph_with(
    value = "Slide 3",
    location = ph_location_type(type = "sldNum")
  ) |>
  
  # ---- CHART SLIDE ----
  add_slide(layout = "Title and Content") |>
  ph_with(
    value = "Data Visualization",
    location = ph_location_type(type = "title")
  ) |>
  ph_with(
    value = "[Chart will be inserted here]",
    location = ph_location_type(type = "body")
  ) |>
  ph_with(
    value = format(Sys.Date(), "%d %B %Y"),
    location = ph_location_type(type = "dt")
  ) |>
  ph_with(
    value = "Slide 4",
    location = ph_location_type(type = "sldNum")
  )

# Create assets directory if it doesn't exist
if (!dir.exists("assets")) {
  dir.create("assets", recursive = TRUE)
}

# Save the template
print(ppt, target = "assets/template.pptx")

message("✅ KEMRI template created at: assets/template.pptx")
message("\n📋 Template layouts included:")
message("   • Title Slide (ctrTitle, subTitle)")
message("   • Title and Content (title, body)")
message("   • Two Content (title, left, right)")
message("\n📐 All slides include:")
message("   • Date (dt)")
message("   • Slide Number (sldNum)")