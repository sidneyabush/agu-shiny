### setup
# shiny has two main parts: the ui and the server
# the ui defines what people see, including menus, buttons and plot spaces
# the server contains the code that responds to choices and fills those spaces
# the setup code below prepares the data and settings used by both parts

# load the tools for page controls and updates when choices change
library(shiny)
# build plots by combining data, axes, points, bars and appearance settings
library(ggplot2)
# draw the interactive map with background tiles and site markers
library(leaflet)
# plotly adds hover details to graphs created with ggplot2
library(plotly)

### data and menu settings
# change the text below to change the large heading at the top of the app
app_title <- "Watershed explorer"

# the compare sites tab needs a csv with one row per site
# before starting the app, follow the readme commands in the rstudio console
# choose the downloaded site averages csv when the file window opens
# to use your own data, choose your own site table in that window instead
# this line reads that file path from your r session
# if no file was chosen, it uses data/example_sites.csv from the app folder
# the daily observations file is selected separately in the time series section
data_file <- Sys.getenv("AGU_SHINY_DATA_FILE", unset = "data/example_sites.csv")

# tell the app which csv columns hold the site id, name, group and coordinates
# keep id, name, group, latitude and longitude on the left as written
# change the names in quotes on the right to match your csv column names exactly
# the group column contains categories such as climate zones or regions
# latitude and longitude locate each site on the map
columns <- c(
  id = "Stream_ID", name = "Stream_Name", group = "KG_Class",
  latitude = "Latitude", longitude = "Longitude"
)
group_label <- "Climate zone"
all_groups <- "All groups"
# these column names determine the starting axes and histogram choice
defaults <- c(x = "precip", y = "temp", histogram = "precip")

# labels appear in the menus and values must match numeric column names
# use only units you know from your own data
# each left-hand label is visible in a menu and its right-hand value selects a column
variables <- c(
  "Mean stream discharge [m³/s]" = "mean_discharge_m3_s",
  "Precipitation [mm/day]" = "precip",
  "Temperature [°C]" = "temp",
  "Drainage area [km²]" = "drainage_area",
  "Elevation [m]" = "elevation",
  "Watershed slope [degrees]" = "basin_slope",
  "Cropland cover [fraction, 0–1]" = "land_cropland",
  "Forest cover [fraction, 0–1]" = "land_forest",
  "Impervious cover [fraction, 0–1]" = "land_impervious",
  "Population density, 2020 [people/km2]" = "human_population_density_people_km2_2020",
  "Dam/barrier density [count/1,000 km2]" = "human_dam_barrier_density_per_1000_km2"
)

### read the table
# read site identifiers as text to preserve leading zeros
# keep spaces in column names and treat blank cells or na as missing values
site_data <- read.csv(
  data_file, stringsAsFactors = FALSE, check.names = FALSE,
  na.strings = c("", "NA"),
  colClasses = setNames("character", columns[["id"]])
)

### chemistry choices
# keep a short teaching menu while leaving all chemistry in the csv
# add another label and matching column here to offer another parameter
# find chemistry fields by their shared mean prefix without adding every one to the menu
chemistry_columns <- grep("^Mean ", names(site_data), value = TRUE)
common_chemistry <- c(
  "Mean dissolved silica [uM]" = "Mean DSi [uM]",
  "Mean calcium [uM]" = "Mean Ca [uM]",
  "Mean magnesium [uM]" = "Mean Mg [uM]",
  "Mean sodium [uM]" = "Mean Na [uM]",
  "Mean potassium [uM]" = "Mean K [uM]",
  "Mean chloride [uM]" = "Mean Cl [uM]",
  "Mean sulfate [uM]" = "Mean SO4 [uM]",
  "Mean bicarbonate [uM]" = "Mean HCO3 [uM]",
  "Mean nitrate (NO3) [uM]" = "Mean NO3 [uM]",
  "Mean oxidized nitrogen (NOx) [uM]" = "Mean NOx [uM]",
  "Mean ammonium [uM]" = "Mean NH4 [uM]",
  "Mean phosphate [uM]" = "Mean PO4 [uM]",
  "Mean dissolved organic carbon [uM]" = "Mean dissolved org C [uM]",
  "Mean pH" = "Mean pH",
  "Mean conductivity [uS/cm]" = "Mean specific conductivity [uS/cm]",
  "Mean water temperature [°C]" = "Mean temp [C]"
)
# put the common chemistry choices before the watershed choices in each menu
variables <- c(common_chemistry, variables)

# offer only variables present in the chosen table
# the extra water measurements appear when the combined file is selected
variables <- variables[variables %in% names(site_data)]

