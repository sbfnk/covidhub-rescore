# Produce a Fig 3b-style heat-map of per-(model, reference_date) mean WIS,
# coloured relative to the CovidHub-ensemble row.
#
# Reads output/wis_scores.csv produced by src/score.R.

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(scales)
})

script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  m <- grep("^--file=", args, value = TRUE)
  if (length(m)) return(normalizePath(dirname(sub("^--file=", "", m[1]))))
  normalizePath(".")
}
OUT_DIR <- normalizePath(file.path(script_dir(), "..", "output"))

scores <- fread(file.path(OUT_DIR, "wis_scores.csv"))
scores[, reference_date := as.Date(reference_date)]

# Order rows: lowest season-mean at top
ord <- scores[, .(season_mean = mean(mean_wis)), by = model][order(season_mean)]
scores[, model := factor(model, levels = ord$model)]

# Reference: CovidHub-ensemble per-cell
ref <- scores[model == "CovidHub-ensemble",
              .(reference_date, ens_wis = mean_wis)]
scores <- merge(scores, ref, by = "reference_date", all.x = TRUE)
scores[, delta := mean_wis - ens_wis]

# Add a final "Average WIS" column per model
avg_per_model <- scores[, .(reference_date = max(scores$reference_date) + 7,
                            mean_wis = mean(mean_wis),
                            ens_wis = NA, delta = NA),
                        by = model]
scores2 <- rbind(scores, avg_per_model, fill = TRUE)

p <- ggplot(scores2,
            aes(x = reference_date, y = model, fill = delta)) +
  geom_tile(colour = "grey80") +
  geom_text(aes(label = round(mean_wis)), size = 2.8) +
  scale_fill_gradient2(low = "#3b6cb1", mid = "white", high = "#c0392b",
                       midpoint = 0, na.value = "grey90",
                       limits = c(-30, 30), oob = squish,
                       name = expression(Delta * "WIS vs CovidHub-ensemble")) +
  scale_x_date(date_breaks = "1 week", date_labels = "%m-%d",
               expand = expansion(mult = c(0.01, 0.01))) +
  labs(
    title = "CovidHub model WIS by reference date (2024/25 season)",
    subtitle = "Scored against CovidHub target-data commit 674471b (2025-04-30, the closest commit to the paper's 2025-05-01 cutoff); missing truth values imputed to zero per the paper's stated methodology.",
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 10) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    axis.text.y = element_text(size = 9),
    panel.grid = element_blank(),
    legend.position = "right",
    plot.subtitle = element_text(size = 9, lineheight = 1.1)
  )

ggsave(file.path(OUT_DIR, "heatmap.png"), p,
       width = 12, height = max(4, 0.4 * uniqueN(scores2$model) + 2),
       dpi = 150)
ggsave(file.path(OUT_DIR, "heatmap.pdf"), p,
       width = 12, height = max(4, 0.4 * uniqueN(scores2$model) + 2))

message("Wrote heatmap to ", file.path(OUT_DIR, "heatmap.png"))
