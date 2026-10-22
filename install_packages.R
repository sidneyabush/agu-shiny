### package setup
# run this file once from the project folder to install missing packages
# installation stays separate so the app never installs software on startup
if (getRversion() < "4.1") {
  stop("Please use R 4.1 or newer for this example.")
}

packages <- c("shiny", "ggplot2", "leaflet", "plotly", "data.table")

# check each package without loading it into the session
missing_packages <- packages[
  !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}
