### data checks
# run from the project folder without opening a browser
sites <- read.csv("data/example_sites.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))
stopifnot(nrow(sites) == 109L, ncol(sites) == 152L,
          all(startsWith(sites$Stream_ID, "USGS")), !anyDuplicated(sites$Stream_ID),
          "basin_slope" %in% names(sites))

### app checks
# source constructs the app without starting a web server
app_environment <- new.env(parent = globalenv())
app <- source("app.R", local = app_environment)$value
loaded_sites <- app_environment$site_data
original_rows <- match(sites$Stream_ID, loaded_sites$Stream_ID)
stopifnot(inherits(app, "shiny.appobj"), !anyNA(original_rows))
stopifnot(isTRUE(all.equal(loaded_sites[original_rows, names(sites)], sites, tolerance = 0)))
stopifnot(!anyDuplicated(loaded_sites$Stream_ID))
stopifnot(all(vapply(loaded_sites[unname(app_environment$variables)], is.numeric, logical(1))))
stopifnot(!anyDuplicated(app_environment$group_shapes))
### numeric band checks
# ties, a constant column and missing values must produce usable groups
make_groups <- app_environment$numeric_groups
bands <- make_groups(c(0, 1, 2, 3, 4, 5, 6, 7, 8, NA), "m")
stopifnot(identical(as.integer(table(bands)), c(3L, 3L, 3L, 1L)))
stopifnot(length(levels(make_groups(c(1, 1, 1, 1, 2), "m"))) == 2L)
stopifnot(length(levels(make_groups(rep(5, 4), "m"))) == 1L)
stopifnot(as.character(make_groups(c(NA_real_, Inf), "m"))[1] == "Not available")

chemistry_columns <- app_environment$chemistry_columns
if (length(chemistry_columns) > 0) {
  stopifnot(nrow(loaded_sites) == 112L, length(chemistry_columns) == 38L)
  stopifnot(length(intersect(unname(app_environment$variables), chemistry_columns)) == 16L)
  stopifnot(all(c("Mean NO3 [uM]", "Mean NOx [uM]", "Mean NO2 [uM]", "Mean pH") %in% chemistry_columns))
  stopifnot(!any(c("mean_chloride_mg_L", "mean_nitrate_mg_L", "hydroviz_site_id") %in% names(loaded_sites)))
  stopifnot(sum(loaded_sites$discharge_n_days) == 1529475L)
  stopifnot(sum(loaded_sites$discharge_source_records) == 1825601L)
  stopifnot(sum(loaded_sites$discharge_conflicting_days) == 3923L)
}

shiny::testServer(app_environment$server, {
  session$setInputs(group_by = app_environment$columns[["group"]], climate = "All groups",
                    xvar = "precip", yvar = "temp", histvar = "precip")
  expected_map <- sum(is.finite(loaded_sites$Latitude) & is.finite(loaded_sites$Longitude))
  stopifnot(nrow(filtered_sites()) == nrow(loaded_sites))
  stopifnot(nrow(scatter_sites()) == 109L, nrow(histogram_sites()) == 109L)
  stopifnot(nrow(mapped_sites()) == expected_map)
  stopifnot(output$counts == sprintf("%s sites selected", nrow(loaded_sites)))

  # every point has its own site identifier and selected values on hover
  scatter <- jsonlite::fromJSON(output$scatter, simplifyVector = FALSE)
  scatter_text <- unlist(lapply(scatter$x$data, function(trace) trace$text))
  stopifnot(length(scatter_text) == 109L)
  stopifnot(all(vapply(scatter_sites()$Stream_ID, function(id) {
    any(grepl(id, scatter_text, fixed = TRUE))
  }, logical(1))))
  stopifnot(all(grepl("Precipitation [mm/day]:", scatter_text, fixed = TRUE)))
  stopifnot(all(grepl("Temperature [°C]:", scatter_text, fixed = TRUE)))

  # histogram counts and site assignments use the same original bin boundaries
  histogram <- jsonlite::fromJSON(output$histogram, simplifyVector = FALSE)
  bars <- histogram$x$data
  counts <- Reduce(`+`, lapply(bars, function(trace) unlist(trace$y)))
  original <- ggplot2::ggplot_build(
    ggplot2::ggplot(histogram_sites(), ggplot2::aes(x = precip)) +
      ggplot2::geom_histogram(bins = 20)
  )$data[[1]]
  assigned <- cut(histogram_sites()$precip,
                  breaks = c(original$xmin[1], original$xmax),
                  include.lowest = TRUE, labels = FALSE)
  stopifnot(all(counts == original$count), sum(counts) == 109L)
  stopifnot(all(tabulate(assigned, nbins = length(counts)) == counts))

  # neutral bars show all sites in the bin regardless of climate group
  stopifnot(length(bars) == 1L, isFALSE(histogram$x$layout$showlegend))
  stopifnot(bars[[1]]$marker$color == plotly::toRGB("#8a8f94"))
  for (i in seq_along(counts)) {
    tooltip <- bars[[1]]$text[[i]]
    stopifnot(grepl(paste0("Sites: ", counts[i], "<br>"), tooltip, fixed = TRUE))
    ids <- histogram_sites()$Stream_ID[assigned == i]
    tooltip <- gsub("[[:space:]]+", " ", gsub("<br>", " ", tooltip, fixed = TRUE))
    for (id in head(ids, 3)) {
      id <- gsub("[[:space:]]+", " ", htmltools::htmlEscape(id))
      stopifnot(grepl(id, tooltip, fixed = TRUE))
    }
  }
  # the map includes every selected site with coordinates
  map <- jsonlite::fromJSON(output$site_map, simplifyVector = FALSE)
  markers <- Filter(function(call) call$method == "addCircleMarkers", map$x$calls)[[1]]
  stopifnot(length(markers$args[[1]]) == expected_map)

  session$setInputs(climate = "Humid Continental")
  stopifnot(nrow(filtered_sites()) == 34L, nrow(mapped_sites()) == 34L)
  stopifnot(all(scatter_sites()$KG_Class == "Humid Continental"))
  histogram <- jsonlite::fromJSON(output$histogram, simplifyVector = FALSE)
  stopifnot(length(histogram$x$data) == 1L)
  stopifnot(sum(unlist(histogram$x$data[[1]]$y)) == 34L)
  stopifnot(histogram$x$data[[1]]$marker$color == plotly::toRGB("#8a8f94"))

  # missing plot values do not remove sites from the map
  session$setInputs(climate = "All groups", xvar = "drainage_area", histvar = "drainage_area")
  stopifnot(nrow(scatter_sites()) == 108L)
  stopifnot(nrow(histogram_sites()) == sum(is.finite(loaded_sites$drainage_area)))
  stopifnot(nrow(mapped_sites()) == expected_map)

  # render representative added measurements with different coverage and units
  examples <- c("mean_discharge_m3_s", "Mean Cl [uM]", "Mean NO3 [uM]", "Mean pH")
  for (column in intersect(examples, names(loaded_sites))) {
    session$setInputs(xvar = column, yvar = column, histvar = column)
    expected <- sum(is.finite(loaded_sites[[column]]))
    stopifnot(nrow(scatter_sites()) == expected, nrow(histogram_sites()) == expected)
    scatter <- jsonlite::fromJSON(output$scatter, simplifyVector = FALSE)
    histogram <- jsonlite::fromJSON(output$histogram, simplifyVector = FALSE)
    stopifnot(sum(vapply(scatter$x$data, function(trace) length(trace$x), integer(1))) == expected)
    stopifnot(sum(vapply(histogram$x$data, function(trace) sum(unlist(trace$y)), numeric(1))) == expected)
    stopifnot(scatter$x$layout$hoverlabel$bgcolor == "white")
    stopifnot(histogram$x$layout$hoverlabel$bgcolor == "white")
  }

  ### daily time-series checks
  if (!is.null(app_environment$time_series_data)) {
    daily <- app_environment$time_series_data
    stopifnot(nrow(daily) == 2044404L, length(unique(daily$Stream_ID)) == 111L)
    stopifnot(length(unique(daily$parameter[daily$type == "chemistry"])) == 38L)
    stopifnot(length(app_environment$time_parameters) == 16L)
    session$setInputs(series_sites = app_environment$default_sites,
                      series_parameters = app_environment$first_parameter,
                      series_dates = c(app_environment$default_start, app_environment$default_end))
    stopifnot(output$series_counts == "2 sites selected")
    stopifnot(nrow(chemistry_observations()) > 0, nrow(discharge_observations()) > 0)
    stopifnot(length(unique(selected_observations()$Stream_ID)) == 2L)

    # dates are filtered before plotting and daily values retain their units
    window <- as.Date(c("2020-01-01", "2020-12-31"))
    parameters <- unname(app_environment$time_parameters[1:2])
    session$setInputs(series_parameters = parameters, series_dates = window)
    rows <- selected_observations()
    stopifnot(all(rows$date >= window[1] & rows$date <= window[2]))
    expected <- daily$Stream_ID %in% app_environment$default_sites &
      daily$date >= window[1] & daily$date <= window[2] &
      daily$type == "chemistry" & daily$parameter %in% parameters
    stopifnot(nrow(chemistry_observations()) == sum(expected))
    stopifnot(length(unique(chemistry_observations()$parameter)) == 2L)
    chemistry <- jsonlite::fromJSON(output$chemistry_series, simplifyVector = FALSE)
    discharge <- jsonlite::fromJSON(output$discharge_series, simplifyVector = FALSE)
    stopifnot(chemistry$x$layout$hoverlabel$bgcolor == "white")
    stopifnot(discharge$x$layout$hoverlabel$bgcolor == "white")
    stopifnot(any(grepl("uM", unlist(lapply(chemistry$x$data, function(trace) trace$text)), fixed = TRUE)))
    stopifnot(any(grepl("m³/s", unlist(lapply(discharge$x$data, function(trace) trace$text)), fixed = TRUE)))
    for (trace in chemistry$x$data) {
      stopifnot(trace$marker$color %in% plotly::toRGB(app_environment$time_colors, alpha = 1))
    }
    # actual daily records with different units remain separate panels
    mixed <- rbind(head(daily[daily$parameter == "DSi [uM]", ], 2),
                   head(daily[daily$parameter == "temp [C]", ], 2))
    stopifnot(length(unique(mixed$units)) == 2L)
    mixed_plot <- plotly::plotly_build(app_environment$draw_time_series(mixed, separate_panels = TRUE))
    panel_labels <- vapply(mixed_plot$x$layout$annotations, function(annotation) annotation$text, character(1))
    stopifnot(any(grepl("DSi [uM]", panel_labels, fixed = TRUE)))
    stopifnot(any(grepl("temp [C]", panel_labels, fixed = TRUE)))
    before <- chemistry_observations()
    session$setInputs(climate = "Humid Continental")
    stopifnot(identical(before, chemistry_observations()))
    session$setInputs(climate = "All groups")
    session$setInputs(series_sites = character(0))
    stopifnot(nrow(chemistry_observations()) == 0L, nrow(discharge_observations()) == 0L)
    session$setInputs(series_sites = app_environment$default_sites,
                      series_dates = as.Date(c("1800-01-01", "1800-12-31")))
    stopifnot(nrow(selected_observations()) == 0L)
    empty_message <- tryCatch({ output$chemistry_series; "" }, error = function(error) conditionMessage(error))
    stopifnot(grepl("No water-quality values", empty_message, fixed = TRUE))
  }

  ### grouping checks
  # grouping changes styles and rows without changing the original table
  for (column in unname(app_environment$group_by_choices)) {
    session$setInputs(group_by = column, xvar = "precip", yvar = "temp", histvar = "precip")
    stopifnot(nrow(filtered_sites()) == nrow(loaded_sites))
    settings <- grouping()
    stopifnot(!anyDuplicated(settings$colors), !anyDuplicated(settings$shapes))
    stopifnot(nrow(mapped_sites()) == expected_map)
    histogram <- jsonlite::fromJSON(output$histogram, simplifyVector = FALSE)
    stopifnot(sum(unlist(histogram$x$data[[1]]$y)) == 109L)
    stopifnot(histogram$x$data[[1]]$marker$color == plotly::toRGB("#8a8f94"))
    scatter <- jsonlite::fromJSON(output$scatter, simplifyVector = FALSE)
    stopifnot(scatter$x$layout$hoverlabel$bgcolor == "white")
    stopifnot(all(vapply(scatter$x$data, function(trace) {
      trace$marker$color %in% plotly::toRGB(settings$colors, alpha = 1)
    }, logical(1))))
    before <- settings$values
    session$setInputs(xvar = "land_cropland", log_x = TRUE)
    stopifnot(identical(grouping()$values, before))
    choice <- settings$labels[1]
    session$setInputs(climate = choice)
    stopifnot(nrow(filtered_sites()) == sum(as.character(settings$values) == choice))
    session$setInputs(log_x = FALSE)
  }
  # even a missing-value filter must reset when it also exists in the next mode
  session$setInputs(group_by = "elevation", climate = "All groups")
  if ("Not available" %in% grouping()$labels) {
    session$setInputs(climate = "Not available")
    session$setInputs(group_by = "basin_slope")
    stopifnot(nrow(filtered_sites()) == nrow(loaded_sites))
  }
  session$setInputs(group_by = app_environment$columns[["group"]], climate = "All groups")

  # test each log axis with zero and negative values without editing the csv
  original_table <- app_environment$site_data
  app_environment$site_data$precip[1:2] <- c(0, -1)
  app_environment$site_data$temp[3:4] <- c(0, -1)
  # refresh the local display copy after changing the test-only table
  session$setInputs(climate = "Humid Continental")
  session$setInputs(climate = "All groups")
  for (log_x in c(FALSE, TRUE)) {
    for (log_y in c(FALSE, TRUE)) {
      session$setInputs(climate = "All groups", xvar = "precip", yvar = "temp",
                        log_x = log_x, log_y = log_y)
      table <- app_environment$site_data
      expected <- is.finite(table$precip) & is.finite(table$temp)
      if (log_x) expected <- expected & table$precip > 0
      if (log_y) expected <- expected & table$temp > 0
      stopifnot(nrow(scatter_sites()) == sum(expected))
      scatter <- jsonlite::fromJSON(output$scatter, simplifyVector = FALSE)
      stopifnot(sum(vapply(scatter$x$data, function(trace) length(trace$x), integer(1))) == sum(expected))
      stopifnot(nrow(mapped_sites()) == expected_map)
      stopifnot(output$counts == sprintf("%s sites selected", nrow(loaded_sites)))
    }
  }
  app_environment$site_data <- original_table
  session$setInputs(log_x = FALSE, log_y = FALSE)

  if ("Not available" %in% loaded_sites$KG_Class) {
    session$setInputs(climate = "Not available", histvar = "drainage_area")
    stopifnot(nrow(filtered_sites()) == 3L, nrow(mapped_sites()) == 3L)
    histogram <- jsonlite::fromJSON(output$histogram, simplifyVector = FALSE)
    stopifnot(sum(unlist(histogram$x$data[[1]]$y)) == 3L)
    stopifnot(histogram$x$data[[1]]$marker$color == plotly::toRGB("#8a8f94"))
  }
})
message("Original data, grouping, logs, plots, maps, and selected daily time-series checks passed.")
