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

  list(
    plots = plots,
    soorten = soorten,
    plot_jaar_oppervlak = pjo,
    plot_jaar_teller = pjt,
    territoria = territoria,
    evg_vogelgroepen = evg_groepen,
    evg_vogel_landschapgroep = evg_koppeling
  )
}

make_cache_signature <- function(path) {
  info <- file.info(path)
  paste(
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
    if (!is.null(cache) && identical(cache$signature, signature) && !is.null(cache$data)) {
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
