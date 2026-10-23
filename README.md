# AGU Shiny example

Explore sites, water quality, and streamflow with a beginner-friendly Shiny app.

## Download

Install [R](https://cran.r-project.org/) and [RStudio Desktop](https://docs.posit.co/ide/user/download.html) if needed.

Download and extract the [app ZIP](https://github.com/sidneyabush/agu-shiny/archive/refs/heads/main.zip). Keep the extracted folder together.

Download both data files and save them somewhere easy to find:

- [Site averages](https://github.com/sidneyabush/agu-shiny/releases/download/workshop-data/example_sites_water_quality.csv)
- [Daily observations](https://github.com/sidneyabush/agu-shiny/releases/download/workshop-data/usgs_time_series.csv)

## Run the app

Open `agu-shiny-template.Rproj` from the extracted folder in RStudio.
Run these lines one at a time in the **Console** (beside the `>` prompt).
Wait for package installation to finish before continuing.

```r
source("install_packages.R")
Sys.setenv(AGU_SHINY_DATA_FILE = file.choose())
Sys.setenv(AGU_SHINY_TIME_SERIES_FILE = file.choose())
shiny::runApp(".")
```

Choose `example_sites_water_quality.csv` in the first file window and
`usgs_time_series.csv` in the second. The app then opens in a viewer or browser.

## Explore the code

Open `app.R` to read the comments and make changes. Save your edits, click
**Stop** in the Console, and run `shiny::runApp(".")` again.
