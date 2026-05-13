query <- "
WITH eligible AS (
  SELECT plot_id
  FROM territoria
  WHERE soort_id = 188
    AND jaar BETWEEN 1990 AND 2025
    AND territoria > 0
  GROUP BY plot_id
  HAVING COUNT(DISTINCT jaar) >= 25
),
counted AS (
  SELECT DISTINCT plot_id, jaar
  FROM plot_jaar_teller
  WHERE jaar BETWEEN 1990 AND 2025
)
SELECT
  c.jaar,
  p.plot_id,
  p.kavel_nummer,
  p.plot_naam,
  COALESCE(SUM(t.territoria), 0) AS territoria
FROM eligible e
JOIN counted c
  ON c.plot_id = e.plot_id
JOIN plots p
  ON p.plot_id = e.plot_id
LEFT JOIN territoria t
  ON t.plot_id = c.plot_id
 AND t.jaar = c.jaar
 AND t.soort_id = 188
GROUP BY c.jaar, p.plot_id, p.kavel_nummer, p.plot_naam
ORDER BY p.kavel_nummer, c.jaar
"

mysql_args <- c(
  "--no-defaults",
  "-uroot",
  "-pYaTp$2022",
  "--protocol=SOCKET",
  "--socket=/tmp/mysql.sock",
  "-D", "meijendel",
  "--batch",
  "--raw",
  "--column-names",
  "-e", query
)

raw <- system2("mysql", mysql_args, stdout = TRUE, stderr = TRUE)
raw <- raw[!grepl("^mysql: \\[Warning\\]", raw)]
dat <- read.delim(text = paste(raw, collapse = "\n"), check.names = FALSE)

out_dir <- "output_kleine_karekiet_kaveltrends"
write.table(
  dat,
  file = file.path(out_dir, "kleine_karekiet_kavel_data.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

years <- 1990:2025
kavels <- sort(unique(dat$kavel_nummer))

trend <- do.call(rbind, lapply(kavels, function(kavel) {
  d <- dat[dat$kavel_nummer == kavel, ]
  fit <- lm(territoria ~ jaar, data = d)
  pred <- predict(fit, newdata = data.frame(jaar = years))
  base <- pred[years == 1990]
  data.frame(
    jaar = years,
    kavel_nummer = kavel,
    index_1990 = 100 * pred / base,
    territoria_trend = pred
  )
}))

write.table(
  trend,
  file = file.path(out_dir, "kleine_karekiet_kavel_trendindex.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

png(
  filename = file.path(out_dir, "kleine_karekiet_trendlijnen_per_kavel_1990_2025.png"),
  width = 1800,
  height = 1100,
  res = 160
)

op <- par(
  mar = c(5, 5, 4, 12),
  xaxs = "i",
  yaxs = "i",
  family = "sans"
)

palette_cols <- c(
  "#1b9e77", "#d95f02", "#7570b3", "#e7298a", "#66a61e",
  "#e6ab02", "#a6761d", "#1f78b4", "#b2df8a", "#fb9a99",
  "#cab2d6", "#fdbf6f", "#6a3d9a", "#b15928", "#000000"
)
cols <- setNames(palette_cols[seq_along(kavels)], kavels)

yrange <- range(trend$index_1990, na.rm = TRUE)
plot(
  NA,
  xlim = c(1990, 2025),
  ylim = c(max(0, floor(yrange[1] / 10) * 10), ceiling(yrange[2] / 10) * 10),
  xaxt = "n",
  xlab = "Jaar",
  ylab = "Trendindex Kleine Karekiet (1990 = 100)",
  main = "Kleine Karekiet: trendmatige ontwikkeling per kavel",
  las = 1
)
axis(1, at = seq(1990, 2025, 5), labels = seq(1990, 2025, 5))
grid(nx = NA, ny = NULL, col = "#e6e6e6", lty = 1)
abline(h = 100, col = "#666666", lty = 2, lwd = 1)

for (kavel in kavels) {
  d <- trend[trend$kavel_nummer == kavel, ]
  lwd <- if (kavel %in% c("M2", "M12a")) 3 else 1.8
  lines(d$jaar, d$index_1990, col = cols[[kavel]], lwd = lwd)
}

legend(
  "topright",
  inset = c(-0.31, 0),
  legend = kavels,
  col = cols[kavels],
  lwd = ifelse(kavels %in% c("M2", "M12a"), 3, 1.8),
  bty = "n",
  cex = 0.8,
  title = "Kavel",
  xpd = TRUE
)

mtext(
  "Alleen kavels met minimaal 25 territoriumjaren; lineaire trend per kavel, geindexeerd op trendwaarde 1990.",
  side = 1,
  line = 3.5,
  adj = 0,
  cex = 0.75,
  col = "#555555"
)

par(op)
dev.off()
