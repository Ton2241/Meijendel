extract_columns <- function(header) {
  start <- regexpr("\\(", header)[1]
  end <- regexpr("\\) VALUES", header)[1]
  cols <- substring(header, start + 1L, end - 1L)
  cols <- gsub("`", "", cols, fixed = TRUE)
  trimws(strsplit(cols, ",", fixed = TRUE)[[1]])
}

split_tuples <- function(values_text) {
  tuples <- character()
  n <- nchar(values_text, type = "bytes")
  in_quote <- FALSE
  escape_next <- FALSE
  depth <- 0L
  start <- NA_integer_

  for (i in seq_len(n)) {
    ch <- substr(values_text, i, i)

    if (escape_next) {
      escape_next <- FALSE
      next
    }

    if (ch == "\\") {
      escape_next <- TRUE
      next
    }

    if (ch == "'") {
      in_quote <- !in_quote
      next
    }

    if (!in_quote) {
      if (ch == "(") {
        if (depth == 0L) start <- i + 1L
        depth <- depth + 1L
      } else if (ch == ")") {
        depth <- depth - 1L
        if (depth == 0L && !is.na(start)) {
          tuples <- c(tuples, substring(values_text, start, i - 1L))
          start <- NA_integer_
        }
      }
    }
  }

  tuples
}

split_fields <- function(tuple_text) {
  fields <- character()
  n <- nchar(tuple_text, type = "bytes")
  in_quote <- FALSE
  escape_next <- FALSE
  start <- 1L

  for (i in seq_len(n)) {
    ch <- substr(tuple_text, i, i)

    if (escape_next) {
      escape_next <- FALSE
      next
    }

    if (ch == "\\") {
      escape_next <- TRUE
      next
    }

    if (ch == "'") {
      in_quote <- !in_quote
      next
    }

    if (!in_quote && ch == ",") {
      fields <- c(fields, substring(tuple_text, start, i - 1L))
      start <- i + 1L
    }
  }

  fields <- c(fields, substring(tuple_text, start, n))
  trimws(fields)
}

decode_sql_value <- function(x) {
  if (identical(x, "NULL")) {
    return(NA_character_)
  }

  if (nchar(x) >= 2L && substr(x, 1L, 1L) == "'" && substr(x, nchar(x), nchar(x)) == "'") {
    x <- substring(x, 2L, nchar(x) - 1L)
    x <- gsub("\\\\'", "'", x)
    x <- gsub("\\\\\\\\", "\\\\", x)
    return(x)
  }

  x
}

read_insert_table <- function(path, table, keep_columns = NULL) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  prefix <- paste0("INSERT INTO `", table, "` ")
  starts <- which(startsWith(lines, prefix))

  if (!length(starts)) {
    stop(sprintf("Geen INSERT-blokken gevonden voor tabel '%s'.", table))
  }

  out <- list()
  row_counter <- 0L

  for (idx in starts) {
    block_lines <- lines[idx]
    pos <- idx
    while (!grepl(";$", block_lines[length(block_lines)])) {
      pos <- pos + 1L
      block_lines <- c(block_lines, lines[pos])
    }

    block <- paste(block_lines, collapse = "\n")
    header <- sub("\n.*$", "", block)
    columns <- extract_columns(header)
    values_text <- sub("^.*?VALUES\\s*", "", block)
    values_text <- sub(";\\s*$", "", values_text)
    tuples <- split_tuples(values_text)

    parsed_rows <- vector("list", length(tuples))
    for (i in seq_along(tuples)) {
      fields <- split_fields(tuples[[i]])
      parsed_rows[[i]] <- vapply(fields, decode_sql_value, character(1))
    }

    mat <- do.call(rbind, parsed_rows)
    df <- as.data.frame(mat, stringsAsFactors = FALSE)
    names(df) <- columns

    if (!is.null(keep_columns)) {
      df <- df[keep_columns]
    }

    row_counter <- row_counter + 1L
    out[[row_counter]] <- df
  }

  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

to_integer <- function(x) as.integer(x)
to_numeric <- function(x) as.numeric(x)

parse_meijendel_tables <- function(path) {
  plots <- read_insert_table(path, "plots", c("plot_id", "plot_naam", "kavel_nummer"))
  soorten <- read_insert_table(path, "soorten", c("id", "euring_code", "soort_naam", "engelse_naam"))
  pjo <- read_insert_table(path, "plot_jaar_oppervlak", c("plot_id", "jaar", "oppervlakte_km2"))
  pjt <- read_insert_table(path, "plot_jaar_teller", c("plot_id", "jaar"))
  territoria <- read_insert_table(path, "territoria", c("plot_id", "soort_id", "jaar", "territoria"))
  evg_groepen <- read_insert_table(path, "evg_vogelgroepen", c("groepsnummer", "landschap_groep"))
  evg_koppeling <- read_insert_table(path, "evg_vogel_landschapgroep", c("groepsnummer", "vogel_id"))
  habitattypen <- read_insert_table(path, "habitattypen", c("id", "habitat_code", "habitat_naam"))
  pjh <- read_insert_table(path, "plot_jaar_habitat", c("plot_id", "jaar", "habitat_id", "aandeel_m2"))
  pja <- read_insert_table(path, "plot_jaar_ahn_dtm", c("plot_id", "jaar", "bron", "ahn_mean", "ahn_sd"))
  pjs <- read_insert_table(path, "plot_jaar_stikstof", c("plot_id", "jaar", "bron", "stikstof_mean"))
  pji <- read_insert_table(path, "plot_jaar_infra", c("plot_id", "jaar", "bron", "variabele", "waarde"))
  pjtg <- read_insert_table(path, "plot_jaar_toegankelijkheid", c("plot_id", "jaar", "bron", "status_code"))

  plots$plot_id <- to_integer(plots$plot_id)
  soorten$id <- to_integer(soorten$id)
  soorten$euring_code <- to_integer(soorten$euring_code)
  pjo$plot_id <- to_integer(pjo$plot_id)
  pjo$jaar <- to_integer(pjo$jaar)
  pjo$oppervlakte_km2 <- to_numeric(pjo$oppervlakte_km2)
  pjt$plot_id <- to_integer(pjt$plot_id)
  pjt$jaar <- to_integer(pjt$jaar)
  territoria$plot_id <- to_integer(territoria$plot_id)
  territoria$soort_id <- to_integer(territoria$soort_id)
  territoria$jaar <- to_integer(territoria$jaar)
  territoria$territoria <- to_numeric(territoria$territoria)
  evg_groepen$groepsnummer <- to_integer(evg_groepen$groepsnummer)
  evg_koppeling$groepsnummer <- to_integer(evg_koppeling$groepsnummer)
  evg_koppeling$vogel_id <- to_integer(evg_koppeling$vogel_id)
  habitattypen$id <- to_integer(habitattypen$id)
  pjh$plot_id <- to_integer(pjh$plot_id)
  pjh$jaar <- to_integer(pjh$jaar)
  pjh$habitat_id <- to_integer(pjh$habitat_id)
  pjh$aandeel_m2 <- to_numeric(pjh$aandeel_m2)
  pja$plot_id <- to_integer(pja$plot_id)
  pja$jaar <- to_integer(pja$jaar)
  pja$ahn_mean <- to_numeric(pja$ahn_mean)
  pja$ahn_sd <- to_numeric(pja$ahn_sd)
  pjs$plot_id <- to_integer(pjs$plot_id)
  pjs$jaar <- to_integer(pjs$jaar)
  pjs$stikstof_mean <- to_numeric(pjs$stikstof_mean)
  pji$plot_id <- to_integer(pji$plot_id)
  pji$jaar <- to_integer(pji$jaar)
  pji$waarde <- to_numeric(pji$waarde)
  pjtg$plot_id <- to_integer(pjtg$plot_id)
  pjtg$jaar <- to_integer(pjtg$jaar)

  list(
    plots = plots,
    soorten = soorten,
    plot_jaar_oppervlak = pjo,
    plot_jaar_teller = pjt,
    territoria = territoria,
    evg_vogelgroepen = evg_groepen,
    evg_vogel_landschapgroep = evg_koppeling,
    habitattypen = habitattypen,
    plot_jaar_habitat = pjh,
    plot_jaar_ahn_dtm = pja,
    plot_jaar_stikstof = pjs,
    plot_jaar_infra = pji,
    plot_jaar_toegankelijkheid = pjtg
  )
}

