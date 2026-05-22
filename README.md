# covidhub-rescore

Code to re-scores CovidHub forecasts for the 2024/25 season using the methodology described in Aygün et al. (2026, *Nature*, doi:[10.1038/s41586-026-10658-6](https://doi.org/10.1038/s41586-026-10658-6)), and to plot a heat-map comparable to Figure 3b.

Applies the same preprocessing, as per the paper "missing values in the dataset were replaced by zeros to enable tree search to find executable code with the criterion score (WIS)" and uses a single snapshot, "available as of 2025-05-01 for the entire retrospective season".

Forecasts and target data come from <https://github.com/CDCgov/covid19-forecast-hub>. Truth is the `value` column of the target-data CSV at commit `674471b` (2025-04-30, the closest commit to 2025-05-01); per the CovidHub data dictionary this maps to NHSN HRD `totalconfc19newadm`.

## Outputs

- `output/wis_scores.csv` — mean WIS per (model × reference_date) for every CovidHub-submitted model
- `output/heatmap.png` — Figure 3b-style heat-map, coloured relative to the CovidHub-ensemble row.
- `output/comparison_with_aygun.csv` — replicated CovidHub-ensemble and UMass-ar6_pooled cells against the values shown in Aygün et al. Fig 3b.

The 2025-04-30 snapshot has no NaN cells inside its observed range (52 jurisdictions × 25 weeks ending 2025-04-26), so the "replace by zero" rule has nothing to act on. Forecast-target tuples whose `target_end_date` falls past 2025-04-26 are not in the snapshot at all and are dropped from scoring; they aren't "missing values in the dataset" in any natural reading of that phrase.

## Findings

The pipeline doesn't reproduce the paper's headline. 22 of the 27 reference dates in Fig 3b have at least one horizon whose target falls within the snapshot; the remaining 5 (2025-05-03 to 2025-05-31) have Aygün values of 10-13 that cannot be computed from a 2025-05-01-cutoff snapshot at all. Over the 22 scorable reference dates, the CovidHub-ensemble row averages **33.09** in the paper vs **31.4** in this replication (sum of absolute per-cell differences: 38.3 across the 22 cells).

## Method

For each quantile prediction in a submission, look up the truth at the (location, target_end_date) in commit `674471b`; drop predictions whose target date is past the snapshot's last observed week. Score using `scoringutils::score()` on a `forecast_quantile` object (`count_median_twice = FALSE`, the Bracher 2021 form used by CovidHub and FluSight). Average over 52 jurisdictions × 4 horizons in each (model, reference_date) cell.

Reference dates: 27 Saturdays from 2024-11-23 to 2025-05-31. 2025-01-25 is dropped because no CovidHub model submitted that week. Horizons 0:3, Aygün's "current week and three subsequent weeks". Jurisdictions are 50 states plus DC and PR.

## How to run

R 4.2+ with:

```r
install.packages(c("data.table", "scoringutils", "ggplot2", "scales"))
```

then:

```sh
Rscript src/score.R     # clones CovidHub, computes WIS, writes output/wis_scores.csv
Rscript src/heatmap.R   # produces output/heatmap.{png,pdf}
```
