prepare_model_repo <- function() {
  configured <- Sys.getenv("MEIJENDEL_REPO", unset = "")
  if (nzchar(configured)) return(normalizePath(configured, mustWork = TRUE))

  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) {
    script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
    return(normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE))
  }
  normalizePath(getwd(), mustWork = TRUE)
}

.prepare_model_repo <- prepare_model_repo()
source(file.path(
  .prepare_model_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_teller_data.R"
))

require_prepare_fields <- function(data, fields, name) {
  if (!is.data.frame(data)) stop(name, " ontbreekt of is geen tabel.", call. = FALSE)
  missing <- setdiff(fields, names(data))
  if (length(missing)) stop(name, " mist verplichte velden: ", paste(missing, collapse = ", "), ".", call. = FALSE)
}

build_bmp_effort <- function(dagbezoeken, valid_plot_years) {
  require_prepare_fields(
    dagbezoeken,
    c("plot_id", "jaar", "dagvanjaar", "bezoekduur_min", "gunstig"),
    "dagbezoeken_bmp"
  )
  require_prepare_fields(valid_plot_years, c("plot_id", "jaar"), "valid_plot_years")

  visits <- dagbezoeken
  visits$plot_id <- as.integer(visits$plot_id)
  visits$jaar <- as.integer(visits$jaar)
  visits$dagvanjaar <- as.integer(visits$dagvanjaar)
  visits$bezoekduur_min <- as.numeric(visits$bezoekduur_min)
  visits$gunstig <- as.numeric(visits$gunstig)
  valid <- unique(valid_plot_years[c("plot_id", "jaar")])
  valid$plot_id <- as.integer(valid$plot_id)
  valid$jaar <- as.integer(valid$jaar)
  visits <- merge(visits, valid, by = c("plot_id", "jaar"), all = FALSE, sort = FALSE)
  if (!nrow(visits)) {
    return(data.frame(
      plot_id = integer(), jaar = integer(), aantal_bezoeken = integer(),
      totale_bezoekduur_min = numeric(), eerste_bezoekdag = integer(),
      laatste_bezoekdag = integer(), aandeel_gunstig = numeric(),
      stringsAsFactors = FALSE
    ))
  }

  visit_split <- split(seq_len(nrow(visits)), paste(visits$plot_id, visits$jaar, sep = ":"))
  rows <- lapply(visit_split, function(indices) {
    current <- visits[indices, , drop = FALSE]
    finite_days <- current$dagvanjaar[is.finite(current$dagvanjaar)]
    known_favourable <- current$gunstig[is.finite(current$gunstig)]
    data.frame(
      plot_id = current$plot_id[[1L]],
      jaar = current$jaar[[1L]],
      aantal_bezoeken = nrow(current),
      totale_bezoekduur_min = sum(current$bezoekduur_min, na.rm = TRUE),
      eerste_bezoekdag = if (length(finite_days)) min(finite_days) else NA_integer_,
      laatste_bezoekdag = if (length(finite_days)) max(finite_days) else NA_integer_,
      aandeel_gunstig = if (length(known_favourable)) mean(known_favourable) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  effort <- do.call(rbind, rows)
  effort <- effort[order(effort$jaar, effort$plot_id), , drop = FALSE]
  rownames(effort) <- NULL
  effort
}

standardize_with <- function(x, center, scale) {
  if (!is.finite(scale) || scale <= 0) return(rep(0, length(x)))
  (x - center) / scale
}

prepare_teller_population <- function(data, scaling) {
  data <- data[order(data$soort_id, data$plot_id, data$jaar), , drop = FALSE]
  data$row_id <- paste(data$soort_id, data$plot_id, data$jaar, sep = ":")
  if (anyDuplicated(data$row_id)) stop("Modelpopulatie bevat dubbele soort-plot-jaarcellen.", call. = FALSE)
  data$count <- as.numeric(data$count_raw)
  data$jaar_decennium <- (as.numeric(data$jaar) - 1990) / 10
  data$ervaring_plot_z <- standardize_with(
    data$ervaring_plot_mean,
    scaling$ervaring_plot_mean,
    scaling$ervaring_plot_sd
  )
  data$ervaring_elders_z <- standardize_with(
    data$ervaring_elders_mean,
    scaling$ervaring_elders_mean,
    scaling$ervaring_elders_sd
  )
  data$log_oppervlakte_km2 <- log(as.numeric(data$oppervlakte_km2))
  data$soort_factor <- factor(data$soort_id)
  data$plot_factor <- factor(data$plot_id)
  data$jaar_factor <- factor(data$jaar)
  data$plotjaar_factor <- factor(paste(data$plot_id, data$jaar, sep = ":"))
  data$soort_plot_factor <- factor(paste(data$soort_id, data$plot_id, sep = ":"))
  data$tellerteam_factor <- factor(data$tellerteam_sleutel)
  data$analyse_bron_factor <- factor(data$analyse_bron_code)
  if ("sovon_m" %in% levels(data$analyse_bron_factor)) {
    data$analyse_bron_factor <- stats::relevel(data$analyse_bron_factor, ref = "sovon_m")
  }
  rownames(data) <- NULL
  data
}

species_eligibility <- function(data) {
  species_split <- split(data, data$soort_id)
  rows <- lapply(species_split, function(current) {
    data.frame(
      soort_id = as.integer(current$soort_id[[1L]]),
      soort_naam = as.character(current$soort_naam[[1L]]),
      n = nrow(current),
      positief = sum(current$count > 0, na.rm = TRUE),
      plots = length(unique(current$plot_id)),
      teams = length(unique(current$tellerteam_sleutel)),
      jaren = length(unique(current$jaar)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$structureel_geschikt <- with(
    out,
    n >= 30L & positief >= 10L & plots >= 3L & teams >= 3L & jaren >= 3L
  )
  out <- out[order(out$soort_id), , drop = FALSE]
  rownames(out) <- NULL
  out
}

row_set_sha256 <- function(row_ids) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("R-pakket digest ontbreekt.", call. = FALSE)
  digest::digest(paste(sort(as.character(row_ids)), collapse = "\n"), algo = "sha256", serialize = FALSE)
}

build_teller_model_populations <- function(matrix, teams, effort) {
  require_prepare_fields(
    matrix,
    c(
      "soort_id", "soort_naam", "plot_id", "jaar", "kavel_nummer",
      "oppervlakte_km2", "geteld", "count_raw", "analyse_bron_code", "nulstatus"
    ),
    "analysematrix"
  )
  require_prepare_fields(
    teams,
    c(
      "plot_id", "jaar", "tellerteam_sleutel", "aantal_tellers",
      "ervaring_plot_mean", "ervaring_plot_min", "ervaring_plot_max",
      "ervaring_elders_mean", "ervaring_elders_min", "ervaring_elders_max"
    ),
    "tellerteams"
  )
  require_prepare_fields(
    effort,
    c("plot_id", "jaar", "aantal_bezoeken", "totale_bezoekduur_min"),
    "bmp_inspanning"
  )

  replacement_fields <- intersect(
    names(matrix),
    c(
      "tellerteam_sleutel", "aantal_tellers", "tellerregistratie_bekend",
      "ervaring_plot_mean", "ervaring_plot_min", "ervaring_plot_max",
      "ervaring_elders_mean", "ervaring_elders_min", "ervaring_elders_max"
    )
  )
  if (length(replacement_fields)) matrix[replacement_fields] <- NULL
  joined <- merge(matrix, teams, by = c("plot_id", "jaar"), all.x = TRUE, sort = FALSE)
  joined <- joined[
    as.logical(joined$geteld) & is.finite(joined$count_raw) &
      !(joined$kavel_nummer == "M62" & joined$jaar == 2016L) &
      !is.na(joined$tellerteam_sleutel) & nzchar(joined$tellerteam_sleutel),
    ,
    drop = FALSE
  ]
  if (!nrow(joined)) stop("Geen geldige responscellen met bekende teller.", call. = FALSE)
  if (any(!is.finite(joined$oppervlakte_km2) | joined$oppervlakte_km2 <= 0)) {
    stop("Modelpopulatie bevat een ontbrekende of niet-positieve oppervlakte.", call. = FALSE)
  }

  scaling <- list(
    ervaring_plot_mean = mean(joined$ervaring_plot_mean),
    ervaring_plot_sd = stats::sd(joined$ervaring_plot_mean),
    ervaring_elders_mean = mean(joined$ervaring_elders_mean),
    ervaring_elders_sd = stats::sd(joined$ervaring_elders_mean)
  )
  long <- prepare_teller_population(joined, scaling)
  single <- prepare_teller_population(joined[joined$aantal_tellers == 1L, , drop = FALSE], scaling)

  effort_joined <- merge(joined, effort, by = c("plot_id", "jaar"), all.x = FALSE, sort = FALSE)
  effort_joined <- effort_joined[
    effort_joined$jaar >= 1984L & effort_joined$jaar <= 2025L &
      is.finite(effort_joined$totale_bezoekduur_min) & effort_joined$totale_bezoekduur_min > 0,
    ,
    drop = FALSE
  ]
  effort_population <- prepare_teller_population(effort_joined, scaling)
  if (nrow(effort_population)) {
    log_duration <- log1p(effort_population$totale_bezoekduur_min)
    log_visits <- log1p(effort_population$aantal_bezoeken)
    effort_population$inspanning_duur_z <- standardize_with(log_duration, mean(log_duration), stats::sd(log_duration))
    effort_population$inspanning_bezoeken_z <- standardize_with(log_visits, mean(log_visits), stats::sd(log_visits))
  }

  eligibility <- species_eligibility(long)
  hashes <- c(
    long = row_set_sha256(long$row_id),
    single_teller = row_set_sha256(single$row_id),
    effort_1984_2025 = row_set_sha256(effort_population$row_id)
  )
  coverage <- data.frame(
    metric = c(
      "lange_modelrijen", "lange_plotjaren", "een_teller_modelrijen",
      "inspanning_modelrijen", "structureel_geschikte_soorten"
    ),
    value = as.numeric(c(
      nrow(long),
      length(unique(paste(long$plot_id, long$jaar, sep = ":"))),
      nrow(single),
      nrow(effort_population),
      sum(eligibility$structureel_geschikt)
    )),
    stringsAsFactors = FALSE
  )

  list(
    long = long,
    single_teller = single,
    effort_1984_2025 = effort_population,
    eligibility = eligibility,
    coverage = coverage,
    scaling = scaling,
    row_hashes = hashes
  )
}