make_cache_signature <- function(path) {
  info <- file.info(path)
  paste(
    MEIJENDEL_PARSER_CACHE_VERSION,
    normalizePath(path, winslash = "/", mustWork = TRUE),
    info$size,
    as.numeric(info$mtime),
    sep = "|"
  )
}

load_meijendel_tables_cached <- function(path, cache_path = NULL) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (is.null(cache_path)) {
    cache_path <- file.path(tempdir(), "meijendel_tables_cache.rds")
  }

  signature <- make_cache_signature(path)

  if (file.exists(cache_path)) {
    cache <- tryCatch(readRDS(cache_path), error = function(e) NULL)
    cache_valid <- !is.null(cache) &&
      identical(cache$signature, signature) &&
      !is.null(cache$data) &&
      all(c("habitattypen", "plot_jaar_habitat", "plot_jaar_ahn_dtm", "plot_jaar_stikstof", "plot_jaar_infra", "plot_jaar_toegankelijkheid") %in% names(cache$data))
    if (cache_valid) {
      return(list(data = cache$data, from_cache = TRUE, cache_path = cache_path))
    }
  }

  data <- parse_meijendel_tables(path)
  cache <- list(signature = signature, data = data)
  saveRDS(cache, cache_path)
  list(data = data, from_cache = FALSE, cache_path = cache_path)
}

safe_mean <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  mean(x)
}

calc_pct_trend <- function(slope) {
  if (!is.finite(slope)) return(NA_real_)
  (exp(slope) - 1) * 100
}

duid_trend <- function(pct_per_year, p_value = NA_real_) {
  if (!is.finite(pct_per_year)) {
    return("onvoldoende_data")
  }
  if (is.finite(p_value) && p_value >= 0.05) {
    if (abs(pct_per_year) < 1) {
      return("stabiel")
    }
    return("onzeker")
  }
  abs_pct <- abs(pct_per_year)
  richting <- if (pct_per_year > 0) "toename" else if (pct_per_year < 0) "afname" else "stabiel"
  if (richting == "stabiel") {
    return("stabiel")
  }
  sterkte <- if (abs_pct >= 5) {
    "sterke"
  } else if (abs_pct >= 2) {
    "matige"
  } else {
    "lichte"
  }
  paste(sterkte, richting)
}

run_lm_trend <- function(df, value_col) {
  df <- df[is.finite(df[[value_col]]) & df[[value_col]] > 0, , drop = FALSE]
  if (nrow(df) < 3L || length(unique(df$jaar)) < 3L) {
    return(list(slope = NA_real_, p = NA_real_, r2 = NA_real_, n = nrow(df)))
  }
  fit <- lm(log(df[[value_col]]) ~ jaar, data = df)
  sm <- summary(fit)
  list(
    slope = unname(coef(fit)[["jaar"]]),
    p = sm$coefficients["jaar", "Pr(>|t|)"],
    r2 = sm$r.squared,
    n = nrow(df)
  )
}

fit_gam_curve <- function(df, value_col) {
  df <- df[is.finite(df[[value_col]]) & df[[value_col]] > 0, , drop = FALSE]
  if (nrow(df) < 5L || length(unique(df$jaar)) < 5L) {
    return(NULL)
  }

  n_years <- length(unique(df$jaar))
  k_value <- max(4L, min(10L, n_years - 1L))

  fit <- tryCatch(
    mgcv::gam(stats::as.formula(sprintf("log(%s) ~ s(jaar, k = %d)", value_col, k_value)), data = df, method = "REML"),
    error = function(e) NULL
  )
  if (is.null(fit)) {
    return(NULL)
  }

  pred_years <- data.frame(jaar = seq(min(df$jaar), max(df$jaar)))
  pred <- tryCatch(
    predict(fit, newdata = pred_years, se.fit = TRUE),
    error = function(e) NULL
  )
  if (is.null(pred)) {
    return(NULL)
  }

  pred_years$fit <- exp(pred$fit)
  pred_years$lower <- exp(pred$fit - 1.96 * pred$se.fit)
  pred_years$upper <- exp(pred$fit + 1.96 * pred$se.fit)
  pred_years
}

make_group_descriptions <- function(evg_vogelgroepen) {
  groep_100 <- unique((evg_vogelgroepen$groepsnummer %/% 100L) * 100L)
  groep_100 <- groep_100[order(groep_100)]
  label <- character(length(groep_100))

  for (i in seq_along(groep_100)) {
    g <- groep_100[[i]]
    rows <- evg_vogelgroepen[(evg_vogelgroepen$groepsnummer %/% 100L) * 100L == g, , drop = FALSE]
    exact <- rows$landschap_groep[rows$groepsnummer == g]
    if (length(exact) && !is.na(exact[[1]]) && nzchar(exact[[1]])) {
      label[[i]] <- exact[[1]]
    } else {
      label[[i]] <- rows$landschap_groep[[1]]
    }
  }

  data.frame(groep_100 = groep_100, groep_titel = label, stringsAsFactors = FALSE)
}

prepare_analysis_basis_subset <- function(tbls, selected_kavels, year_from, year_to) {
  years <- year_from:year_to
  pjo <- tbls$plot_jaar_oppervlak
  pjo <- merge(pjo, tbls$plots, by = "plot_id", all.x = TRUE)
  pjo <- pjo[pjo$jaar %in% years & pjo$kavel_nummer %in% selected_kavels, ]

  surveyed <- unique(rbind(
    tbls$plot_jaar_teller[c("plot_id", "jaar")],
    tbls$territoria[c("plot_id", "jaar")]
  ))
  surveyed$geteld <- TRUE

  basis <- merge(pjo, surveyed, by = c("plot_id", "jaar"), all.x = TRUE)
  basis$geteld[is.na(basis$geteld)] <- FALSE

  ref_area <- aggregate(oppervlakte_km2 ~ plot_id, data = basis, FUN = median, na.rm = TRUE)
  names(ref_area)[2] <- "referentie_oppervlakte_km2"
  basis <- merge(basis, ref_area, by = "plot_id", all.x = TRUE)
  basis$oppervlakte_factor <- ifelse(
    is.finite(basis$oppervlakte_km2) &
      basis$oppervlakte_km2 > 0 &
      is.finite(basis$referentie_oppervlakte_km2) &
      basis$referentie_oppervlakte_km2 > 0,
    basis$referentie_oppervlakte_km2 / basis$oppervlakte_km2,
    NA_real_
  )
  basis$analyse_reeks <- sprintf("subset_%s_%s", year_from, year_to)
  basis[order(basis$jaar, basis$kavel_nummer, basis$plot_id), ]
}

