args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_vegetatie_data.R"))

expect_error <- function(expr, pattern) {
  found <- tryCatch({ force(expr); "" }, error = function(e) conditionMessage(e))
  stopifnot(grepl(pattern, found, fixed = TRUE))
}

base <- expand.grid(
  soort_id = c(1L, 2L, 5L),
  plot_id = c(10L, 20L),
  jaar = 2001:2003,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
base$soort_naam <- ifelse(base$soort_id == 5L, "Aalscholver", ifelse(base$soort_id == 1L, "A", "B"))
base$count <- base$soort_id + base$jaar - 2001L
base$count_raw <- base$count
base$row_id <- paste(base$soort_id, base$plot_id, base$jaar, sep = ":")
base$tellerteam_factor <- factor(ifelse(base$plot_id == 10L, "T1", "T2"))
base$soort_factor <- factor(base$soort_id)
base$soort_plot_factor <- factor(paste(base$soort_id, base$plot_id, sep = ":"))
base$jaar_factor <- factor(base$jaar)
base$plotjaar_factor <- factor(paste(base$plot_id, base$jaar, sep = ":"))
base$jaar_decennium <- (base$jaar - 1990) / 10
base$analyse_bron_factor <- factor("sovon_m")
base$ervaring_plot_z <- 0
base$ervaring_elders_z <- 0
base$log_oppervlakte_km2 <- 0

pq <- data.frame(
  plot_id = rep(c(10L, 20L), each = 3),
  jaar = rep(2000:2002, 2),
  n_pq = 1L,
  n_opnamen = 1L,
  soortenrijkdom_gem = c(10, 12, 14, 20, 19, 18),
  bedekking_som_gem = c(100, 120, 140, 200, 190, 180),
  shannon_gem = c(1, 1.2, 1.4, 2, 1.9, 1.8),
  dekking_kwaliteit = "redelijk",
  stringsAsFactors = FALSE
)

features <- build_pq_plotyear_features(pq)
stopifnot(nrow(features) == 6L)
within_means <- aggregate(features["soortenrijkdom_within"], features["plot_id"], mean)
stopifnot(all(abs(within_means$soortenrijkdom_within) < 1e-12))
stopifnot(all(features$soortenrijkdom_between[features$plot_id == 10L] == 12))
stopifnot(all(features$soortenrijkdom_between[features$plot_id == 20L] == 19))

lag0 <- build_vegetation_population(base, pq, lag_years = 0L)
lag1 <- build_vegetation_population(base, pq, lag_years = 1L)
stopifnot(nrow(lag0$data) == 8L)
stopifnot(nrow(lag1$data) == 12L)
stopifnot(!5L %in% lag0$data$soort_id)
stopifnot(!"Aalscholver" %in% lag0$data$soort_naam)
stopifnot(length(unique(lag1$data$pq_jaar)) == 3L)
stopifnot(all(lag1$data$jaar - lag1$data$pq_jaar == 1L))
stopifnot(identical(lag1$row_hash, row_set_sha256(lag1$data$row_id)))
stopifnot(identical(sort(unique(lag1$data$plot_id)), c(10L, 20L)))

duplicate <- rbind(pq, pq[1, ])
expect_error(build_pq_plotyear_features(duplicate), "dubbele plot-jaarrijen")

missing_value <- pq
missing_value$shannon_gem[1] <- NA_real_
expect_error(build_pq_plotyear_features(missing_value), "ontbrekende of niet-eindige")

cat("OK: vegetatiedata en vertragingen\n")
