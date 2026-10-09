teller_model_repo <- function() {
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

.teller_model_repo <- teller_model_repo()
source(file.path(.teller_model_repo, "R", "meijendel_cache_contract.R"))

canonical_tellerteam_key <- function(teller_ids) {
  teller_ids <- sort(unique(as.integer(teller_ids)))
  teller_ids <- teller_ids[!is.na(teller_ids)]
  if (!length(teller_ids)) stop("Een tellerteam moet minstens één geldige teller-id bevatten.", call. = FALSE)
  paste(teller_ids, collapse = "+")
}

build_teller_experience_layer <- function(data, year_min = 1958L, year_max = 2025L) {
  if (!is.list(data)) stop("Tellerinvoer moet een lijst met tabellen zijn.", call. = FALSE)
  required <- c("plots", "plot_analyse_scope", "plot_jaar_teller")
  missing <- required[!vapply(required, function(name) is.data.frame(data[[name]]), logical(1))]
  if (length(missing)) stop("Tellerinvoer mist tabel(len): ", paste(missing, collapse = ", "), ".", call. = FALSE)
  required_pjt <- c("plot_id", "jaar", "teller_id")
  if (length(setdiff(required_pjt, names(data$plot_jaar_teller)))) {
    stop("plot_jaar_teller mist plot_id, jaar of teller_id.", call. = FALSE)
  }

  year_min <- as.integer(year_min)
  year_max <- as.integer(year_max)
  if (length(year_min) != 1L || length(year_max) != 1L || is.na(year_min) || is.na(year_max) || year_min > year_max) {
    stop("De ervaringsperiode is ongeldig.", call. = FALSE)
  }

  scoped <- apply_meijendel_plot_scope(data)
  plots <- unique(scoped$plots[c("plot_id", "kavel_nummer")])
  plots$plot_id <- as.integer(plots$plot_id)
  plots$kavel_nummer <- normalize_meijendel_kavel(plots$kavel_nummer)
  if (anyDuplicated(plots$plot_id)) stop("plots bevat dubbele plot-id's.", call. = FALSE)

  participations <- scoped$plot_jaar_teller[required_pjt]
  participations$plot_id <- as.integer(participations$plot_id)
  participations$jaar <- as.integer(participations$jaar)
  participations$teller_id <- as.integer(participations$teller_id)
  if (anyNA(participations)) stop("plot_jaar_teller bevat een lege plot-, jaar- of teller-id.", call. = FALSE)
  participations <- unique(participations)
  participations <- merge(participations, plots, by = "plot_id", all.x = TRUE, sort = FALSE)
  if (any(is.na(participations$kavel_nummer))) stop("Niet iedere tellerregistratie is aan een kavel gekoppeld.", call. = FALSE)
  participations <- participations[
    participations$jaar >= year_min & participations$jaar <= year_max &
      !(participations$kavel_nummer == "M62" & participations$jaar == 2016L),
    ,
    drop = FALSE
  ]
  participations <- participations[order(participations$teller_id, participations$jaar, participations$plot_id), , drop = FALSE]
  rownames(participations) <- NULL

  experience_rows <- lapply(seq_len(nrow(participations)), function(index) {
    current <- participations[index, , drop = FALSE]
    teller_rows <- participations[
      participations$teller_id == current$teller_id & participations$jaar < current$jaar,
      ,
      drop = FALSE
    ]
    total_years <- unique(teller_rows$jaar)
    plot_years <- unique(teller_rows$jaar[teller_rows$plot_id == current$plot_id])
    elsewhere_years <- setdiff(total_years, plot_years)
    c(
      eerdere_jaren_totaal = length(total_years),
      eerdere_jaren_plot = length(plot_years),
      eerdere_jaren_elders = length(elsewhere_years)
    )
  })
  experience <- if (length(experience_rows)) do.call(rbind, experience_rows) else matrix(integer(), nrow = 0L, ncol = 3L)
  participations$eerdere_jaren_totaal <- as.integer(experience[, "eerdere_jaren_totaal"])
  participations$eerdere_jaren_plot <- as.integer(experience[, "eerdere_jaren_plot"])
  participations$eerdere_jaren_elders <- as.integer(experience[, "eerdere_jaren_elders"])
  participations$ervaring_plot_log1p <- log1p(participations$eerdere_jaren_plot)
  participations$ervaring_elders_log1p <- log1p(participations$eerdere_jaren_elders)

  team_split <- split(seq_len(nrow(participations)), paste(participations$plot_id, participations$jaar, sep = ":"))
  team_rows <- lapply(team_split, function(indices) {
    team <- participations[indices, , drop = FALSE]
    data.frame(
      plot_id = team$plot_id[[1L]],
      jaar = team$jaar[[1L]],
      tellerteam_sleutel = canonical_tellerteam_key(team$teller_id),
      aantal_tellers = length(unique(team$teller_id)),
      ervaring_plot_mean = mean(team$ervaring_plot_log1p),
      ervaring_plot_min = min(team$ervaring_plot_log1p),
      ervaring_plot_max = max(team$ervaring_plot_log1p),
      ervaring_elders_mean = mean(team$ervaring_elders_log1p),
      ervaring_elders_min = min(team$ervaring_elders_log1p),
      ervaring_elders_max = max(team$ervaring_elders_log1p),
      stringsAsFactors = FALSE
    )
  })
  teams <- if (length(team_rows)) do.call(rbind, team_rows) else data.frame()
  if (nrow(teams)) teams <- teams[order(teams$jaar, teams$plot_id), , drop = FALSE]
  rownames(teams) <- NULL

  summary <- data.frame(
    metric = c(
      "tellerdeelnames", "tellers", "plotjaren", "tellerteams",
      "eerste_geregistreerde_teljaren", "eerste_geregistreerde_plotjaren"
    ),
    value = as.numeric(c(
      nrow(participations),
      length(unique(participations$teller_id)),
      nrow(teams),
      length(unique(teams$tellerteam_sleutel)),
      sum(participations$eerdere_jaren_totaal == 0L),
      sum(participations$eerdere_jaren_plot == 0L)
    )),
    stringsAsFactors = FALSE
  )

  list(participations = participations, teams = teams, summary = summary)
}
