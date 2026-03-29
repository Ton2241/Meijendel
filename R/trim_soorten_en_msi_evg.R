args <- commandArgs(trailingOnly = TRUE)

user_lib <- file.path(Sys.getenv("HOME"), "Library/R/arm64/4.5/library")
if (dir.exists(user_lib)) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages(library(rtrim))

sql_path <- if (length(args) >= 1L) args[[1]] else "/Users/ton/Documents/GitHub/Meijendel/Meijendel.sql"
species_dir <- if (length(args) >= 2L) args[[2]] else "/Users/ton/Documents/GitHub/Meijendel/trim/soorten"
group_dir <- if (length(args) >= 3L) args[[3]] else "/Users/ton/Documents/GitHub/Meijendel/trim_msi_evg"

dir.create(species_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(group_dir, recursive = TRUE, showWarnings = FALSE)

historische_kavels <- c(
  "1", "1a", "1b", "2", "3", "4", "4-5", "5", "6", "7", "8", "8/9", "8/11",
  "9", "10", "10-12-76", "11", "12", "12a", "13", "13s", "14", "15", "16",
  "16s", "17", "17a"
)

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

parse_tables <- function(path) {
  plots <- read_insert_table(path, "plots", c("plot_id", "plot_naam", "kavel_nummer"))
  soorten <- read_insert_table(path, "soorten", c("id", "euring_code", "soort_naam"))
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

run_lm_trend <- function(df, value_col, year_min = NULL, year_max = NULL) {
  if (!is.null(year_min)) df <- df[df$jaar >= year_min, , drop = FALSE]
  if (!is.null(year_max)) df <- df[df$jaar <= year_max, , drop = FALSE]
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

prepare_analysis_basis <- function(tbls) {
  pjo <- tbls$plot_jaar_oppervlak
  pjo <- merge(pjo, tbls$plots, by = "plot_id", all.x = TRUE)
  pjo <- pjo[pjo$jaar >= 1958 & pjo$jaar <= 2025, ]
  pjo$in_hist_kern <- pjo$kavel_nummer %in% historische_kavels
  pjo$in_analyse <- ifelse(pjo$jaar <= 1972, pjo$in_hist_kern, !is.na(pjo$kavel_nummer))

  surveyed <- unique(rbind(
    tbls$plot_jaar_teller[c("plot_id", "jaar")],
    tbls$territoria[c("plot_id", "jaar")]
  ))
  surveyed$geteld <- TRUE

  basis <- merge(pjo, surveyed, by = c("plot_id", "jaar"), all.x = TRUE)
  basis$geteld[is.na(basis$geteld)] <- FALSE
  basis <- basis[basis$in_analyse, ]

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
  basis$analyse_reeks <- ifelse(basis$jaar <= 1972, "historische_kern_1958_1972", "volledig_netwerk_1973_2025")
  basis[order(basis$jaar, basis$kavel_nummer, basis$plot_id), ]
}

build_species_matrix <- function(tbls, basis) {
  species <- unique(tbls$territoria$soort_id)
  grid <- expand.grid(
    soort_id = species,
    row_id = seq_len(nrow(basis)),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid <- merge(grid, data.frame(row_id = seq_len(nrow(basis)), basis, stringsAsFactors = FALSE), by = "row_id", all.x = TRUE)
  grid$row_id <- NULL

  counts <- tbls$territoria[tbls$territoria$jaar >= 1958 & tbls$territoria$jaar <= 2025, c("plot_id", "soort_id", "jaar", "territoria")]
  grid <- merge(grid, counts, by = c("plot_id", "soort_id", "jaar"), all.x = TRUE)
  grid <- merge(grid, tbls$soorten[, c("id", "euring_code", "soort_naam")], by.x = "soort_id", by.y = "id", all.x = TRUE)

  grid$count_raw <- ifelse(grid$geteld & is.na(grid$territoria), 0, grid$territoria)
  grid$count_adjusted <- ifelse(grid$geteld, grid$count_raw * grid$oppervlakte_factor, NA_real_)
  grid$post84 <- ifelse(grid$jaar >= 1984, "post1984", "pre1984")
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
        trim(
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

collect_period_index <- function(fit_obj, soort_id, soort_naam, euring_code, periode_label) {
  idx <- index(fit_obj$model)
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
  out$periode <- periode_label
  out$model_config <- fit_obj$config
  out$model_warnings <- fit_obj$warnings
  out$trim_year <- NULL
  out <- out[, c("soort_id", "euring_code", "soort_naam", "periode", "jaar", "trim_index", "trim_se", "model_config", "model_warnings")]
  base_value <- out$trim_index[match(min(out$jaar), out$jaar)]
  out$index_100 <- ifelse(is.finite(out$trim_index) & is.finite(base_value) & base_value > 0, 100 * out$trim_index / base_value, NA_real_)
  out
}

classificeer_soort_status <- function(pre_ok, post_ok, pre_years, post_years, observed_positive) {
  if (pre_ok && post_ok) {
    return("brugbare_tijdreeks")
  }
  if (pre_ok && !post_ok) {
    return("alleen_pre_bruikbaar")
  }
  if (!pre_ok && post_ok) {
    return("alleen_post_bruikbaar")
  }
  if (observed_positive <= 2 || max(pre_years, post_years) <= 2) {
    return("te_zeldzaam")
  }
  if (pre_years > 0 || post_years > 0) {
    return("te_weinig_data")
  }
  "geen_bruikbare_reeks"
}

maak_status_samenvatting <- function(status_df) {
  out <- aggregate(
    soort_id ~ analyse_categorie,
    data = status_df,
    FUN = length
  )
  names(out)[2] <- "aantal_soorten"
  out <- out[order(out$aantal_soorten, decreasing = TRUE), ]
  rownames(out) <- NULL
  out
}

bridge_species_indices <- function(pre_idx, post_idx) {
  if (is.null(pre_idx) && is.null(post_idx)) {
    return(list(series = NULL, bridge_factor = NA_real_, bridge_method = "geen_model"))
  }
  if (is.null(pre_idx)) {
    post_idx$index_gebrugged <- post_idx$index_100
    post_idx$brugfactor <- 1
    post_idx$brugmethode <- "alleen_post"
    return(list(series = post_idx, bridge_factor = 1, bridge_method = "alleen_post"))
  }
  if (is.null(post_idx)) {
    pre_idx$index_gebrugged <- pre_idx$index_100
    pre_idx$brugfactor <- 1
    pre_idx$brugmethode <- "alleen_pre"
    return(list(series = pre_idx, bridge_factor = 1, bridge_method = "alleen_pre"))
  }

  pre_anchor <- pre_idx$index_100[pre_idx$jaar %in% 1981:1983]
  post_anchor <- post_idx$index_100[post_idx$jaar %in% 1984:1986]

  if (!length(pre_anchor)) pre_anchor <- tail(pre_idx$index_100[is.finite(pre_idx$index_100)], 3L)
  if (!length(post_anchor)) post_anchor <- head(post_idx$index_100[is.finite(post_idx$index_100)], 3L)

  bridge_factor <- safe_mean(pre_anchor) / safe_mean(post_anchor)
  if (!is.finite(bridge_factor) || bridge_factor <= 0) {
    bridge_factor <- 1
    bridge_method <- "fallback_1"
  } else {
    bridge_method <- "1981_1983_naar_1984_1986"
  }

  pre_idx$index_gebrugged <- pre_idx$index_100
  post_idx$index_gebrugged <- post_idx$index_100 * bridge_factor
  pre_idx$brugfactor <- bridge_factor
  post_idx$brugfactor <- bridge_factor
  pre_idx$brugmethode <- bridge_method
  post_idx$brugmethode <- bridge_method

  combined <- rbind(pre_idx, post_idx)
  combined <- combined[order(combined$jaar, combined$periode), ]
  first_value <- combined$index_gebrugged[match(min(combined$jaar), combined$jaar)]
  combined$index_gebrugged <- ifelse(
    is.finite(combined$index_gebrugged) & is.finite(first_value) & first_value > 0,
    100 * combined$index_gebrugged / first_value,
    NA_real_
  )

  list(series = combined, bridge_factor = bridge_factor, bridge_method = bridge_method)
}

analyse_species <- function(species_matrix) {
  split_species <- split(species_matrix, species_matrix$soort_id)
  status_rows <- list()
  index_rows <- list()
  trend_rows <- list()
  bridge_rows <- list()

  counter <- 0L
  for (df in split_species) {
    counter <- counter + 1L
    soort_id <- unique(df$soort_id)[1]
    soort_naam <- unique(df$soort_naam)[1]
    euring_code <- unique(df$euring_code)[1]

    observed_positive <- sum(df$geteld & is.finite(df$count_adjusted) & df$count_adjusted > 0, na.rm = TRUE)
    observed_years <- length(unique(df$jaar[df$geteld & is.finite(df$count_adjusted)]))

    pre_df <- df[df$jaar <= 1983, ]
    post_df <- df[df$jaar >= 1984, ]

    pre_positive_years <- length(unique(pre_df$jaar[pre_df$geteld & is.finite(pre_df$count_adjusted) & pre_df$count_adjusted > 0]))
    post_positive_years <- length(unique(post_df$jaar[post_df$geteld & is.finite(post_df$count_adjusted) & post_df$count_adjusted > 0]))
    pre_counted_cells <- sum(pre_df$geteld & is.finite(pre_df$count_adjusted), na.rm = TRUE)
    post_counted_cells <- sum(post_df$geteld & is.finite(post_df$count_adjusted), na.rm = TRUE)

    pre_ok <- pre_positive_years >= 3 && pre_counted_cells >= 3
    post_ok <- post_positive_years >= 3 && post_counted_cells >= 3

    pre_fit <- if (pre_ok) fit_trim_model(pre_df) else list(model = NULL, config = NA_character_, error = "te_weinig_data_pre", warnings = NA_character_, year_map = NULL)
    post_fit <- if (post_ok) fit_trim_model(post_df) else list(model = NULL, config = NA_character_, error = "te_weinig_data_post", warnings = NA_character_, year_map = NULL)

    pre_idx <- if (!is.null(pre_fit$model)) collect_period_index(pre_fit, soort_id, soort_naam, euring_code, "1958-1983") else NULL
    post_idx <- if (!is.null(post_fit$model)) collect_period_index(post_fit, soort_id, soort_naam, euring_code, "1984-2025") else NULL

    bridged <- bridge_species_indices(pre_idx, post_idx)

    analyse_categorie <- classificeer_soort_status(
      pre_ok = !is.null(pre_fit$model),
      post_ok = !is.null(post_fit$model),
      pre_years = pre_positive_years,
      post_years = post_positive_years,
      observed_positive = observed_positive
    )

    status_rows[[counter]] <- data.frame(
      soort_id = soort_id,
      euring_code = euring_code,
      soort_naam = soort_naam,
      n_getelde_cellen = sum(df$geteld, na.rm = TRUE),
      n_positieve_cellen = observed_positive,
      n_jaren_geteld = observed_years,
      pre_model_gelukt = !is.null(pre_fit$model),
      post_model_gelukt = !is.null(post_fit$model),
      pre_model = pre_fit$config,
      post_model = post_fit$config,
      pre_fout = pre_fit$error,
      post_fout = post_fit$error,
      pre_waarschuwingen = pre_fit$warnings,
      post_waarschuwingen = post_fit$warnings,
      pre_positieve_jaren = pre_positive_years,
      post_positieve_jaren = post_positive_years,
      analyse_categorie = analyse_categorie,
      stringsAsFactors = FALSE
    )

    bridge_rows[[counter]] <- data.frame(
      soort_id = soort_id,
      euring_code = euring_code,
      soort_naam = soort_naam,
      brugfactor = bridged$bridge_factor,
      brugmethode = bridged$bridge_method,
      stringsAsFactors = FALSE
    )

    if (!is.null(bridged$series)) {
      series <- bridged$series
      series <- series[!duplicated(series[, c("soort_id", "jaar")]), ]
      index_rows[[counter]] <- series[order(series$jaar), ]

      tr_all <- run_lm_trend(series, "index_gebrugged")
      tr_pre <- run_lm_trend(series, "index_gebrugged", year_max = 1983)
      tr_post <- run_lm_trend(series, "index_gebrugged", year_min = 1984)

      overall_pct <- calc_pct_trend(tr_all$slope)
      pre_pct <- calc_pct_trend(tr_pre$slope)
      post_pct <- calc_pct_trend(tr_post$slope)

      trend_rows[[counter]] <- data.frame(
        soort_id = soort_id,
        euring_code = euring_code,
        soort_naam = soort_naam,
        analyse_categorie = analyse_categorie,
        eerste_jaar = min(series$jaar, na.rm = TRUE),
        laatste_jaar = max(series$jaar, na.rm = TRUE),
        n_jaren_index = nrow(series),
        overall_trend_pct_per_jaar = overall_pct,
        overall_p = tr_all$p,
        overall_r2 = tr_all$r2,
        overall_uitleg = duid_trend(overall_pct, tr_all$p),
        trend_pre_pct_per_jaar = pre_pct,
        trend_pre_p = tr_pre$p,
        trend_pre_r2 = tr_pre$r2,
        trend_pre_uitleg = duid_trend(pre_pct, tr_pre$p),
        trend_post_pct_per_jaar = post_pct,
        trend_post_p = tr_post$p,
        trend_post_r2 = tr_post$r2,
        trend_post_uitleg = duid_trend(post_pct, tr_post$p),
        brugfactor = bridged$bridge_factor,
        brugmethode = bridged$bridge_method,
        stringsAsFactors = FALSE
      )
    }
  }

  list(
    status = do.call(rbind, status_rows),
    indices = do.call(rbind, Filter(Negate(is.null), index_rows)),
    trends = do.call(rbind, Filter(Negate(is.null), trend_rows)),
    bridges = do.call(rbind, bridge_rows)
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

analyse_groups <- function(species_indices, group_mapping) {
  merged <- merge(
    species_indices[!duplicated(species_indices[, c("soort_id", "jaar")]), c("soort_id", "euring_code", "soort_naam", "jaar", "index_gebrugged")],
    group_mapping,
    by = "soort_id",
    all = FALSE
  )

  merged <- merged[is.finite(merged$index_gebrugged) & merged$index_gebrugged > 0, ]
  merged$log_index <- log(merged$index_gebrugged)

  msi <- aggregate(log_index ~ groep_100 + groep_titel + jaar, data = merged, FUN = mean)
  n_species <- aggregate(soort_id ~ groep_100 + jaar, data = merged, FUN = function(x) length(unique(x)))
  names(n_species)[3] <- "n_soorten"
  msi <- merge(msi, n_species, by = c("groep_100", "jaar"), all.x = TRUE)
  msi$msi <- exp(msi$log_index)
  msi$periode <- ifelse(msi$jaar <= 1983, "1958-1983", "1984-2025")
  msi <- msi[order(msi$groep_100, msi$jaar), ]

  trend_rows <- lapply(split(msi, msi$groep_100), function(df) {
    tr_all <- run_lm_trend(df, "msi")
    tr_pre <- run_lm_trend(df, "msi", year_max = 1983)
    tr_post <- run_lm_trend(df, "msi", year_min = 1984)
    overall_pct <- calc_pct_trend(tr_all$slope)
    pre_pct <- calc_pct_trend(tr_pre$slope)
    post_pct <- calc_pct_trend(tr_post$slope)

    data.frame(
      groep_100 = df$groep_100[[1]],
      groep_titel = df$groep_titel[[1]],
      eerste_jaar = min(df$jaar, na.rm = TRUE),
      laatste_jaar = max(df$jaar, na.rm = TRUE),
      gemiddeld_n_soorten = mean(df$n_soorten, na.rm = TRUE),
      overall_trend_pct_per_jaar = overall_pct,
      overall_p = tr_all$p,
      overall_r2 = tr_all$r2,
      overall_uitleg = duid_trend(overall_pct, tr_all$p),
      trend_pre_pct_per_jaar = pre_pct,
      trend_pre_p = tr_pre$p,
      trend_pre_r2 = tr_pre$r2,
      trend_pre_uitleg = duid_trend(pre_pct, tr_pre$p),
      trend_post_pct_per_jaar = post_pct,
      trend_post_p = tr_post$p,
      trend_post_r2 = tr_post$r2,
      trend_post_uitleg = duid_trend(post_pct, tr_post$p),
      stringsAsFactors = FALSE
    )
  })

  composition <- unique(merged[, c("groep_100", "groep_titel", "soort_id", "euring_code", "soort_naam")])
  composition <- composition[order(composition$groep_100, composition$soort_naam), ]

  list(
    msi = msi,
    trends = do.call(rbind, trend_rows),
    composition = composition
  )
}

write_outputs <- function(basis, species_results, group_results) {
  status_samenvatting <- maak_status_samenvatting(species_results$status)
  bruikbaar_status <- species_results$status[species_results$status$analyse_categorie == "brugbare_tijdreeks", ]
  bruikbaar_trends <- species_results$trends[species_results$trends$analyse_categorie == "brugbare_tijdreeks", ]
  bruikbaar_ids <- unique(bruikbaar_status$soort_id)
  bruikbaar_indices <- species_results$indices[species_results$indices$soort_id %in% bruikbaar_ids, ]

  write.csv(basis, file.path(species_dir, "analysebasis_plot_jaar.csv"), row.names = FALSE)
  write.csv(species_results$status, file.path(species_dir, "soorten_modelstatus.csv"), row.names = FALSE)
  write.csv(status_samenvatting, file.path(species_dir, "soorten_status_samenvatting.csv"), row.names = FALSE)
  write.csv(bruikbaar_status, file.path(species_dir, "soorten_bruikbare_tijdreeks_selectie.csv"), row.names = FALSE)
  write.csv(species_results$indices, file.path(species_dir, "soortindices_per_jaar.csv"), row.names = FALSE)
  write.csv(bruikbaar_indices, file.path(species_dir, "soortindices_bruikbare_tijdreeks.csv"), row.names = FALSE)
  write.csv(species_results$trends, file.path(species_dir, "soorten_trendoverzicht.csv"), row.names = FALSE)
  write.csv(bruikbaar_trends, file.path(species_dir, "soorten_trendoverzicht_bruikbare_tijdreeks.csv"), row.names = FALSE)
  write.csv(species_results$bridges, file.path(species_dir, "soorten_brugfactoren.csv"), row.names = FALSE)

  write.csv(group_results$composition, file.path(group_dir, "groepssamenstelling_100tal.csv"), row.names = FALSE)
  write.csv(group_results$msi, file.path(group_dir, "msi_per_groep_per_jaar.csv"), row.names = FALSE)
  write.csv(group_results$trends, file.path(group_dir, "trendoverzicht_msi_groepen.csv"), row.names = FALSE)
}

tbls <- parse_tables(sql_path)
basis <- prepare_analysis_basis(tbls)
species_matrix <- build_species_matrix(tbls, basis)
species_results <- analyse_species(species_matrix)
group_mapping <- build_group_mapping(tbls)
group_results <- analyse_groups(species_results$indices, group_mapping)
write_outputs(basis, species_results, group_results)

cat("Klaar.\n")
cat("Soorten-output:", species_dir, "\n")
cat("Groeps-output:", group_dir, "\n")
