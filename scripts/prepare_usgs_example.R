# Instructor-only preparation. Participants use the included cleaned CSV.
# This is not sourced by app.R: launching the app never needs the master data.
prepare_usgs_example <- function(source_file, output_file = "data/example_sites.csv") {
  if (!file.exists(source_file)) stop("Source CSV not found: ", source_file)
  # Read as text to preserve identifiers and the source's numeric precision.
  d <- read.csv(source_file, colClasses = "character", check.names = FALSE,
                stringsAsFactors = FALSE, na.strings = NULL)
  drop <- c("sizer_bandwidth", "section", "section_start", "section_end",
    "section_duration", "segment_position", "segment_behavior", "inflection_point",
    "inflection_points", "test_p_value", "r_squared", "sizer_slope_type",
    "slope_estimate", "slope_std_error", "slope_shape", "cq_model_class",
    "threshold_response", "low_flow_slope", "high_flow_slope", "low_flow_behavior",
    "high_flow_behavior", "nobs")
  if (!"Stream_ID" %in% names(d)) stop("Missing Stream_ID column.")
  if (!all(drop %in% names(d))) stop("Source schema changed; review the exclusion list.")
  d <- d[startsWith(d$Stream_ID, "USGS"), !names(d) %in% drop, drop = FALSE]
  d <- unique(d)  # Only completely identical rows are collapsed.
  if (!nrow(d)) stop("No USGS-prefixed records found.")
  if (anyDuplicated(d$Stream_ID)) stop("Some sites have differing retained rows; review before use.")
  if (!"basin_slope" %in% names(d)) stop("Expected watershed slope was not retained.")
  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  write.csv(d, output_file, row.names = FALSE, na = "NA")
  message("Wrote ", nrow(d), " sites and ", ncol(d), " columns to ", output_file)
  invisible(d)
}
