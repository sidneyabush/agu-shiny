# USGS example data

Source: `sizer_outs_with_drivers_all_sites_20260830.csv`, supplied by Sidney Bush.
This is a site-level watershed predictor table, not dated chemistry or discharge
observations. The app does not need the master chemistry/discharge folder.

The extract keeps only rows where `Stream_ID` starts with `USGS` (case-sensitive).
The recorded source has 514 rows and 174 columns, including 112 USGS rows.
Removing 22 SiZer/segmentation/model fields and collapsing exact duplicate
retained rows yields 109 unique sites and 152 columns. No differing site records
were combined or averaged. `basin_slope` is retained as a watershed characteristic.

`provenance.json` records the excluded columns, row counts, and source SHA-256.
The extraction script copies retained fields without unit conversions. The source
file was unavailable during the app simplification, so its values were not
independently compared again. The bundled CSV and provenance were left unchanged.

`Stream_ID`, `LTER`, and `Stream_Name` identify sites. `Latitude` and `Longitude`
locate them. `KG_Class` supplies the climate filter and scatterplot/map colors.
Other columns describe land cover, terrain, climate, and human pressures.

The app labels precipitation in mm/day, temperature in degrees Celsius, drainage
area in square kilometres, elevation in metres, watershed slope in degrees, and
land cover as a fraction from 0 to 1. These units follow the field names and land
cover values in `spatial_predictors_glass_climate_era5_land_modis_glc_20261015.csv`.
The supplied reference has daily-rate precipitation fields as well as separate
accumulated precipitation fields. No values were converted or replaced; the
precipitation averaging period was not established from this reference.

A missing drainage-area value remains missing. Each display omits missing or
non-finite values only for the columns it uses, and the app reports a
count for the selected group. Missing values can leave fewer sites in a display.

The original source file is not modified or needed to launch the app.
To rebuild the extract after receiving the same source file, run from the project folder:

```r
source("scripts/prepare_usgs_example.R")
prepare_usgs_example("/path/to/sizer_outs_with_drivers_all_sites_20260830.csv")
```

## Shared September water measurements

`example_sites_water_quality.csv` is kept outside the GitHub project. It has 112
site rows and 466 columns. The original 109 rows retain all 152 original fields
unchanged. Three additional September sites are SOUTH PLATTE, HUDSON RIVER, and
SAGEHEN C. The bundled CSV and `provenance.json` remain unchanged.

The water measurements come directly from these dated source files:

- `chemistry/20260925_masterdata_chem.csv`
- `discharge/20260925_masterdata_discharge.csv`

Both are in the `chemistry-discharge-qaqc/current` source folder. Only rows with
LTER equal to USGS were used. This export uses neither the HydroViz prepared
subset nor paired chemistry/flow records. There is no concentration conversion
and no requirement for chemistry to have discharge on the same date.

Names were matched after removing case, spaces, and punctuation, with no fuzzy
matching. The September union has 111 sites and unique normalized names: 108
match the original table and three are added. Original Merced River has no
September match. `september_site_name`, `september_site_match`, and
`water_source_release` record the match and release. The added sites receive
coordinates and drainage area from `Site_Reference_Table_current_20260903.csv`.
That reference has no climate field, so their climate is “Not available”.
No predictor values were guessed or copied from another site.

### Chemistry

The source contains 550,906 USGS records at 110 sites. Of these, 547,387 finite
values are included; 3,519 missing/non-finite values are excluded and counted.
All finite negative values are retained as supplied. All dates are present.

Each of the 38 parameter/unit combinations has its own mean column beginning
with `Mean `, such as `Mean Cl [uM]`, `Mean NO3 [uM]`, and `Mean NOx [uM]`.
NO3, NO2, and NOx are never combined. Source units including uM, mg/L, ug/L,
uS/cm, C, and NTU are preserved. For blank units, the label says “unit not
recorded”; pH is labeled `Mean pH`. Parameter spellings are retained, including
separately named ANC fields. Missing source units were not inferred from names.

For each site, date, parameter, and unit, identical repeated values are counted
once in the daily mean. Distinct values on the same day are averaged, then these
daily means are averaged with equal weight per day. This gives 514,929
site/parameter days, including 31,959 repeated days and 13,762 days with conflicting
values. Conflicts are exposed rather than silently selecting a preferred record.

Each mean has companion fields named with the same parameter/unit label:
`days`, `records`, `repeated_days`, `conflicting_days`, `start_date`, `end_date`,
and `excluded_records`. `records` counts the finite source rows before daily
summarizing. `days` counts the dates used for the mean. Missing summaries have
zero counts and missing values/dates. Coverage varies widely: DSi has values at
110 sites, chloride at 106, NOx at 100, NO3 at eight, and pH at four.

### Discharge

All 1,825,601 USGS source rows at 111 sites have finite flow and valid dates.
`Qcms` is retained in m³/s, including zero flow. Repeated site/date records occur
on 18,536 days; 3,923 of these days have distinct conflicting values within the
same per-site source filename, so no source-file priority resolves them.

Identical values within a day count once, distinct daily values are averaged,
and days are then averaged equally. The result uses 1,529,475 site-days.
`mean_discharge_m3_s` has companion fields `discharge_n_days`,
`discharge_source_records`, `discharge_repeated_days`,
`discharge_conflicting_days`, `discharge_start_date`, and `discharge_end_date`.

Chemistry and discharge are summarized separately before attaching summaries to
site rows. There is no daily chemistry-by-discharge join to multiply records.
These are available-day means over differing periods, not a shared study window,
flow-weighted concentrations, or trend estimates. The export preserves source
conflicts in count fields; averaging them does not resolve their underlying cause.


## Daily time-series file

`usgs_time_series.csv` is a second file outside the GitHub project. It contains
2,044,404 daily observations at 111 USGS sites, dated 1906-09-10 through 2026-09-17:
514,929 chemistry site/parameter days and 1,529,475 discharge site-days. Merced River
has no September records and therefore has no rows in this daily file.

Both files use the same exact September 25, 2026 chemistry and discharge sources,
the same site matching, and the same duplicate/conflict handling described above.
These are daily observations after processing repeated values, not raw individual
samples. Repeated identical values count once within a day. Distinct reported
values for that day are averaged. Negative finite chemistry values remain as
supplied. No unit conversions or chemistry/discharge pairing are performed.

`Stream_ID` and `Stream_Name` match the site-summary file. `date`, `type`,
`variable`, `units`, `parameter`, and `value` identify each daily measurement.
`parameter` includes its source unit for clear panel labels; pH retains its own
label. `source_records` counts finite rows contributing to that day,
`distinct_values` counts their different reported values, and `conflicting_values`
flags days with more than one distinct value. `source_release` is 20260925.
Each site/date/type/parameter combination appears once. There are 38 chemistry
parameter/unit combinations plus discharge in m³/s.

Checks confirmed that averaging the daily values reproduces every corresponding
site mean in `example_sites_water_quality.csv`. The app filters sites, dates,
and parameters before plotting and does not downsample the selected records.

