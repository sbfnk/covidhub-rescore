# Re-score CovidHub forecasts for the 2024/25 season per Aygün et al.'s
# stated methodology (Methods, lines 672-674, 679):
#
#   - Truth: NHSN HRD `totalconfc19newadm`, snapshot "available as of
#     2025-05-01" (we use the CovidHub-curated target-data CSV at commit
#     674471b, 2025-04-30, the closest commit to 2025-05-01).
#   - Preprocessing: missing truth values are replaced with zero.
#   - Score: Weighted Interval Score (Bracher et al. 2021), via the
#     `scoringutils` R package with its default `count_median_twice = FALSE`.
#   - Aggregation: simple mean across 52 jurisdictions x 4 horizons per cell.
#
# Reference dates: 27 Saturdays 2024-11-23 through 2025-05-31, omitting
# 2025-01-25 (no CovidHub model submitted that week).
# Horizons 0:3 ("current week and three subsequent weeks").
# Jurisdictions: 50 states + DC + PR (no US national).

suppressPackageStartupMessages({
  library(data.table)
  library(scoringutils)
})

# ---- Configuration --------------------------------------------------------

REPO_URL    <- "https://github.com/CDCgov/covid19-forecast-hub.git"
TRUTH_COMMIT <- "674471b"        # 2025-04-30 commit, closest to 2025-05-01
HORIZONS    <- 0:3
MIN_COVERAGE <- 0.75             # Aygün's criterion (Methods, line 677)

script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  m <- grep("^--file=", args, value = TRUE)
  if (length(m)) return(normalizePath(dirname(sub("^--file=", "", m[1]))))
  normalizePath(".")
}
PROJ_DIR <- normalizePath(file.path(script_dir(), ".."))
REPO_DIR <- file.path(PROJ_DIR, "data", "covid19-forecast-hub")
OUT_DIR  <- file.path(PROJ_DIR, "output")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

REF_DATES <- as.Date(c(
  "2024-11-23", "2024-11-30", "2024-12-07", "2024-12-14", "2024-12-21",
  "2024-12-28", "2025-01-04", "2025-01-11", "2025-01-18", "2025-02-01",
  "2025-02-08", "2025-02-15", "2025-02-22", "2025-03-01", "2025-03-08",
  "2025-03-15", "2025-03-22", "2025-03-29", "2025-04-05", "2025-04-12",
  "2025-04-19", "2025-04-26", "2025-05-03", "2025-05-10", "2025-05-17",
  "2025-05-24", "2025-05-31"
))

FIPS_52 <- c(
  "01", "02", "04", "05", "06", "08", "09", "10", "11", "12", "13", "15",
  "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27",
  "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39",
  "40", "41", "42", "44", "45", "46", "47", "48", "49", "50", "51", "53",
  "54", "55", "56", "72"
)

# ---- Fetch repo if needed -------------------------------------------------

if (!dir.exists(REPO_DIR)) {
  dir.create(dirname(REPO_DIR), recursive = TRUE, showWarnings = FALSE)
  message("Cloning CovidHub repo to ", REPO_DIR, " (this can take a minute)...")
  system2("git", c("clone", "--filter=blob:none", REPO_URL, REPO_DIR))
}

# ---- Load truth from specific commit --------------------------------------

truth_txt <- system2("git", c("-C", REPO_DIR, "show",
                              paste0(TRUTH_COMMIT, ":target-data/covid-hospital-admissions.csv")),
                     stdout = TRUE)
truth <- fread(text = paste(truth_txt, collapse = "\n"))
# Earlier CovidHub commits used "date"; later ones use "target_end_date"
if ("date" %in% names(truth)) setnames(truth, "date", "target_end_date")
truth[, target_end_date := as.Date(target_end_date)]
truth[, location := sprintf("%s", location)]
truth <- truth[location %in% FIPS_52, .(location, target_end_date,
                                        observed = value)]
message("Truth snapshot last observed week: ",
        as.character(max(truth$target_end_date)),
        " (", nrow(truth), " rows)")

# ---- Score each model ------------------------------------------------------

models <- list.files(file.path(REPO_DIR, "model-output"))
models <- models[!startsWith(models, ".")]
message("Found ", length(models), " model directories")

