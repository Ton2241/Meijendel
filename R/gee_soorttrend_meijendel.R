args <- commandArgs(trailingOnly = TRUE)

user_lib <- file.path(Sys.getenv("HOME"), "Library/R/arm64/4.5/library")
if (dir.exists(user_lib)) {
  .libPaths(c(user_lib, .libPaths()))
}

required_packages <- c("geepack", "broom")
missing_packages <- required_packages[!required_packages %in% rownames(installed.packages())]
if (length(missing_packages) > 0L) {
  install.packages(missing_packages)
}

suppressPackageStartupMessages(library(geepack))
suppressPackageStartupMessages(library(broom))

sql_path <- if (length(args) >= 1L) args[[1]] else "/Users/ton/Documents/GitHub/Meijendel/Meijendel.sql"
species_name <- if (length(args) >= 2L) args[[2]] else "Nachtegaal"
output_dir <- if (length(args) >= 3L) args[[3]] else "/Users/ton/Documents/GitHub/Meijendel/output_gee"
year_min <- if (length(args) >= 4L) as.integer(args[[4]]) else 1984L
year_max <- if (length(args) >= 5L) as.integer(args[[5]]) else 2025L
analysis_set <- if (length(args) >= 6L) args[[6]] else "uitgebreid"
gee_corstr <- if (length(args) >= 7L) args[[7]] else "exchangeable"

historische_kavels <- c(
  "1", "1a", "1b", "2", "3", "4", "4-5", "5", "6", "7", "8", "8/9", "8/11",
  "9", "10", "10-12-76", "11", "12", "12a", "13", "13s", "14", "15", "16",
  "16s", "17", "17a"
)

sandra_kavels <- c(
  "1a", "1b", "3", "4-5", "6", "7", "8", "10-12-76", "12a", "13", "13s", "14",
  "15", "16", "17a", "17b", "45", "54a", "62", "71", "72", "73", "74", "75", "83"
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
  soorten <- read_insert_table(path, "soorten", c("id", "euring_code", "soort_naam", "engelse_naam"))
  pjo <- read_insert_table(path, "plot_jaar_oppervlak", c("plot_id", "jaar", "oppervlakte_km2"))
  pjt <- read_insert_table(path, "plot_jaar_teller", c("plot_id", "jaar"))
  territoria <- read_insert_table(path, "territoria", c("plot_id", "soort_id", "jaar", "territoria"))

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

  list(
    plots = plots,
    soorten = soorten,
    plot_jaar_oppervlak = pjo,
    plot_jaar_teller = pjt,
    territoria = territoria
  )
}

make_analysis_basis <- function(tbls, year_min, year_max, analysis_set) {
  pjo <- merge(tbls$plot_jaar_oppervlak, tbls$plots, by = "plot_id", all.x = TRUE)
  pjo <- pjo[pjo$jaar >= year_min & pjo$jaar <= year_max, , drop = FALSE]

  if (analysis_set == "lange_reeks") {
    pjo <- pjo[pjo$kavel_nummer %in% historische_kavels, , drop = FALSE]
  } else if (analysis_set == "sandra") {
    pjo <- pjo[pjo$kavel_nummer %in% sandra_kavels, , drop = FALSE]
  } else if (analysis_set != "uitgebreid") {
    stop("Onbekende analysis_set. Gebruik 'uitgebreid', 'lange_reeks' of 'sandra'.")
  }

  surveyed <- unique(rbind(
    tbls$plot_jaar_teller[c("plot_id", "jaar")],
    tbls$territoria[c("plot_id", "jaar")]
  ))
  surveyed$geteld <- TRUE

  basis <- merge(pjo, surveyed, by = c("plot_id", "jaar"), all.x = TRUE)
  basis$geteld[is.na(basis$geteld)] <- FALSE
  basis$plot_label <- ifelse(
    !is.na(basis$kavel_nummer) & nzchar(basis$kavel_nummer),
    basis$kavel_nummer,
    basis$plot_naam
  )

  basis <- unique(basis[, c(
    "plot_id", "jaar", "oppervlakte_km2", "plot_naam", "kavel_nummer",
    "plot_label", "geteld"
  )])

  basis[order(basis$plot_id, basis$jaar), ]
}

