# AGU Shiny example

Explore sites, water quality, and streamflow with a beginner-friendly Shiny app.

## Download

Install [R](https://cran.r-project.org/) and [RStudio Desktop](https://docs.posit.co/ide/user/download.html) if needed.

Download and unzip the [app](https://github.com/sidneyabush/agu-shiny/archive/refs/heads/main.zip).
Download both CSVs and put them inside the app's `data` folder:

- [Site averages](https://github.com/sidneyabush/agu-shiny/releases/download/workshop-data/example_sites_water_quality.csv)
- [Daily observations](https://github.com/sidneyabush/agu-shiny/releases/download/workshop-data/usgs_time_series.csv)

Keep their filenames unchanged.

## Run

Open `agu-shiny-template.Rproj` in RStudio, open `app.R`, and click **Run App**
above the code.

If Shiny is not installed, use **Tools → Install Packages**, enter `shiny`,
and click **Install**. Then click **Run App**. Other missing packages install
automatically on the first launch; stay online and allow a few minutes.

## Edit

The comments in `app.R` explain the code. After editing, save the file, click
**Stop**, and click **Run App** again.