### check the data
# catch common table and menu mistakes before starting the app
if (!all(c(columns, variables) %in% names(site_data))) {
  stop("Some setup column names are missing from the data. Check columns and variables.")
}
# check each required plotting column once and stop early if it contains text
numeric_columns <- unique(c(unname(variables), columns[c("latitude", "longitude")]))
if (!all(vapply(site_data[numeric_columns], is.numeric, logical(1)))) {
  stop("Plot variables and coordinates must be numeric columns.")
}
if (!all(defaults %in% variables)) {
  stop("Each default must match a column offered in variables.")
}
if (anyNA(site_data[[columns[["group"]]]])) {
  stop("Each row needs a group value for the filter and colors.")
}

### labels and group styles
# wrap long axis labels so they remain readable in a smaller panel
# this helper takes a column name and returns its readable label with line breaks
variable_label <- function(column) {
  label <- names(variables)[match(column, variables)]
  paste(strwrap(label, width = 35), collapse = "\n")
}

### numeric group bands
# turn one numeric column into fixed low, middle and high groups
# these thirds describe this table, not standard environmental thresholds
# inputs are the numeric values and their unit label
# the result gives each row a group, with a fixed order for menus and legends
numeric_groups <- function(values, units) {
  available <- is.finite(values)
  result <- rep("Not available", length(values))
  if (!any(available)) return(factor(result, levels = "Not available"))
  numbers <- values[available]
  # quantiles find the values about one third and two thirds through the data
  # round the displayed cutoffs and use those exact boundaries for the groups
  cutoffs <- unique(signif(quantile(numbers, c(1 / 3, 2 / 3), names = FALSE), 5))
  cutoffs <- cutoffs[cutoffs >= min(numbers) & cutoffs < max(numbers)]
  limits <- format(cutoffs, trim = TRUE, scientific = FALSE)
  # repeated values can leave fewer usable boundaries, so allow fewer bands
  if (length(cutoffs) == 2) {
    labels <- c(paste0("Low ≤ ", limits[1], " ", units),
                paste0("Middle > ", limits[1], " to ", limits[2], " ", units),
                paste0("High > ", limits[2], " ", units))
  } else if (length(cutoffs) == 1) {
    labels <- c(paste0("Low ≤ ", limits[1], " ", units),
                paste0("High > ", limits[1], " ", units))
  } else {
    labels <- paste0("All values: ", format(min(numbers), trim = TRUE),
                     " to ", format(max(numbers), trim = TRUE), " ", units)
  }
  # cut gives each value the label of its interval, including its upper boundary
  result[available] <- as.character(cut(numbers, c(-Inf, cutoffs, Inf), labels = labels))
  factor(result, levels = c(labels, if (any(!available)) "Not available"))
}

# calculate each grouping once from the full table before any display filters
# only offer numeric group columns that exist in the chosen csv
group_units <- c(elevation = "m", basin_slope = "degrees", drainage_area = "km²")
# give each numeric grouping a different set of clearly separated colors
# hex codes specify exact colors and their order follows low, middle and high
numeric_palettes <- list(
  elevation = c("#0072b2", "#d55e00", "#009e73"),
  basin_slope = c("#7b3294", "#c17d11", "#008a9b"),
  drainage_area = c("#b83250", "#567d24", "#4b52a3")
)
group_values <- list()
group_values[[columns[["group"]]]] <- factor(site_data[[columns[["group"]]]])
# repeat this preparation for each available numeric grouping column
for (column in intersect(names(group_units), names(site_data))) {
  if (is.numeric(site_data[[column]])) {
    group_values[[column]] <- numeric_groups(site_data[[column]], group_units[[column]])
  }
}
# these visible menu labels point to the grouping columns prepared above
group_by_choices <- c(setNames(columns[["group"]], group_label),
                      "Elevation" = "elevation", "Basin slope" = "basin_slope",
                      "Drainage area" = "drainage_area")
group_by_choices <- group_by_choices[group_by_choices %in% names(group_values)]

# keep each group's color the same when the filter changes
groups <- sort(unique(site_data[[columns[["group"]]]]))
# use the same climate colors chosen for the hydroviz modules
# other data groups keep a default color until you add them here
climate_colors <- c(
  "Arid" = "#c77b63",
  "Semi-Arid" = "#d8a160",
  "Mediterranean" = "#b8a55d",
  "Humid Subtropical" = "#6f996f",
  "Tropical" = "#4f8c7e",
  "Humid Continental" = "#6f93b1",
  "Subarctic" = "#5b78a0",
  "Tundra" = "#8fb3c2"
)
# named colors let every climate keep its color even when other groups are hidden
group_colors <- setNames(hcl.colors(length(groups), "Dark 3"), groups)
matched_groups <- intersect(groups, names(climate_colors))
group_colors[matched_groups] <- climate_colors[matched_groups]

