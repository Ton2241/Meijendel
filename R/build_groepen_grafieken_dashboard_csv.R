args <- commandArgs(trailingOnly = TRUE)

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else "R/build_groepen_grafieken_dashboard_csv.R"
repo_dir <- normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
sql_path <- if (length(args) >= 1L) args[[1]] else file.path(repo_dir, "meijendel.sql")
out_dir <- if (length(args) >= 2L) args[[2]] else file.path(repo_dir, "groepen_grafieken")
helpers_path <- file.path(repo_dir, "shiny_meijendel", "helpers.R")
trim_msi_dir <- file.path(dirname(out_dir), "trim_msi_evg")
trim_soorten_dir <- file.path(dirname(out_dir), "trim", "soorten")
dashboard_msi_path <- file.path(trim_msi_dir, "msi_per_groep_per_jaar.csv")
dashboard_landelijk_gam_path <- file.path(trim_msi_dir, "gam_voorspellingen_landelijk_msi_groepen.csv")
dashboard_composition_path <- file.path(trim_msi_dir, "groepssamenstelling_100tal.csv")
trim_index_base_path <- file.path(trim_soorten_dir, "soortindices_bruikbare_tijdreeks.csv")
trim_index_post_path <- file.path(trim_soorten_dir, "soortindices_per_jaar.csv")
out_path <- file.path(out_dir, "gam_dashboard_groepen.csv")
species_out_path <- file.path(out_dir, "groep_soorten.csv")
density_out_path <- file.path(out_dir, "groep_dichtheid.csv")

