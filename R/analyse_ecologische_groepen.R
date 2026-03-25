args <- commandArgs(trailingOnly = TRUE)
suppressPackageStartupMessages(library(mgcv))

sql_path <- if (length(args) >= 1) {
  args[[1]]
} else {
  "/Users/ton/Documents/GitHub/Meijendel/20260324.sql"
}

output_dir <- if (length(args) >= 2) {
  args[[2]]
} else {
  "/Users/ton/Documents/GitHub/Meijendel/output_ecologische_groepen"
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

selected_kavels <- c(
  "1a", "1b", "2", "3", "4-5", "6", "7", "8", "9",
  "10-12-76", "12", "12a", "13", "13s", "14", "15", "16", "16s", "17a"
)

extract_columns <- function(header) {
  start <- regexpr("\\(", header)[1]
  end <- regexpr("\\) VALUES", header)[1]
  cols <- substring(header, start + 1, end - 1)
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
        if (depth == 0L) {
          start <- i + 1L
        }
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

    if (!length(tuples)) {
      next
    }

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

safe_ratio <- function(num, den) {
  ifelse(is.na(num) | is.na(den) | den == 0, NA_real_, num / den)
}

safe_log_ratio <- function(num, den) {
  ifelse(is.na(num) | is.na(den) | num <= 0 | den <= 0, NA_real_, log(num / den))
}

calc_pct_trend <- function(slope) {
  (exp(slope) - 1) * 100
}

parse_needed_tables <- function(path) {
  plots <- read_insert_table(path, "plots", c("plot_id", "kavel_nummer"))
  soorten <- read_insert_table(path, "soorten", c("id", "soort_naam"))
  evg_vogelgroepen <- read_insert_table(path, "evg_vogelgroepen", c("groepsnummer", "landschap_groep"))
  evg_vogel_landschapgroep <- read_insert_table(
    path,
    "evg_vogel_landschapgroep",
    c("groepsnummer", "vogel_id", "veeleisendheid_score")
  )
  plot_jaar_oppervlak <- read_insert_table(
    path,
    "plot_jaar_oppervlak",
    c("plot_id", "jaar", "oppervlakte_km2")
  )
  territoria <- read_insert_table(
    path,
    "territoria",
    c("plot_id", "soort_id", "jaar", "territoria")
  )

  plots$plot_id <- to_integer(plots$plot_id)
  soorten$id <- to_integer(soorten$id)
  evg_vogelgroepen$groepsnummer <- to_integer(evg_vogelgroepen$groepsnummer)
  evg_vogel_landschapgroep$groepsnummer <- to_integer(evg_vogel_landschapgroep$groepsnummer)
  evg_vogel_landschapgroep$vogel_id <- to_integer(evg_vogel_landschapgroep$vogel_id)
  evg_vogel_landschapgroep$veeleisendheid_score <- to_integer(evg_vogel_landschapgroep$veeleisendheid_score)
  plot_jaar_oppervlak$plot_id <- to_integer(plot_jaar_oppervlak$plot_id)
  plot_jaar_oppervlak$jaar <- to_integer(plot_jaar_oppervlak$jaar)
  plot_jaar_oppervlak$oppervlakte_km2 <- to_numeric(plot_jaar_oppervlak$oppervlakte_km2)
  territoria$plot_id <- to_integer(territoria$plot_id)
  territoria$soort_id <- to_integer(territoria$soort_id)
  territoria$jaar <- to_integer(territoria$jaar)
  territoria$territoria <- to_numeric(territoria$territoria)

  list(
    plots = plots,
    soorten = soorten,
    evg_vogelgroepen = evg_vogelgroepen,
    evg_vogel_landschapgroep = evg_vogel_landschapgroep,
    plot_jaar_oppervlak = plot_jaar_oppervlak,
    territoria = territoria
  )
}

make_group_descriptions <- function(evg_vogelgroepen) {
  groep_100 <- unique((evg_vogelgroepen$groepsnummer %/% 100L) * 100L)
  groep_100 <- groep_100[order(groep_100)]
  desc <- character(length(groep_100))

  for (i in seq_along(groep_100)) {
    g <- groep_100[[i]]
    rows <- evg_vogelgroepen[(evg_vogelgroepen$groepsnummer %/% 100L) * 100L == g, ]
    exact <- rows$landschap_groep[rows$groepsnummer == g]
    desc[[i]] <- if (length(exact) > 0L && !is.na(exact[[1]]) && nzchar(exact[[1]])) exact[[1]] else rows$landschap_groep[[1]]
  }

  data.frame(groep_100 = groep_100, korte_beschrijving = desc, stringsAsFactors = FALSE)
}

read_previous_outputs <- function(out_dir) {
  trend_path <- file.path(out_dir, "trendanalyse_per_groep.csv")
  period_path <- file.path(out_dir, "vergelijking_trends_tussen_periodes.csv")

  if (!file.exists(trend_path) || !file.exists(period_path)) {
    return(NULL)
  }

  old_trend <- tryCatch(read.csv(trend_path, stringsAsFactors = FALSE), error = function(e) NULL)
  old_period <- tryCatch(read.csv(period_path, stringsAsFactors = FALSE), error = function(e) NULL)

  if (is.null(old_trend) || is.null(old_period)) {
    return(NULL)
  }

  list(trend = old_trend, period = old_period)
}

prepare_base_data <- function(tbls) {
  selected_plots <- tbls$plots[tbls$plots$kavel_nummer %in% selected_kavels, c("plot_id", "kavel_nummer")]
  selected_species <- tbls$soorten[!grepl("meeuw", tbls$soorten$soort_naam, ignore.case = TRUE), c("id", "soort_naam")]
  names(selected_species)[1] <- "soort_id"

  bird_groups <- unique(data.frame(
    soort_id = tbls$evg_vogel_landschapgroep$vogel_id,
    groep_100 = (tbls$evg_vogel_landschapgroep$groepsnummer %/% 100L) * 100L,
    stringsAsFactors = FALSE
  ))

  filtered <- merge(tbls$territoria[tbls$territoria$jaar >= 1958 & tbls$territoria$jaar <= 2025, ], selected_plots, by = "plot_id")
  filtered <- merge(filtered, selected_species, by = "soort_id")
  filtered <- merge(filtered, bird_groups, by = "soort_id")

  surveyed_keys <- unique(filtered[c("plot_id", "jaar")])
  surveyed <- merge(surveyed_keys, tbls$plot_jaar_oppervlak, by = c("plot_id", "jaar"))
  surveyed_km2 <- aggregate(oppervlakte_km2 ~ jaar, data = surveyed, FUN = sum, na.rm = TRUE)
  names(surveyed_km2)[2] <- "surveyed_km2"

  annual_species <- aggregate(territoria ~ groep_100 + soort_id + soort_naam + jaar, data = filtered, FUN = sum, na.rm = TRUE)
  annual_species <- merge(annual_species, surveyed_km2, by = "jaar")
  annual_species$density_per_km2 <- annual_species$territoria / annual_species$surveyed_km2
  annual_species$periode <- ifelse(annual_species$jaar <= 1983, "1958-1983", "1984-2025")
  annual_species <- annual_species[order(annual_species$groep_100, annual_species$soort_id, annual_species$jaar), ]

  annual_group_density <- aggregate(territoria ~ groep_100 + jaar, data = filtered, FUN = sum, na.rm = TRUE)
  annual_group_density <- merge(annual_group_density, surveyed_km2, by = "jaar")
  annual_group_density$density_per_km2 <- annual_group_density$territoria / annual_group_density$surveyed_km2

  list(
    annual_species = annual_species,
    annual_group_density = annual_group_density,
    surveyed_km2 = surveyed_km2,
    group_desc = make_group_descriptions(tbls$evg_vogelgroepen)
  )
}

build_species_indices <- function(annual_species) {
  species_indices <- lapply(split(annual_species, annual_species$soort_id), function(df) {
    df <- df[order(df$jaar), ]
    mean_pre <- mean(df$density_per_km2[df$jaar <= 1983], na.rm = TRUE)
    mean_post <- mean(df$density_per_km2[df$jaar >= 1984], na.rm = TRUE)

    if (!is.finite(mean_pre) || !is.finite(mean_post) || mean_pre <= 0 || mean_post <= 0) {
      return(NULL)
    }

    df$index_raw <- ifelse(
      df$jaar <= 1983,
      100 * df$density_per_km2 / mean_pre,
      100 * df$density_per_km2 / mean_post
    )

    pre_ref <- mean(df$index_raw[df$jaar >= 1981 & df$jaar <= 1983], na.rm = TRUE)
    post_ref <- mean(df$index_raw[df$jaar >= 1984 & df$jaar <= 1986], na.rm = TRUE)

    if (!is.finite(pre_ref) || !is.finite(post_ref) || pre_ref <= 0 || post_ref <= 0) {
      return(NULL)
    }

    df$bridge_factor <- pre_ref / post_ref
    df$index_spliced <- ifelse(df$jaar <= 1983, df$index_raw, df$index_raw * df$bridge_factor)
    df$log_index_spliced <- log(df$index_spliced)
    df
  })

  species_indices <- Filter(Negate(is.null), species_indices)
  out <- do.call(rbind, species_indices)
  rownames(out) <- NULL
  out
}

build_group_msi <- function(species_indices, group_desc, annual_group_density) {
  msi <- aggregate(log_index_spliced ~ groep_100 + jaar, data = species_indices, FUN = mean, na.rm = TRUE)
  species_n <- aggregate(soort_id ~ groep_100 + jaar, data = species_indices, FUN = function(x) length(unique(x)))
  names(species_n)[3] <- "n_soorten"
  msi$msi <- exp(msi$log_index_spliced)
  msi$periode <- ifelse(msi$jaar <= 1983, "1958-1983", "1984-2025")
  msi <- merge(msi, species_n, by = c("groep_100", "jaar"), all.x = TRUE)
  msi <- merge(msi, annual_group_density[c("groep_100", "jaar", "density_per_km2")], by = c("groep_100", "jaar"), all.x = TRUE)
  msi <- merge(msi, group_desc, by = "groep_100", all.x = TRUE)
  msi <- msi[order(msi$groep_100, msi$jaar), ]
  msi
}

summarise_periods <- function(msi) {
  out <- do.call(
    rbind,
    lapply(split(msi, msi$groep_100), function(df) {
      pre <- df[df$periode == "1958-1983", ]
      post <- df[df$periode == "1984-2025", ]
      data.frame(
        groep_100 = df$groep_100[[1]],
        korte_beschrijving = df$korte_beschrijving[[1]],
        n_pre = nrow(pre),
        n_post = nrow(post),
        mean_pre = mean(pre$msi, na.rm = TRUE),
        mean_post = mean(post$msi, na.rm = TRUE),
        median_pre = median(pre$msi, na.rm = TRUE),
        median_post = median(post$msi, na.rm = TRUE),
        sd_pre = sd(pre$msi, na.rm = TRUE),
        sd_post = sd(post$msi, na.rm = TRUE),
        species_mean_pre = mean(pre$n_soorten, na.rm = TRUE),
        species_mean_post = mean(post$n_soorten, na.rm = TRUE),
        bridge_pre_8183 = mean(df$msi[df$jaar >= 1981 & df$jaar <= 1983], na.rm = TRUE),
        bridge_post_8486 = mean(df$msi[df$jaar >= 1984 & df$jaar <= 1986], na.rm = TRUE),
        stringsAsFactors = FALSE
      )
    })
  )

  out$ratio_post_pre <- safe_ratio(out$mean_post, out$mean_pre)
  out$pct_change_post_pre <- (out$ratio_post_pre - 1) * 100
  out$bridge_factor <- safe_ratio(out$bridge_pre_8183, out$bridge_post_8486)
  out$bridge_log_ratio <- safe_log_ratio(out$bridge_pre_8183, out$bridge_post_8486)
  out[order(out$groep_100), ]
}

summarise_trends <- function(msi) {
  trend_summary <- do.call(
    rbind,
    lapply(split(msi, msi$groep_100), function(df) {
      df <- df[order(df$jaar), ]
      df$jaar_c <- df$jaar - 1958
      df$post_break <- ifelse(df$jaar >= 1984, 1, 0)
      df$jaar_na_break <- pmax(df$jaar - 1983, 0)

      fit_break <- lm(log(msi) ~ jaar_c + post_break + jaar_na_break, data = df)
      fit_spliced <- lm(log(msi) ~ jaar, data = df)
      coef_break <- summary(fit_break)$coefficients
      coef_spliced <- summary(fit_spliced)$coefficients

      pre_slope <- unname(coef(fit_break)[["jaar_c"]])
      slope_change <- unname(coef(fit_break)[["jaar_na_break"]])
      post_slope <- pre_slope + slope_change
      level_shift <- unname(coef(fit_break)[["post_break"]])
      overall_slope <- unname(coef(fit_spliced)[["jaar"]])

      data.frame(
        groep_100 = df$groep_100[[1]],
        korte_beschrijving = df$korte_beschrijving[[1]],
        n_jaren = nrow(df),
        mean_species_contributing = mean(df$n_soorten, na.rm = TRUE),
        pre_trend_pct_per_jaar = calc_pct_trend(pre_slope),
        post_trend_pct_per_jaar = calc_pct_trend(post_slope),
        overall_trend_pct_per_jaar = calc_pct_trend(overall_slope),
        break_level_shift_pct = calc_pct_trend(level_shift),
        p_pre_slope = coef_break["jaar_c", "Pr(>|t|)"],
        p_break_shift = coef_break["post_break", "Pr(>|t|)"],
        p_slope_change = coef_break["jaar_na_break", "Pr(>|t|)"],
        p_overall_trend = coef_spliced["jaar", "Pr(>|t|)"],
        r2_break_model = summary(fit_break)$r.squared,
        r2_spliced_model = summary(fit_spliced)$r.squared,
        stringsAsFactors = FALSE
      )
    })
  )

  trend_summary[order(trend_summary$groep_100), ]
}

summarise_period_trends <- function(msi) {
  period_trends <- do.call(
    rbind,
    lapply(split(msi, msi$groep_100), function(df_group) {
      do.call(
        rbind,
        lapply(split(df_group, df_group$periode), function(df_period) {
          df_period <- df_period[order(df_period$jaar), ]
          fit <- lm(log(msi) ~ jaar, data = df_period)
          cf <- summary(fit)$coefficients
          slope <- unname(coef(fit)[["jaar"]])

          data.frame(
            groep_100 = df_period$groep_100[[1]],
            korte_beschrijving = df_period$korte_beschrijving[[1]],
            periode = df_period$periode[[1]],
            eerste_jaar = min(df_period$jaar, na.rm = TRUE),
            laatste_jaar = max(df_period$jaar, na.rm = TRUE),
            n_jaren = nrow(df_period),
            mean_msi = mean(df_period$msi, na.rm = TRUE),
            median_msi = median(df_period$msi, na.rm = TRUE),
            mean_species_contributing = mean(df_period$n_soorten, na.rm = TRUE),
            trend_pct_per_jaar = calc_pct_trend(slope),
            p_trend = cf["jaar", "Pr(>|t|)"],
            r2 = summary(fit)$r.squared,
            stringsAsFactors = FALSE
          )
        })
      )
    })
  )

  period_trends <- period_trends[order(period_trends$groep_100, period_trends$periode), ]

  period_trend_wide <- do.call(
    rbind,
    lapply(split(period_trends, period_trends$groep_100), function(df) {
      pre <- df[df$periode == "1958-1983", ]
      post <- df[df$periode == "1984-2025", ]

      data.frame(
        groep_100 = df$groep_100[[1]],
        korte_beschrijving = df$korte_beschrijving[[1]],
        trend_pre_pct_per_jaar = pre$trend_pct_per_jaar[[1]],
        trend_post_pct_per_jaar = post$trend_pct_per_jaar[[1]],
        verschil_trendpunten = post$trend_pct_per_jaar[[1]] - pre$trend_pct_per_jaar[[1]],
        mean_pre = pre$mean_msi[[1]],
        mean_post = post$mean_msi[[1]],
        verhouding_post_pre = safe_ratio(post$mean_msi[[1]], pre$mean_msi[[1]]),
        stringsAsFactors = FALSE
      )
    })
  )

  list(
    period_trends = period_trends,
    period_trend_wide = period_trend_wide[order(period_trend_wide$groep_100), ]
  )
}

fit_gam_msi <- function(msi) {
  gam_models <- list()
  gam_predictions <- list()
  gam_summary <- list()

  for (g in sort(unique(msi$groep_100))) {
    df <- msi[msi$groep_100 == g, ]
    df <- df[order(df$jaar), ]
    df$post_break <- factor(ifelse(df$jaar >= 1984, "post", "pre"), levels = c("pre", "post"))
    df$log_msi <- log(df$msi)

    fit <- mgcv::gam(
      log_msi ~ post_break + s(jaar, by = post_break, k = 8),
      data = df,
      method = "REML"
    )

    pred <- predict(fit, newdata = df, se.fit = TRUE, type = "link")
    df$gam_fit_log <- as.numeric(pred$fit)
    df$gam_fit_se <- as.numeric(pred$se.fit)
    df$gam_fit_msi <- exp(df$gam_fit_log)
    df$gam_fit_lower <- exp(df$gam_fit_log - 1.96 * df$gam_fit_se)
    df$gam_fit_upper <- exp(df$gam_fit_log + 1.96 * df$gam_fit_se)

    s_table <- summary(fit)$s.table
    row_pre <- grep("pre", rownames(s_table), fixed = TRUE)
    row_post <- grep("post", rownames(s_table), fixed = TRUE)

    gam_models[[as.character(g)]] <- fit
    gam_predictions[[as.character(g)]] <- df
    gam_summary[[as.character(g)]] <- data.frame(
      groep_100 = g,
      korte_beschrijving = df$korte_beschrijving[[1]],
      n_jaren = nrow(df),
      deviance_explained = summary(fit)$dev.expl,
      r_sq_adj = summary(fit)$r.sq,
      aic = AIC(fit),
      edf_pre = if (length(row_pre)) s_table[row_pre[1], "edf"] else NA_real_,
      p_pre = if (length(row_pre)) s_table[row_pre[1], "p-value"] else NA_real_,
      edf_post = if (length(row_post)) s_table[row_post[1], "edf"] else NA_real_,
      p_post = if (length(row_post)) s_table[row_post[1], "p-value"] else NA_real_,
      stringsAsFactors = FALSE
    )
  }

  list(
    models = gam_models,
    predictions = do.call(rbind, gam_predictions),
    summary = do.call(rbind, gam_summary)
  )
}

classify_gam_need <- function(gam_summary) {
  out <- gam_summary
  out$max_edf <- pmax(out$edf_pre, out$edf_post, na.rm = TRUE)
  out$min_p_smooth <- pmin(out$p_pre, out$p_post, na.rm = TRUE)

  out$advies <- ifelse(
    out$max_edf >= 2 & out$deviance_explained >= 0.7,
    "GAM aanbevolen",
    ifelse(
      out$max_edf > 1.2 & out$deviance_explained >= 0.5,
      "GAM nuttig",
      "Lineair meestal voldoende"
    )
  )

  out$toelichting <- ifelse(
    out$advies == "GAM aanbevolen",
    "Duidelijke niet-lineariteit; een rechte lijn verliest belangrijke trendvorm.",
    ifelse(
      out$advies == "GAM nuttig",
      "Enige kromming aanwezig; GAM helpt vooral voor visualisatie en timing van omslagen.",
      "Trend is grotendeels lineair; lineaire samenvatting is meestal toereikend."
    )
  )

  out[order(out$groep_100), c(
    "groep_100", "korte_beschrijving", "deviance_explained",
    "edf_pre", "edf_post", "min_p_smooth", "advies", "toelichting"
  )]
}

compare_old_new <- function(old_outputs, new_trend_summary, new_period_trend_wide) {
  if (is.null(old_outputs)) {
    return(NULL)
  }

  old_trend <- old_outputs$trend
  old_period <- old_outputs$period

  need_trend <- c("groep_100", "overall_trend_pct_per_jaar", "pre_trend_pct_per_jaar", "post_trend_pct_per_jaar")
  need_period <- c("groep_100", "trend_pre_pct_per_jaar", "trend_post_pct_per_jaar")
  if (!all(need_trend %in% names(old_trend)) || !all(need_period %in% names(old_period))) {
    return(NULL)
  }

  comp <- merge(
    old_trend[need_trend],
    new_trend_summary[c("groep_100", "korte_beschrijving", "overall_trend_pct_per_jaar", "pre_trend_pct_per_jaar", "post_trend_pct_per_jaar")],
    by = "groep_100",
    suffixes = c("_oud", "_msi")
  )
  comp <- merge(
    comp,
    old_period[need_period],
    by = "groep_100",
    suffixes = c("", "_oldperiod")
  )
  comp <- merge(
    comp,
    new_period_trend_wide[c("groep_100", "trend_pre_pct_per_jaar", "trend_post_pct_per_jaar")],
    by = "groep_100",
    suffixes = c("_oud_periodetabel", "_msi_periodetabel")
  )

  comp$delta_overall_trend <- comp$overall_trend_pct_per_jaar_msi - comp$overall_trend_pct_per_jaar_oud
  comp$delta_pre_trend <- comp$pre_trend_pct_per_jaar_msi - comp$pre_trend_pct_per_jaar_oud
  comp$delta_post_trend <- comp$post_trend_pct_per_jaar_msi - comp$post_trend_pct_per_jaar_oud
  comp$richting_gewijzigd_overall <- sign(comp$overall_trend_pct_per_jaar_msi) != sign(comp$overall_trend_pct_per_jaar_oud)
  comp$richting_gewijzigd_pre <- sign(comp$pre_trend_pct_per_jaar_msi) != sign(comp$pre_trend_pct_per_jaar_oud)
  comp$richting_gewijzigd_post <- sign(comp$post_trend_pct_per_jaar_msi) != sign(comp$post_trend_pct_per_jaar_oud)

  comp[order(comp$groep_100), ]
}

analyse_groups <- function(tbls, old_outputs = NULL) {
  base <- prepare_base_data(tbls)
  species_indices <- build_species_indices(base$annual_species)
  msi <- build_group_msi(species_indices, base$group_desc, base$annual_group_density)
  period_summary <- summarise_periods(msi)
  trend_summary <- summarise_trends(msi)
  period_parts <- summarise_period_trends(msi)
  gam_parts <- fit_gam_msi(msi)
  gam_interpretation <- classify_gam_need(gam_parts$summary)
  comparison_old_new <- compare_old_new(old_outputs, trend_summary, period_parts$period_trend_wide)

  list(
    annual_density = msi,
    period_summary = period_summary,
    spliced_index = msi,
    trend_summary = trend_summary,
    period_trends = period_parts$period_trends,
    period_trend_wide = period_parts$period_trend_wide,
    gam_summary = gam_parts$summary,
    gam_interpretation = gam_interpretation,
    gam_predictions = gam_parts$predictions,
    species_indices = species_indices,
    comparison_old_new = comparison_old_new
  )
}

write_outputs <- function(results, out_dir) {
  write.csv(results$annual_density, file.path(out_dir, "jaarreeksen_dichtheid_per_groep.csv"), row.names = FALSE)
  write.csv(results$period_summary, file.path(out_dir, "vergelijking_periodes_1958_1983_vs_1984_2025.csv"), row.names = FALSE)
  write.csv(results$spliced_index, file.path(out_dir, "doorlopende_index_per_groep.csv"), row.names = FALSE)
  write.csv(results$trend_summary, file.path(out_dir, "trendanalyse_per_groep.csv"), row.names = FALSE)
  write.csv(results$period_trends, file.path(out_dir, "trendanalyse_los_per_periode.csv"), row.names = FALSE)
  write.csv(results$period_trend_wide, file.path(out_dir, "vergelijking_trends_tussen_periodes.csv"), row.names = FALSE)
  write.csv(results$gam_summary, file.path(out_dir, "gam_trendanalyse_per_groep.csv"), row.names = FALSE)
  write.csv(results$gam_interpretation, file.path(out_dir, "gam_interpretatie_per_groep.csv"), row.names = FALSE)
  write.csv(results$gam_predictions, file.path(out_dir, "gam_voorspellingen_per_groep.csv"), row.names = FALSE)
  write.csv(results$species_indices, file.path(out_dir, "soortindices_voor_msi.csv"), row.names = FALSE)

  if (!is.null(results$comparison_old_new)) {
    write.csv(results$comparison_old_new, file.path(out_dir, "vergelijking_oude_analyse_vs_msi.csv"), row.names = FALSE)
  }

  png(
    filename = file.path(out_dir, "doorlopende_index_per_groep.png"),
    width = 1600,
    height = 2200,
    res = 150
  )
  op <- par(no.readonly = TRUE)
  on.exit(par(op), add = TRUE)

  groups <- unique(results$spliced_index$groep_100)
  n_col <- 2
  n_row <- ceiling(length(groups) / n_col)
  par(mfrow = c(n_row, n_col), mar = c(3, 3, 3, 1), oma = c(2, 2, 2, 1))

  for (g in groups) {
    df <- results$spliced_index[results$spliced_index$groep_100 == g, ]
    plot(
      df$jaar,
      df$msi,
      type = "l",
      lwd = 2,
      col = "#1f4e79",
      main = sprintf("%s (%s)", g, df$korte_beschrijving[[1]]),
      xlab = "Jaar",
      ylab = "MSI"
    )
    abline(v = 1983.5, lty = 2, col = "firebrick")
  }

  mtext("Ecologische groepen Meijendel: MSI met breukcorrectie", outer = TRUE, cex = 1.1)
  dev.off()

  png(
    filename = file.path(out_dir, "gam_msi_per_groep.png"),
    width = 1600,
    height = 2200,
    res = 150
  )
  op <- par(no.readonly = TRUE)
  on.exit(par(op), add = TRUE)

  groups <- unique(results$gam_predictions$groep_100)
  n_col <- 2
  n_row <- ceiling(length(groups) / n_col)
  par(mfrow = c(n_row, n_col), mar = c(3, 3, 3, 1), oma = c(2, 2, 2, 1))

  for (g in groups) {
    df <- results$gam_predictions[results$gam_predictions$groep_100 == g, ]
    yr <- df$jaar
    ylim <- range(c(df$msi, df$gam_fit_lower, df$gam_fit_upper), na.rm = TRUE)
    plot(
      yr, df$msi,
      type = "p",
      pch = 16,
      cex = 0.6,
      col = "#9db7c8",
      main = sprintf("%s (%s)", g, df$korte_beschrijving[[1]]),
      xlab = "Jaar",
      ylab = "MSI",
      ylim = ylim
    )
    polygon(
      c(yr, rev(yr)),
      c(df$gam_fit_lower, rev(df$gam_fit_upper)),
      col = adjustcolor("#1f4e79", alpha.f = 0.18),
      border = NA
    )
    lines(yr, df$gam_fit_msi, lwd = 2, col = "#1f4e79")
    abline(v = 1983.5, lty = 2, col = "firebrick")
  }

  mtext("Ecologische groepen Meijendel: GAM-smooths voor MSI", outer = TRUE, cex = 1.1)
  dev.off()
}

if (sys.nframe() == 0) {
  cat(sprintf("Lees SQL-dump: %s\n", sql_path))
  old_outputs <- read_previous_outputs(output_dir)
  tables <- parse_needed_tables(sql_path)
  cat("Voer MSI-analyse uit...\n")
  results <- analyse_groups(tables, old_outputs = old_outputs)
  write_outputs(results, output_dir)

  cat("\nMSI-kernsamenvatting:\n")
  print(results$period_summary[, c(
    "groep_100", "korte_beschrijving", "mean_pre", "mean_post",
    "pct_change_post_pre", "bridge_factor", "species_mean_pre", "species_mean_post"
  )])

  cat("\nMSI-trendsamenvatting:\n")
  print(results$trend_summary[, c(
    "groep_100", "korte_beschrijving", "pre_trend_pct_per_jaar",
    "post_trend_pct_per_jaar", "overall_trend_pct_per_jaar",
    "break_level_shift_pct", "p_slope_change", "mean_species_contributing"
  )])

  cat("\nMSI losse trends per periode:\n")
  print(results$period_trend_wide[, c(
    "groep_100", "korte_beschrijving", "trend_pre_pct_per_jaar",
    "trend_post_pct_per_jaar", "verschil_trendpunten", "verhouding_post_pre"
  )])

  cat("\nGAM samenvatting:\n")
  print(results$gam_summary[, c(
    "groep_100", "korte_beschrijving", "deviance_explained",
    "edf_pre", "p_pre", "edf_post", "p_post"
  )])

  cat("\nGAM interpretatie per groep:\n")
  print(results$gam_interpretation[, c(
    "groep_100", "korte_beschrijving", "advies", "deviance_explained",
    "edf_pre", "edf_post"
  )])

  if (!is.null(results$comparison_old_new)) {
    cat("\nVergelijking oude analyse versus MSI:\n")
    print(results$comparison_old_new[, c(
      "groep_100", "korte_beschrijving", "overall_trend_pct_per_jaar_oud",
      "overall_trend_pct_per_jaar_msi", "delta_overall_trend",
      "richting_gewijzigd_overall"
    )])
  }

  cat(sprintf("\nBestanden geschreven naar: %s\n", output_dir))
}
