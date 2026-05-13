out_dir <- "output_kleine_karekiet_trend"
export <- read.delim(file.path(out_dir, "kleine_karekiet_trend_data.tsv"), stringsAsFactors = FALSE)
export$index_1990 <- as.numeric(export$index_1990)

png(file.path(out_dir, "kleine_karekiet_trend_1990_100.png"), width = 1400, height = 850, res = 150)
op <- par(mar = c(5, 5, 4, 2) + 0.1)
plot(
  NA,
  xlim = range(export$jaar, na.rm = TRUE),
  ylim = c(0, max(export$index_1990, na.rm = TRUE) * 1.08),
  xlab = "Jaar",
  ylab = "Index (1990 = 100)",
  main = "Kleine Karekiet: lokale dichtheid versus landelijke trend"
)
grid(col = "grey88")
cols <- c("M1a + M1b" = "#1b9e77", "M10-12-76 + M14" = "#d95f02", "Landelijk" = "#111111")
ltys <- c("M1a + M1b" = 1, "M10-12-76 + M14" = 1, "Landelijk" = 2)
for (naam in names(cols)) {
  d <- export[export$reeks == naam, ]
  lines(d$jaar, d$index_1990, col = cols[[naam]], lwd = 2.5, lty = ltys[[naam]])
  points(d$jaar, d$index_1990, col = cols[[naam]], pch = 16, cex = 0.55)
}
legend(
  "topright",
  legend = c(
    "M1a + M1b (dichtheid per km2, index)",
    "M10-12-76 + M14 (dichtheid per km2, index)",
    "Landelijk (trendindex)"
  ),
  col = cols,
  lty = ltys,
  lwd = 2.5,
  pch = 16,
  bty = "n"
)
mtext(
  "Bron: live MySQL database Meijendel; lokale lijnen: territoria / geteld plotoppervlak; alle lijnen herleid naar 1990 = 100.",
  side = 1,
  line = 4,
  cex = 0.8
)
par(op)
dev.off()
