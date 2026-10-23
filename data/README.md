# Example data

- `example_sites.csv`: watershed information for 109 sites, included with the app
- `example_sites_water_quality.csv`: watershed information and water-quality
  and streamflow averages for 112 sites
- `usgs_time_series.csv`: daily chemistry and streamflow values for 111 sites

Download both larger CSVs from the [GitHub release](https://github.com/sidneyabush/agu-shiny/releases/tag/workshop-data).
See the main [README](../README.md) for setup instructions.

## Sources and processing

Water measurements come from `20260925_masterdata_chem.csv` and
`20260925_masterdata_discharge.csv`, using USGS sites only. Chemistry retains
the recorded units; streamflow is in m³/s.

Identical repeated values within a day count once; distinct values are averaged.
Site averages give each available day equal weight. Dates and measurement
availability vary by site. Missing values remain missing.