find_species <- function(soorten, species_name) {
  exact <- soorten[soorten$soort_naam == species_name, , drop = FALSE]
  if (nrow(exact) == 1L) {
    return(exact)
  }
  if (nrow(exact) > 1L) {
    stop("Meerdere exacte matches voor soortnaam: ", species_name)
  }

  case_insensitive <- soorten[tolower(soorten$soort_naam) == tolower(species_name), , drop = FALSE]
  if (nrow(case_insensitive) == 1L) {
    return(case_insensitive)
  }
  if (nrow(case_insensitive) > 1L) {
    stop("Meerdere case-insensitive matches voor soortnaam: ", species_name)
  }

  stop("Soort niet gevonden in tabel 'soorten': ", species_name)
}

build_species_counts <- function(tbls, species_id, year_min, year_max, plot_ids) {
  counts <- tbls$territoria[
    tbls$territoria$soort_id == species_id &
      tbls$territoria$jaar >= year_min &
      tbls$territoria$jaar <= year_max &
      tbls$territoria$plot_id %in% plot_ids,
    c("plot_id", "jaar", "territoria")
  ]

  if (!nrow(counts)) {
    return(data.frame(plot_id = integer(), jaar = integer(), count = numeric(), stringsAsFactors = FALSE))
  }

  agg <- aggregate(territoria ~ plot_id + jaar, data = counts, FUN = sum, na.rm = TRUE)
  names(agg)[names(agg) == "territoria"] <- "count"
  agg
}

build_model_dataset <- function(basis, counts) {
  dat <- merge(basis, counts, by = c("plot_id", "jaar"), all.x = TRUE)
  dat$count <- ifelse(dat$geteld & is.na(dat$count), 0, dat$count)
  dat$count <- ifelse(!dat$geteld, NA_real_, dat$count)
  dat$log_area <- ifelse(
    is.finite(dat$oppervlakte_km2) & dat$oppervlakte_km2 > 0,
    log(dat$oppervlakte_km2),
    NA_real_
  )

  dat
}

validate_inputs <- function(sql_path, year_min, year_max, gee_corstr) {
  if (!file.exists(sql_path)) {
    stop("SQL-dump niet gevonden: ", sql_path)
  }
  if (!is.finite(year_min) || !is.finite(year_max) || year_min > year_max) {
    stop("Ongeldig jaarbereik.")
  }
  if (!gee_corstr %in% c("exchangeable", "ar1", "independence", "unstructured")) {
    stop("Ongeldige correlatiestructuur: ", gee_corstr)
  }
}

write_outputs <- function(output_dir, slug, pred_df, coef_tab, summary_df, dat_model) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  write.csv(pred_df, file.path(output_dir, paste0("gee_index_", slug, ".csv")), row.names = FALSE)
  write.csv(coef_tab, file.path(output_dir, paste0("gee_coef_", slug, ".csv")), row.names = FALSE)
  write.csv(summary_df, file.path(output_dir, paste0("gee_samenvatting_", slug, ".csv")), row.names = FALSE)
  write.csv(dat_model, file.path(output_dir, paste0("gee_dataset_", slug, ".csv")), row.names = FALSE)
}

validate_inputs(sql_path, year_min, year_max, gee_corstr)
tbls <- parse_tables(sql_path)
species_row <- find_species(tbls$soorten, species_name)
species_id <- species_row$id[[1]]
species_slug <- gsub("[^a-z0-9]+", "_", tolower(species_name))
species_slug <- gsub("^_+|_+$", "", species_slug)

basis <- make_analysis_basis(tbls, year_min, year_max, analysis_set)
if (!nrow(basis)) {
  stop("Geen geldige plot-jaar-combinaties voor deze selectie.")
}

counts <- build_species_counts(tbls, species_id, year_min, year_max, unique(basis$plot_id))
dat <- build_model_dataset(basis, counts)

if (!any(!is.na(dat$count))) {
  stop("Geen getelde plot-jaren voor deze selectie.")
}
if (sum(dat$count, na.rm = TRUE) <= 0) {
  stop("Geen territoria voor deze soort in de gekozen selectie.")
}

