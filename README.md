# covidhub-rescore

Re-scores CovidHub forecasts for the 2024/25 season using the methodology Aygün et al. describe (2026, *Nature*, doi:[10.1038/s41586-026-10658-6](https://doi.org/10.1038/s41586-026-10658-6)) and plots a heat-map comparable to their Figure 3b.

The paper's only stated preprocessing is one sentence — *"missing values in the dataset were replaced by zeros to enable tree search to find executable code with the criterion score (WIS)"* — applied to a single snapshot, *"available as of 2025-05-01 for the entire retrospective season"*.

Forecasts and target data come from <https://github.com/CDCgov/covid19-forecast-hub>. Truth is the `value` column of the target-data CSV at commit `674471b` (2025-04-30, the closest commit to 2025-05-01); per the CovidHub data dictionary this maps to NHSN HRD `totalconfc19newadm`.

## Outputs

- `output/wis_scores.csv` — mean WIS per (model × reference_date) for every CovidHub-submitted model with ≥75 % season coverage.
- `output/heatmap.png` — Figure 3b-style heat-map, coloured relative to the CovidHub-ensemble row.
- `output/comparison_with_aygun.csv` — replicated CovidHub-ensemble and UMass-ar6_pooled cells against the values shown in Aygün et al. Fig 3b.

## Findings

The pipeline doesn't reproduce the paper's headline. Their CovidHub-ensemble row averages 28.96 WIS (rounded to 29 in the text); a literal implementation of the same recipe gives **31.4** at the same snapshot.

## Method

For each quantile prediction in a model's submission, look up the truth at the (location, target_end_date) in commit `674471b`. If it's missing because the target date falls past the snapshot's last observed week (2025-04-26), impute zero. Score using `scoringutils::score()` on a `forecast_quantile` object — that's `count_median_twice = FALSE` by default, the Bracher (2021) form used by CovidHub and FluSight. Average over the 52 jurisdictions and 4 horizons in each (model, reference_date) cell.

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
