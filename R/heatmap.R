library(data.table)
library(ggplot2)
library(scales)
library(here)

OUT_DIR <- here("output")

scores <- fread(file.path(OUT_DIR, "wis_scores.csv"))
scores[, reference_date := as.Date(reference_date)]

ord <- scores[
  ,
  .(season_mean = mean(mean_wis)),
  by = model
][order(season_mean)]
scores[, model := factor(model, levels = ord$model)]

ref <- scores[
  model == "CovidHub-ensemble",
  .(reference_date, ens_wis = mean_wis)
]
scores <- merge(scores, ref, by = "reference_date", all.x = TRUE)
scores[, delta := mean_wis - ens_wis]

avg_per_model <- scores[, .(
  reference_date = max(scores$reference_date) + 7,
  mean_wis = mean(mean_wis),
  ens_wis = NA,
  delta = NA
), by = model]
scores2 <- rbind(scores, avg_per_model, fill = TRUE)

p <- ggplot(scores2, aes(x = reference_date, y = model, fill = delta)) +
  geom_tile(colour = "grey80") +
  geom_text(aes(label = round(mean_wis)), size = 2.8) +
  scale_fill_gradient2(
    low = "#3b6cb1", mid = "white", high = "#c0392b",
    midpoint = 0, na.value = "grey90",
    limits = c(-30, 30), oob = squish,
    name = expression(Delta * "WIS vs CovidHub-ensemble")
  ) +
  scale_x_date(
    date_breaks = "1 week",
    date_labels = "%m-%d",
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  labs(
    title = "CovidHub model WIS by reference date (2024/25 season)",
    subtitle = paste(
      "Scored against CovidHub target-data commit 674471b",
      "(2025-04-30, closest to the 2025-05-01 cutoff described in the paper).",
      "Forecast-target tuples past 2025-04-26 are absent from",
      "the snapshot and shown as blank cells."
    ),
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

ggsave(
  file.path(OUT_DIR, "heatmap.png"), p,
  width = 12,
  height = max(4, 0.4 * uniqueN(scores2$model) + 2),
  dpi = 150
)
ggsave(
  file.path(OUT_DIR, "heatmap.pdf"), p,
  width = 12,
  height = max(4, 0.4 * uniqueN(scores2$model) + 2)
)

message("Wrote heatmap to ", file.path(OUT_DIR, "heatmap.png"))