dat_model <- dat[!is.na(dat$count) & is.finite(dat$log_area), , drop = FALSE]
if (nrow(dat_model) < 20L) {
  warning("Weinig bruikbare waarnemingen; model kan instabiel zijn.")
}
if (length(unique(dat_model$jaar)) < 3L) {
  stop("Te weinig unieke jaren voor een GEE-trend.")
}
if (length(unique(dat_model$plot_id)) < 2L) {
  stop("Te weinig unieke plots voor een GEE-analyse.")
}

dat_model$year_c <- dat_model$jaar - min(dat_model$jaar, na.rm = TRUE)
dat_model <- dat_model[order(dat_model$plot_id, dat_model$jaar), ]

gee_fit <- geeglm(
  formula = count ~ year_c + offset(log_area),
  family = poisson(link = "log"),
  id = plot_id,
  corstr = gee_corstr,
  data = dat_model
)

coef_tab <- broom::tidy(gee_fit)
year_row <- coef_tab[coef_tab$term == "year_c", , drop = FALSE]
if (nrow(year_row) != 1L) {
  stop("Jaarcoëfficiënt niet gevonden in modeluitvoer.")
}

beta <- year_row$estimate[[1]]
se <- year_row$std.error[[1]]
zval <- year_row$statistic[[1]]
pval <- year_row$p.value[[1]]

annual_multiplier <- exp(beta)
annual_pct <- (annual_multiplier - 1) * 100
ci_low <- exp(beta - 1.96 * se)
ci_high <- exp(beta + 1.96 * se)

pred_years <- data.frame(
  jaar = seq(min(dat_model$jaar), max(dat_model$jaar)),
  year_c = seq(min(dat_model$jaar), max(dat_model$jaar)) - min(dat_model$jaar),
  log_area = 0,
  stringsAsFactors = FALSE
)

pred_link <- predict(gee_fit, newdata = pred_years, type = "link", se.fit = TRUE)
pred_df <- pred_years
pred_df$eta <- as.numeric(pred_link$fit)
pred_df$se_eta <- as.numeric(pred_link$se.fit)
pred_df$mu <- exp(pred_df$eta)
pred_df$mu_low <- exp(pred_df$eta - 1.96 * pred_df$se_eta)
pred_df$mu_high <- exp(pred_df$eta + 1.96 * pred_df$se_eta)
pred_df$index <- 100 * pred_df$mu / pred_df$mu[[1]]
pred_df$index_low <- 100 * pred_df$mu_low / pred_df$mu[[1]]
pred_df$index_high <- 100 * pred_df$mu_high / pred_df$mu[[1]]

summary_df <- data.frame(
  soort_id = species_id,
  soort_naam = species_row$soort_naam[[1]],
  engelse_naam = species_row$engelse_naam[[1]],
  analysis_set = analysis_set,
  gee_corstr = gee_corstr,
  year_min = min(dat_model$jaar),
  year_max = max(dat_model$jaar),
  n_plots = length(unique(dat_model$plot_id)),
  n_plot_jaren = nrow(dat_model),
  totaal_territoria = sum(dat_model$count, na.rm = TRUE),
  jaarcoef_log = beta,
  robuuste_se = se,
  z = zval,
  p = pval,
  jaarlijkse_factor = annual_multiplier,
  jaarlijkse_pct = annual_pct,
  ci_low_factor = ci_low,
  ci_high_factor = ci_high,
  ci_low_pct = (ci_low - 1) * 100,
  ci_high_pct = (ci_high - 1) * 100,
  stringsAsFactors = FALSE
)

write_outputs(output_dir, species_slug, pred_df, coef_tab, summary_df, dat_model)

cat("Soort:", species_row$soort_naam[[1]], "\n")
cat("Analyse-set:", analysis_set, "\n")
cat("Correlatiestructuur:", gee_corstr, "\n")
cat("Plots:", length(unique(dat_model$plot_id)), "\n")
cat("Jaren:", min(dat_model$jaar), "-", max(dat_model$jaar), "\n")
cat("Gebruikte plot-jaren:", nrow(dat_model), "\n")
cat("Totaal territoria:", sum(dat_model$count, na.rm = TRUE), "\n")
cat("Jaarlijkse procentuele verandering:", round(annual_pct, 2), "%\n")
cat("95%-BI %:", round((ci_low - 1) * 100, 2), "tot", round((ci_high - 1) * 100, 2), "\n")
cat("Outputmap:", output_dir, "\n")