if (!file.exists(helpers_path)) {
  stop("helpers.R ontbreekt: ", helpers_path)
}
if (!file.exists(sql_path)) {
  stop("SQL-bestand ontbreekt: ", sql_path)
}
if (!file.exists(dashboard_msi_path)) {
  stop("Dashboardbestand ontbreekt: ", dashboard_msi_path)
}
if (!file.exists(dashboard_landelijk_gam_path)) {
  stop("Dashboardbestand ontbreekt: ", dashboard_landelijk_gam_path)
}
if (!file.exists(dashboard_composition_path)) {
  stop("Dashboardbestand ontbreekt: ", dashboard_composition_path)
}
if (!file.exists(trim_index_base_path)) {
  stop("Dashboardbestand ontbreekt: ", trim_index_base_path)
}
if (!file.exists(trim_index_post_path)) {
  stop("Dashboardbestand ontbreekt: ", trim_index_post_path)
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
source(helpers_path)

normalize_1990 <- function(curve) {
  if (is.null(curve) || !nrow(curve)) return(NULL)
  base <- curve$fit[curve$jaar == 1990]
  if (!length(base) || !is.finite(base[[1]]) || base[[1]] <= 0) return(NULL)
  factor <- 100 / base[[1]]
  curve$fit_1990 <- curve$fit * factor
  curve$lower_1990 <- curve$lower * factor
  curve$upper_1990 <- curve$upper * factor
  curve
}

chart_rows <- list()
species_rows <- list()
density_rows <- list()

add_species_rows <- function(chart_id, chart_title, species_names) {
  species_names <- sort(unique(species_names[!is.na(species_names) & nzchar(species_names)]))
  if (!length(species_names)) return(invisible(FALSE))
  species_rows[[length(species_rows) + 1L]] <<- data.frame(
    chart_id = as.character(chart_id),
    chart_title = chart_title,
    soort_naam = species_names,
    stringsAsFactors = FALSE
  )
  invisible(TRUE)
}

add_density_rows <- function(chart_id, chart_title, tbls, species_ids) {
  species_ids <- unique(as.integer(species_ids))
  if (!length(species_ids)) return(invisible(FALSE))
  area <- aggregate(oppervlakte_km2 ~ jaar, data = tbls$plot_jaar_oppervlak, FUN = sum, na.rm = TRUE)
  area$jaar <- as.integer(area$jaar)
  area <- area[area$jaar >= 1958 & is.finite(area$oppervlakte_km2) & area$oppervlakte_km2 > 0, , drop = FALSE]
  territory_years <- sort(unique(as.integer(tbls$territoria$jaar)))
  area <- area[area$jaar %in% territory_years, , drop = FALSE]
  if (!nrow(area)) return(invisible(FALSE))

  terr <- tbls$territoria[as.integer(tbls$territoria$soort_id) %in% species_ids, , drop = FALSE]
  if (nrow(terr)) {
    totals <- aggregate(territoria ~ jaar, data = terr, FUN = sum, na.rm = TRUE)
    totals$jaar <- as.integer(totals$jaar)
  } else {
    totals <- data.frame(jaar = integer(), territoria = numeric())
  }

  out <- merge(area, totals, by = "jaar", all.x = TRUE)
  out$territoria[is.na(out$territoria)] <- 0
  out$dichtheid <- ifelse(out$oppervlakte_km2 > 0, out$territoria / out$oppervlakte_km2, NA_real_)
  out <- out[is.finite(out$dichtheid), , drop = FALSE]
  if (!nrow(out)) return(invisible(FALSE))
  density_rows[[length(density_rows) + 1L]] <<- data.frame(
    chart_id = as.character(chart_id),
    chart_title = chart_title,
    jaar = out$jaar,
    dichtheid = round(out$dichtheid, 3),
    territoria = out$territoria,
    oppervlakte_km2 = out$oppervlakte_km2,
    stringsAsFactors = FALSE
  )
  invisible(TRUE)
}

add_curve <- function(chart_id, chart_title, serie, df, value_col = "msi") {
  curve <- normalize_1990(fit_gam_curve(df, value_col))
  if (is.null(curve)) return(invisible(FALSE))
  chart_rows[[length(chart_rows) + 1L]] <<- data.frame(
    chart_id = chart_id,
    chart_title = chart_title,
    serie = serie,
    jaar = curve$jaar,
    fit_1990 = curve$fit_1990,
    lower_1990 = curve$lower_1990,
    upper_1990 = curve$upper_1990,
    stringsAsFactors = FALSE
  )
  invisible(TRUE)
}

fit_continuous_dashboard_curve <- function(df, value_col = "msi") {
  log_rows <- data.frame(
    jaar = as.numeric(df$jaar),
    log_value = log(as.numeric(df[[value_col]])),
    stringsAsFactors = FALSE
  )
  log_rows <- log_rows[is.finite(log_rows$jaar) & is.finite(log_rows$log_value), , drop = FALSE]
  log_rows <- log_rows[order(log_rows$jaar), , drop = FALSE]
  if (!nrow(log_rows)) return(NULL)

  years <- log_rows$jaar
  span <- max(years) - min(years)
  bandwidth <- max(4, min(9, span / 9))

  rows <- lapply(seq_len(nrow(log_rows)), function(i) {
    x0 <- log_rows$jaar[[i]]
    weighted <- data.frame(
      dx = log_rows$jaar - x0,
      y = log_rows$log_value,
      w = exp(-0.5 * ((log_rows$jaar - x0) / bandwidth)^2),
      stringsAsFactors = FALSE
    )
    weighted <- weighted[weighted$w > 1e-6, , drop = FALSE]
    sw <- sum(weighted$w)
    sx <- sum(weighted$w * weighted$dx)
    sx2 <- sum(weighted$w * weighted$dx * weighted$dx)
    sy <- sum(weighted$w * weighted$y)
    sxy <- sum(weighted$w * weighted$dx * weighted$y)
    det <- sw * sx2 - sx * sx
    intercept <- if (det != 0) (sy * sx2 - sx * sxy) / det else sy / sw
    slope <- if (det != 0) (sw * sxy - sx * sy) / det else 0
    rss <- sum(weighted$w * (weighted$y - (intercept + slope * weighted$dx))^2)
    eff_n <- sw * sw / sum(weighted$w * weighted$w)
    sigma <- sqrt(max(0, rss / max(1, sw - 2)))
    se_mean <- if (det != 0) {
      sqrt(max(0, sigma * sigma * sx2 / det))
    } else {
      sigma / sqrt(max(1, eff_n))
    }
    band_se <- max(se_mean, sigma * 0.35)
    data.frame(
      jaar = x0,
      fit = exp(intercept),
      lower = exp(intercept - 1.96 * band_se),
      upper = exp(intercept + 1.96 * band_se),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[is.finite(out$fit) & out$fit > 0, , drop = FALSE]
}

add_meijendel_curve <- function(chart_id, chart_title, df, value_col = "msi") {
  curve <- normalize_1990(fit_continuous_dashboard_curve(df, value_col))
  if (is.null(curve)) return(invisible(FALSE))
  chart_rows[[length(chart_rows) + 1L]] <<- data.frame(
    chart_id = chart_id,
    chart_title = chart_title,
    serie = "meijendel",
    jaar = curve$jaar,
    fit_1990 = curve$fit_1990,
    lower_1990 = curve$lower_1990,
    upper_1990 = curve$upper_1990,
    stringsAsFactors = FALSE
  )
  invisible(TRUE)
}

build_national_msi <- function(trends, soort_ids) {
  df <- trends[
    trends$soort_id %in% unique(as.integer(soort_ids)) &
      trends$regio == "Landelijk" &
      is.finite(trends$waarde) &
      trends$waarde > 0,
    ,
    drop = FALSE
  ]
  if (!nrow(df)) return(NULL)

  species_rows <- lapply(split(df, df$soort_id), function(part) {
    part <- part[order(part$jaar), , drop = FALSE]
    base <- part$waarde[[1]]
    if (!is.finite(base) || base <= 0) return(NULL)
    part$index_100 <- 100 * part$waarde / base
    part
  })
  species_rows <- Filter(Negate(is.null), species_rows)
  if (!length(species_rows)) return(NULL)

  species_index <- do.call(rbind, species_rows)
  msi <- aggregate(log(index_100) ~ jaar, data = species_index, FUN = mean, na.rm = TRUE)
  names(msi)[names(msi) == "log(index_100)"] <- "log_index"
  msi$msi <- exp(msi$log_index)
  msi
}

fit_national_gam_curve <- function(msi) {
  msi <- msi[is.finite(msi$msi) & msi$msi > 0, , drop = FALSE]
  if (nrow(msi) < 5L || length(unique(msi$jaar)) < 5L) return(NULL)

  msi <- msi[order(msi$jaar), , drop = FALSE]
  msi$log_msi <- log(msi$msi)
  k_value <- max(3L, min(8L, nrow(msi) - 1L))
  fit <- tryCatch(
    mgcv::gam(log_msi ~ s(jaar, k = k_value), data = msi, method = "REML"),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)

  pred <- tryCatch(
    predict(fit, newdata = msi, se.fit = TRUE, type = "link"),
    error = function(e) NULL
  )
  if (is.null(pred)) return(NULL)

  data.frame(
    jaar = msi$jaar,
    fit = exp(as.numeric(pred$fit)),
    lower = exp(as.numeric(pred$fit) - 1.96 * as.numeric(pred$se.fit)),
    upper = exp(as.numeric(pred$fit) + 1.96 * as.numeric(pred$se.fit)),
    stringsAsFactors = FALSE
  )
}

add_national_curve <- function(chart_id, chart_title, trends, soort_ids) {
  msi <- build_national_msi(trends, soort_ids)
  if (is.null(msi)) return(invisible(FALSE))
  curve <- normalize_1990(fit_national_gam_curve(msi))
  if (is.null(curve)) return(invisible(FALSE))
  chart_rows[[length(chart_rows) + 1L]] <<- data.frame(
    chart_id = chart_id,
    chart_title = chart_title,
    serie = "landelijk",
    jaar = curve$jaar,
    fit_1990 = curve$fit_1990,
    lower_1990 = curve$lower_1990,
    upper_1990 = curve$upper_1990,
    stringsAsFactors = FALSE
  )
  invisible(TRUE)
}

add_dashboard_national_curve <- function(chart_id, chart_title, dashboard_landelijk_gam) {
  part <- dashboard_landelijk_gam[dashboard_landelijk_gam$groep_100 == as.integer(chart_id), , drop = FALSE]
  if (!nrow(part)) return(invisible(FALSE))
  curve <- data.frame(
    jaar = part$jaar,
    fit = part$gam_fit_msi,
    lower = part$gam_fit_lower,
    upper = part$gam_fit_upper,
    stringsAsFactors = FALSE
  )
  curve <- normalize_1990(curve)
  if (is.null(curve)) return(invisible(FALSE))
  chart_rows[[length(chart_rows) + 1L]] <<- data.frame(
    chart_id = as.character(chart_id),
    chart_title = chart_title,
    serie = "landelijk",
    jaar = curve$jaar,
    fit_1990 = curve$fit_1990,
    lower_1990 = curve$lower_1990,
    upper_1990 = curve$upper_1990,
    stringsAsFactors = FALSE
  )
  invisible(TRUE)
}

merge_trim_rows <- function(primary, secondary) {
  key_for <- function(df) {
    species_key <- if ("soort_id" %in% names(df)) df$soort_id else df$soort_naam
    paste(species_key, df$jaar, sep = "::")
  }
  primary$key <- key_for(primary)
  secondary$key <- key_for(secondary)
  merged <- rbind(primary, secondary[!secondary$key %in% primary$key, names(primary), drop = FALSE])
  merged$key <- NULL
  merged
}

get_trim_index_values <- function(df) {
  values <- rep(NA_real_, nrow(df))
  for (col in c("index_gebrugged", "index_100", "trim_index")) {
    if (col %in% names(df)) {
      candidate <- suppressWarnings(as.numeric(df[[col]]))
      values[!is.finite(values) & is.finite(candidate)] <- candidate[!is.finite(values) & is.finite(candidate)]
    }
  }
  values
}

rebase_trim_series <- function(series, years, base_year) {
  values <- rep(NA_real_, length(years))
  if (is.null(base_year) || !is.finite(base_year)) return(values)
  base <- series$waarde[series$jaar == base_year]
  if (!length(base) || !is.finite(base[[1]]) || base[[1]] == 0) return(values)
  matched <- match(years, series$jaar)
  has_match <- !is.na(matched)
  values[has_match] <- 100 * series$waarde[matched[has_match]] / base[[1]]
  values
}

get_common_base_year <- function(series_list) {
  common_years <- Reduce(intersect, lapply(series_list, function(x) x$jaar[is.finite(x$waarde) & x$waarde != 0]))
  common_years <- sort(as.integer(common_years))
  if (!length(common_years)) return(NA_integer_)
  common_years[[1]]
}

build_trim_group_series <- function(trim_index_data, species_names) {
  series_list <- lapply(species_names, function(species_name) {
    part <- trim_index_data[trim_index_data$soort_naam == species_name, , drop = FALSE]
    if (!nrow(part)) return(NULL)
    part$waarde <- get_trim_index_values(part)
    part <- part[is.finite(part$jaar) & is.finite(part$waarde) & part$waarde > 0, c("jaar", "waarde"), drop = FALSE]
    part <- part[order(part$jaar), , drop = FALSE]
    if (!nrow(part)) return(NULL)
    part
  })
  series_list <- Filter(Negate(is.null), series_list)
  if (!length(series_list)) return(NULL)

  years <- sort(unique(unlist(lapply(series_list, function(x) x$jaar))))
  common_base <- get_common_base_year(series_list)
  rebased <- lapply(series_list, function(series) {
    base_year <- if (is.finite(common_base)) common_base else series$jaar[[1]]
    rebase_trim_series(series, years, base_year)
  })

  values <- vapply(seq_along(years), function(i) {
    year_values <- vapply(rebased, function(x) x[[i]], numeric(1))
    year_values <- year_values[is.finite(year_values) & year_values > 0]
    if (!length(year_values)) return(NA_real_)
    round(exp(mean(log(year_values))), 1)
  }, numeric(1))
  n_soorten <- vapply(seq_along(years), function(i) {
    year_values <- vapply(rebased, function(x) x[[i]], numeric(1))
    sum(is.finite(year_values) & year_values > 0)
  }, integer(1))

  out <- data.frame(jaar = years, msi = values, n_soorten = n_soorten, stringsAsFactors = FALSE)
  out[is.finite(out$msi) & out$msi > 0, , drop = FALSE]
}

species_names_from_ids <- function(tbls, species_ids) {
  species_ids <- unique(as.integer(species_ids))
  names <- tbls$soorten$soort_naam[as.integer(tbls$soorten$id) %in% species_ids]
  sort(unique(names[!is.na(names) & nzchar(names)]))
}

get_rode_lijst_species_ids <- function(tbls) {
  richtlijn_ids <- tbls$richtlijnen$id[startsWith(tbls$richtlijnen$naam, "RL:")]
  unique(as.integer(tbls$soort_richtlijn$soort_id[tbls$soort_richtlijn$richtlijn_id %in% richtlijn_ids]))
}

get_oranje_lijst_species_ids <- function(tbls) {
  unique(as.integer(tbls$soort_richtlijn$soort_id[as.character(tbls$soort_richtlijn$richtlijn_id) == "6"]))
}

get_habitat_species_ids <- function(tbls, soorten_habitattypen, prefix) {
  habitat_codes <- toupper(as.character(tbls$habitattypen$habitat_code))
  habitat_ids <- as.integer(tbls$habitattypen$id[startsWith(habitat_codes, paste0("H", prefix))])
  if (!length(habitat_ids)) return(integer())
  strength <- tolower(trimws(as.character(soorten_habitattypen$koppelingsterkte)))
  unique(as.integer(soorten_habitattypen$soort_id[
    as.integer(soorten_habitattypen$habitattype_id) %in% habitat_ids &
      strength %in% c("sterk", "matig", "zwak")
  ]))
}

weighted_geomean <- function(values, weights) {
  keep <- is.finite(values) & values > 0 & is.finite(weights) & weights > 0
  if (!any(keep)) return(NA_real_)
  exp(sum(log(values[keep]) * weights[keep]) / sum(weights[keep]))
}

add_weighted_dashboard_national_curve <- function(chart_id, chart_title, dashboard_landelijk_gam, species_ids, tbls) {
  species_ids <- unique(as.integer(species_ids))
  evg <- tbls$evg_vogel_landschapgroep[as.integer(tbls$evg_vogel_landschapgroep$vogel_id) %in% species_ids, , drop = FALSE]
  if (!nrow(evg)) return(invisible(FALSE))
  groep_100 <- floor(as.integer(evg$groepsnummer) / 100) * 100
  weights <- as.data.frame(table(groep_100), stringsAsFactors = FALSE)
  names(weights) <- c("groep_100", "weight")
  weights$groep_100 <- as.integer(weights$groep_100)
  weights$weight <- as.numeric(weights$weight)

  part <- merge(dashboard_landelijk_gam, weights, by = "groep_100")
  if (!nrow(part)) return(invisible(FALSE))
  rows <- lapply(split(part, part$jaar), function(year_rows) {
    data.frame(
      jaar = as.integer(year_rows$jaar[[1]]),
      fit = weighted_geomean(as.numeric(year_rows$gam_fit_msi), year_rows$weight),
      lower = weighted_geomean(as.numeric(year_rows$gam_fit_lower), year_rows$weight),
      upper = weighted_geomean(as.numeric(year_rows$gam_fit_upper), year_rows$weight),
      stringsAsFactors = FALSE
    )
  })
  curve <- do.call(rbind, rows)
  curve <- curve[order(curve$jaar), , drop = FALSE]
  curve <- normalize_1990(curve)
  if (is.null(curve)) return(invisible(FALSE))
  chart_rows[[length(chart_rows) + 1L]] <<- data.frame(
    chart_id = chart_id,
    chart_title = chart_title,
    serie = "landelijk",
    jaar = curve$jaar,
    fit_1990 = curve$fit_1990,
    lower_1990 = curve$lower_1990,
    upper_1990 = curve$upper_1990,
    stringsAsFactors = FALSE
  )
  invisible(TRUE)
}

habitat_specs <- list(
  "2110-embryonale-wandelende-duinen" = list(
    title = "H2110 - Embryonale wandelende duinen",
    prefix = "2110"
  ),
  "2120-witte-duinen" = list(
    title = "H2120 - Witte duinen",
    prefix = "2120"
  ),
  "2130-grijze-duinen" = list(
    title = "H2130 - Grijze duinen",
    prefix = "2130"
  ),
  "2160-duindoornstruwelen" = list(
    title = "H2160 - Duindoornstruwelen",
    prefix = "2160"
  ),
  "2180-duinbossen" = list(
    title = "H2180 - Duinbossen",
    prefix = "2180"
  ),
  "2190-vochtige-duinvalleien" = list(
    title = "H2190 - Vochtige duinvalleien",
    prefix = "2190"
  ),
  "3140-kranswierwateren" = list(
    title = "H3140 - Kranswierwateren",
    prefix = "3140"
  ),
  "6430-ruigten-en-zomen" = list(
    title = "H6430 - Ruigten en zomen",
    prefix = "6430"
  )
)

tbls <- load_meijendel_tables_cached(sql_path)$data
soorten_habitattypen <- read_insert_table(
  sql_path,
  "soorten_habitattypen",
  c("id", "soort_id", "habitattype_id", "koppelingsterkte"),
  fast_tuples = TRUE,
  keep_only = TRUE
)

group_msi <- read.csv(dashboard_msi_path, stringsAsFactors = FALSE)
group_msi <- group_msi[group_msi$msi_variant == "volledig", , drop = FALSE]
group_composition <- read.csv(dashboard_composition_path, stringsAsFactors = FALSE)
group_composition <- group_composition[group_composition$msi_variant == "volledig", , drop = FALSE]
for (groep in sort(unique(group_msi$groep_100))) {
  part <- group_msi[group_msi$groep_100 == groep, , drop = FALSE]
  title <- unique(part$groep_titel)[[1]]
  add_meijendel_curve(as.character(groep), title, part)
  species_part <- group_composition[group_composition$groep_100 == groep, , drop = FALSE]
  add_species_rows(as.character(groep), title, species_part$soort_naam)
  add_density_rows(as.character(groep), title, tbls, species_part$soort_id)
}

trim_base <- read.csv(trim_index_base_path, stringsAsFactors = FALSE)
trim_post <- read.csv(trim_index_post_path, stringsAsFactors = FALSE)
trim_post <- trim_post[tolower(trimws(trim_post$brugmethode)) == "alleen_post", , drop = FALSE]
trim_index_data <- merge_trim_rows(trim_base, trim_post)
trim_index_data$jaar <- as.integer(trim_index_data$jaar)

lijst_specs <- list(
  "oranje-lijst" = list(title = "Oranje Lijst", species_ids = get_oranje_lijst_species_ids(tbls)),
  "rode-lijst" = list(title = "Rode Lijst Totaal", species_ids = get_rode_lijst_species_ids(tbls)),
  "rode-en-oranje-lijst" = list(
    title = "Rode & Oranjelijst",
    species_ids = union(get_rode_lijst_species_ids(tbls), get_oranje_lijst_species_ids(tbls))
  )
)
for (slug in names(lijst_specs)) {
  spec <- lijst_specs[[slug]]
  species_names <- species_names_from_ids(tbls, spec$species_ids)
  series <- build_trim_group_series(trim_index_data, species_names)
  if (!is.null(series) && nrow(series)) add_meijendel_curve(slug, spec$title, series)
  add_species_rows(slug, spec$title, species_names)
  add_density_rows(slug, spec$title, tbls, spec$species_ids)
}

dashboard_landelijk_gam <- read.csv(dashboard_landelijk_gam_path, stringsAsFactors = FALSE)
for (groep in sort(unique(group_msi$groep_100))) {
  part <- group_msi[group_msi$groep_100 == groep, , drop = FALSE]
  add_dashboard_national_curve(as.character(groep), unique(part$groep_titel)[[1]], dashboard_landelijk_gam)
}

for (slug in names(lijst_specs)) {
  spec <- lijst_specs[[slug]]
  add_weighted_dashboard_national_curve(slug, spec$title, dashboard_landelijk_gam, spec$species_ids, tbls)
}

for (slug in names(habitat_specs)) {
  spec <- habitat_specs[[slug]]
  species_ids <- get_habitat_species_ids(tbls, soorten_habitattypen, spec$prefix)
  species_names <- species_names_from_ids(tbls, species_ids)
  series <- build_trim_group_series(trim_index_data, species_names)
  if (!is.null(series) && nrow(series)) add_meijendel_curve(slug, spec$title, series)
  add_species_rows(slug, spec$title, species_names)
  add_density_rows(slug, spec$title, tbls, species_ids)
}

for (slug in names(habitat_specs)) {
  spec <- habitat_specs[[slug]]
  species_ids <- get_habitat_species_ids(tbls, soorten_habitattypen, spec$prefix)
  add_weighted_dashboard_national_curve(slug, spec$title, dashboard_landelijk_gam, species_ids, tbls)
}

if (!length(chart_rows)) {
  stop("Geen grafiekrijen gegenereerd.")
}

out <- do.call(rbind, chart_rows)
out <- out[order(out$chart_id, out$serie, out$jaar), ]
write.csv(out, out_path, row.names = FALSE)
species_out <- do.call(rbind, species_rows)
species_out <- species_out[order(species_out$chart_id, species_out$soort_naam), ]
write.csv(species_out, species_out_path, row.names = FALSE)
density_out <- do.call(rbind, density_rows)
density_out <- density_out[order(density_out$chart_id, density_out$jaar), ]
write.csv(density_out, density_out_path, row.names = FALSE)
cat(out_path, nrow(out), "rows\n")
cat(species_out_path, nrow(species_out), "rows\n")
cat(density_out_path, nrow(density_out), "rows\n")