score_one_model <- function(model) {
  files <- file.path(REPO_DIR, "model-output", model,
                     paste0(format(REF_DATES), "-", model, ".csv"))
  files <- files[file.exists(files)]
  if (length(files) < MIN_COVERAGE * length(REF_DATES)) return(NULL)

  fc <- tryCatch(rbindlist(lapply(files, fread), fill = TRUE),
                 error = function(e) NULL)
  if (is.null(fc) || nrow(fc) == 0) return(NULL)
  fc[, reference_date := as.Date(reference_date)]
  fc[, target_end_date := as.Date(target_end_date)]
  fc[, location := sprintf("%s", location)]
  fc[, output_type_id := as.numeric(output_type_id)]
  fc <- fc[output_type == "quantile" &
           target == "wk inc covid hosp" &
           horizon %in% HORIZONS &
           location %in% FIPS_52]
  if (nrow(fc) == 0) return(NULL)

  # Each row = one quantile prediction. The paper says "missing values in
  # the dataset were replaced by zeros". The 2025-04-30 snapshot has no NaN
  # cells inside its observed range, so that rule has no effect on the
  # truth values it does contain; forecast-target tuples whose target_end_date
  # falls past the snapshot's last observed week (2025-04-26) are not "in
  # the dataset" at all and are dropped here.
  d <- merge(fc, truth, by = c("location", "target_end_date"))

  fcq <- as_forecast_quantile(
    d[, .(reference_date, horizon, location, target_end_date,
          quantile_level = output_type_id,
          predicted = value, observed)],
    forecast_unit = c("reference_date", "horizon", "location", "target_end_date"),
    observed = "observed", predicted = "predicted",
    quantile_level = "quantile_level"
  )
  s <- as.data.table(score(fcq))
  s[, model := model]
  s[, .(model, reference_date, horizon, location, target_end_date, wis)]
}

per_forecast <- rbindlist(lapply(models, function(m) {
  out <- score_one_model(m)
  if (!is.null(out)) message("  ", m, ": ", uniqueN(out$reference_date),
                              " ref dates, mean WIS = ",
                              sprintf("%.2f", mean(out$wis)))
  out
}))

# Per-cell aggregate
per_cell <- per_forecast[, .(mean_wis = mean(wis), n_tuples = .N),
                         by = .(model, reference_date)][order(model, reference_date)]
fwrite(per_cell, file.path(OUT_DIR, "wis_scores.csv"))
message("Wrote ", file.path(OUT_DIR, "wis_scores.csv"))

# ---- Comparison with Aygün's Fig 3b (CovidHub-ensemble & UMass-ar6_pooled) -

aygun <- data.table(
  reference_date = REF_DATES,
  `CovidHub-ensemble` = c(39, 30, 40, 61, 59, 73, 54, 82, 40, 32, 26, 27, 22,
                           26, 19, 17, 17, 17, 13, 13, 11, 10, 10, 10, 11,
                           12, 11),
  `UMass-ar6_pooled`  = c(36, 33, 39, 61, 61, 82, 51, 86, 40, 34, 29, 29, 25,
                           26, 22, 22, 24, 25, 22, 19, 17, NA, 17, 16, 13,
                           14, 11)
)
ours_wide <- dcast(per_cell[model %in% c("CovidHub-ensemble",
                                          "UMass-ar6_pooled")],
                   reference_date ~ model, value.var = "mean_wis")
cmp <- merge(aygun, ours_wide, by = "reference_date",
             suffixes = c("_aygun", "_ours"), all.x = TRUE)
fwrite(cmp, file.path(OUT_DIR, "comparison_with_aygun.csv"))
message("Wrote ", file.path(OUT_DIR, "comparison_with_aygun.csv"))

if ("CovidHub-ensemble_ours" %in% names(cmp)) {
  scorable <- cmp[!is.na(`CovidHub-ensemble_ours`)]
  message("\nReplication summary (paper-as-written, snapshot has no NaN, drop targets past snapshot):")
  message(sprintf("  Reference dates with at least one scorable horizon: %d (of 27)",
                  nrow(scorable)))
  message(sprintf("  Aygün CovidHub-ensemble row mean over those %d cells:  %.2f",
                  nrow(scorable), mean(scorable$`CovidHub-ensemble_aygun`)))
  message(sprintf("  Our replication mean over those %d cells:             %.2f",
                  nrow(scorable), mean(scorable$`CovidHub-ensemble_ours`)))
  message(sprintf("  Sum_abs_diff across %d cells:                         %.2f",
                  nrow(scorable), sum(abs(scorable$`CovidHub-ensemble_aygun` -
                                          scorable$`CovidHub-ensemble_ours`))))
  message(sprintf("  Reference dates Aygün scores but we cannot (target past 2025-04-26): %d",
                  sum(is.na(cmp$`CovidHub-ensemble_ours`))))
}
