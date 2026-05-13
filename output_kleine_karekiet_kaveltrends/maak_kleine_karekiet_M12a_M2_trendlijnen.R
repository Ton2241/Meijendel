out_dir <- "output_kleine_karekiet_kaveltrends"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

dat <- read.delim(
  file.path(out_dir, "kleine_karekiet_M12a_M2_data.tsv"),
  check.names = FALSE
)

landelijk <- read.delim(
  file.path("output_kleine_karekiet_trend", "kleine_karekiet_trend_data.tsv"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)
landelijk <- landelijk[
  landelijk$reeks == "Landelijk" &
    landelijk$jaar >= 1990 &
    landelijk$jaar <= 2025,
  c("jaar", "index_1990")
]
landelijk$kavel_nummer <- "Landelijk"
names(landelijk)[names(landelijk) == "index_1990"] <- "index_1990"
landelijk$territoria_trend <- NA_real_
landelijk <- landelijk[, c("jaar", "kavel_nummer", "territoria_trend", "index_1990")]

library(mgcv)

years <- 1990:2025
kavels <- c("M12a", "M2")

trend <- do.call(rbind, lapply(kavels, function(kavel) {
  d <- dat[dat$kavel_nummer == kavel, ]
  fit <- gam(
    territoria ~ s(jaar, k = 8),
    data = d,
    family = quasipoisson(link = "log"),
    method = "REML"
  )
  pred <- predict(fit, newdata = data.frame(jaar = years), type = "response")
  base <- pred[years == 1990]
  data.frame(
    jaar = years,
    kavel_nummer = kavel,
    territoria_trend = pred,
    index_1990 = 100 * pred / base
  )
}))

trend_export <- rbind(trend, landelijk)

write.table(
  trend_export,
  file = file.path(out_dir, "kleine_karekiet_M12a_M2_trendindex.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

png(
  filename = file.path(out_dir, "kleine_karekiet_M12a_M2_GAM_landelijk_tabel_1990_2025.png"),
  width = 1900,
  height = 1350,
  res = 160
)

op <- par(family = "sans")
layout(matrix(c(1, 2), nrow = 2), heights = c(3.2, 1.45))

par(mar = c(4.5, 5, 4, 2), xaxs = "i", yaxs = "i")

cols <- c(M12a = "#0072B2", M2 = "#D55E00", Landelijk = "#111111")
yrange <- range(trend$index_1990, landelijk$index_1990, na.rm = TRUE)

plot(
  NA,
  xlim = c(1990, 2025),
  ylim = c(max(0, floor(yrange[1] / 10) * 10), ceiling(yrange[2] / 10) * 10),
  xaxt = "n",
  xlab = "Jaar",
  ylab = "Trendindex Kleine Karekiet (1990 = 100)",
  main = "Kleine Karekiet: GAM-trendlijnen in M12a en M2, met landelijke trend",
  las = 1
)

axis(1, at = seq(1990, 2025, 5), labels = seq(1990, 2025, 5))
grid(nx = NA, ny = NULL, col = "#e6e6e6", lty = 1)
abline(h = 100, col = "#666666", lty = 2, lwd = 1)

for (kavel in kavels) {
  d <- trend[trend$kavel_nummer == kavel, ]
  lines(d$jaar, d$index_1990, col = cols[[kavel]], lwd = 3)
}
lines(landelijk$jaar, landelijk$index_1990, col = cols[["Landelijk"]], lwd = 2.5, lty = 2)

legend(
  "topright",
  legend = c(kavels, "Landelijk"),
  col = cols[c(kavels, "Landelijk")],
  lwd = c(3, 3, 2.5),
  lty = c(1, 1, 2),
  bty = "n",
  title = "Reeks"
)

mtext(
  "GAM-trend per plot op basis van getelde jaren; landelijke reeks is de beschikbare landelijke index. Alle lijnen: 1990 = 100.",
  side = 1,
  line = 3.5,
  adj = 0,
  cex = 0.75,
  col = "#555555"
)

par(mar = c(1, 5, 1.2, 2), xaxs = "i", yaxs = "i")
plot.new()
plot.window(xlim = c(0, 1), ylim = c(0, 1))

count_matrix <- matrix("-", nrow = length(kavels), ncol = length(years))
rownames(count_matrix) <- kavels
colnames(count_matrix) <- as.character(years)
for (i in seq_len(nrow(dat))) {
  y <- as.character(dat$jaar[i])
  k <- dat$kavel_nummer[i]
  if (k %in% kavels && y %in% colnames(count_matrix)) {
    count_matrix[k, y] <- as.character(dat$territoria[i])
  }
}

draw_count_table <- function(year_block, x0, x1, y_top) {
  rows <- c("Jaar", kavels)
  n_col <- length(year_block) + 1
  n_row <- length(rows)
  cell_w <- (x1 - x0) / n_col
  cell_h <- 0.105
  y0 <- y_top - n_row * cell_h

  rect(x0, y0, x1, y_top, border = "#bdbdbd", col = NA)
  for (c in 0:n_col) {
    x <- x0 + c * cell_w
    segments(x, y0, x, y_top, col = "#d9d9d9")
  }
  for (r in 0:n_row) {
    y <- y_top - r * cell_h
    segments(x0, y, x1, y, col = "#d9d9d9")
  }
  rect(x0, y_top - cell_h, x1, y_top, border = NA, col = "#f2f2f2")
  rect(x0, y0, x0 + cell_w, y_top, border = NA, col = "#f7f7f7")

  text(x0 + 0.5 * cell_w, y_top - 0.5 * cell_h, "Jaar", font = 2, cex = 0.74)
  for (j in seq_along(year_block)) {
    text(x0 + (j + 0.5) * cell_w, y_top - 0.5 * cell_h, year_block[j], font = 2, cex = 0.68)
  }
  for (r in seq_along(kavels)) {
    y <- y_top - (r + 0.5) * cell_h
    text(x0 + 0.5 * cell_w, y, kavels[r], font = 2, cex = 0.74)
    for (j in seq_along(year_block)) {
      text(
        x0 + (j + 0.5) * cell_w,
        y,
        count_matrix[kavels[r], as.character(year_block[j])],
        cex = 0.68
      )
    }
  }
}

text(0, 0.96, "Daadwerkelijke aantallen territoria", adj = 0, font = 2, cex = 0.9)
draw_count_table(1990:2007, 0.00, 1.00, 0.86)
draw_count_table(2008:2025, 0.00, 1.00, 0.43)
text(0, 0.01, "- = plot niet als geteld jaar in de gebruikte plot-jaarreeks.", adj = 0, cex = 0.68, col = "#555555")

par(op)
dev.off()