build_species_selection_subset <- function(tbls, selected_kavels, year_from, year_to) {
  territoria <- tbls$territoria[tbls$territoria$jaar >= year_from & tbls$territoria$jaar <= year_to, c("plot_id", "soort_id", "jaar", "territoria")]
  territoria <- merge(territoria, tbls$plots[, c("plot_id", "kavel_nummer")], by = "plot_id", all.x = TRUE)
  territoria <- territoria[territoria$kavel_nummer %in% selected_kavels, , drop = FALSE]
  territoria <- territoria[territoria$territoria > 0, , drop = FALSE]

  total_presence <- aggregate(territoria ~ soort_id, data = territoria, FUN = sum, na.rm = TRUE)
  names(total_presence)[2] <- "som_territoria"

  out <- merge(tbls$soorten, total_presence, by.x = "id", by.y = "soort_id", all.x = TRUE)
  out$som_territoria[is.na(out$som_territoria)] <- 0
  out$in_selectie <- out$som_territoria > 0
  out$selectie_reden <- ifelse(out$in_selectie, "aanwezig_in_geselecteerde_kavels_en_jaren", "geen_territoria_in_selectie")
  out[order(out$soort_naam), ]
}

build_species_matrix_subset <- function(tbls, basis, selection_df, year_from, year_to) {
  selected_species <- selection_df$id[selection_df$in_selectie]
  grid <- expand.grid(
    soort_id = selected_species,
    row_id = seq_len(nrow(basis)),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid <- merge(
    grid,
    data.frame(row_id = seq_len(nrow(basis)), basis, stringsAsFactors = FALSE),
    by = "row_id",
    all.x = TRUE
  )
  grid$row_id <- NULL

  counts <- tbls$territoria[tbls$territoria$jaar >= year_from & tbls$territoria$jaar <= year_to, c("plot_id", "soort_id", "jaar", "territoria")]
  grid <- merge(grid, counts, by = c("plot_id", "soort_id", "jaar"), all.x = TRUE)
  grid <- merge(
    grid,
    selection_df[, c("id", "euring_code", "soort_naam", "engelse_naam")],
    by.x = "soort_id",
    by.y = "id",
    all.x = TRUE
  )

  grid$count_raw <- ifelse(grid$geteld & is.na(grid$territoria), 0, grid$territoria)
  grid$count_adjusted <- ifelse(grid$geteld, grid$count_raw * grid$oppervlakte_factor, NA_real_)
  grid[order(grid$soort_id, grid$plot_id, grid$jaar), ]
}

prepare_trim_period <- function(df) {
  df <- df[df$geteld & is.finite(df$count_adjusted), , drop = FALSE]
  if (!nrow(df)) {
    return(list(ok = FALSE, reason = "geen_getelde_cellen"))
  }

  year_totals <- aggregate(count_adjusted ~ jaar, data = df, FUN = function(x) sum(x, na.rm = TRUE))
  positive_years <- sort(year_totals$jaar[year_totals$count_adjusted > 0])
  if (length(positive_years) < 3L) {
    return(list(ok = FALSE, reason = "te_weinig_positieve_jaren"))
  }

  df <- df[df$jaar %in% positive_years, , drop = FALSE]
  site_totals <- aggregate(count_adjusted ~ plot_id, data = df, FUN = function(x) sum(x, na.rm = TRUE))
  active_sites <- site_totals$plot_id[site_totals$count_adjusted > 0]
  if (!length(active_sites)) {
    return(list(ok = FALSE, reason = "geen_actieve_plots"))
  }
  df <- df[df$plot_id %in% active_sites, , drop = FALSE]

  year_map <- data.frame(
    jaar = positive_years,
    trim_year = seq_along(positive_years),
    stringsAsFactors = FALSE
  )
  df <- merge(df, year_map, by = "jaar", all.x = TRUE)
  df <- df[order(df$plot_id, df$jaar), ]

  list(ok = TRUE, data = df, year_map = year_map)
}

fit_trim_model <- function(df) {
  prepared <- prepare_trim_period(df)
  if (!prepared$ok) {
    return(list(model = NULL, config = NA_character_, error = prepared$reason, warnings = NA_character_, year_map = NULL))
  }

  df_fit <- prepared$data[, c("plot_id", "trim_year", "count_adjusted")]
  names(df_fit) <- c("site", "year", "count")

  configs <- list(
    list(model = 3, overdisp = FALSE, serialcor = FALSE, label = "model3_basis"),
    list(model = 3, overdisp = TRUE, serialcor = FALSE, label = "model3_overdisp"),
    list(model = 3, overdisp = TRUE, serialcor = TRUE, label = "model3_overdisp_serialcor"),
    list(model = 2, overdisp = FALSE, serialcor = FALSE, label = "model2_basis")
  )

  last_error <- NULL
  last_warnings <- character()

  for (cfg in configs) {
    warning_messages <- character()
    fit <- tryCatch(
      withCallingHandlers(
        rtrim::trim(
          df_fit,
          model = cfg$model,
          overdisp = cfg$overdisp,
          serialcor = cfg$serialcor,
          autodelete = TRUE,
          conv_crit = 1e-5,
          max_iter = 400
        ),
        warning = function(w) {
          warning_messages <<- c(warning_messages, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) e
    )
    if (!inherits(fit, "error")) {
      return(list(
        model = fit,
        config = cfg$label,
        error = NA_character_,
        warnings = if (length(warning_messages)) paste(unique(warning_messages), collapse = " | ") else NA_character_,
        year_map = prepared$year_map
      ))
    }
    last_error <- conditionMessage(fit)
    last_warnings <- warning_messages
  }

  list(
    model = NULL,
    config = NA_character_,
    error = last_error,
    warnings = if (length(last_warnings)) paste(unique(last_warnings), collapse = " | ") else NA_character_,
    year_map = prepared$year_map
  )
}

collect_index <- function(fit_obj, soort_id, soort_naam, euring_code, engelse_naam) {
  idx <- rtrim::index(fit_obj$model)
  jaar_lookup <- fit_obj$year_map
  out <- merge(
    data.frame(trim_year = idx$time, trim_index = idx$imputed, trim_se = idx$se_imp, stringsAsFactors = FALSE),
    jaar_lookup,
    by = "trim_year",
    all.x = TRUE
  )
  out <- out[order(out$jaar), ]
  out$soort_id <- soort_id
  out$euring_code <- euring_code
  out$soort_naam <- soort_naam
  out$engelse_naam <- engelse_naam
  out$model_config <- fit_obj$config
  out$model_warnings <- fit_obj$warnings
  out$trim_year <- NULL
  base_value <- out$trim_index[match(min(out$jaar), out$jaar)]
  out$index_100 <- ifelse(
    is.finite(out$trim_index) & is.finite(base_value) & base_value > 0,
    100 * out$trim_index / base_value,
    NA_real_
  )
  out[, c("soort_id", "euring_code", "soort_naam", "engelse_naam", "jaar", "trim_index", "trim_se", "index_100", "model_config", "model_warnings")]
}

classificeer_soort_status <- function(model_ok, positieve_jaren, getelde_cellen) {
  if (positieve_jaren < 3L || getelde_cellen < 3L) {
    return("te_zeldzaam")
  }
  if (model_ok) {
    return("trim_bruikbaar")
  }
  "model_mislukt"
}

analyse_species_subset <- function(species_matrix) {
  split_species <- split(species_matrix, species_matrix$soort_id)
  status_rows <- list()
  index_rows <- list()
  trend_rows <- list()

  counter <- 0L
  for (df in split_species) {
    counter <- counter + 1L
    soort_id <- unique(df$soort_id)[1]
    soort_naam <- unique(df$soort_naam)[1]
    engelse_naam <- unique(df$engelse_naam)[1]
    euring_code <- unique(df$euring_code)[1]

    positieve_cellen <- sum(df$geteld & is.finite(df$count_adjusted) & df$count_adjusted > 0, na.rm = TRUE)
    positieve_jaren <- length(unique(df$jaar[df$geteld & is.finite(df$count_adjusted) & df$count_adjusted > 0]))
    getelde_cellen <- sum(df$geteld & is.finite(df$count_adjusted), na.rm = TRUE)
    n_jaren_geteld <- length(unique(df$jaar[df$geteld & is.finite(df$count_adjusted)]))

    fit <- if (positieve_jaren >= 3L && getelde_cellen >= 3L) {
      fit_trim_model(df)
    } else {
      list(model = NULL, config = NA_character_, error = "te_weinig_data", warnings = NA_character_, year_map = NULL)
    }

    analyse_categorie <- classificeer_soort_status(!is.null(fit$model), positieve_jaren, getelde_cellen)

    status_rows[[counter]] <- data.frame(
      soort_id = soort_id,
      euring_code = euring_code,
      soort_naam = soort_naam,
      engelse_naam = engelse_naam,
      n_getelde_cellen = getelde_cellen,
      n_positieve_cellen = positieve_cellen,
      n_jaren_geteld = n_jaren_geteld,
      n_positieve_jaren = positieve_jaren,
      model_gelukt = !is.null(fit$model),
      model = fit$config,
      fout = fit$error,
      waarschuwingen = fit$warnings,
      analyse_categorie = analyse_categorie,
      stringsAsFactors = FALSE
    )

    if (!is.null(fit$model)) {
      index_df <- collect_index(fit, soort_id, soort_naam, euring_code, engelse_naam)
      index_rows[[counter]] <- index_df

      tr <- run_lm_trend(index_df, "index_100")
      pct <- calc_pct_trend(tr$slope)
      trend_rows[[counter]] <- data.frame(
        soort_id = soort_id,
        euring_code = euring_code,
        soort_naam = soort_naam,
        engelse_naam = engelse_naam,
        analyse_categorie = analyse_categorie,
        eerste_jaar = min(index_df$jaar, na.rm = TRUE),
        laatste_jaar = max(index_df$jaar, na.rm = TRUE),
        n_jaren_index = nrow(index_df),
        trend_pct_per_jaar = pct,
        trend_p = tr$p,
        trend_r2 = tr$r2,
        trend_uitleg = duid_trend(pct, tr$p),
        model = fit$config,
        stringsAsFactors = FALSE
      )
    }
  }

  list(
    status = do.call(rbind, status_rows),
    indices = do.call(rbind, Filter(Negate(is.null), index_rows)),
    trends = do.call(rbind, Filter(Negate(is.null), trend_rows))
  )
}

build_group_mapping <- function(tbls) {
  mapping <- unique(data.frame(
    soort_id = tbls$evg_vogel_landschapgroep$vogel_id,
    groep_100 = (tbls$evg_vogel_landschapgroep$groepsnummer %/% 100L) * 100L,
    stringsAsFactors = FALSE
  ))
  mapping <- mapping[order(mapping$groep_100, mapping$soort_id), ]
  merge(mapping, make_group_descriptions(tbls$evg_vogelgroepen), by = "groep_100", all.x = TRUE)
}

analyse_groups_subset <- function(species_indices, group_mapping) {
  merged <- merge(
    species_indices[, c("soort_id", "euring_code", "soort_naam", "engelse_naam", "jaar", "index_100")],
    group_mapping,
    by = "soort_id",
    all = FALSE
  )

  merged <- merged[is.finite(merged$index_100) & merged$index_100 > 0, ]
  merged$log_index <- log(merged$index_100)

  msi <- aggregate(log_index ~ groep_100 + groep_titel + jaar, data = merged, FUN = mean)
  n_species <- aggregate(soort_id ~ groep_100 + jaar, data = merged, FUN = function(x) length(unique(x)))
  names(n_species)[3] <- "n_soorten"
  msi <- merge(msi, n_species, by = c("groep_100", "jaar"), all.x = TRUE)
  msi$msi <- exp(msi$log_index)
  msi <- msi[order(msi$groep_100, msi$jaar), ]

  trend_rows <- lapply(split(msi, msi$groep_100), function(df) {
    tr <- run_lm_trend(df, "msi")
    pct <- calc_pct_trend(tr$slope)
    data.frame(
      groep_100 = df$groep_100[[1]],
      groep_titel = df$groep_titel[[1]],
      eerste_jaar = min(df$jaar, na.rm = TRUE),
      laatste_jaar = max(df$jaar, na.rm = TRUE),
      gemiddeld_n_soorten = mean(df$n_soorten, na.rm = TRUE),
      trend_pct_per_jaar = pct,
      trend_p = tr$p,
      trend_r2 = tr$r2,
      trend_uitleg = duid_trend(pct, tr$p),
      stringsAsFactors = FALSE
    )
  })

  composition <- unique(merged[, c("groep_100", "groep_titel", "soort_id", "euring_code", "soort_naam", "engelse_naam")])
  composition <- composition[order(composition$groep_100, composition$soort_naam), ]

  list(
    msi = msi,
    trends = do.call(rbind, trend_rows),
    composition = composition
  )
}

analyse_subset <- function(tbls, selected_kavels, year_from, year_to) {
  basis <- prepare_analysis_basis_subset(tbls, selected_kavels, year_from, year_to)
  selection_df <- build_species_selection_subset(tbls, selected_kavels, year_from, year_to)
  species_matrix <- build_species_matrix_subset(tbls, basis, selection_df, year_from, year_to)
  species_results <- analyse_species_subset(species_matrix)
  group_mapping <- build_group_mapping(tbls)
  group_results <- analyse_groups_subset(species_results$indices, group_mapping)

  list(
    basis = basis,
    selection = selection_df,
    species_matrix = species_matrix,
    species_results = species_results,
    group_results = group_results
  )
}

find_species_by_name <- function(tbls, species_name) {
  exact <- tbls$soorten[tbls$soorten$soort_naam == species_name, , drop = FALSE]
  if (nrow(exact) == 1L) {
    return(exact)
  }
  case_insensitive <- tbls$soorten[tolower(tbls$soorten$soort_naam) == tolower(species_name), , drop = FALSE]
  if (nrow(case_insensitive) == 1L) {
    return(case_insensitive)
  }
  stop(sprintf("Soort niet gevonden: %s", species_name))
}

find_group_by_code <- function(tbls, groep_100) {
  groups <- make_group_descriptions(tbls$evg_vogelgroepen)
  row <- groups[groups$groep_100 == as.integer(groep_100), , drop = FALSE]
  if (nrow(row) == 1L) {
    return(row)
  }
  stop(sprintf("Ecologische vogelgroep niet gevonden: %s", groep_100))
}

pick_nearest_value_by_year <- function(rows, target_year, value_col, allow_past_only = FALSE) {
  if (!nrow(rows)) {
    return(NA)
  }
  rows <- rows[is.finite(rows$jaar), , drop = FALSE]
  if (!nrow(rows)) {
    return(NA)
  }
  if (allow_past_only) {
    rows <- rows[rows$jaar <= target_year, , drop = FALSE]
    if (!nrow(rows)) {
      return(NA)
    }
    rows <- rows[order(-rows$jaar), , drop = FALSE]
    return(rows[[value_col]][[1]])
  }
  rows$afstand <- abs(rows$jaar - target_year)
  rows <- rows[order(rows$afstand, -rows$jaar), , drop = FALSE]
  rows[[value_col]][[1]]
}

add_numeric_covariate <- function(dat, source_df, value_col, new_col, variabele = NULL) {
  if (nrow(dat) == 0L) {
    dat[[new_col]] <- numeric()
    return(dat)
  }
  if (!is.null(variabele)) {
    source_df <- source_df[source_df$variabele == variabele, , drop = FALSE]
  }
  dat[[new_col]] <- vapply(seq_len(nrow(dat)), function(i) {
    rows <- source_df[source_df$plot_id == dat$plot_id[[i]], , drop = FALSE]
    val <- pick_nearest_value_by_year(rows, dat$jaar[[i]], value_col)
    if (length(val) == 0L || is.null(val)) {
      return(NA_real_)
    }
    as.numeric(val)
  }, numeric(1))
  dat
}

add_toegankelijkheid_covariate <- function(dat, source_df, new_col = "toegankelijkheid_status") {
  if (nrow(dat) == 0L) {
    dat[[new_col]] <- character()
    return(dat)
  }
  dat[[new_col]] <- vapply(seq_len(nrow(dat)), function(i) {
    rows <- source_df[source_df$plot_id == dat$plot_id[[i]], , drop = FALSE]
    val <- pick_nearest_value_by_year(rows, dat$jaar[[i]], "status_code", allow_past_only = TRUE)
    if (length(val) == 0L || is.null(val) || is.na(val)) {
      return("onbekend")
    }
    as.character(val)
  }, character(1))
  dat[[new_col]] <- factor(dat[[new_col]], levels = c("vrij", "beperkt", "afgesloten", "deels beperkt, deels vrij", "deels afgesloten, deels vrij", "onbekend"))
  dat
}

build_gee_dataset <- function(tbls, selected_kavels, year_from, year_to, target_type = c("species", "group"), target_value) {
  target_type <- match.arg(target_type)
  basis <- prepare_analysis_basis_subset(tbls, selected_kavels, year_from, year_to)
  if (!nrow(basis)) {
    stop("Geen geldige plot-jaar-combinaties voor deze selectie.")
  }

  if (target_type == "species") {
    species_row <- find_species_by_name(tbls, target_value)
    counts <- tbls$territoria[
      tbls$territoria$soort_id == species_row$id[[1]] &
        tbls$territoria$jaar >= year_from &
        tbls$territoria$jaar <= year_to,
      c("plot_id", "jaar", "territoria")
    ]
    target_label <- species_row$soort_naam[[1]]
    target_slug <- tolower(gsub("[^a-z0-9]+", "_", target_label))
  } else {
    species_row <- NULL
    group_row <- find_group_by_code(tbls, target_value)
    group_mapping <- build_group_mapping(tbls)
    group_species <- unique(group_mapping$soort_id[group_mapping$groep_100 == group_row$groep_100[[1]]])
    counts <- tbls$territoria[
      tbls$territoria$soort_id %in% group_species &
        tbls$territoria$jaar >= year_from &
        tbls$territoria$jaar <= year_to,
      c("plot_id", "jaar", "territoria")
    ]
    target_label <- group_row$groep_titel[[1]]
    target_slug <- paste0("groep_", group_row$groep_100[[1]], "_", tolower(gsub("[^a-z0-9]+", "_", target_label)))
  }
  if (nrow(counts)) {
    counts <- aggregate(territoria ~ plot_id + jaar, data = counts, FUN = sum, na.rm = TRUE)
    names(counts)[names(counts) == "territoria"] <- "count"
  } else {
    counts <- data.frame(plot_id = integer(), jaar = integer(), count = numeric(), stringsAsFactors = FALSE)
  }

  dat <- merge(basis, counts, by = c("plot_id", "jaar"), all.x = TRUE)
  dat$count <- ifelse(dat$geteld & is.na(dat$count), 0, dat$count)
  dat$count <- ifelse(!dat$geteld, NA_real_, dat$count)
  dat$log_area <- ifelse(is.finite(dat$oppervlakte_km2) & dat$oppervlakte_km2 > 0, log(dat$oppervlakte_km2), NA_real_)
  dat$year_c <- dat$jaar - min(dat$jaar, na.rm = TRUE)

  dat <- add_numeric_covariate(dat, tbls$plot_jaar_ahn_dtm, "ahn_mean", "ahn_mean")
  dat <- add_numeric_covariate(dat, tbls$plot_jaar_ahn_dtm, "ahn_sd", "ahn_sd")
  dat <- add_numeric_covariate(dat, tbls$plot_jaar_stikstof, "stikstof_mean", "stikstof_mean")
  dat <- add_numeric_covariate(dat, tbls$plot_jaar_infra, "waarde", "afstand_pad_m", "afstand_pad_m")
  dat <- add_numeric_covariate(dat, tbls$plot_jaar_infra, "waarde", "padlengte_m_per_ha", "padlengte_m_per_ha")
  dat <- add_numeric_covariate(dat, tbls$plot_jaar_infra, "waarde", "afstand_parkeerplaats_m", "afstand_parkeerplaats_m")
  dat <- add_numeric_covariate(dat, tbls$plot_jaar_infra, "waarde", "afstand_hoofdtoegang_m", "afstand_hoofdtoegang_m")
  dat <- add_toegankelijkheid_covariate(dat, tbls$plot_jaar_toegankelijkheid)

  dat$analyse_niveau <- ifelse(target_type == "species", "Soort", "Ecologische Vogelgroep")
  dat$doel_label <- target_label
  dat$doel_slug <- target_slug
  if (target_type == "species") {
    dat$soort_id <- species_row$id[[1]]
    dat$soort_naam <- species_row$soort_naam[[1]]
    dat$engelse_naam <- species_row$engelse_naam[[1]]
    dat$groep_100 <- NA_integer_
    dat$groep_titel <- NA_character_
  } else {
    dat$soort_id <- NA_integer_
    dat$soort_naam <- NA_character_
    dat$engelse_naam <- NA_character_
    dat$groep_100 <- as.integer(target_value)
    dat$groep_titel <- target_label
  }
  dat[order(dat$plot_id, dat$jaar), ]
}

gee_covariate_specs <- function() {
  data.frame(
    code = c(
      "year_c",
      "stikstof_mean",
      "toegankelijkheid_status"
    ),
    label = c(
      "Jaar (controlevariabele)",
      "Stikstof gemiddelde depositie",
      "Toegankelijkheidsstatus"
    ),
    type = c("numeric", "numeric", "factor"),
    stringsAsFactors = FALSE
  )
}

gee_ahn_covariate_specs <- function() {
  data.frame(
    code = c("ahn_mean", "ahn_sd"),
    label = c("Gemiddelde hoogte", "Standaard deviatie"),
    type = c("numeric", "numeric"),
    stringsAsFactors = FALSE
  )
}

gee_infra_covariate_specs <- function() {
  data.frame(
    code = c("afstand_pad_m", "padlengte_m_per_ha", "afstand_parkeerplaats_m", "afstand_hoofdtoegang_m"),
    label = c("Afstand tot pad", "Padlengte per hectare", "Afstand tot parkeerplaats", "Afstand tot hoofdtoegang"),
    type = c("numeric", "numeric", "numeric", "numeric"),
    stringsAsFactors = FALSE
  )
}

gee_habitat_covariate_specs <- function(tbls) {
  if (is.null(tbls$habitattypen) || !nrow(tbls$habitattypen)) {
    return(data.frame(code = character(), label = character(), habitat_id = integer(), stringsAsFactors = FALSE))
  }
  out <- tbls$habitattypen[, c("id", "habitat_code", "habitat_naam")]
  out$code <- paste0("habitat_", out$id)
  out$label <- paste0(out$habitat_code, " - ", out$habitat_naam)
  names(out)[names(out) == "id"] <- "habitat_id"
  out[, c("code", "label", "habitat_id")]
}

build_habitat_share_lookup <- function(tbls) {
  pjh <- tbls$plot_jaar_habitat
  if (is.null(pjh) || !nrow(pjh)) {
    return(data.frame())
  }
  opp <- tbls$plot_jaar_oppervlak[, c("plot_id", "jaar", "oppervlakte_km2")]
  hab <- merge(pjh, opp, by = c("plot_id", "jaar"), all.x = TRUE)
  hab$share_pct <- ifelse(
    is.finite(hab$aandeel_m2) & is.finite(hab$oppervlakte_km2) & hab$oppervlakte_km2 > 0,
    100 * hab$aandeel_m2 / (hab$oppervlakte_km2 * 1000000),
    NA_real_
  )
  hab
}

add_habitat_covariates <- function(dat, tbls, habitat_codes) {
  if (!length(habitat_codes) || !nrow(dat)) {
    return(dat)
  }
  specs <- gee_habitat_covariate_specs(tbls)
  lookup <- build_habitat_share_lookup(tbls)
  for (code in habitat_codes) {
    row <- specs[specs$code == code, , drop = FALSE]
    if (!nrow(row)) next
    habitat_id <- row$habitat_id[[1]]
    dat[[code]] <- vapply(seq_len(nrow(dat)), function(i) {
      rows <- lookup[lookup$plot_id == dat$plot_id[[i]] & lookup$habitat_id == habitat_id, , drop = FALSE]
      val <- pick_nearest_value_by_year(rows, dat$jaar[[i]], "share_pct")
      if (length(val) == 0L || is.null(val)) {
        return(NA_real_)
      }
      as.numeric(val)
    }, numeric(1))
  }
  dat
}

sanitize_gee_design <- function(dat_model, chosen) {
  dat_model <- droplevels(dat_model)
  keep <- character()
  dropped <- character()

  for (nm in chosen) {
    x <- dat_model[[nm]]
    if (is.factor(x)) {
      x <- droplevels(x)
      dat_model[[nm]] <- x
      if (nlevels(x) < 2L) {
        dropped <- c(dropped, nm)
      } else {
        keep <- c(keep, nm)
      }
    } else {
      vals <- x[is.finite(x)]
      if (length(unique(vals)) < 2L) {
        dropped <- c(dropped, nm)
      } else {
        keep <- c(keep, nm)
      }
    }
  }

  if (!length(keep)) {
    stop("Alle gekozen covariaten vallen weg in deze selectie. Kies minder of andere covariaten.")
  }

  repeat {
    rhs <- stats::reformulate(keep)
    mm <- stats::model.matrix(rhs, data = dat_model)
    q <- qr(mm)
    if (q$rank == ncol(mm)) {
      break
    }
    assign_idx <- attr(mm, "assign")
    term_labels <- attr(stats::terms(rhs), "term.labels")
    dropped_cols <- setdiff(seq_len(ncol(mm)), q$pivot[seq_len(q$rank)])
    dropped_terms_idx <- unique(assign_idx[dropped_cols])
    dropped_terms_idx <- dropped_terms_idx[dropped_terms_idx > 0L]
    if (!length(dropped_terms_idx)) {
      break
    }
    aliased_terms <- term_labels[dropped_terms_idx]
    keep <- setdiff(keep, aliased_terms)
    dropped <- c(dropped, aliased_terms)
    if (!length(keep)) {
      stop("De gekozen covariaten zijn lineair afhankelijk in deze selectie. Kies minder of andere covariaten.")
    }
  }

  list(
    data = dat_model,
    chosen = keep,
    dropped = unique(dropped)
  )
}

precheck_gee_complexity <- function(dat_model, gee_corstr) {
  cluster_sizes <- as.integer(table(dat_model$plot_id))
  n_clusters <- length(cluster_sizes)
  max_cluster <- max(cluster_sizes)
  n_rows <- nrow(dat_model)

  if (gee_corstr == "unstructured" && max_cluster > 12L) {
    stop("Correlatiestructuur 'unstructured' is te zwaar voor deze selectie. Kies 'independence' of 'ar1'.")
  }

  if (gee_corstr == "exchangeable" && max_cluster > 40L && n_clusters > 10L) {
    stop("Correlatiestructuur 'exchangeable' is te zwaar voor deze selectie. Kies 'independence' of verklein jaren/kavels.")
  }

  if (gee_corstr == "ar1" && max_cluster > 80L && n_rows > 1500L) {
    stop("Correlatiestructuur 'ar1' is te zwaar voor deze selectie. Verklein jaren/kavels of kies 'independence'.")
  }

  invisible(list(
    n_clusters = n_clusters,
    max_cluster = max_cluster,
    n_rows = n_rows
  ))
}

run_gee_subset <- function(tbls, selected_kavels, year_from, year_to, target_type = c("species", "group"), target_value, covariates, ahn_covariates = character(), infra_covariates = character(), habitat_covariates = character(), gee_corstr = "exchangeable") {
  target_type <- match.arg(target_type)
  if (!requireNamespace("geepack", quietly = TRUE)) {
    stop("Package 'geepack' is niet beschikbaar.")
  }
  if (!requireNamespace("broom", quietly = TRUE)) {
    stop("Package 'broom' is niet beschikbaar.")
  }
  cov_specs <- gee_covariate_specs()
  ahn_specs <- gee_ahn_covariate_specs()
  infra_specs <- gee_infra_covariate_specs()
  habitat_specs <- gee_habitat_covariate_specs(tbls)
  chosen <- unique(c("year_c", covariates, ahn_covariates, infra_covariates, habitat_covariates))
  allowed <- unique(c(cov_specs$code, ahn_specs$code, infra_specs$code, habitat_specs$code))
  chosen <- chosen[chosen %in% allowed]
  if (!length(chosen)) {
    stop("Kies minstens één G.E.E.-covariaat.")
  }

  dat <- build_gee_dataset(tbls, selected_kavels, year_from, year_to, target_type = target_type, target_value = target_value)
  dat <- add_habitat_covariates(dat, tbls, habitat_covariates)
  dat_model <- dat[!is.na(dat$count) & is.finite(dat$log_area), , drop = FALSE]
  for (nm in chosen) {
    type_val <- cov_specs$type[cov_specs$code == nm]
    if (!length(type_val)) {
      type_val <- ahn_specs$type[ahn_specs$code == nm]
    }
    if (!length(type_val)) {
      type_val <- infra_specs$type[infra_specs$code == nm]
    }
    if (!length(type_val)) {
      type_val <- "numeric"
    }
    if (type_val == "numeric") {
      dat_model <- dat_model[is.finite(dat_model[[nm]]), , drop = FALSE]
    } else {
      dat_model <- dat_model[!is.na(dat_model[[nm]]) & nzchar(as.character(dat_model[[nm]])), , drop = FALSE]
    }
  }

  if (nrow(dat_model) < 20L) {
    stop("Te weinig bruikbare plot-jaren voor een stabiele G.E.E.-analyse.")
  }
  if (length(unique(dat_model$jaar)) < 3L) {
    stop("Te weinig unieke jaren voor een G.E.E.-analyse.")
  }
  if (length(unique(dat_model$plot_id)) < 2L) {
    stop("Te weinig unieke plots voor een G.E.E.-analyse.")
  }
  if (sum(dat_model$count, na.rm = TRUE) <= 0) {
    stop("Geen territoria voor deze selectie.")
  }

  design <- sanitize_gee_design(dat_model, chosen)
  dat_model <- design$data
  chosen <- design$chosen

  dat_model <- dat_model[order(dat_model$plot_id, dat_model$jaar), , drop = FALSE]
  precheck_gee_complexity(dat_model, gee_corstr)
  pre_mm <- stats::model.matrix(stats::reformulate(chosen), data = dat_model)
  pre_qr <- qr(pre_mm)
  if (pre_qr$rank < ncol(pre_mm)) {
    stop("De overblijvende covariaten zijn in deze selectie nog lineair afhankelijk. Kies minder habitattypen of minder covariaten tegelijk.")
  }
  formula_txt <- sprintf("count ~ %s + offset(log_area)", paste(chosen, collapse = " + "))
  gee_fit <- tryCatch({
    setTimeLimit(elapsed = 20, transient = TRUE)
    on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
    geepack::geeglm(
      formula = stats::as.formula(formula_txt),
      family = stats::poisson(link = "log"),
      id = plot_id,
      corstr = gee_corstr,
      control = geepack::geese.control(maxit = 20, epsilon = 1e-04, trace = FALSE),
      data = dat_model
    )
  }, error = function(e) e)

  if (inherits(gee_fit, "error")) {
    msg <- conditionMessage(gee_fit)
    if (grepl("elapsed time limit", msg, fixed = TRUE)) {
      stop("De G.E.E.-fit duurde te lang. Kies minder jaren, minder kavels of een eenvoudigere correlatiestructuur zoals independence.")
    }
    stop(msg)
  }

  coef_tab <- broom::tidy(gee_fit)
  coef_tab <- coef_tab[coef_tab$term != "(Intercept)", , drop = FALSE]
  coef_tab$irr <- exp(coef_tab$estimate)
  coef_tab$irr_low <- exp(coef_tab$estimate - 1.96 * coef_tab$std.error)
  coef_tab$irr_high <- exp(coef_tab$estimate + 1.96 * coef_tab$std.error)

  summary_df <- data.frame(
    analyse_niveau = unique(dat_model$analyse_niveau)[1],
    doel_label = unique(dat_model$doel_label)[1],
    doel_slug = unique(dat_model$doel_slug)[1],
    gee_corstr = gee_corstr,
    covariaten = paste(chosen, collapse = ", "),
    covariaten_vervallen = paste(design$dropped, collapse = ", "),
    n_plots = length(unique(dat_model$plot_id)),
    n_plot_jaren = nrow(dat_model),
    eerste_jaar = min(dat_model$jaar, na.rm = TRUE),
    laatste_jaar = max(dat_model$jaar, na.rm = TRUE),
    totaal_territoria = sum(dat_model$count, na.rm = TRUE),
    stringsAsFactors = FALSE
  )

  list(
    dataset = dat,
    model_data = dat_model,
    coefficients = coef_tab,
    summary = summary_df,
    fit = gee_fit,
    covariates = chosen
  )
}

load_t0_msi_selection <- function(path = NULL) {
  candidates <- if (is.null(path)) {
    c(
      "evg_selctie_T0soort_T0msi.csv",
      file.path("..", "R", "evg_selctie_T0soort_T0msi.csv")
    )
  } else {
    path
  }

  existing <- candidates[file.exists(candidates)]
  if (!length(existing)) {
    return(NULL)
  }

  df <- utils::read.csv(existing[[1]], stringsAsFactors = FALSE)
  required <- c("groep_100", "soort_id", "t0_msi_eindselectie")
  if (!all(required %in% names(df))) {
    return(NULL)
  }

  df <- df[df$t0_msi_eindselectie %in% c(TRUE, "TRUE", 1, "1"), required, drop = FALSE]
  df$groep_100 <- as.integer(df$groep_100)
  df$soort_id <- as.integer(df$soort_id)
  unique(df)
}

classificeer_lambda_status <- function(valid_years, consecutive_pairs, zero_share, positive_years, pre_present, post_present) {
  if (!is.finite(valid_years) || valid_years < 10L) {
    return("ongeschikt_voor_T0")
  }
  if (!is.finite(consecutive_pairs) || consecutive_pairs < 8L) {
    return("ongeschikt_voor_T0")
  }
  if (!is.finite(zero_share) || zero_share > 0.50) {
    return("ongeschikt_voor_T0")
  }
  if (!is.finite(positive_years) || positive_years < 5L) {
    return("ongeschikt_voor_T0")
  }
  if (valid_years >= 12L &&
      consecutive_pairs >= 10L &&
      zero_share <= 0.33 &&
      isTRUE(pre_present) &&
      isTRUE(post_present)) {
    return("geschikt_voor_T0_MSI")
  }
  "geschikt_voor_T0_soortanalyse"
}

bereken_lambda_jaarreeks <- function(df, id_cols, value_col = "count_adjusted") {
  if (!nrow(df)) {
    return(df)
  }

  df <- df[df$jaar != 1958L, , drop = FALSE]
  if (!nrow(df)) {
    return(df)
  }

  df$periode <- ifelse(df$jaar <= 1983L, "1959-1983", "1984-heden")
  df$voorkeur_t0_jaar <- ifelse(df$periode == "1959-1983", 1959L, 1984L)
  df$basis_waarde <- df[[value_col]]
  df$t0_jaar <- NA_integer_
  df$lambda <- NA_real_
  df$log_lambda <- NA_real_
  df$t0_index <- NA_real_

  split_key <- interaction(df[[id_cols[[1]]]], df$periode, drop = TRUE, lex.order = TRUE)
  parts <- split(df, split_key)
  out <- vector("list", length(parts))

  for (i in seq_along(parts)) {
    part <- parts[[i]]
    part <- part[order(part$jaar), , drop = FALSE]

    prev_year <- c(NA_integer_, head(part$jaar, -1L))
    prev_value <- c(NA_real_, head(part$basis_waarde, -1L))
    consecutive <- !is.na(prev_year) & (part$jaar - prev_year == 1L)
    positive_pair <- consecutive & is.finite(prev_value) & prev_value > 0 & is.finite(part$basis_waarde) & part$basis_waarde > 0

    part$lambda[positive_pair] <- part$basis_waarde[positive_pair] / prev_value[positive_pair]
    part$log_lambda[positive_pair] <- log(part$lambda[positive_pair])

    voorkeur_t0_jaar <- part$voorkeur_t0_jaar[1]
    t0_row <- which(part$jaar == voorkeur_t0_jaar & is.finite(part$basis_waarde) & part$basis_waarde > 0)
    if (length(t0_row)) {
      t0_row <- t0_row[[1]]
    } else {
      t0_row <- which(is.finite(part$basis_waarde) & part$basis_waarde > 0)
      t0_row <- if (length(t0_row)) t0_row[[1]] else NA_integer_
    }

    t0_value <- if (is.na(t0_row)) NA_real_ else part$basis_waarde[t0_row]
    t0_jaar <- if (is.na(t0_row)) NA_integer_ else part$jaar[t0_row]
    if (is.finite(t0_value) && t0_value > 0) {
      part$t0_jaar <- t0_jaar
      part$t0_index <- 100 * part$basis_waarde / t0_value
    }

    out[[i]] <- part
  }

  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out$basis_waarde <- NULL
  out[order(out[[id_cols[[1]]]], out$jaar), , drop = FALSE]
}

analyse_lambda_species_subset <- function(species_matrix) {
  df <- species_matrix[species_matrix$jaar != 1958L & species_matrix$geteld & is.finite(species_matrix$count_adjusted), c(
    "soort_id", "euring_code", "soort_naam", "engelse_naam", "jaar", "count_adjusted"
  )]

  if (!nrow(df)) {
    empty_yearly <- data.frame(
      soort_id = integer(),
      euring_code = integer(),
      soort_naam = character(),
      engelse_naam = character(),
      jaar = integer(),
      count_adjusted = numeric(),
      periode = character(),
      t0_jaar = integer(),
      lambda = numeric(),
      log_lambda = numeric(),
      t0_index = numeric(),
      stringsAsFactors = FALSE
    )
    empty_summary <- data.frame(
      soort_id = integer(),
      euring_code = integer(),
      soort_naam = character(),
      engelse_naam = character(),
      eerste_jaar = integer(),
      laatste_jaar = integer(),
      geldige_jaren = integer(),
      positieve_jaren = integer(),
      geldige_jaarparen = integer(),
      nul_aandeel = numeric(),
      pre_1984_aanwezig = logical(),
      post_1984_aanwezig = logical(),
      gemiddeld_lambda = numeric(),
      gemiddelde_verandering_pct = numeric(),
      analyse_categorie = character(),
      stringsAsFactors = FALSE
    )
    return(list(yearly = empty_yearly, summary = empty_summary))
  }

  annual <- aggregate(
    count_adjusted ~ soort_id + euring_code + soort_naam + engelse_naam + jaar,
    data = df,
    FUN = function(x) sum(x, na.rm = TRUE)
  )

  annual <- bereken_lambda_jaarreeks(
    annual,
    id_cols = c("soort_id"),
    value_col = "count_adjusted"
  )

  summary_rows <- lapply(split(annual, annual$soort_id), function(part) {
    positive_years <- sum(is.finite(part$count_adjusted) & part$count_adjusted > 0, na.rm = TRUE)
    valid_years <- nrow(part)
    zero_share <- mean(part$count_adjusted <= 0, na.rm = TRUE)
    consecutive_pairs <- sum(is.finite(part$lambda), na.rm = TRUE)
    pre_present <- any(part$periode == "1959-1983" & part$count_adjusted > 0, na.rm = TRUE)
    post_present <- any(part$periode == "1984-heden" & part$count_adjusted > 0, na.rm = TRUE)
    mean_log_lambda <- safe_mean(part$log_lambda)
    mean_lambda <- if (is.finite(mean_log_lambda)) exp(mean_log_lambda) else NA_real_
    pct_change <- if (is.finite(mean_log_lambda)) (exp(mean_log_lambda) - 1) * 100 else NA_real_

    data.frame(
      soort_id = part$soort_id[[1]],
      euring_code = part$euring_code[[1]],
      soort_naam = part$soort_naam[[1]],
      engelse_naam = part$engelse_naam[[1]],
      eerste_jaar = min(part$jaar, na.rm = TRUE),
      laatste_jaar = max(part$jaar, na.rm = TRUE),
      geldige_jaren = valid_years,
      positieve_jaren = positive_years,
      geldige_jaarparen = consecutive_pairs,
      nul_aandeel = zero_share,
      pre_1984_aanwezig = pre_present,
      post_1984_aanwezig = post_present,
      gemiddeld_lambda = mean_lambda,
      gemiddelde_verandering_pct = pct_change,
      analyse_categorie = classificeer_lambda_status(
        valid_years = valid_years,
        consecutive_pairs = consecutive_pairs,
        zero_share = zero_share,
        positive_years = positive_years,
        pre_present = pre_present,
        post_present = post_present
      ),
      stringsAsFactors = FALSE
    )
  })

  list(
    yearly = annual,
    summary = do.call(rbind, summary_rows)
  )
}

analyse_lambda_groups_subset <- function(lambda_species, group_mapping, t0_msi_selection = NULL) {
  summary_df <- lambda_species$summary
  yearly_df <- lambda_species$yearly
  empty_index <- data.frame(
    groep_100 = integer(),
    groep_titel = character(),
    jaar = integer(),
    periode = character(),
    n_soorten = integer(),
    t0_index = numeric(),
    lambda = numeric(),
    log_lambda = numeric(),
    stringsAsFactors = FALSE
  )
  empty_summary <- data.frame(
    groep_100 = integer(),
    groep_titel = character(),
    eerste_jaar = integer(),
    laatste_jaar = integer(),
    n_indexjaren = integer(),
    geldige_jaarparen = integer(),
    gemiddeld_lambda = numeric(),
    gemiddelde_verandering_pct = numeric(),
    stringsAsFactors = FALSE
  )
  empty_comp <- data.frame(
    groep_100 = integer(),
    groep_titel = character(),
    soort_id = integer(),
    euring_code = integer(),
    soort_naam = character(),
    engelse_naam = character(),
    stringsAsFactors = FALSE
  )
  eligible_species <- summary_df$soort_id[summary_df$analyse_categorie == "geschikt_voor_T0_MSI"]

  if (!length(eligible_species)) {
    return(list(index = empty_index, summary = empty_summary, composition = empty_comp))
  }

  merged <- merge(
    yearly_df[yearly_df$soort_id %in% eligible_species & is.finite(yearly_df$t0_index) & yearly_df$t0_index > 0, c(
      "soort_id", "euring_code", "soort_naam", "engelse_naam", "jaar", "periode", "t0_index"
    )],
    group_mapping,
    by = "soort_id",
    all = FALSE
  )

  if (!is.null(t0_msi_selection) && nrow(t0_msi_selection) > 0) {
    merged <- merge(
      merged,
      t0_msi_selection,
      by = c("groep_100", "soort_id"),
      all = FALSE
    )
  }

  if (!nrow(merged)) {
    return(list(index = empty_index, summary = empty_summary, composition = empty_comp))
  }

  merged$log_t0_index <- log(merged$t0_index)
  group_index <- aggregate(
    log_t0_index ~ groep_100 + groep_titel + jaar + periode,
    data = merged,
    FUN = mean
  )
  n_species <- aggregate(soort_id ~ groep_100 + jaar + periode, data = merged, FUN = function(x) length(unique(x)))
  names(n_species)[4] <- "n_soorten"
  group_index <- merge(group_index, n_species, by = c("groep_100", "jaar", "periode"), all.x = TRUE)
  group_index$t0_index <- exp(group_index$log_t0_index)
  group_index <- bereken_lambda_jaarreeks(group_index, id_cols = c("groep_100"), value_col = "t0_index")

  summary_rows <- lapply(split(group_index, group_index$groep_100), function(part) {
    mean_log_lambda <- safe_mean(part$log_lambda)
    mean_lambda <- if (is.finite(mean_log_lambda)) exp(mean_log_lambda) else NA_real_
    pct_change <- if (is.finite(mean_log_lambda)) (exp(mean_log_lambda) - 1) * 100 else NA_real_

    data.frame(
      groep_100 = part$groep_100[[1]],
      groep_titel = part$groep_titel[[1]],
      eerste_jaar = min(part$jaar, na.rm = TRUE),
      laatste_jaar = max(part$jaar, na.rm = TRUE),
      n_indexjaren = sum(is.finite(part$t0_index), na.rm = TRUE),
      geldige_jaarparen = sum(is.finite(part$lambda), na.rm = TRUE),
      gemiddeld_lambda = mean_lambda,
      gemiddelde_verandering_pct = pct_change,
      stringsAsFactors = FALSE
    )
  })

  composition <- unique(merged[, c("groep_100", "groep_titel", "soort_id", "euring_code", "soort_naam", "engelse_naam")])
  composition <- composition[order(composition$groep_100, composition$soort_naam), , drop = FALSE]

  list(
    index = group_index[order(group_index$groep_100, group_index$jaar), , drop = FALSE],
    summary = do.call(rbind, summary_rows),
    composition = composition
  )
}

analyse_lambda_subset <- function(tbls, selected_kavels, year_from, year_to) {
  basis <- prepare_analysis_basis_subset(tbls, selected_kavels, year_from, year_to)
  selection_df <- build_species_selection_subset(tbls, selected_kavels, year_from, year_to)
  species_matrix <- build_species_matrix_subset(tbls, basis, selection_df, year_from, year_to)
  lambda_species <- analyse_lambda_species_subset(species_matrix)
  group_mapping <- build_group_mapping(tbls)
  t0_msi_selection <- load_t0_msi_selection()
  lambda_groups <- analyse_lambda_groups_subset(lambda_species, group_mapping, t0_msi_selection = t0_msi_selection)

  list(
    basis = basis,
    selection = selection_df,
    species_matrix = species_matrix,
    species_results = lambda_species,
    group_results = lambda_groups
  )
}
MEIJENDEL_PARSER_CACHE_VERSION <- 2L
