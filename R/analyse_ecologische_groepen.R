args <- commandArgs(trailingOnly = TRUE)

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
  end <- regexpr("\\) VALUES", header, fixed = FALSE)[1]
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

to_integer <- function(x) {
  as.integer(x)
}

to_numeric <- function(x) {
  as.numeric(x)
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
    if (length(exact) > 0L && !is.na(exact[[1]]) && nzchar(exact[[1]])) {
      desc[[i]] <- exact[[1]]
    } else {
      desc[[i]] <- rows$landschap_groep[[1]]
    }
  }

  data.frame(
    groep_100 = groep_100,
    korte_beschrijving = desc,
    stringsAsFactors = FALSE
  )
}

safe_ratio <- function(num, den) {
  ifelse(is.na(num) | is.na(den) | den == 0, NA_real_, num / den)
}

safe_log_ratio <- function(num, den) {
  ifelse(is.na(num) | is.na(den) | num <= 0 | den <= 0, NA_real_, log(num / den))
}

analyse_groups <- function(tbls) {
  plots <- tbls$plots
  soorten <- tbls$soorten
  evg_vogelgroepen <- tbls$evg_vogelgroepen
  evg_vogel_landschapgroep <- tbls$evg_vogel_landschapgroep
  plot_jaar_oppervlak <- tbls$plot_jaar_oppervlak
  territoria <- tbls$territoria

  selected_plots <- plots[plots$kavel_nummer %in% selected_kavels, c("plot_id", "kavel_nummer")]
  selected_species <- soorten[!grepl("meeuw", soorten$soort_naam, ignore.case = TRUE), c("id", "soort_naam")]

  bird_groups <- unique(data.frame(
    soort_id = evg_vogel_landschapgroep$vogel_id,
    groep_100 = (evg_vogel_landschapgroep$groepsnummer %/% 100L) * 100L,
    stringsAsFactors = FALSE
  ))

  filtered <- merge(
    territoria[territoria$jaar >= 1958 & territoria$jaar <= 2025, ],
    selected_plots,
    by = "plot_id"
  )
  filtered <- merge(
    filtered,
    data.frame(soort_id = selected_species$id, soort_naam = selected_species$soort_naam, stringsAsFactors = FALSE),
    by = "soort_id"
  )
  filtered <- merge(filtered, bird_groups, by = "soort_id")

  surveyed_keys <- unique(filtered[c("plot_id", "jaar")])
  surveyed <- merge(surveyed_keys, plot_jaar_oppervlak, by = c("plot_id", "jaar"))
  surveyed_km2 <- aggregate(oppervlakte_km2 ~ jaar, data = surveyed, FUN = sum, na.rm = TRUE)
  names(surveyed_km2)[2] <- "surveyed_km2"

  annual_territoria <- aggregate(territoria ~ groep_100 + jaar, data = filtered, FUN = sum, na.rm = TRUE)
  annual_density <- merge(annual_territoria, surveyed_km2, by = "jaar")
  annual_density$density_per_km2 <- annual_density$territoria / annual_density$surveyed_km2
  annual_density$periode <- ifelse(annual_density$jaar <= 1983, "1958-1983", "1984-2025")

  group_desc <- make_group_descriptions(evg_vogelgroepen)
  annual_density <- merge(annual_density, group_desc, by = "groep_100", all.x = TRUE)
  annual_density <- annual_density[order(annual_density$groep_100, annual_density$jaar), ]

  period_summary <- do.call(
    rbind,
    lapply(split(annual_density, annual_density$groep_100), function(df) {
      pre <- df[df$periode == "1958-1983", ]
      post <- df[df$periode == "1984-2025", ]
      data.frame(
        groep_100 = df$groep_100[[1]],
        korte_beschrijving = df$korte_beschrijving[[1]],
        n_pre = nrow(pre),
        n_post = nrow(post),
        mean_pre = mean(pre$density_per_km2, na.rm = TRUE),
        mean_post = mean(post$density_per_km2, na.rm = TRUE),
        median_pre = median(pre$density_per_km2, na.rm = TRUE),
        median_post = median(post$density_per_km2, na.rm = TRUE),
        sd_pre = stats::sd(pre$density_per_km2, na.rm = TRUE),
        sd_post = stats::sd(post$density_per_km2, na.rm = TRUE),
        bridge_pre_8183 = mean(df$density_per_km2[df$jaar >= 1981 & df$jaar <= 1983], na.rm = TRUE),
        bridge_post_8486 = mean(df$density_per_km2[df$jaar >= 1984 & df$jaar <= 1986], na.rm = TRUE),
        stringsAsFactors = FALSE
      )
    })
  )

  period_summary$ratio_post_pre <- safe_ratio(period_summary$mean_post, period_summary$mean_pre)
  period_summary$pct_change_post_pre <- (period_summary$ratio_post_pre - 1) * 100
  period_summary$bridge_factor <- safe_ratio(period_summary$bridge_pre_8183, period_summary$bridge_post_8486)
  period_summary$bridge_log_ratio <- safe_log_ratio(period_summary$bridge_pre_8183, period_summary$bridge_post_8486)
  period_summary <- period_summary[order(period_summary$groep_100), ]

  spliced_list <- lapply(split(annual_density, annual_density$groep_100), function(df) {
    mean_pre <- mean(df$density_per_km2[df$jaar <= 1983], na.rm = TRUE)
    mean_post <- mean(df$density_per_km2[df$jaar >= 1984], na.rm = TRUE)

    df$index_raw <- ifelse(
      df$jaar <= 1983,
      100 * df$density_per_km2 / mean_pre,
      100 * df$density_per_km2 / mean_post
    )

    pre_ref <- mean(df$index_raw[df$jaar >= 1981 & df$jaar <= 1983], na.rm = TRUE)
    post_ref <- mean(df$index_raw[df$jaar >= 1984 & df$jaar <= 1986], na.rm = TRUE)
    bridge_factor <- safe_ratio(pre_ref, post_ref)

    df$index_spliced <- ifelse(df$jaar <= 1983, df$index_raw, df$index_raw * bridge_factor)
    df$bridge_factor <- bridge_factor
    df
  })
  spliced <- do.call(rbind, spliced_list)
  rownames(spliced) <- NULL

  trend_summary <- do.call(
    rbind,
    lapply(split(spliced, spliced$groep_100), function(df) {
      df <- df[order(df$jaar), ]
      df$jaar_c <- df$jaar - 1958
      df$post_break <- ifelse(df$jaar >= 1984, 1, 0)
      df$jaar_na_break <- pmax(df$jaar - 1983, 0)

      fit_break <- lm(log(density_per_km2 + 0.1) ~ jaar_c + post_break + jaar_na_break, data = df)
      fit_spliced <- lm(log(index_spliced + 0.1) ~ jaar, data = df)
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
        pre_trend_pct_per_jaar = (exp(pre_slope) - 1) * 100,
        post_trend_pct_per_jaar = (exp(post_slope) - 1) * 100,
        overall_trend_pct_per_jaar = (exp(overall_slope) - 1) * 100,
        break_level_shift_pct = (exp(level_shift) - 1) * 100,
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
  trend_summary <- trend_summary[order(trend_summary$groep_100), ]

  period_trends <- do.call(
    rbind,
    lapply(split(annual_density, annual_density$groep_100), function(df_group) {
      do.call(
        rbind,
        lapply(split(df_group, df_group$periode), function(df_period) {
          df_period <- df_period[order(df_period$jaar), ]
          fit <- lm(log(density_per_km2 + 0.1) ~ jaar, data = df_period)
          cf <- summary(fit)$coefficients
          slope <- unname(coef(fit)[["jaar"]])

          data.frame(
            groep_100 = df_period$groep_100[[1]],
            korte_beschrijving = df_period$korte_beschrijving[[1]],
            periode = df_period$periode[[1]],
            eerste_jaar = min(df_period$jaar, na.rm = TRUE),
            laatste_jaar = max(df_period$jaar, na.rm = TRUE),
            n_jaren = nrow(df_period),
            mean_density = mean(df_period$density_per_km2, na.rm = TRUE),
            median_density = median(df_period$density_per_km2, na.rm = TRUE),
            trend_pct_per_jaar = (exp(slope) - 1) * 100,
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
        mean_pre = pre$mean_density[[1]],
        mean_post = post$mean_density[[1]],
        verhouding_post_pre = safe_ratio(post$mean_density[[1]], pre$mean_density[[1]]),
        stringsAsFactors = FALSE
      )
    })
  )
  period_trend_wide <- period_trend_wide[order(period_trend_wide$groep_100), ]

  list(
    annual_density = annual_density,
    period_summary = period_summary,
    spliced_index = spliced,
    trend_summary = trend_summary,
    period_trends = period_trends,
    period_trend_wide = period_trend_wide
  )
}

write_outputs <- function(results, out_dir) {
  write.csv(results$annual_density, file.path(out_dir, "jaarreeksen_dichtheid_per_groep.csv"), row.names = FALSE)
  write.csv(results$period_summary, file.path(out_dir, "vergelijking_periodes_1958_1983_vs_1984_2025.csv"), row.names = FALSE)
  write.csv(results$spliced_index, file.path(out_dir, "doorlopende_index_per_groep.csv"), row.names = FALSE)
  write.csv(results$trend_summary, file.path(out_dir, "trendanalyse_per_groep.csv"), row.names = FALSE)
  write.csv(results$period_trends, file.path(out_dir, "trendanalyse_los_per_periode.csv"), row.names = FALSE)
  write.csv(results$period_trend_wide, file.path(out_dir, "vergelijking_trends_tussen_periodes.csv"), row.names = FALSE)

  png(
    filename = file.path(out_dir, "doorlopende_index_per_groep.png"),
    width = 1600,
    height = 2200,
    res = 150
  )
  op <- par(no.readonly = TRUE)
  on.exit(par(op), add = TRUE)

  groups <- unique(results$spliced_index$groep_100)
  n_panels <- length(groups)
  n_col <- 2
  n_row <- ceiling(n_panels / n_col)
  par(mfrow = c(n_row, n_col), mar = c(3, 3, 3, 1), oma = c(2, 2, 2, 1))

  for (g in groups) {
    df <- results$spliced_index[results$spliced_index$groep_100 == g, ]
    plot(
      df$jaar,
      df$index_spliced,
      type = "l",
      lwd = 2,
      col = "#1f4e79",
      main = sprintf("%s (%s)", g, df$korte_beschrijving[[1]]),
      xlab = "Jaar",
      ylab = "Doorlopende index"
    )
    abline(v = 1983.5, lty = 2, col = "firebrick")
  }

  mtext("Ecologische groepen Meijendel: doorlopende index met breukcorrectie", outer = TRUE, cex = 1.1)
  dev.off()
}

cat(sprintf("Lees SQL-dump: %s\n", sql_path))
tables <- parse_needed_tables(sql_path)
cat("Voer analyse uit...\n")
results <- analyse_groups(tables)
write_outputs(results, output_dir)

cat("\nKernsamenvatting:\n")
print(results$period_summary[, c(
  "groep_100", "korte_beschrijving", "mean_pre", "mean_post",
  "pct_change_post_pre", "bridge_factor"
)])

cat("\nTrendsamenvatting:\n")
print(results$trend_summary[, c(
  "groep_100", "korte_beschrijving", "pre_trend_pct_per_jaar",
  "post_trend_pct_per_jaar", "overall_trend_pct_per_jaar",
  "break_level_shift_pct", "p_slope_change"
)])

cat("\nLosse trends per periode:\n")
print(results$period_trend_wide[, c(
  "groep_100", "korte_beschrijving", "trend_pre_pct_per_jaar",
  "trend_post_pct_per_jaar", "verschil_trendpunten",
  "verhouding_post_pre"
)])

cat(sprintf("\nBestanden geschreven naar: %s\n", output_dir))