# each example group has a different shape as well as a different color
# the same group keeps its shape when the filter or axis menus change
# shape numbers choose plotting symbols rather than changing the data values
group_shapes <- setNames(rep(c(16, 17, 15, 18, 3, 8, 4), length.out = length(groups)), groups)
# keep the original climate shapes when a group without metadata is added
climate_shapes <- c("Arid" = 16, "Humid Continental" = 17, "Humid Subtropical" = 15,
                    "Mediterranean" = 18, "Semi-Arid" = 3, "Subarctic" = 8,
                    "Not available" = 4)
known_shapes <- intersect(groups, names(climate_shapes))
group_shapes[known_shapes] <- climate_shapes[known_shapes]
# missing group information always uses neutral gray and a cross
group_colors[names(group_colors) == "Not available"] <- "#8a8f94"

### time series data
# the daily file is optional so the comparison tab works on its own
# read only columns needed by the plots to keep startup quick
time_series_file <- Sys.getenv("AGU_SHINY_TIME_SERIES_FILE", unset = "")
time_series_data <- NULL
if (nzchar(time_series_file) && file.exists(time_series_file)) {
  time_columns <- c("Stream_ID", "Stream_Name", "date", "type", "parameter", "units",
                    "value", "source_records", "conflicting_values")
  # a failed read leaves the daily file absent instead of stopping the comparison tab
  # the double colon calls the fast reader from its package without attaching it
  time_series_data <- tryCatch(
    data.table::fread(time_series_file, select = time_columns, data.table = FALSE,
                     colClasses = c(Stream_ID = "character"), nThread = 4,
                     showProgress = FALSE),
    error = function(error) NULL
  )
  if (!is.null(time_series_data)) {
    if (all(time_columns %in% names(time_series_data)) && nrow(time_series_data) > 0) {
      # date objects let the date filter and plots compare days rather than text
      time_series_data$date <- as.Date(time_series_data$date)
    } else {
      time_series_data <- NULL
    }
  }
}

### time series starting choices
# use the same common water-quality menu without the word mean
# choose two sites with recent observations for the first available parameter
if (!is.null(time_series_data)) {
  time_parameters <- setNames(sub("^Mean ", "", unname(common_chemistry)),
                              sub("^Mean ", "", names(common_chemistry)))
  time_parameters <- time_parameters[time_parameters %in%
    unique(time_series_data$parameter[time_series_data$type == "chemistry"])]
  time_sites <- unique(time_series_data[c("Stream_ID", "Stream_Name")])
  time_sites <- time_sites[order(time_sites$Stream_Name), ]
  # these colors identify sites and are shared by both time-series plots
  time_colors <- setNames(hcl.colors(nrow(time_sites), "Dark 3"), time_sites$Stream_Name)
  first_parameter <- unname(time_parameters[1])
  available <- time_series_data$type == "chemistry" & time_series_data$parameter == first_parameter
  # find the latest observed day at each site, then choose the most recent sites
  last_dates <- tapply(as.numeric(time_series_data$date[available]),
                       time_series_data$Stream_ID[available], max)
  default_sites <- names(sort(last_dates, decreasing = TRUE))[seq_len(min(2, length(last_dates)))]
  default_end <- as.Date(max(last_dates[default_sites]), origin = "1970-01-01")
  default_start <- default_end - 365 * 5
}

