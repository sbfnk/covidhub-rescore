# covidhub-rescore

Rescores CovidHub forecasts for the 2024/25 season using the methodology described in Aygün et al. (2026, *Nature*, doi:[10.1038/s41586-026-10658-6](https://doi.org/10.1038/s41586-026-10658-6)), and plots a heatmap comparable to Figure 3b.

Aygün et al. replace "missing values in the dataset" with zero and use NHSN HRD "available as of 2025-05-01". We take the CovidHub commit closest to that date, [`674471b`](https://github.com/CDCgov/covid19-forecast-hub/tree/674471b) (2025-04-30). The `value` column there corresponds to the `totalconfc19newadm` column in NHSN. The snapshot has no NaN cells in the observed range, so the zero-replacement rule applies to no values. Forecast targets after 2025-04-26 (the last observed week in the snapshot) are dropped.

## What we find

The pipeline does not reproduce the headline reported in the paper. 22 of the 27 reference dates in Fig 3b have at least one scorable horizon. The other 5 cover targets after 2025-04-26 and so cannot be scored from this snapshot at all, even though Aygün et al. report values of 10 to 13 for those weeks. Over the 22 scorable dates, the CovidHub-ensemble row averages 33.1 in the paper vs 31.4 here.

## Method

Score with `scoringutils::score()` on a `forecast_quantile` object (default `count_median_twice = FALSE`, the Bracher 2021 form used by CovidHub and FluSight). Average over 52 jurisdictions and 4 horizons per (model, reference_date) cell. Reference dates: 2024-11-23 to 2025-05-31, skipping 2025-01-25 (no model submitted that week). Horizons 0 to 3.

## Run

```r
install.packages(c("data.table", "scoringutils", "ggplot2", "scales"))
```
```sh
Rscript src/score.R     # writes output/wis_scores.csv, output/comparison_with_aygun.csv
Rscript src/heatmap.R   # writes output/heatmap.{png,pdf}
```
