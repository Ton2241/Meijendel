args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_vegetatiesamenstelling.R"
))

expect_error <- function(expr, pattern) {
  found <- tryCatch({ force(expr); "" }, error = function(e) conditionMessage(e))
  stopifnot(grepl(pattern, found, fixed = TRUE))
}

opnamen <- data.frame(
  opname_id = 1:6,
  pq_nummer = 101:106,
  jaar = rep(2001:2003, 2),
  ipi_code = c(214L, 151L, 131L, 213L, 352L, 155L),
  ipi_naam = c(
    "Open duingebied", "Duinstruweel", "Droog bos",
    "Natte duinvalleien", "Duinplassen", "Wilgenstruweel"
  ),
  stringsAsFactors = FALSE
)
opname_plot <- data.frame(
  opname_id = 1:6,
  plot_id = rep(c(10L, 20L), each = 3),
  stringsAsFactors = FALSE
)
waarnemingen <- data.frame(
  opname_id = c(1L, 1L, 2L, 3L, 3L, 4L, 5L, 5L, 6L),
  taxon_id = c(1L, 2L, 1L, 2L, 3L, 1L, 2L, 3L, 3L),
  taxon_naam = c("A", "B", "A", "B", "C", "A", "B", "C", "C"),
  taxonrang = "species",
  taxonvorm = "taxon",
  abundantie_percentage = c(50, 50, 100, 25, 75, 100, 50, 50, 100),
  stringsAsFactors = FALSE
)

stopifnot(identical(
  unname(ipi_group_for_code(c(214L, 211L, 213L, 352L, 150L, 151L, 155L, 111L, 193L))),
  c("open", "open", "nat_water", "nat_water", "struweel", "struweel", "struweel", "bos", "bos")
))
expect_error(ipi_group_for_code(999L), "onbekende IPI-code")
stopifnot(identical(normalize_supplement_plot_code("28045"), "10_12_76"))

composition <- build_pq_composition_features(
  opnamen, waarnemingen, opname_plot, n_axes = 2L
)
stopifnot(nrow(composition$features) == 6L)
stopifnot(identical(names(composition$features)[3:4], c("compositie_pc1", "compositie_pc2")))
stopifnot(nrow(composition$variance) == 2L)
stopifnot(abs(sum(composition$variance$verklaarde_variantie) -
  sum(composition$pca$sdev[1:2]^2) / sum(composition$pca$sdev^2)) < 1e-12)
stopifnot(nrow(composition$loadings) == 6L)
stopifnot(composition$quality$n_taxa == 3L)
stopifnot(composition$quality$n_opnamen == 6L)

duplicate <- rbind(waarnemingen, waarnemingen[1, ])
expect_error(
  build_pq_composition_features(opnamen, duplicate, opname_plot, 2L),
  "dubbele opname-taxonregel"
)

ipi <- build_ipi_plotyear_features(opnamen, opname_plot)
stopifnot(nrow(ipi) == 6L)
stopifnot(all(abs(rowSums(ipi[c("ipi_open", "ipi_nat_water", "ipi_struweel", "ipi_bos")]) - 1) < 1e-12))

feature_input <- data.frame(
  plot_id = rep(c(10L, 20L), each = 3),
  jaar = rep(2001:2003, 2),
  compositie_pc1 = c(-1, 0, 1, 2, 3, 4),
  compositie_pc2 = c(2, 1, 0, -1, -2, -3),
  stringsAsFactors = FALSE
)
split <- split_multivariate_plotyear_features(
  feature_input, c("compositie_pc1", "compositie_pc2")
)
for (field in c("compositie_pc1", "compositie_pc2")) {
  within <- paste0(field, "_within")
  means <- aggregate(split[[within]], list(split$plot_id), mean)$x
  stopifnot(all(abs(means) < 1e-12))
}

landcover <- data.frame(
  supplement_plot = c("1a", "10_12_76"),
  plot_area_ha = c(41.38, 35.50),
  struik_2001_ha = c(10, 5), struik_2022_ha = c(8, 4),
  bos_2001_ha = c(4, 10), bos_2022_ha = c(3, 8),
  boomgroep_2001_ha = c(8, 2), boomgroep_2022_ha = c(8, 3),
  laag_2001_ha = c(6, 8), laag_2022_ha = c(7, 9),
  riet_2001_ha = c(4, 1), riet_2022_ha = c(4, 1),
  zand_2001_ha = c(1, 3), zand_2022_ha = c(2, 4),
  water_2001_ha = c(8.38, 6), water_2022_ha = c(9.38, 6),
  stringsAsFactors = FALSE
)
plots <- data.frame(
  plot_id = c(3534L, 3502L),
  kavel_nummer = c("M1a", "M10-12-76"),
  stringsAsFactors = FALSE
)
long <- normalize_landcover_supplement(landcover, plots)
stopifnot(nrow(long) == 4L)
stopifnot(identical(sort(unique(long$plot_id)), c(3502L, 3534L)))
stopifnot(all(abs(rowSums(long[c("struik_aandeel", "bos_aandeel", "boomgroep_aandeel", "laag_aandeel", "riet_aandeel", "zand_aandeel", "water_aandeel")]) - 1) < 1e-10))
stopifnot(min(long$geclassificeerd_aandeel_plot) < 1)

or2 <- matrix(NA, nrow = 9, ncol = 24)
or2[7:9, 1] <- c("1a", "10_12_76", "Total")
or2[7:9, 2] <- c(41.38, 35, 76.38)
or2_columns <- list(c(3, 4), c(6, 7), c(9, 10), c(12, 14), c(16, 17), c(19, 20), c(22, 23))
for (class_index in seq_along(or2_columns)) {
  columns <- or2_columns[[class_index]]
  or2[7, columns] <- c(class_index, class_index + 1)
  or2[8, columns] <- c(class_index + 1, class_index + 2)
  or2[9, columns] <- c(class_index + 2, class_index + 3)
}
parsed <- parse_landcover_or2(or2)
stopifnot(nrow(parsed) == 2L)
stopifnot(identical(parsed$supplement_plot, c("1a", "10_12_76")))
stopifnot(all(c("struik_2001_ha", "water_2022_ha") %in% names(parsed)))

cat("OK: vegetatiesamenstelling, IPI en landbedekkingscontracten\n")