### time series plot
# draw daily values with the same site colors in both time-series plots
# separate chemistry panels keep different parameters and units apart
# define this reusable plotting function here and call it from the server later
# rows supplies already filtered daily records and the other arguments control the panels and height
draw_time_series <- function(rows, separate_panels = FALSE, plot_height = 360) {
  rows$hover_text <- paste0(
    htmltools::htmlEscape(rows$Stream_Name), "<br>",
    htmltools::htmlEscape(rows$Stream_ID), "<br>", rows$date, "<br>",
    htmltools::htmlEscape(rows$parameter), ": ", signif(rows$value, 5), "<br>",
    "Source records that day: ", rows$source_records,
    ifelse(rows$conflicting_values, "<br>Distinct source values were averaged", "")
  )
  # mappings inside aes connect columns to axes, site colors and hover text
  # fixed sizes outside aes apply equally to all lines or points
  # plus signs add layers and appearance settings to the same plot
  # lines connect each site and parameter separately and points mark observed daily values
  plot <- ggplot(rows, aes(x = date, y = value, color = Stream_Name,
                           group = interaction(Stream_ID, parameter), text = hover_text)) +
    geom_line(linewidth = 0.6) + geom_point(size = 1) +
    scale_color_manual(values = time_colors, name = "Site") +
    labs(x = "Date", y = if (separate_panels) "Daily value" else "Streamflow [m³/s]") +
    theme_minimal(base_size = 12) +
    theme(panel.grid = element_blank(), axis.line = element_line(color = "#24323d"),
          axis.ticks = element_line(color = "#24323d"), legend.position = "bottom")
  # chemistry panels use their own vertical ranges and their labels retain the units
  if (separate_panels) plot <- plot + facet_wrap(~parameter, scales = "free_y", ncol = 1)
  # keep the legend the same distance below the axes as panels make the plot taller
  # the pipe passes this plot to the next display-setting function
  # margins reserve space for labels and the legend without narrowing the data area
  ggplotly(plot, tooltip = "text", height = plot_height) |>
    plotly::layout(margin = list(l = 65, r = 20, t = 20, b = 140),
                   legend = list(orientation = "h", yanchor = "top", font = list(size = 11),
                                 y = -55 / (plot_height - 160)),
                   hoverlabel = list(bgcolor = "white", bordercolor = "#bfd0db",
                                     font = list(color = "#24323d"))) |>
    config(displayModeBar = FALSE)
}

### time series page
# show a helpful message when the separate daily file has not been selected
# assemble this page piece now and insert it into the time-series tab later
time_series_ui <- if (is.null(time_series_data)) {
  div(class = "display-panel",
      p("Select the shared usgs_time_series.csv in RStudio before starting the app."),
      p("The README explains the file setting. The comparison tab can be used without this file."))
} else {
  # the page uses twelve columns: three for controls and nine for the results
  sidebarLayout(
    sidebarPanel(width = 3,
      h2("Choose time series"),
      # these searchable menus allow several choices and store their values by input name
      selectizeInput("series_sites", "Sites", multiple = TRUE,
                     choices = setNames(time_sites$Stream_ID, time_sites$Stream_Name),
                     selected = default_sites),
      selectizeInput("series_parameters", "Water-quality parameters", multiple = TRUE,
                     choices = time_parameters, selected = first_parameter),
      # the starting dates show recent observations and min/max bound the calendar choices
      dateRangeInput("series_dates", "Date range", start = default_start, end = default_end,
                     min = min(time_series_data$date), max = max(time_series_data$date)),
      helpText("These are daily values after repeat handling. Each panel shows its recorded units.")
    ),
    mainPanel(width = 9,
      textOutput("series_counts"),
      # this space receives a plot area whose height changes with the number of parameters
      div(class = "display-panel", h2("Water quality"), uiOutput("chemistry_series_space")),
      div(class = "display-panel map-panel", h2("Streamflow"),
          plotlyOutput("discharge_series", height = "360px"))
    )
  )
}

