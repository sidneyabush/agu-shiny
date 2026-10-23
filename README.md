# AGU Shiny example

This app compares site averages and plots daily water-quality and streamflow
time series. This guide explains how to open it, use it, and find the code
behind each feature. No Shiny experience is needed.

Open `app.R` to see the app code and teaching comments. `install_packages.R`
installs the packages it needs. The `data` folder holds the included example data.

## Get the app running

Install [R from CRAN](https://cran.r-project.org/), then install the free
[RStudio Desktop from Posit](https://docs.posit.co/ide/user/download.html).
R runs the code; RStudio gives you an editor and a Console. Use R 4.1 or newer
and an RStudio release supported by your computer.

Download the [app ZIP](https://github.com/sidneyabush/agu-shiny/archive/refs/heads/main.zip)
from the [GitHub repository](https://github.com/sidneyabush/agu-shiny) and extract it.
Download both data files from the repository’s release:

- [Site averages: example_sites_water_quality.csv](https://github.com/sidneyabush/agu-shiny/releases/download/workshop-data/example_sites_water_quality.csv)
- [Daily observations: usgs_time_series.csv](https://github.com/sidneyabush/agu-shiny/releases/download/workshop-data/usgs_time_series.csv)

Keep `app.R`, `install_packages.R`, and the `data` folder together in the extracted
app folder. Save the two downloaded CSVs somewhere easy to find; you will select
them when starting the app.

Open `agu-shiny-template.Rproj` in RStudio. Paste these commands into the
**Console**, where R shows a `>` prompt:

```r
# install any missing packages
source("install_packages.R")

# choose the downloaded site averages csv
Sys.setenv(AGU_SHINY_DATA_FILE = file.choose())

# choose the downloaded daily observations csv
Sys.setenv(AGU_SHINY_TIME_SERIES_FILE = file.choose())

# start the app from this project folder
shiny::runApp(".")
```

Choose `example_sites_water_quality.csv` in the first file window and
`usgs_time_series.csv` in the second. The setup file installs shiny, ggplot2,
leaflet, plotly, and data.table if needed. This may take a few minutes and needs
internet access. Wait for installation to finish before
starting the app.

The app opens in RStudio's app window or a browser. Expect a white page with
**Compare sites** and **Time series** tabs. Compare sites starts with
**112 sites selected**, grouping and group-filter menus, three variable menus,
two log-scale checkboxes, two plots, and a map. Map backgrounds need internet
access; the table and plots use local data.

The file selections last for this R session. After restarting R, select both
files again. To use only the bundled **109-site watershed example**, skip both
`Sys.setenv(...)` lines. To clear paths already selected, run
`Sys.unsetenv(c("AGU_SHINY_DATA_FILE", "AGU_SHINY_TIME_SERIES_FILE"))` before
launching again. Without the daily file, Compare sites still works and the
Time series tab explains which file to select.

The project file is optional. Without it, first set the folder that contains
`app.R`; replace this example path with your own, using forward slashes:

```r
setwd("/full/path/to/agu-shiny")
```

Then use the same launch commands above. You can also launch with the full path:
`shiny::runApp("/full/path/to/agu-shiny")`.

## Stop, edit, and restart

Use the **Stop** button in the Console, or press Escape there, to stop the app.
Open `app.R` in RStudio's **Source editor** to edit the app. The editor holds the
file; the Console runs commands. Save your edits, stop the running app, and run
`shiny::runApp(".")` again. Refreshing the browser alone does not reload the code.