### page layout
# ui: build the page that people see and interact with
# the small style block keeps the page white with simple panels
# combine the header, comparison layout and previously prepared time-series page
# class names below connect page elements to the matching style rules
ui <- fluidPage(
  tags$head(tags$style(HTML("
    /* base page colors and type: hex codes choose colors and #fff is white
       the font list uses available computer fonts and line height spaces the text */
    body {
      background: #fff;
      color: #24323d;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      font-size: 15px;
      line-height: 1.5;
    }
    /* limit the page width on wide screens and leave space inside its edges */
    .container-fluid { max-width: 1500px; padding: 30px; }
    /* margin adds space outside the header and padding adds space inside
       border sets the outline and radius rounds the corners
       shadow adds a soft edge with a low-opacity color */
    .page-header {
      margin: 0 0 26px; padding: 26px 30px; border: 1px solid #d7e3ea;
      border-radius: 18px; background: #fff;
      box-shadow: 0 12px 30px rgba(53,79,92,0.06);
    }
    /* size and weight make the page title prominent and margins control its spacing */
    .page-header h1 { margin: 6px 0 10px; font-size: 34px; font-weight: 700; }
    /* keep the introductory sentence muted and remove its extra outside gap */
    .page-header p { margin: 0; color: #536772; }
    /* style the small label above the title with spaced letters and blue text */
    .eyebrow { color: #2f6c8f; font-size: 12px; font-weight: 700; letter-spacing: 1.5px; }
    /* the sidebar uses well and plot cards use display-panel
       both keep white backgrounds, pale outlines and soft shadows */
    .well, .display-panel {
      background: #fff; border: 1px solid #d7e3ea; border-radius: 16px;
      box-shadow: 0 12px 28px rgba(53,79,92,0.07);
    }
    /* give controls breathing room and mark the sidebar with a thin green top edge */
    .well { padding: 22px; border-top: 4px solid #7a9e63; }
    /* set the sidebar heading size and leave room before the first control */
    .well h2 { font-size: 20px; margin: 0 0 22px; font-weight: 700; }
    /* style the text above each control and separate it from the input */
    .control-label { color: #344e5d; margin-bottom: 8px; }
    /* leave a vertical gap between neighboring controls */
    .form-group { margin-bottom: 22px; }
    /* round the searchable input box and add space around its selected text */
    .selectize-input { border-color: #bfd0db; border-radius: 8px; padding: 10px 12px; }
    /* show a blue outline and pale ring around the active input */
    .selectize-input.focus { border-color: #2f6c8f; box-shadow: 0 0 0 3px #e2edf3; }
    /* give the open list of choices a matching border and rounded corners */
    .selectize-dropdown { border-color: #bfd0db; border-radius: 8px; }
    /* highlight the active choice inside an open list */
    .selectize-dropdown .active { background: #e8f1f5; color: #24323d; }
    /* keep the short instructions smaller and less prominent than control labels */
    .help-block { color: #536772; font-size: 14px; }
    /* outline the selection count and keep its background transparent */
    .site-counts {
      margin-bottom: 18px; padding: 13px 18px; background: transparent;
      border: 1px solid #d7e3ea; border-radius: 10px; color: #24323d;
    }
    /* place two equally wide plots side by side with a gap
       minmax allows each plot to shrink instead of forcing the page wider */
    .plot-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 20px; }
    /* pad the inside of plot cards and allow narrow grid columns */
    .display-panel { padding: 18px; min-width: 0; }
    /* use readable blue headings above the plots */
    .display-panel h2 { font-size: 19px; font-weight: 700; margin: 0 0 14px; color: #2f6c8f; }
    /* separate the lower map or streamflow card from the card above it */
    .map-panel { margin-top: 20px; }
    /* round the visible map corners */
    .leaflet-container { border-radius: 10px; }
    /* stack the comparison plots when the screen is narrower than 1100 pixels */
    @media (max-width: 1100px) { .plot-grid { grid-template-columns: minmax(0, 1fr); } }
    /* on small screens, reduce page padding and title size to leave more room */
    @media (max-width: 767px) {
      .container-fluid { padding: 16px; }
      .page-header { padding: 22px; }
      .page-header h1 { font-size: 28px; }
    }
  "))),
  div(class = "page-header",
    span(class = "eyebrow", "AGU · SHINY"),
    h1(app_title),
    p(sprintf("Explore patterns across %s USGS stream monitoring sites", nrow(site_data)))
  ),
  # keep the two sets of controls in separate tabs
  tabsetPanel(
    tabPanel("Compare sites",
      # this layout puts controls on the left and display panels on the right
      # the panels stack vertically on smaller screens
      sidebarLayout(
        sidebarPanel(width = 3,
          h2("Choose your view"),
          # each input name becomes a value in server, such as input$xvar
          # the show group menu filters rows and the axis menus choose plot columns
          # selected sets the starting choice and choices supplies labels and stored values
          # group_by changes the categories while climate selects which category is shown
          selectInput("group_by", "Group by", choices = group_by_choices,
                      selected = columns[["group"]]),
          selectInput("climate", "Show group", choices = c(all_groups, groups)),
          selectInput("xvar", "Horizontal axis", choices = variables, selected = defaults[["x"]]),
          # checkboxes return true or false as input$log_x and input$log_y
          checkboxInput("log_x", "Log scale for x axis", value = FALSE),
          selectInput("yvar", "Vertical axis", choices = variables, selected = defaults[["y"]]),
          checkboxInput("log_y", "Log scale for y axis", value = FALSE),
          helpText("Log scales apply to the scatterplot and show positive values only."),
          selectInput("histvar", "Histogram variable", choices = variables, selected = defaults[["histogram"]]),
          helpText("The group filter updates all three displays. Variable choices update only the plots.")
        ),
        # output names match the server, such as output$scatter
        # the graph outputs reserve space for plots with hover details
        # the map output reserves space for an interactive map
        mainPanel(width = 9,
          # output ids connect these page spaces to matching output entries in the server
          # heights reserve vertical room in pixels and do not change plotted values
          div(class = "site-counts", textOutput("counts")),
          div(class = "plot-grid",
            div(class = "display-panel",
              h2("Compare sites"), plotlyOutput("scatter", height = "460px")
            ),
            div(class = "display-panel",
              h2("Distribution across sites"), plotlyOutput("histogram", height = "360px")
            )
          ),
          div(class = "display-panel map-panel",
            h2("Locate sites"), leafletOutput("site_map", height = "360px")
          )
        )
      )
    ),
    tabPanel("Time series", time_series_ui)
  )
)

### ------------------------------------------------------------------------

### server
# server: use the selected inputs to filter data and update plots and the map
# input reads a choice from the ui and output sends a result back to the ui
# session lets the server refresh a menu for this person without affecting other users
server <- function(input, output, session) {
  ### time series filters
  # filter dates and sites before building either plot
  # these choices are independent of the comparison tab grouping and filter
  # reactive calculations update when their input choices change
  # call them with parentheses to get the current result
  # req pauses this calculation until the daily file and date choices are ready
  selected_observations <- reactive({
    req(!is.null(time_series_data), input$series_dates)
    keep <- time_series_data$Stream_ID %in% input$series_sites &
      time_series_data$date >= input$series_dates[1] & time_series_data$date <= input$series_dates[2]
    # keep is true for matching rows and drop = false keeps the result as a table
    time_series_data[keep, , drop = FALSE]
  })
  chemistry_observations <- reactive({
    rows <- selected_observations()
    rows[rows$type == "chemistry" & rows$parameter %in% input$series_parameters, , drop = FALSE]
  })
  discharge_observations <- reactive({
    rows <- selected_observations()
    rows[rows$type == "discharge", , drop = FALSE]
  })
  # send plain selection text to the page space named series_counts
  output$series_counts <- renderText({
    sprintf("%s sites selected", length(input$series_sites))
  })

  ### time series outputs
  # give each selected parameter enough room for its own panel
  # this output builds page elements rather than drawing a plot
  # its plot space grows with the number of selected parameters
  output$chemistry_series_space <- renderUI({
    plotlyOutput("chemistry_series", height = paste0(max(320, 230 * length(input$series_parameters)), "px"))
  })
  # plotting outputs fill the reserved plot spaces with interactive graphs
  # validate shows a useful message in that space when the selected rows are empty
  output$chemistry_series <- renderPlotly({
    rows <- chemistry_observations()
    validate(need(nrow(rows) > 0, "No water-quality values for these sites, parameters and dates."))
    draw_time_series(rows, separate_panels = TRUE,
                     plot_height = max(320, 230 * length(input$series_parameters)))
  })
  output$discharge_series <- renderPlotly({
    rows <- discharge_observations()
    validate(need(nrow(rows) > 0, "No streamflow values for these sites and dates."))
    draw_time_series(rows)
  })

  ### group choices and styles
  # this calculation changes only when a different grouping is chosen
  grouping <- reactive({
    req(input$group_by %in% unname(group_by_choices))
    values <- group_values[[input$group_by]]
    labels <- levels(values)
    if (input$group_by == columns[["group"]]) {
      colors <- group_colors[labels]
      shapes <- group_shapes[labels]
    } else {
      available <- setdiff(labels, "Not available")
      colors <- setNames(numeric_palettes[[input$group_by]][seq_along(available)], available)
      shapes <- setNames(c(16, 17, 15)[seq_along(available)], available)
      colors["Not available"] <- "#8a8f94"
      shapes["Not available"] <- 4
      colors <- colors[labels]
      shapes <- shapes[labels]
    }
    # return the labels and styles together so the scatterplot and map agree
    list(values = values, labels = labels, colors = colors, shapes = shapes,
         title = names(group_by_choices)[match(input$group_by, group_by_choices)])
  })

  ### group filter
  # reset the row filter immediately when the grouping changes
  # update the menu to show only choices for this grouping
  # store the current filter choice in a value that can trigger display updates
  selected_group <- reactiveVal(all_groups)
  # run this block on a grouping change, before other updates use the old filter
  observeEvent(input$group_by, {
    selected_group(all_groups)
    updateSelectInput(session, "climate", choices = c(all_groups, grouping()$labels),
                      selected = all_groups)
  }, priority = 1)
  # after startup, a valid filter choice updates the stored selection
  observeEvent(input$climate, {
    if (input$climate %in% c(all_groups, grouping()$labels)) selected_group(input$climate)
  }, ignoreInit = TRUE)

  # add display labels to a local copy, leaving the source table unchanged
  # the same filtered rows feed both plots and the map
  filtered_sites <- reactive({
    sites <- site_data
    sites$display_group <- grouping()$values
    if (selected_group() == all_groups) {
      sites
    } else {
      sites[sites$display_group == selected_group(), , drop = FALSE]
    }
  })

  ### scatterplot rows
  # the scatterplot needs finite values for both selected columns
  scatter_sites <- reactive({
    req(input$xvar %in% variables, input$yvar %in% variables)
    sites <- filtered_sites()
    # finite values exclude missing numbers and infinity before plotting
    keep <- is.finite(sites[[input$xvar]]) & is.finite(sites[[input$yvar]])
    # logarithms need positive numbers, so leave out zero and negative values
    # filter only this plot without changing the table, histogram or map
    if (isTRUE(input$log_x)) keep <- keep & sites[[input$xvar]] > 0
    if (isTRUE(input$log_y)) keep <- keep & sites[[input$yvar]] > 0
    sites[keep, , drop = FALSE]
  })

  ### histogram rows
  # the histogram needs only its own selected column
  histogram_sites <- reactive({
    req(input$histvar %in% variables)
    sites <- filtered_sites()
    sites[is.finite(sites[[input$histvar]]), , drop = FALSE]
  })

  ### map rows
  # map coordinates come from the names in the setup section
  mapped_sites <- reactive({
    sites <- filtered_sites()
    keep <- is.finite(sites[[columns[["latitude"]]]]) &
      is.finite(sites[[columns[["longitude"]]]])
    sites[keep, , drop = FALSE]
  })

  ### selected site count
  # count all selected rows before individual displays omit missing values
  # send the result to the text output named counts
  output$counts <- renderText({
    sprintf("%s sites selected", nrow(filtered_sites()))
  })

  ### scatterplot
  # .data[[...]] reads the column named by a menu or setup setting
  # send the interactive result to the graph output named scatter
  # changing an axis menu or the group filter rebuilds this result
  output$scatter <- renderPlotly({
    sites <- scatter_sites()
    validate(need(nrow(sites) > 0, "No sites have values for these axis settings."))

    ### scatterplot hover
    # a tooltip is the small label shown when the pointer is over a point
    # build one label per site using its name, identifier, group and axis values
    # paste0 joins the pieces and <br> starts a new line in the label
    # escape names to display them as text rather than treating them as web code
    # signif shortens displayed numbers without changing the original values
    # edit this block to choose which site details appear on hover
    group_details <- as.character(sites$display_group)
    if (input$group_by != columns[["group"]]) {
      values <- sites[[input$group_by]]
      available <- is.finite(values)
      group_details[available] <- paste0(group_details[available], "; value: ",
        signif(values[available], 5), " ", group_units[[input$group_by]])
    }
    sites$hover_text <- paste0(
      htmltools::htmlEscape(sites[[columns[["name"]]]]), "<br>",
      htmltools::htmlEscape(sites[[columns[["id"]]]]), "<br>",
      grouping()$title, ": ", htmltools::htmlEscape(group_details), "<br>",
      variable_label(input$xvar), ": ", signif(sites[[input$xvar]], 5), "<br>",
      variable_label(input$yvar), ": ", signif(sites[[input$yvar]], 5)
    )
    ### scatterplot appearance
    # text = hover_text connects each point to its own hover label
    # color and shape both identify the group for every axis choice
    # map group names to colors and symbols while keeping point size and opacity fixed
    plot <- ggplot(sites, aes(x = .data[[input$xvar]], y = .data[[input$yvar]],
                             color = display_group, shape = display_group, text = hover_text)) +
      geom_point(size = 3, alpha = 0.85) +
      scale_color_manual(values = grouping()$colors, name = grouping()$title) +
      scale_shape_manual(values = grouping()$shapes, name = grouping()$title) +
      labs(x = variable_label(input$xvar), y = variable_label(input$yvar)) +
      # the legend explains symbols and colors while the theme keeps axis lines and removes grids
      guides(color = guide_legend(ncol = 2), shape = guide_legend(ncol = 2)) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom", panel.grid.minor = element_blank(),
            text = element_text(color = "#24323d"), panel.grid.major = element_blank(),
            axis.line = element_line(color = "#24323d"),
            axis.ticks = element_line(color = "#24323d"))

    ### logarithmic axes
    # a log scale spaces values by powers of ten to reveal smaller values
    # apply it only when its checkbox is checked
    # axis labels and hover text still show the original units and values
    if (isTRUE(input$log_x)) plot <- plot + scale_x_log10()
    if (isTRUE(input$log_y)) plot <- plot + scale_y_log10()

    ### legend and hover appearance
    # keep site information white rather than using the point color as a fill
    # ggplotly converts the ggplot into an interactive browser graph
    # tooltip = "text" shows only the custom label defined above
    # hide extra toolbar buttons for this simple example
    # place the legend below the graph so it does not narrow the axes
    # the bottom margin leaves room for the axis label and wrapped legend
    ggplotly(plot, tooltip = "text") |>
      plotly::layout(legend = list(orientation = "h", x = 0, xanchor = "left",
                                   font = list(size = 11),
                                   title = list(text = grouping()$title, side = "top"),
                                   y = -0.25, yanchor = "top"),
                     margin = list(l = 60, r = 15, t = 10, b = 150)) |>
      plotly::layout(hoverlabel = list(bgcolor = "white", bordercolor = "#bfd0db",
                                     font = list(color = "#24323d"))) |>
      config(displayModeBar = FALSE)
  })

  ### histogram
  # each bar counts sites within a range of values
  # use neutral bars so any selected variable works without a climate color key
  output$histogram <- renderPlotly({
    sites <- histogram_sites()
    validate(need(nrow(sites) > 0, "No sites have values for the histogram variable."))

    # calculate the same bin boundaries used by the original histogram
    bin_plot <- ggplot(sites, aes(x = .data[[input$histvar]])) +
      geom_histogram(bins = 20)

    ### histogram hover
    # assign each site to a plotted range to build its bar hover label
    bins <- ggplot_build(bin_plot)$data[[1]]
    bin_number <- cut(sites[[input$histvar]],
                      breaks = c(bins$xmin[1], bins$xmax),
                      include.lowest = TRUE, labels = FALSE)
    site_labels <- paste0(
      htmltools::htmlEscape(sites[[columns[["name"]]]]),
      " (", htmltools::htmlEscape(sites[[columns[["id"]]]]), ")"
    )
    # wrap long names so the hover label fits beside a bar
    site_labels <- vapply(site_labels, function(label) {
      paste(strwrap(label, width = 45), collapse = "<br>")
    }, character(1))

    # make one bar per bin and list up to three of its sites on hover
    # this small plotting table holds bar positions and counts, not replacement site data
    bar_data <- data.frame(value = bins$x, count = bins$count, hover_text = "")
    # repeat once per bin and use only the site names assigned to that bin
    for (i in seq_len(nrow(bins))) {
      labels <- site_labels[bin_number == i]
      bar_data$hover_text[i] <- paste0(
        variable_label(input$histvar), "<br>",
        signif(bins$xmin[i], 5), " to ", signif(bins$xmax[i], 5), "<br>",
        "Sites: ", bins$count[i], "<br>", paste(head(labels, 3), collapse = "<br>")
      )
      if (length(labels) > 3) {
        bar_data$hover_text[i] <- paste0(
          bar_data$hover_text[i], "<br>+ ", length(labels) - 3, " more sites"
        )
      }
    }

    # draw neutral gray bars at the original bin centers and widths
    # bar heights come from the existing counts and gray fill applies to every bar
    plot <- ggplot(bar_data, aes(x = value, y = count, text = hover_text)) +
      geom_col(width = bins$xmax[1] - bins$xmin[1], fill = "#8a8f94", color = "white") +
      labs(x = variable_label(input$histvar), y = "Number of sites") +
      theme_minimal(base_size = 12) +
      theme(panel.grid.minor = element_blank(), text = element_text(color = "#24323d"),
            panel.grid.major = element_blank(),
            axis.line = element_line(color = "#24323d"),
            axis.ticks = element_line(color = "#24323d"))

    # keep hover boxes white and leave out a legend for the neutral bars
    ggplotly(plot, tooltip = "text") |>
      plotly::layout(showlegend = FALSE,
                     hoverlabel = list(bgcolor = "white", bordercolor = "#bfd0db",
                                       font = list(color = "#24323d"))) |>
      config(displayModeBar = FALSE)
  })

  ### site map
  # send the map to the map output named site_map
  # rebuilding this small map keeps the group filter connection easy to follow
  output$site_map <- renderLeaflet({
    sites <- mapped_sites()
    validate(need(nrow(sites) > 0, "No sites have coordinates for this group."))
    longitude <- sites[[columns[["longitude"]]]]
    latitude <- sites[[columns[["latitude"]]]]
    # add the background tiles and fit the view to the sites
    # draw circles for the sites and show names when hovering
    # add a legend explaining the group colors
    # marker radius changes size and fill opacity changes transparency
    # labels show site names and the legend uses the same group colors as the scatterplot
    leaflet(sites) |>
      addTiles() |>
      fitBounds(min(longitude), min(latitude), max(longitude), max(latitude),
                options = list(padding = c(20, 20), maxZoom = 8)) |>
      addCircleMarkers(
        lng = longitude, lat = latitude,
        color = unname(grouping()$colors[as.character(sites$display_group)]),
        radius = 6, stroke = FALSE, fillOpacity = 0.85,
        label = sites[[columns[["name"]]]]
      ) |>
      addLegend(colors = unname(grouping()$colors), labels = grouping()$labels,
                title = grouping()$title)
  })
}

### start the app
# join the page layout and server calculations into one app
shinyApp(ui, server)
