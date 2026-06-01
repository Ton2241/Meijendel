extract_columns <- function(header) {
  if (!grepl("\\) VALUES", header, fixed = FALSE)) {
    return(character())
  }
  start <- regexpr("\\(", header)[1]
  end <- regexpr("\\) VALUES", header)[1]
  cols <- substring(header, start + 1L, end - 1L)
  cols <- gsub("`", "", cols, fixed = TRUE)
  trimws(strsplit(cols, ",", fixed = TRUE)[[1]])
}

meijendel_analysis_packages <- function() {
  c(
    "shiny", "bslib", "DBI", "RSQLite", "rtrim", "mgcv", "broom",
    "geepack", "broom.mixed", "DHARMa", "glmmTMB", "lme4", "TMB",
    "vegan", "pls", "changepoint", "strucchange", "lavaan", "piecewiseSEM",
    "betapart", "unmarked"
  )
}

r_code <- function(code) {
  structure(as.character(code), class = "meijendel_r_code")
}

count_overdispersion_diagnostic <- function(counts) {
  vals <- counts[is.finite(counts)]
  mean_val <- mean(vals, na.rm = TRUE)
  variance_val <- if (length(vals) >= 2L) stats::var(vals, na.rm = TRUE) else NA_real_
  ratio_val <- if (is.finite(mean_val) && mean_val > 0) variance_val / mean_val else NA_real_
  interpretation <- if (!is.finite(ratio_val)) {
    "niet te beoordelen"
  } else if (ratio_val > 2) {
    "sterke overdispersie"
  } else if (ratio_val > 1.5) {
    "matige overdispersie"
  } else {
    "geen duidelijke overdispersie"
  }
  advies <- if (!is.finite(ratio_val)) {
    "niet te beoordelen"
  } else if (ratio_val > 2) {
    "gebruik bij voorkeur GLMM Negative Binomial of vergelijk met een alternatief voor Poisson"
  } else if (ratio_val > 1.5) {
    "interpreteer Poisson voorzichtig en vergelijk met GLMM Negative Binomial"
  } else {
    "Poisson is op basis van deze maat verdedigbaar"
  }
  list(
    count_mean = mean_val,
    count_variance = variance_val,
    variance_mean_ratio = ratio_val,
    overdispersion_interpretatie = interpretation,
    overdispersion_advies = advies
  )
}

r_literal <- function(x) {
  if (inherits(x, "meijendel_r_code")) {
    return(unclass(x)[[1]])
  }
  paste(capture.output(dput(x)), collapse = "\n")
}

analysis_export_call <- function(function_name, args) {
  arg_lines <- sprintf(
    "  %s = %s",
    names(args),
    vapply(args, r_literal, character(1))
  )
  paste0(function_name, "(\n", paste(arg_lines, collapse = ",\n"), "\n)")
}

analysis_export_script <- function(title, call_expr) {
  pkgs <- meijendel_analysis_packages()
  versions <- vapply(pkgs, function(pkg) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      as.character(utils::packageVersion(pkg))
    } else {
      "niet geinstalleerd"
    }
  }, character(1))

  c(
    "# Reproduceerbaar R-script uit Shiny Meijendel",
    paste0("# Analyse: ", title),
    paste0("# Gegenereerd: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste0("# R: ", R.version.string),
    "#",
    "# Packageversies bij export:",
    paste0("# - ", names(versions), ": ", unname(versions)),
    "",
    "required_packages <- c(",
    paste0("  ", r_literal(pkgs)),
    ")",
    "missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]",
    "if (length(missing_packages)) {",
    "  stop(\"Ontbrekende packages: \", paste(missing_packages, collapse = \", \"))",
    "}",
    "",
    "if (!file.exists(\"helpers.R\")) {",
    "  stop(\"Voer dit script uit vanuit de map shiny_meijendel.\")",
    "}",
    "source(\"helpers.R\")",
    "sql_path <- \"../Meijendel.sql\"",
    "tbls <- load_meijendel_tables_cached(sql_path)$data",
    "",
    paste0("analyse <- ", call_expr),
    "",
    "print(analyse$summary)",
    "utils::sessionInfo()"
  )
}

attach_analysis_export_script <- function(analyse, title, function_name, args) {
  analyse$export_script <- analysis_export_script(
    title = title,
    call_expr = analysis_export_call(function_name, args)
  )
  if (identical(function_name, "run_sem_subset")) {
    analyse$export_script <- c(
      "# LET OP: deze SEM-output is exploratief.",
      "# De modelstructuur is hard-coded en mag niet als causale rapportage worden gebruikt zonder vooraf gespecificeerd hypothesemodel.",
      "",
      analyse$export_script
    )
  }
  analyse
}

write_analysis_export_script <- function(analyse, file) {
  if (is.null(analyse$export_script)) {
    stop("Geen R-script beschikbaar. Voer de analyse opnieuw uit.")
  }
  writeLines(analyse$export_script, file, useBytes = TRUE)
}

extract_create_table_columns <- function(lines, table) {
  start <- which(grepl(paste0("^CREATE TABLE `", table, "` \\("), lines, useBytes = TRUE))
  if (!length(start)) {
    return(character())
  }

  out <- character()
  pos <- start[1] + 1L
  while (pos <= length(lines) && !grepl("^\\) ENGINE=", lines[pos], useBytes = TRUE)) {
    m <- regexec("^\\s*`([^`]+)`", lines[pos])
    hit <- regmatches(lines[pos], m)[[1]]
    if (length(hit) >= 2L) {
      out <- c(out, hit[2])
    }
    pos <- pos + 1L
  }
  out
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

split_tuples_fast <- function(values_text) {
  values_text <- trimws(values_text)
  values_text <- sub("^\\(", "", values_text)
  values_text <- sub("\\)$", "", values_text)
  if (!nzchar(values_text)) {
    return(character())
  }
  strsplit(values_text, "\\),\\(", perl = TRUE, useBytes = TRUE)[[1]]
}

split_fields <- function(tuple_text, respect_parens = FALSE) {
  fields <- character()
  n <- nchar(tuple_text, type = "bytes")
  in_quote <- FALSE
  escape_next <- FALSE
  paren_depth <- 0L
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

    if (respect_parens && !in_quote && ch == "(") {
      paren_depth <- paren_depth + 1L
      next
    }

    if (respect_parens && !in_quote && ch == ")" && paren_depth > 0L) {
      paren_depth <- paren_depth - 1L
      next
    }

    if (!in_quote && paren_depth == 0L && ch == ",") {
      fields <- c(fields, substring(tuple_text, start, i - 1L))
      start <- i + 1L
    }
  }

  fields <- c(fields, substring(tuple_text, start, n))
  trimws(fields)
}

split_fields_keep <- function(tuple_text, keep_idx, respect_parens = FALSE) {
  fields <- vector("list", length(keep_idx))
  names(fields) <- as.character(keep_idx)
  max_keep_idx <- max(keep_idx)
  n <- nchar(tuple_text, type = "bytes")
  in_quote <- FALSE
  escape_next <- FALSE
  paren_depth <- 0L
  start <- 1L
  field_idx <- 1L

  capture_field <- function(end_pos) {
    match_pos <- match(field_idx, keep_idx)
    if (!is.na(match_pos)) {
      fields[[match_pos]] <<- trimws(substring(tuple_text, start, end_pos))
    }
  }

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

    if (respect_parens && !in_quote && ch == "(") {
      paren_depth <- paren_depth + 1L
      next
    }

    if (respect_parens && !in_quote && ch == ")" && paren_depth > 0L) {
      paren_depth <- paren_depth - 1L
      next
    }

    if (!in_quote && paren_depth == 0L && ch == ",") {
      capture_field(i - 1L)
      start <- i + 1L
      field_idx <- field_idx + 1L
      if (field_idx > max_keep_idx) {
        break
      }
    }
  }

  if (field_idx <= max_keep_idx) {
    capture_field(n)
  }
  unname(unlist(fields, use.names = FALSE))
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

read_values_csv_block <- function(values_text, columns, keep_columns = NULL) {
  values_text <- trimws(values_text)
  values_text <- sub("^\\(", "", values_text)
  values_text <- sub("\\)$", "", values_text)
  values_text <- gsub("\\),\\(", "\n", values_text, perl = TRUE, useBytes = TRUE)
  df <- utils::read.csv(
    text = values_text,
    header = FALSE,
    sep = ",",
    quote = "'",
    na.strings = "NULL",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    comment.char = "",
    colClasses = "character",
    allowEscapes = TRUE
  )
  if (ncol(df) != length(columns)) {
    stop(sprintf(
      "Aantal waarden (%s) past niet bij aantal kolommen (%s).",
      ncol(df),
      length(columns)
    ))
  }
  names(df) <- columns
  if (!is.null(keep_columns)) {
    missing_columns <- setdiff(keep_columns, names(df))
    if (length(missing_columns)) {
      stop(sprintf("Tabel mist kolommen: %s.", paste(missing_columns, collapse = ", ")))
    }
    df <- df[keep_columns]
  }
  df
}

read_insert_table <- function(path, table, keep_columns = NULL, respect_parens = FALSE, sanitize_binary = FALSE, fast_tuples = FALSE, keep_only = FALSE) {
  lines <- readLines(path, warn = FALSE, encoding = if (sanitize_binary) "latin1" else "UTF-8")
  prefix <- paste0("INSERT INTO `", table, "` ")
  starts <- which(startsWith(lines, prefix))
  create_columns <- extract_create_table_columns(lines, table)

  if (!length(starts)) {
    stop(sprintf("Geen INSERT-blokken gevonden voor tabel '%s'.", table))
  }

  out <- list()
  row_counter <- 0L

  for (idx in starts) {
    block_lines <- lines[idx]
    pos <- idx
    while (!grepl(";$", block_lines[length(block_lines)], useBytes = TRUE)) {
      pos <- pos + 1L
      block_lines <- c(block_lines, lines[pos])
    }

    block <- paste(block_lines, collapse = "\n")
    header <- sub("\n.*$", "", block)
    columns <- extract_columns(header)
    if (!length(columns)) {
      columns <- create_columns
    }
    if (!length(columns)) {
      stop(sprintf("Geen kolommen gevonden voor tabel '%s'.", table))
    }
    values_text <- sub("^.*?VALUES\\s*", "", block)
    values_text <- sub(";\\s*$", "", values_text)
    if (sanitize_binary) {
      values_text <- gsub("_binary '[^']*'", "NULL", values_text, perl = TRUE, useBytes = TRUE)
    }
    tuples <- if (fast_tuples) split_tuples_fast(values_text) else split_tuples(values_text)

    keep_idx <- if (!is.null(keep_columns) && keep_only) match(keep_columns, columns) else integer()
    if (keep_only && any(is.na(keep_idx))) {
      stop(sprintf(
        "Tabel '%s' mist kolommen: %s.",
        table,
        paste(keep_columns[is.na(keep_idx)], collapse = ", ")
      ))
    }

    parsed_rows <- vector("list", length(tuples))
    for (i in seq_along(tuples)) {
      fields <- if (keep_only && length(keep_idx)) {
        split_fields_keep(tuples[[i]], keep_idx, respect_parens = respect_parens)
      } else {
        split_fields(tuples[[i]], respect_parens = respect_parens)
      }
      parsed_rows[[i]] <- vapply(fields, decode_sql_value, character(1))
    }

    mat <- do.call(rbind, parsed_rows)
    df <- as.data.frame(mat, stringsAsFactors = FALSE)
    expected_columns <- if (keep_only && !is.null(keep_columns)) keep_columns else columns
    if (ncol(df) != length(expected_columns)) {
      stop(sprintf(
        "Aantal waarden (%s) past niet bij aantal kolommen (%s) voor tabel '%s'.",
        ncol(df),
        length(expected_columns),
        table
      ))
    }
    names(df) <- expected_columns

    if (!is.null(keep_columns) && !keep_only) {
      missing_columns <- setdiff(keep_columns, names(df))
      if (length(missing_columns)) {
        stop(sprintf(
          "Tabel '%s' mist kolommen: %s.",
          table,
          paste(missing_columns, collapse = ", ")
        ))
      }
      df <- df[keep_columns]
    }

    row_counter <- row_counter + 1L
    out[[row_counter]] <- df
  }

  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

extract_insert_values_text <- function(path, table, encoding = "UTF-8") {
  lines <- readLines(path, warn = FALSE, encoding = encoding)
  prefix <- paste0("INSERT INTO `", table, "` ")
  starts <- which(startsWith(lines, prefix))
  if (!length(starts)) {
    stop(sprintf("Geen INSERT-blokken gevonden voor tabel '%s'.", table))
  }
  block_lines <- lines[starts[[1]]]
  pos <- starts[[1]]
  while (!grepl(";$", block_lines[length(block_lines)], useBytes = TRUE)) {
    pos <- pos + 1L
    block_lines <- c(block_lines, lines[pos])
  }
  block <- paste(block_lines, collapse = "\n")
  values_text <- sub("^.*?VALUES\\s*", "", block)
  sub(";\\s*$", "", values_text)
}

read_dagwaarnemingen_bmp_fast <- function(path) {
  perl <- Sys.which("perl")
  if (nzchar(perl)) {
    out_file <- tempfile(fileext = ".tsv")
    script_file <- tempfile(fileext = ".pl")
    script <- paste0(
      "binmode(STDIN); binmode(STDOUT); ",
      "local $/; my $s=<>; ",
      "$s =~ s/^.*?INSERT INTO `dagwaarnemingen_bmp` .*? VALUES //s; ",
      "$s = (split(/\\/\\*!40000 ALTER TABLE `dagwaarnemingen_bmp` ENABLE KEYS/, $s))[0]; ",
      "while ($s =~ /(?:^|\\),)\\(([^,]+),[^,]*,([^,]+),([^,]+),([^,]+),([^,]+),[^,]*,[^,]*,([^,]+),([^,]+),([^,]*),([^,]*)/g) { ",
      "my @v=($1,$2,$3,$4,$5,$6,$7,$8,$9); ",
      "for (@v) { s/^'//; s/'$//; s/\\\\'/'/g; s/\\t/ /g; } ",
      "print join(\"\\t\", @v), \"\\n\"; ",
      "}"
    )
    writeLines(script, script_file, useBytes = TRUE)
    status <- system2(perl, c(script_file, path), stdout = out_file, stderr = FALSE)
    if (identical(status, 0L) && file.exists(out_file) && file.info(out_file)$size > 0) {
      out <- utils::read.delim(out_file, header = FALSE, stringsAsFactors = FALSE, colClasses = "character", quote = "")
      names(out) <- c("id", "bezoek_id", "plot_id", "soort_id", "jaar", "dagvanjaar", "aantal", "broedcode", "wrntype")
      out[out == "NULL"] <- NA_character_
      out[out == ""] <- NA_character_
      out$cluster_territorium <- NA_integer_
      out$in_plot <- NA_integer_
      return(out)
    }
  }
  stop("Perl is niet beschikbaar; dagwaarnemingen_bmp kan niet snel uit de SQL-dump worden gelezen.")
}

read_dagbezoeken_bmp_fast <- function(path) {
  perl <- Sys.which("perl")
  if (nzchar(perl)) {
    out_file <- tempfile(fileext = ".tsv")
    script_file <- tempfile(fileext = ".pl")
    script <- paste0(
      "binmode(STDIN); binmode(STDOUT); ",
      "local $/; my $s=<>; ",
      "$s =~ s/^.*?INSERT INTO `dagbezoeken_bmp` .*? VALUES //s; ",
      "$s = (split(/\\/\\*!40000 ALTER TABLE `dagbezoeken_bmp` ENABLE KEYS/, $s))[0]; ",
      "while ($s =~ /(?:^|\\),)\\(([^,]+),([^,]+),([^,]+),[^,]*,([^,]+),[^,]*,[^,]*,([^,]*),[^,]*,[^,]*,([^,]*)/g) { ",
      "my @v=($1,$2,$3,$4,$5,$6,'',''); ",
      "for (@v) { s/^'//; s/'$//; s/\\\\'/'/g; s/\\t/ /g; } ",
      "print join(\"\\t\", @v), \"\\n\"; ",
      "}"
    )
    writeLines(script, script_file, useBytes = TRUE)
    status <- system2(perl, c(script_file, path), stdout = out_file, stderr = FALSE)
    if (identical(status, 0L) && file.exists(out_file) && file.info(out_file)$size > 0) {
      out <- utils::read.delim(out_file, header = FALSE, stringsAsFactors = FALSE, colClasses = "character", quote = "")
      names(out) <- c("bezoek_id", "plot_id", "jaar", "dagvanjaar", "bezoekduur_min", "gunstig", "aantal_soorten", "aantal_records")
      out[out == "NULL"] <- NA_character_
      out[out == ""] <- NA_character_
      return(out)
    }
  }
  stop("Perl is niet beschikbaar; dagbezoeken_bmp kan niet snel uit de SQL-dump worden gelezen.")
}

to_integer <- function(x) as.integer(x)
to_numeric <- function(x) as.numeric(x)

parse_meijendel_tables <- function(path) {
  plots <- read_insert_table(path, "plots")
  soorten <- read_insert_table(path, "soorten", c("id", "euring_code", "soort_naam", "engelse_naam"))
  pjo <- read_insert_table(path, "plot_jaar_oppervlak", c("plot_id", "jaar", "oppervlakte_km2"))
  pjt <- read_insert_table(path, "plot_jaar_teller", c("plot_id", "jaar"))
  territoria <- read_insert_table(path, "territoria", c("plot_id", "soort_id", "jaar", "territoria"))
  evg_groepen <- read_insert_table(path, "evg_vogelgroepen", c("groepsnummer", "landschap_groep"))
  evg_koppeling <- read_insert_table(path, "evg_vogel_landschapgroep", c("groepsnummer", "vogel_id"))
  richtlijnen <- read_insert_table(path, "richtlijnen", c("id", "naam"))
  soort_richtlijn <- read_insert_table(path, "soort_richtlijn", c("soort_id", "richtlijn_id"))
  soorten_kenmerken <- read_insert_table(path, "soorten_kenmerken", c("id", "soort_id", "soortnaam", "hoofdcategorie_id", "code", "waarde"))
  soorten_kenmerken_datadictionary <- read_insert_table(path, "soorten_kenmerken_datadictionary", c("id", "veld", "betekenis", "betekenis_nederlands", "parent_code", "code_type", "status"))
  soorten_kenmerken_hoofdcategorien <- read_insert_table(path, "soorten_kenmerken_hoofdcategorien", c("id", "code", "beschrijving"))
  soorten_kenmerken_vogeltypering <- read_insert_table(path, "soorten_kenmerken_vogeltypering")
  habitattypen <- read_insert_table(path, "habitattypen", c("id", "habitat_code", "habitat_naam"))
  pjh <- read_insert_table(path, "plot_jaar_habitat", c("plot_id", "jaar", "habitat_id", "aandeel_m2"))
  pja <- read_insert_table(path, "plot_jaar_ahn_dtm", c("plot_id", "jaar", "bron", "ahn_mean", "ahn_sd"))
  pjs <- read_insert_table(path, "plot_jaar_stikstof", c("plot_id", "jaar", "bron", "stikstof_mean"))
  pji <- read_insert_table(path, "plot_jaar_infra", c("plot_id", "jaar", "bron", "variabele", "waarde"))
  pjtg <- read_insert_table(path, "plot_jaar_toegankelijkheid", c("plot_id", "jaar", "bron", "status_code"))

  plots$plot_id <- to_integer(plots$plot_id)
  plots$in_gebruik <- if ("in_gebruik" %in% names(plots)) to_integer(plots$in_gebruik) else 1L
  plots <- plots[, c("plot_id", "plot_naam", "kavel_nummer", "in_gebruik")]
  plots <- plots[plots$in_gebruik == 1L, , drop = FALSE]
  actieve_plot_ids <- unique(plots$plot_id)
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
  richtlijnen$id <- to_integer(richtlijnen$id)
  soort_richtlijn$soort_id <- to_integer(soort_richtlijn$soort_id)
  soort_richtlijn$richtlijn_id <- to_integer(soort_richtlijn$richtlijn_id)
  soorten_kenmerken$id <- to_integer(soorten_kenmerken$id)
  soorten_kenmerken$soort_id <- to_integer(soorten_kenmerken$soort_id)
  soorten_kenmerken$hoofdcategorie_id <- to_integer(soorten_kenmerken$hoofdcategorie_id)
  soorten_kenmerken$waarde <- to_integer(soorten_kenmerken$waarde)
  soorten_kenmerken_datadictionary$id <- to_integer(soorten_kenmerken_datadictionary$id)
  soorten_kenmerken_hoofdcategorien$id <- to_integer(soorten_kenmerken_hoofdcategorien$id)
  if ("soort_id" %in% names(soorten_kenmerken_vogeltypering)) {
    soorten_kenmerken_vogeltypering$soort_id <- to_integer(soorten_kenmerken_vogeltypering$soort_id)
  }
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

  pjo <- pjo[pjo$plot_id %in% actieve_plot_ids, , drop = FALSE]
  pjt <- pjt[pjt$plot_id %in% actieve_plot_ids, , drop = FALSE]
  territoria <- territoria[territoria$plot_id %in% actieve_plot_ids, , drop = FALSE]
  pjh <- pjh[pjh$plot_id %in% actieve_plot_ids, , drop = FALSE]
  pja <- pja[pja$plot_id %in% actieve_plot_ids, , drop = FALSE]
  pjs <- pjs[pjs$plot_id %in% actieve_plot_ids, , drop = FALSE]
  pji <- pji[pji$plot_id %in% actieve_plot_ids, , drop = FALSE]
  pjtg <- pjtg[pjtg$plot_id %in% actieve_plot_ids, , drop = FALSE]

  list(
    plots = plots,
    soorten = soorten,
    plot_jaar_oppervlak = pjo,
    plot_jaar_teller = pjt,
    territoria = territoria,
    evg_vogelgroepen = evg_groepen,
    evg_vogel_landschapgroep = evg_koppeling,
    richtlijnen = richtlijnen,
    soort_richtlijn = soort_richtlijn,
    soorten_kenmerken = soorten_kenmerken,
    soorten_kenmerken_datadictionary = soorten_kenmerken_datadictionary,
    soorten_kenmerken_hoofdcategorien = soorten_kenmerken_hoofdcategorien,
    soorten_kenmerken_vogeltypering = soorten_kenmerken_vogeltypering,
    habitattypen = habitattypen,
    plot_jaar_habitat = pjh,
    plot_jaar_ahn_dtm = pja,
    plot_jaar_stikstof = pjs,
    plot_jaar_infra = pji,
    plot_jaar_toegankelijkheid = pjtg,
    sql_path = normalizePath(path, winslash = "/", mustWork = TRUE)
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
      all(c("richtlijnen", "soort_richtlijn", "soorten_kenmerken", "soorten_kenmerken_datadictionary", "soorten_kenmerken_hoofdcategorien", "soorten_kenmerken_vogeltypering", "habitattypen", "plot_jaar_habitat", "plot_jaar_ahn_dtm", "plot_jaar_stikstof", "plot_jaar_infra", "plot_jaar_toegankelijkheid") %in% names(cache$data))
    if (cache_valid) {
      cache$data$sql_path <- path
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

add_territory_observation_status <- function(dat, count_col = "count") {
  count <- dat[[count_col]]
  dat$is_missing <- !dat$geteld
  dat$territorium_vastgesteld <- dat$geteld & is.finite(count) & count > 0
  dat$echte_nul <- dat$geteld & is.finite(count) & count == 0
  dat$waargenomen_zonder_territorium <- NA
  dat$observatie_status <- ifelse(
    dat$is_missing,
    "niet_geteld",
    ifelse(
      dat$territorium_vastgesteld,
      "territorium_vastgesteld",
      ifelse(dat$echte_nul, "echte_nul_geen_territorium", "onbekend")
    )
  )
  dat
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

  grid$count_raw <- ifelse(!grid$geteld, NA_real_, ifelse(is.na(grid$territoria), 0, grid$territoria))
  grid$territoria_per_km2 <- ifelse(
    grid$geteld &
      is.finite(grid$count_raw) &
      is.finite(grid$oppervlakte_km2) &
      grid$oppervlakte_km2 > 0,
    grid$count_raw / grid$oppervlakte_km2,
    NA_real_
  )
  grid$count_area_standardized <- ifelse(grid$geteld, grid$count_raw * grid$oppervlakte_factor, NA_real_)
  grid$count_adjusted <- grid$count_area_standardized
  grid <- add_territory_observation_status(grid, "count_raw")
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

  first_positive_year <- min(positive_years)
  analysis_years <- sort(year_totals$jaar[year_totals$jaar >= first_positive_year])
  df <- df[df$jaar %in% analysis_years, , drop = FALSE]
  site_totals <- aggregate(count_adjusted ~ plot_id, data = df, FUN = function(x) sum(x, na.rm = TRUE))
  active_sites <- site_totals$plot_id[site_totals$count_adjusted > 0]
  if (length(active_sites) < 2L) {
    return(list(ok = FALSE, reason = "te_weinig_actieve_plots"))
  }
  df <- df[df$plot_id %in% active_sites, , drop = FALSE]

  year_map <- data.frame(
    jaar = analysis_years,
    trim_year = seq_along(analysis_years),
    stringsAsFactors = FALSE
  )
  df <- merge(df, year_map, by = "jaar", all.x = TRUE)
  df <- df[order(df$plot_id, df$jaar), ]

  list(ok = TRUE, data = df, year_map = year_map)
}

fit_trim_model <- function(df) {
  prepared <- prepare_trim_period(df)
  if (!prepared$ok) {
    return(list(model = NULL, config = NA_character_, aic = NA_real_, error = prepared$reason, warnings = NA_character_, attempts = NA_character_, year_map = NULL))
  }

  df_fit <- prepared$data[, c("plot_id", "trim_year", "count_adjusted")]
  names(df_fit) <- c("site", "year", "count")

  configs <- list(
    list(model = 3, overdisp = TRUE, serialcor = FALSE, label = "model3_overdisp"),
    list(model = 3, overdisp = TRUE, serialcor = TRUE, label = "model3_overdisp_serialcor"),
    list(model = 3, overdisp = FALSE, serialcor = FALSE, label = "model3_basis"),
    list(model = 2, overdisp = FALSE, serialcor = FALSE, label = "model2_basis")
  )

  last_error <- NULL
  last_warnings <- character()
  selected <- NULL
  attempts <- character()

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
      fit_aic <- tryCatch(stats::AIC(fit), error = function(e) NA_real_)
      attempts <- c(attempts, sprintf("%s:ok:aic=%s", cfg$label, ifelse(is.finite(fit_aic), round(fit_aic, 3), "NA")))
      if (is.null(selected)) {
        selected <- list(
          model = fit,
          config = cfg$label,
          aic = fit_aic,
          error = NA_character_,
          warnings = if (length(warning_messages)) paste(unique(warning_messages), collapse = " | ") else NA_character_,
          year_map = prepared$year_map
        )
      }
      next
    }
    last_error <- conditionMessage(fit)
    last_warnings <- warning_messages
    attempts <- c(attempts, sprintf("%s:fout:%s", cfg$label, last_error))
  }

  if (!is.null(selected)) {
    selected$attempts <- paste(attempts, collapse = " || ")
    return(selected)
  }

  list(
    model = NULL,
    config = NA_character_,
    aic = NA_real_,
    error = last_error,
    warnings = if (length(last_warnings)) paste(unique(last_warnings), collapse = " | ") else NA_character_,
    attempts = paste(attempts, collapse = " || "),
    year_map = prepared$year_map
  )
}

trim_model_overdisp <- function(model_label) {
  model_label %in% c("model3_overdisp", "model3_overdisp_serialcor")
}

trim_model_serialcor <- function(model_label) {
  identical(model_label, "model3_overdisp_serialcor")
}

trim_model_fallback_reason <- function(model_label) {
  if (is.na(model_label) || !nzchar(model_label)) {
    return("geen_model")
  }
  switch(
    model_label,
    model3_overdisp = "voorkeursmodel_gekozen",
    model3_overdisp_serialcor = "model3_overdisp_mislukt_fallback_naar_serialcor",
    model3_basis = "overdisp_varianten_mislukt_fallback_naar_basis",
    model2_basis = "model3_varianten_mislukt_fallback_naar_model2",
    "onbekend"
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
  out$model_overdispersion <- trim_model_overdisp(fit_obj$config)
  out$model_serial_correlation <- trim_model_serialcor(fit_obj$config)
  out$model_warnings <- fit_obj$warnings
  out$basisjaar <- min(out$jaar, na.rm = TRUE)
  out$basisjaar_toelichting <- "index_100 = eerste analysejaar vanaf eerste positieve jaar"
  out$trim_year <- NULL
  base_value <- out$trim_index[match(min(out$jaar), out$jaar)]
  out$index_100 <- ifelse(
    is.finite(out$trim_index) & is.finite(base_value) & base_value > 0,
    100 * out$trim_index / base_value,
    NA_real_
  )
  out[, c("soort_id", "euring_code", "soort_naam", "engelse_naam", "jaar", "basisjaar", "basisjaar_toelichting", "trim_index", "trim_se", "index_100", "model_config", "model_overdispersion", "model_serial_correlation", "model_warnings")]
}

classificeer_soort_status <- function(model_ok, positieve_jaren, getelde_cellen, actieve_plots) {
  if (positieve_jaren < 3L || getelde_cellen < 3L) {
    return("te_zeldzaam")
  }
  if (actieve_plots < 2L) {
    return("lokaal_incidenteel")
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
    actieve_plots <- length(unique(df$plot_id[df$geteld & is.finite(df$count_adjusted) & df$count_adjusted > 0]))
    getelde_cellen <- sum(df$geteld & is.finite(df$count_adjusted), na.rm = TRUE)
    n_jaren_geteld <- length(unique(df$jaar[df$geteld & is.finite(df$count_adjusted)]))

    fit <- if (positieve_jaren >= 3L && actieve_plots >= 2L && getelde_cellen >= 3L) {
      fit_trim_model(df)
    } else {
      list(model = NULL, config = NA_character_, aic = NA_real_, error = "te_weinig_data", warnings = NA_character_, attempts = NA_character_, year_map = NULL)
    }

    analyse_categorie <- classificeer_soort_status(!is.null(fit$model), positieve_jaren, getelde_cellen, actieve_plots)

    status_rows[[counter]] <- data.frame(
      soort_id = soort_id,
      euring_code = euring_code,
      soort_naam = soort_naam,
      engelse_naam = engelse_naam,
      n_getelde_cellen = getelde_cellen,
      n_positieve_cellen = positieve_cellen,
      n_jaren_geteld = n_jaren_geteld,
      n_positieve_jaren = positieve_jaren,
      n_actieve_plots = actieve_plots,
      model_gelukt = !is.null(fit$model),
      model = fit$config,
      model_overdispersion = trim_model_overdisp(fit$config),
      model_serial_correlation = trim_model_serialcor(fit$config),
      model_aic = fit$aic,
      model_fallback_reden = trim_model_fallback_reason(fit$config),
      fout = fit$error,
      waarschuwingen = fit$warnings,
      modelpogingen = fit$attempts,
      modelselectie_methode = "vaste_voorkeurhierarchie_eerste_werkende_model",
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
        basisjaar = min(index_df$jaar, na.rm = TRUE),
        basisjaar_toelichting = "index_100 = eerste analysejaar vanaf eerste positieve jaar",
        eerste_jaar = min(index_df$jaar, na.rm = TRUE),
        laatste_jaar = max(index_df$jaar, na.rm = TRUE),
        n_jaren_index = nrow(index_df),
        trend_pct_per_jaar = pct,
        trend_p = tr$p,
        trend_r2 = tr$r2,
        trend_uitleg = duid_trend(pct, tr$p),
        trendduiding_type = "eigen_trendduiding_op_basis_van_trim_index",
        model = fit$config,
        model_fallback_reden = trim_model_fallback_reason(fit$config),
        model_fallback_gebruikt = !identical(trim_model_fallback_reason(fit$config), "voorkeursmodel_gekozen"),
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

richtlijn_keuzes <- function() {
  c("RL: Verdwenen", "RL: Ernstig bedreigd", "RL: Bedreigd", "RL: Kwetsbaar", "RL: Gevoelig", "Oranje Lijst")
}

richtlijn_verzamelcategorieen <- function() {
  data.frame(
    richtlijn_id = c(1001L, 1002L),
    richtlijn_titel = c("Rode Lijst Totaal", "Rode & Oranjelijst"),
    richtlijn_volgorde = c(7L, 8L),
    stringsAsFactors = FALSE
  )
}

build_richtlijn_mapping <- function(tbls) {
  richtlijnen <- tbls$richtlijnen[tbls$richtlijnen$naam %in% richtlijn_keuzes(), , drop = FALSE]
  richtlijnen$richtlijn_volgorde <- match(richtlijnen$naam, richtlijn_keuzes())
  mapping <- merge(
    tbls$soort_richtlijn,
    richtlijnen,
    by.x = "richtlijn_id",
    by.y = "id",
    all = FALSE
  )
  mapping <- unique(data.frame(
    soort_id = mapping$soort_id,
    richtlijn_id = mapping$richtlijn_id,
    richtlijn_titel = mapping$naam,
    richtlijn_volgorde = mapping$richtlijn_volgorde,
    stringsAsFactors = FALSE
  ))
  verzamel <- richtlijn_verzamelcategorieen()
  rode_lijst_soorten <- unique(mapping$soort_id[mapping$richtlijn_titel %in% richtlijn_keuzes()[1:5]])
  rode_oranje_soorten <- unique(mapping$soort_id[mapping$richtlijn_titel %in% richtlijn_keuzes()])
  extra_mapping <- rbind(
    data.frame(
      soort_id = rode_lijst_soorten,
      richtlijn_id = verzamel$richtlijn_id[verzamel$richtlijn_titel == "Rode Lijst Totaal"],
      richtlijn_titel = "Rode Lijst Totaal",
      richtlijn_volgorde = verzamel$richtlijn_volgorde[verzamel$richtlijn_titel == "Rode Lijst Totaal"],
      stringsAsFactors = FALSE
    ),
    data.frame(
      soort_id = rode_oranje_soorten,
      richtlijn_id = verzamel$richtlijn_id[verzamel$richtlijn_titel == "Rode & Oranjelijst"],
      richtlijn_titel = "Rode & Oranjelijst",
      richtlijn_volgorde = verzamel$richtlijn_volgorde[verzamel$richtlijn_titel == "Rode & Oranjelijst"],
      stringsAsFactors = FALSE
    )
  )
  mapping <- unique(rbind(mapping, extra_mapping))
  mapping[order(mapping$richtlijn_volgorde, mapping$soort_id), , drop = FALSE]
}

analyse_groups_subset <- function(species_indices, group_mapping, msi_variant = "volledig") {
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
  msi$msi_variant <- msi_variant
  msi <- msi[order(msi$groep_100, msi$jaar), ]

  trend_rows <- lapply(split(msi, msi$groep_100), function(df) {
    tr <- run_lm_trend(df, "msi")
    pct <- calc_pct_trend(tr$slope)
    min_n_soorten <- min(df$n_soorten, na.rm = TRUE)
    max_n_soorten <- max(df$n_soorten, na.rm = TRUE)
    cv_n_soorten <- stats::sd(df$n_soorten, na.rm = TRUE) / mean(df$n_soorten, na.rm = TRUE)
    samenstelling_waarschuwing <- ifelse(
      is.finite(min_n_soorten) && is.finite(max_n_soorten) && max_n_soorten > 0 && min_n_soorten / max_n_soorten < 0.75,
      "wisselend_soortenaantal",
      "stabiel_soortenaantal"
    )
    data.frame(
      groep_100 = df$groep_100[[1]],
      groep_titel = df$groep_titel[[1]],
      msi_variant = msi_variant,
      basisjaar = min(df$jaar, na.rm = TRUE),
      basisjaar_toelichting = "MSI = 100 in het eerste analysejaar met geldige groepsindex",
      eerste_jaar = min(df$jaar, na.rm = TRUE),
      laatste_jaar = max(df$jaar, na.rm = TRUE),
      gemiddeld_n_soorten = mean(df$n_soorten, na.rm = TRUE),
      min_n_soorten = min_n_soorten,
      max_n_soorten = max_n_soorten,
      cv_n_soorten = cv_n_soorten,
      samenstelling_waarschuwing = samenstelling_waarschuwing,
      trend_pct_per_jaar = pct,
      trend_p = tr$p,
      trend_r2 = tr$r2,
      trend_uitleg = duid_trend(pct, tr$p),
      trendduiding_type = "eigen_trendduiding_op_basis_van_trim_index",
      stringsAsFactors = FALSE
    )
  })

  composition <- unique(merged[, c("groep_100", "groep_titel", "soort_id", "euring_code", "soort_naam", "engelse_naam")])
  composition$msi_variant <- msi_variant
  composition <- composition[order(composition$groep_100, composition$soort_naam), ]

  list(
    msi = msi,
    trends = do.call(rbind, trend_rows),
    composition = composition
  )
}

analyse_richtlijnen_subset <- function(species_indices, richtlijn_mapping, msi_variant = "volledig") {
  empty_msi <- data.frame(
    richtlijn_id = integer(),
    richtlijn_titel = character(),
    richtlijn_volgorde = integer(),
    jaar = integer(),
    log_index = numeric(),
    n_soorten = integer(),
    msi = numeric(),
    stringsAsFactors = FALSE
  )
  empty_trends <- data.frame(
    richtlijn_id = integer(),
    richtlijn_titel = character(),
    richtlijn_volgorde = integer(),
    eerste_jaar = integer(),
    laatste_jaar = integer(),
    gemiddeld_n_soorten = numeric(),
    trend_pct_per_jaar = numeric(),
    trend_p = numeric(),
    trend_r2 = numeric(),
    trend_uitleg = character(),
    stringsAsFactors = FALSE
  )
  empty_comp <- data.frame(
    richtlijn_id = integer(),
    richtlijn_titel = character(),
    richtlijn_volgorde = integer(),
    soort_id = integer(),
    euring_code = integer(),
    soort_naam = character(),
    engelse_naam = character(),
    stringsAsFactors = FALSE
  )

  merged <- merge(
    species_indices[, c("soort_id", "euring_code", "soort_naam", "engelse_naam", "jaar", "index_100")],
    richtlijn_mapping,
    by = "soort_id",
    all = FALSE
  )

  merged <- merged[is.finite(merged$index_100) & merged$index_100 > 0, ]
  if (!nrow(merged)) {
    return(list(msi = empty_msi, trends = empty_trends, composition = empty_comp))
  }

  merged$log_index <- log(merged$index_100)
  msi <- aggregate(log_index ~ richtlijn_id + richtlijn_titel + richtlijn_volgorde + jaar, data = merged, FUN = mean)
  n_species <- aggregate(soort_id ~ richtlijn_id + jaar, data = merged, FUN = function(x) length(unique(x)))
  names(n_species)[3] <- "n_soorten"
  msi <- merge(msi, n_species, by = c("richtlijn_id", "jaar"), all.x = TRUE)
  msi$msi <- exp(msi$log_index)
  msi$msi_variant <- msi_variant
  msi <- msi[order(msi$richtlijn_volgorde, msi$jaar), ]

  trend_rows <- lapply(split(msi, msi$richtlijn_id), function(df) {
    tr <- run_lm_trend(df, "msi")
    pct <- calc_pct_trend(tr$slope)
    data.frame(
      richtlijn_id = df$richtlijn_id[[1]],
      richtlijn_titel = df$richtlijn_titel[[1]],
      richtlijn_volgorde = df$richtlijn_volgorde[[1]],
      msi_variant = msi_variant,
      basisjaar = min(df$jaar, na.rm = TRUE),
      basisjaar_toelichting = "MSI = 100 in het eerste analysejaar met geldige richtlijnindex",
      eerste_jaar = min(df$jaar, na.rm = TRUE),
      laatste_jaar = max(df$jaar, na.rm = TRUE),
      gemiddeld_n_soorten = mean(df$n_soorten, na.rm = TRUE),
      trend_pct_per_jaar = pct,
      trend_p = tr$p,
      trend_r2 = tr$r2,
      trend_uitleg = duid_trend(pct, tr$p),
      trendduiding_type = "eigen_trendduiding_op_basis_van_trim_index",
      stringsAsFactors = FALSE
    )
  })

  composition <- unique(merged[, c("richtlijn_id", "richtlijn_titel", "richtlijn_volgorde", "soort_id", "euring_code", "soort_naam", "engelse_naam")])
  composition$msi_variant <- msi_variant
  composition <- composition[order(composition$richtlijn_volgorde, composition$soort_naam), ]

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
  full_group_results <- analyse_groups_subset(species_results$indices, group_mapping, msi_variant = "volledig")
  min_robuuste_jaren <- max(10L, ceiling(0.75 * length(unique(basis$jaar))))
  robust_ids <- species_results$status$soort_id[
    species_results$status$analyse_categorie == "trim_bruikbaar" &
      species_results$status$n_jaren_geteld >= min_robuuste_jaren &
      species_results$status$n_actieve_plots >= 2L
  ]
  robust_indices <- species_results$indices[species_results$indices$soort_id %in% robust_ids, , drop = FALSE]
  robust_group_results <- analyse_groups_subset(robust_indices, group_mapping, msi_variant = "robuust")
  group_results <- list(
    msi = rbind(full_group_results$msi, robust_group_results$msi),
    trends = rbind(full_group_results$trends, robust_group_results$trends),
    composition = rbind(full_group_results$composition, robust_group_results$composition)
  )
  richtlijn_mapping <- build_richtlijn_mapping(tbls)
  full_richtlijn_results <- analyse_richtlijnen_subset(species_results$indices, richtlijn_mapping, msi_variant = "volledig")
  robust_richtlijn_results <- analyse_richtlijnen_subset(robust_indices, richtlijn_mapping, msi_variant = "robuust")
  richtlijn_results <- list(
    msi = rbind(full_richtlijn_results$msi, robust_richtlijn_results$msi),
    trends = rbind(full_richtlijn_results$trends, robust_richtlijn_results$trends),
    composition = rbind(full_richtlijn_results$composition, robust_richtlijn_results$composition)
  )

  list(
    basis = basis,
    selection = selection_df,
    species_matrix = species_matrix,
    species_results = species_results,
    group_results = group_results,
    richtlijn_results = richtlijn_results
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

find_richtlijn_by_id <- function(tbls, richtlijn_id) {
  mapping <- build_richtlijn_mapping(tbls)
  row <- unique(mapping[mapping$richtlijn_id == as.integer(richtlijn_id), c("richtlijn_id", "richtlijn_titel", "richtlijn_volgorde"), drop = FALSE])
  if (nrow(row) == 1L) {
    return(row)
  }
  stop(sprintf("Richtlijncategorie niet gevonden: %s", richtlijn_id))
}

select_species_for_target <- function(tbls, target_type, target_value) {
  if (identical(target_type, "species")) {
    return(find_species_by_name(tbls, target_value)$id)
  }
  if (identical(target_type, "group")) {
    group_row <- find_group_by_code(tbls, target_value)
    group_mapping <- build_group_mapping(tbls)
    return(unique(group_mapping$soort_id[group_mapping$groep_100 == group_row$groep_100[[1]]]))
  }
  if (identical(target_type, "richtlijn")) {
    richtlijn_row <- find_richtlijn_by_id(tbls, target_value)
    richtlijn_mapping <- build_richtlijn_mapping(tbls)
    return(unique(richtlijn_mapping$soort_id[richtlijn_mapping$richtlijn_id == richtlijn_row$richtlijn_id[[1]]]))
  }
  unique(tbls$soorten$id)
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

build_gee_dataset <- function(tbls, selected_kavels, year_from, year_to, target_type = c("species", "group", "richtlijn"), target_value) {
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
  } else if (target_type == "group") {
    species_row <- NULL
    group_row <- find_group_by_code(tbls, target_value)
    richtlijn_row <- NULL
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
  } else {
    species_row <- NULL
    group_row <- NULL
    richtlijn_row <- find_richtlijn_by_id(tbls, target_value)
    richtlijn_mapping <- build_richtlijn_mapping(tbls)
    richtlijn_species <- unique(richtlijn_mapping$soort_id[richtlijn_mapping$richtlijn_id == richtlijn_row$richtlijn_id[[1]]])
    counts <- tbls$territoria[
      tbls$territoria$soort_id %in% richtlijn_species &
        tbls$territoria$jaar >= year_from &
        tbls$territoria$jaar <= year_to,
      c("plot_id", "jaar", "territoria")
    ]
    target_label <- richtlijn_row$richtlijn_titel[[1]]
    target_slug <- paste0("richtlijn_", richtlijn_row$richtlijn_id[[1]], "_", tolower(gsub("[^a-z0-9]+", "_", target_label)))
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
  dat$territoria_per_km2 <- ifelse(
    dat$geteld &
      is.finite(dat$count) &
      is.finite(dat$oppervlakte_km2) &
      dat$oppervlakte_km2 > 0,
    dat$count / dat$oppervlakte_km2,
    NA_real_
  )
  dat <- add_territory_observation_status(dat, "count")
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

  dat$analyse_niveau <- switch(target_type, species = "Soort", group = "Vogelgroep", richtlijn = "Rode/Oranje Lijst")
  dat$doel_label <- target_label
  dat$doel_slug <- target_slug
  dat$richtlijn_id <- NA_integer_
  dat$richtlijn_titel <- NA_character_
  if (target_type == "species") {
    dat$soort_id <- species_row$id[[1]]
    dat$soort_naam <- species_row$soort_naam[[1]]
    dat$engelse_naam <- species_row$engelse_naam[[1]]
    dat$groep_100 <- NA_integer_
    dat$groep_titel <- NA_character_
  } else if (target_type == "group") {
    dat$soort_id <- NA_integer_
    dat$soort_naam <- NA_character_
    dat$engelse_naam <- NA_character_
    dat$groep_100 <- as.integer(target_value)
    dat$groep_titel <- target_label
  } else {
    dat$soort_id <- NA_integer_
    dat$soort_naam <- NA_character_
    dat$engelse_naam <- NA_character_
    dat$groep_100 <- NA_integer_
    dat$groep_titel <- NA_character_
    dat$richtlijn_id <- as.integer(target_value)
    dat$richtlijn_titel <- target_label
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

calculate_design_vif <- function(mm, term_labels = NULL) {
  if (is.null(mm) || !ncol(mm)) {
    return(data.frame(term = character(), modelkolom = character(), vif = numeric(), stringsAsFactors = FALSE))
  }
  assign_idx <- attr(mm, "assign")
  if (is.null(term_labels)) {
    term_labels <- paste0("term_", seq_len(max(assign_idx, na.rm = TRUE)))
  }
  keep_cols <- colnames(mm) != "(Intercept)"
  x <- mm[, keep_cols, drop = FALSE]
  assign_idx <- assign_idx[keep_cols]
  if (!ncol(x)) {
    return(data.frame(term = character(), modelkolom = character(), vif = numeric(), stringsAsFactors = FALSE))
  }
  if (ncol(x) == 1L) {
    term <- if (assign_idx[[1]] > 0L) term_labels[assign_idx[[1]]] else colnames(x)[[1]]
    return(data.frame(term = term, modelkolom = colnames(x), vif = 1, stringsAsFactors = FALSE))
  }
  out <- lapply(seq_len(ncol(x)), function(j) {
    y <- x[, j]
    others <- x[, -j, drop = FALSE]
    if (length(unique(y[is.finite(y)])) < 2L) {
      vif <- NA_real_
    } else {
      fit <- tryCatch(stats::lm.fit(cbind(1, others), y), error = function(e) NULL)
      if (is.null(fit)) {
        vif <- NA_real_
      } else {
        rss <- sum(fit$residuals^2, na.rm = TRUE)
        tss <- sum((y - mean(y, na.rm = TRUE))^2, na.rm = TRUE)
        r2 <- if (is.finite(tss) && tss > 0) 1 - rss / tss else NA_real_
        vif <- if (is.finite(r2) && r2 < 1) 1 / (1 - r2) else Inf
      }
    }
    term <- if (assign_idx[[j]] > 0L) term_labels[assign_idx[[j]]] else colnames(x)[[j]]
    data.frame(term = term, modelkolom = colnames(x)[[j]], vif = vif, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, out)
  out$beoordeling <- ifelse(
    is.na(out$vif), "niet_berekenbaar",
    ifelse(out$vif >= 10, "hoog",
      ifelse(out$vif >= 5, "matig", "laag")
    )
  )
  out[order(out$vif, decreasing = TRUE, na.last = TRUE), , drop = FALSE]
}

gee_effect_unit_specs <- function() {
  data.frame(
    term = c(
      "year_c",
      "stikstof_mean",
      "ahn_mean",
      "ahn_sd",
      "afstand_pad_m",
      "padlengte_m_per_ha",
      "afstand_parkeerplaats_m",
      "afstand_hoofdtoegang_m"
    ),
    effect_schaal = c(10, 100, 1, 1, 100, 100, 100, 100),
    effect_eenheid = c(
      "per 10 jaar",
      "per 100 mol N/ha/jaar",
      "per 1 m",
      "per 1 m",
      "per 100 m",
      "per 100 m/ha",
      "per 100 m",
      "per 100 m"
    ),
    stringsAsFactors = FALSE
  )
}

gee_effect_scale_for_term <- function(term) {
  if (grepl("^habitat_[0-9]+$", term)) {
    return(list(scale = 10, unit = "per 10 procentpunt"))
  }
  specs <- gee_effect_unit_specs()
  hit <- specs[specs$term == term, , drop = FALSE]
  if (nrow(hit)) {
    return(list(scale = hit$effect_schaal[[1]], unit = hit$effect_eenheid[[1]]))
  }
  list(scale = 1, unit = "factorcontrast / per eenheid")
}

annotate_gee_effect_units <- function(coef_tab) {
  if (!nrow(coef_tab)) {
    coef_tab$effect_schaal <- numeric()
    coef_tab$effect_eenheid <- character()
    coef_tab$estimate_effect <- numeric()
    coef_tab$std.error_effect <- numeric()
    return(coef_tab)
  }
  scales <- lapply(coef_tab$term, gee_effect_scale_for_term)
  coef_tab$effect_schaal <- vapply(scales, `[[`, numeric(1), "scale")
  coef_tab$effect_eenheid <- vapply(scales, `[[`, character(1), "unit")
  coef_tab$estimate_effect <- coef_tab$estimate * coef_tab$effect_schaal
  coef_tab$std.error_effect <- coef_tab$std.error * coef_tab$effect_schaal
  coef_tab$irr <- exp(coef_tab$estimate_effect)
  coef_tab$irr_low <- exp(coef_tab$estimate_effect - 1.96 * coef_tab$std.error_effect)
  coef_tab$irr_high <- exp(coef_tab$estimate_effect + 1.96 * coef_tab$std.error_effect)
  coef_tab
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

run_gee_subset <- function(tbls, selected_kavels, year_from, year_to, target_type = c("species", "group", "richtlijn"), target_value, covariates, ahn_covariates = character(), infra_covariates = character(), habitat_covariates = character(), gee_corstr = "exchangeable") {
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
  vif_tab <- calculate_design_vif(pre_mm, chosen)
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
  coef_tab <- annotate_gee_effect_units(coef_tab)

  disp <- count_overdispersion_diagnostic(dat_model$count)
  summary_df <- data.frame(
    analyse_niveau = unique(dat_model$analyse_niveau)[1],
    doel_label = unique(dat_model$doel_label)[1],
    doel_slug = unique(dat_model$doel_slug)[1],
    gee_corstr = gee_corstr,
    covariaten = paste(chosen, collapse = ", "),
    covariaten_vervallen = paste(design$dropped, collapse = ", "),
    effect_eenheden = paste(unique(paste(coef_tab$term, coef_tab$effect_eenheid, sep = " = ")), collapse = "; "),
    n_plots = length(unique(dat_model$plot_id)),
    n_plot_jaren = nrow(dat_model),
    eerste_jaar = min(dat_model$jaar, na.rm = TRUE),
    laatste_jaar = max(dat_model$jaar, na.rm = TRUE),
    totaal_territoria = sum(dat_model$count, na.rm = TRUE),
    totaal_territoria_per_km2 = sum(dat_model$territoria_per_km2, na.rm = TRUE),
    gemiddelde = disp$count_mean,
    variantie = disp$count_variance,
    variantie_gemiddelde = disp$variance_mean_ratio,
    overdispersie = disp$overdispersion_interpretatie,
    overdispersie_advies = disp$overdispersion_advies,
    respons = "territoria_per_km2_via_poisson_offset_op_oppervlakte",
    stringsAsFactors = FALSE
  )

  list(
    dataset = dat,
    model_data = dat_model,
    coefficients = coef_tab,
    summary = summary_df,
    fit = gee_fit,
    vif = vif_tab,
    covariates = chosen
  )
}

run_gee_screening_subset <- function(tbls, selected_kavels, year_from, year_to, species_name, gee_corstr = "exchangeable") {
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
  all_specs <- rbind(
    cov_specs,
    ahn_specs,
    infra_specs,
    data.frame(code = habitat_specs$code, label = habitat_specs$label, type = "numeric", stringsAsFactors = FALSE)
  )
  all_specs <- all_specs[!duplicated(all_specs$code), , drop = FALSE]
  all_covariates <- all_specs$code

  dat <- build_gee_dataset(tbls, selected_kavels, year_from, year_to, target_type = "species", target_value = species_name)
  dat <- add_habitat_covariates(dat, tbls, habitat_specs$code)
  dat_base <- dat[!is.na(dat$count) & is.finite(dat$log_area), , drop = FALSE]
  if (nrow(dat_base) < 20L) {
    stop("Te weinig bruikbare plot-jaren voor een stabiele G.E.E.-screening.")
  }
  if (length(unique(dat_base$jaar)) < 3L) {
    stop("Te weinig unieke jaren voor een G.E.E.-screening.")
  }
  if (length(unique(dat_base$plot_id)) < 2L) {
    stop("Te weinig unieke plots voor een G.E.E.-screening.")
  }
  if (sum(dat_base$count, na.rm = TRUE) <= 0) {
    stop("Geen territoria voor deze soort in deze selectie.")
  }

  rows <- list()
  used <- 0L
  for (covar in all_covariates) {
    spec <- all_specs[all_specs$code == covar, , drop = FALSE][1, , drop = FALSE]
    dat_model <- dat_base
    if (identical(spec$type[[1]], "numeric")) {
      dat_model <- dat_model[is.finite(dat_model[[covar]]), , drop = FALSE]
    } else {
      dat_model <- dat_model[!is.na(dat_model[[covar]]) & nzchar(as.character(dat_model[[covar]])), , drop = FALSE]
      dat_model[[covar]] <- droplevels(factor(dat_model[[covar]]))
    }
    if (nrow(dat_model) < 20L || length(unique(dat_model$jaar)) < 3L || length(unique(dat_model$plot_id)) < 2L || sum(dat_model$count, na.rm = TRUE) <= 0) {
      next
    }
    design <- tryCatch(sanitize_gee_design(dat_model, covar), error = function(e) e)
    if (inherits(design, "error")) {
      next
    }
    dat_model <- design$data
    dat_model <- dat_model[order(dat_model$plot_id, dat_model$jaar), , drop = FALSE]
    precheck <- tryCatch(precheck_gee_complexity(dat_model, gee_corstr), error = function(e) e)
    if (inherits(precheck, "error")) {
      next
    }
    formula_txt <- sprintf("count ~ %s + offset(log_area)", covar)
    fit <- tryCatch({
      setTimeLimit(elapsed = 10, transient = TRUE)
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
    if (inherits(fit, "error")) {
      next
    }
    coef_tab <- broom::tidy(fit)
    coef_tab <- coef_tab[coef_tab$term != "(Intercept)", , drop = FALSE]
    if (!nrow(coef_tab)) {
      next
    }
    coef_tab <- annotate_gee_effect_units(coef_tab)
    coef_tab$variabele_code <- covar
    coef_tab$variabele_label <- spec$label[[1]]
    coef_tab$n_plot_jaren <- nrow(dat_model)
    coef_tab$n_plots <- length(unique(dat_model$plot_id))
    used <- used + 1L
    rows[[used]] <- coef_tab
  }
  if (!used) {
    stop("Geen G.E.E.-screeningmodellen konden stabiel worden geschat.")
  }
  coef_tab <- do.call(rbind, rows)
  coef_tab <- coef_tab[order(coef_tab$p.value), , drop = FALSE]

  disp <- count_overdispersion_diagnostic(dat_base$count)
  summary_df <- data.frame(
    analyse_niveau = "GEE screening per soort",
    doel_label = unique(dat_base$doel_label)[1],
    doel_slug = unique(dat_base$doel_slug)[1],
    gee_corstr = gee_corstr,
    covariaten = paste(all_covariates, collapse = ", "),
    covariaten_vervallen = "",
    effect_eenheden = paste(unique(paste(coef_tab$term, coef_tab$effect_eenheid, sep = " = ")), collapse = "; "),
    n_plots = length(unique(dat_base$plot_id)),
    n_plot_jaren = nrow(dat_base),
    eerste_jaar = min(dat_base$jaar, na.rm = TRUE),
    laatste_jaar = max(dat_base$jaar, na.rm = TRUE),
    totaal_territoria = sum(dat_base$count, na.rm = TRUE),
    totaal_territoria_per_km2 = sum(dat_base$territoria_per_km2, na.rm = TRUE),
    gemiddelde = disp$count_mean,
    variantie = disp$count_variance,
    variantie_gemiddelde = disp$variance_mean_ratio,
    overdispersie = disp$overdispersion_interpretatie,
    overdispersie_advies = disp$overdispersion_advies,
    respons = "territoria_per_km2_via_poisson_offset_op_oppervlakte",
    n_variabelen_getoetst = length(unique(coef_tab$variabele_code)),
    stringsAsFactors = FALSE
  )

  list(
    dataset = dat,
    model_data = dat_base,
    coefficients = coef_tab,
    summary = summary_df,
    fit = NULL,
    vif = data.frame(),
    covariates = all_covariates,
    analysis_type = "gee_screening"
  )
}

glmm_random_effect_formula <- function(random_effects = c("plot_intercept", "plot_year_intercept", "year_slope_plot")) {
  random_effects <- match.arg(random_effects)
  switch(
    random_effects,
    plot_intercept = "(1 | plot_id_factor)",
    plot_year_intercept = "(1 | plot_id_factor) + (1 | jaar_factor)",
    year_slope_plot = "(year_c | plot_id_factor)"
  )
}

glmm_random_effect_label <- function(random_effects = c("plot_intercept", "plot_year_intercept", "year_slope_plot")) {
  random_effects <- match.arg(random_effects)
  switch(
    random_effects,
    plot_intercept = "(1 | plot)",
    plot_year_intercept = "(1 | plot) + (1 | jaar)",
    year_slope_plot = "(year_c | plot)"
  )
}

glmm_varcorr_table <- function(fit) {
  out <- tryCatch({
    vc_fun <- get("VarCorr.glmmTMB", envir = asNamespace("glmmTMB"))
    vc <- vc_fun(fit)
    cond <- vc$cond
    if (is.null(cond) || !length(cond)) {
      return(data.frame())
    }
    rows <- list()
    for (grp in names(cond)) {
      mat <- as.matrix(cond[[grp]])
      vars <- diag(mat)
      sds <- attr(cond[[grp]], "stddev")
      for (nm in names(vars)) {
        rows[[length(rows) + 1L]] <- data.frame(
          component = "cond",
          grp = grp,
          var1 = nm,
          var2 = NA_character_,
          variance = unname(vars[[nm]]),
          sd = if (!is.null(sds) && nm %in% names(sds)) unname(sds[[nm]]) else sqrt(unname(vars[[nm]])),
          stringsAsFactors = FALSE
        )
      }
      cor_mat <- attr(cond[[grp]], "correlation")
      if (!is.null(cor_mat) && nrow(cor_mat) > 1L) {
        for (i in seq_len(nrow(cor_mat) - 1L)) {
          for (j in (i + 1L):ncol(cor_mat)) {
            rows[[length(rows) + 1L]] <- data.frame(
              component = "cond",
              grp = grp,
              var1 = rownames(cor_mat)[[i]],
              var2 = colnames(cor_mat)[[j]],
              variance = NA_real_,
              sd = unname(cor_mat[i, j]),
              stringsAsFactors = FALSE
            )
          }
        }
      }
    }
    do.call(rbind, rows)
  }, error = function(e) {
    data.frame(melding = paste("Random-effect variantie niet berekend:", conditionMessage(e)), stringsAsFactors = FALSE)
  })
  rownames(out) <- NULL
  out
}

glmm_random_variance_sum <- function(varcorr) {
  if (!nrow(varcorr) || !"variance" %in% names(varcorr)) {
    return(NA_real_)
  }
  if ("var2" %in% names(varcorr)) {
    varcorr <- varcorr[is.na(varcorr$var2) | !nzchar(as.character(varcorr$var2)), , drop = FALSE]
  }
  vals <- suppressWarnings(as.numeric(varcorr$variance))
  sum(vals[is.finite(vals) & vals >= 0], na.rm = TRUE)
}

glmm_r2_icc_table <- function(fit, dat_model, varcorr, glmm_family) {
  fixed_eta <- tryCatch(as.numeric(stats::predict(fit, type = "link", re.form = NA)), error = function(e) rep(NA_real_, nrow(dat_model)))
  mu <- tryCatch(as.numeric(stats::predict(fit, type = "response", re.form = NA)), error = function(e) rep(NA_real_, nrow(dat_model)))
  fixed_var <- stats::var(fixed_eta[is.finite(fixed_eta)], na.rm = TRUE)
  random_var <- glmm_random_variance_sum(varcorr)
  mu <- mu[is.finite(mu) & mu > 0]
  dist_var <- if (length(mu)) {
    if (identical(glmm_family, "nbinom2")) {
      theta <- tryCatch(as.numeric(stats::sigma(fit)), error = function(e) NA_real_)
      if (is.finite(theta) && theta > 0) {
        mean(log(1 + 1 / mu + 1 / theta), na.rm = TRUE)
      } else {
        NA_real_
      }
    } else {
      mean(log(1 + 1 / mu), na.rm = TRUE)
    }
  } else {
    NA_real_
  }
  denom <- fixed_var + random_var + dist_var
  marginal <- if (is.finite(denom) && denom > 0) fixed_var / denom else NA_real_
  conditional <- if (is.finite(denom) && denom > 0) (fixed_var + random_var) / denom else NA_real_
  icc <- if (is.finite(random_var + dist_var) && (random_var + dist_var) > 0) random_var / (random_var + dist_var) else NA_real_
  data.frame(
    type = "modelmaat",
    Maat = c("ICC benadering", "Marginal R2 benadering", "Conditional R2 benadering", "Vaste-effect variantie", "Random-effect variantie", "Distributievariantie"),
    Waarde = c(icc, marginal, conditional, fixed_var, random_var, dist_var),
    Uitleg = c(
      "Aandeel niet-verklaarde variantie dat aan random effects is toe te schrijven.",
      "Variantie verklaard door vaste effecten.",
      "Variantie verklaard door vaste plus random effects.",
      "Variantie van de vaste lineaire voorspeller.",
      "Som van random-effect varianties; bij random slopes is dit een globale benadering.",
      "Benadering voor telmodel met log-link."
    ),
    stringsAsFactors = FALSE
  )
}

glmm_warning_table <- function(dat_model, vif_tab, varcorr, glmm_fit, fit_warnings, random_effects) {
  rows <- list()
  add <- function(type, waarschuwing, advies) {
    rows[[length(rows) + 1L]] <<- data.frame(type = type, Maat = "Waarschuwing", Waarde = NA_real_, waarschuwing = waarschuwing, advies = advies, stringsAsFactors = FALSE)
  }
  if (nrow(dat_model) < 50L) {
    add("weinig_observaties", sprintf("Weinig observaties: %s modelrijen.", nrow(dat_model)), "Interpreteer effecten voorzichtig of vergroot de selectie.")
  }
  if (length(unique(dat_model$plot_id)) < 5L) {
    add("weinig_plots", sprintf("Weinig plots: %s unieke plots.", length(unique(dat_model$plot_id))), "Random effects zijn dan minder stabiel.")
  }
  if (nrow(vif_tab) && "vif" %in% names(vif_tab)) {
    high <- vif_tab[is.finite(vif_tab$vif) & vif_tab$vif >= 5, , drop = FALSE]
    if (nrow(high)) {
      add("hoge_vif", paste("Hoge VIF:", paste(unique(high$term), collapse = ", ")), "Verwijder of combineer sterk gecorreleerde covariaten.")
    }
  }
  rand_var <- glmm_random_variance_sum(varcorr)
  if (is.finite(rand_var) && rand_var < 1e-6) {
    add("singular_fit", "Random-effect variantie is bijna nul.", "Random-effect structuur is mogelijk te complex of niet informatief.")
  }
  pd_hess <- tryCatch(isTRUE(glmm_fit$sdr$pdHess), error = function(e) TRUE)
  if (!pd_hess) {
    add("convergentie", "Hessian is niet positief-definiet.", "Model is mogelijk instabiel; vereenvoudig covariaten of random effects.")
  }
  if (identical(random_effects, "year_slope_plot")) {
    n_plot <- length(unique(dat_model$plot_id))
    if (n_plot < 8L || nrow(dat_model) < 80L) {
      add("complexe_random_effects", "Random slope per plot vraagt relatief veel data.", "Gebruik bij kleine selecties liever (1 | plot).")
    }
  }
  if (length(fit_warnings)) {
    add("model_warning", paste(unique(fit_warnings), collapse = " | "), "Controleer modeldiagnostiek en overweeg een eenvoudiger model.")
  }
  if (!length(rows)) {
    return(data.frame(type = "geen", Maat = "Waarschuwing", Waarde = NA_real_, waarschuwing = "Geen automatische waarschuwingen.", advies = "Controleer de inhoudelijke aannames alsnog.", stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
}

glmm_vif_diagnostic_table <- function(vif_tab) {
  if (is.null(vif_tab) || !nrow(vif_tab) || !"vif" %in% names(vif_tab)) {
    return(data.frame())
  }
  out <- data.frame(
    type = "vif",
    Maat = paste0("VIF ", vif_tab$term),
    Waarde = round(vif_tab$vif, 4),
    Uitleg = ifelse(vif_tab$vif >= 10, "hoog: covariaten sterk gecorreleerd", ifelse(vif_tab$vif >= 5, "matig: controleer collineariteit", "laag")),
    stringsAsFactors = FALSE
  )
  out
}

run_glmm_subset <- function(tbls, selected_kavels, year_from, year_to, target_type = c("species", "group", "richtlijn"), target_value, covariates, ahn_covariates = character(), infra_covariates = character(), habitat_covariates = character(), glmm_family = c("poisson", "nbinom2"), random_effects = c("plot_intercept", "plot_year_intercept", "year_slope_plot")) {
  target_type <- match.arg(target_type)
  glmm_family <- match.arg(glmm_family)
  random_effects <- match.arg(random_effects)
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    stop("Package 'glmmTMB' is niet beschikbaar. Installeer het eerst met install.packages('glmmTMB').")
  }

  cov_specs <- gee_covariate_specs()
  ahn_specs <- gee_ahn_covariate_specs()
  infra_specs <- gee_infra_covariate_specs()
  habitat_specs <- gee_habitat_covariate_specs(tbls)
  chosen <- unique(c("year_c", covariates, ahn_covariates, infra_covariates, habitat_covariates))
  allowed <- unique(c(cov_specs$code, ahn_specs$code, infra_specs$code, habitat_specs$code))
  chosen <- chosen[chosen %in% allowed]
  if (!length(chosen)) {
    stop("Kies minstens één GLMM-covariaat.")
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
    stop("Te weinig bruikbare plot-jaren voor een stabiele GLMM-analyse.")
  }
  if (length(unique(dat_model$jaar)) < 3L) {
    stop("Te weinig unieke jaren voor een GLMM-analyse.")
  }
  if (length(unique(dat_model$plot_id)) < 2L) {
    stop("Te weinig unieke plots voor een GLMM-analyse.")
  }
  if (sum(dat_model$count, na.rm = TRUE) <= 0) {
    stop("Geen territoria voor deze selectie.")
  }
  if (nrow(dat_model) > 5000L) {
    stop("Deze GLMM-selectie is te groot voor interactief gebruik. Verklein jaren, kavels of doelcategorie.")
  }

  design <- sanitize_gee_design(dat_model, chosen)
  dat_model <- droplevels(design$data)
  chosen <- design$chosen
  dat_model$plot_id_factor <- factor(dat_model$plot_id)
  dat_model$jaar_factor <- factor(dat_model$jaar)
  pre_mm <- stats::model.matrix(stats::reformulate(chosen), data = dat_model)
  pre_qr <- qr(pre_mm)
  if (pre_qr$rank < ncol(pre_mm)) {
    stop("De overblijvende covariaten zijn lineair afhankelijk. Kies minder habitattypen of minder covariaten tegelijk.")
  }
  vif_tab <- calculate_design_vif(pre_mm, chosen)

  random_txt <- glmm_random_effect_formula(random_effects)
  formula_txt <- sprintf("count ~ %s + offset(log_area) + %s", paste(chosen, collapse = " + "), random_txt)
  family_obj <- if (glmm_family == "nbinom2") glmmTMB::nbinom2(link = "log") else stats::poisson(link = "log")
  fit_warnings <- character()
  glmm_fit <- tryCatch({
    setTimeLimit(elapsed = 30, transient = TRUE)
    on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
    withCallingHandlers(
      glmmTMB::glmmTMB(
        formula = stats::as.formula(formula_txt),
        family = family_obj,
        data = dat_model,
        control = glmmTMB::glmmTMBControl(optCtrl = list(iter.max = 500, eval.max = 500))
      ),
      warning = function(w) {
        fit_warnings <<- c(fit_warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
  }, error = function(e) e)

  if (inherits(glmm_fit, "error")) {
    msg <- conditionMessage(glmm_fit)
    if (grepl("elapsed time limit", msg, fixed = TRUE)) {
      stop("De GLMM-fit duurde te lang. Verklein jaren/kavels of gebruik minder covariaten.")
    }
    stop(msg)
  }

  sm <- summary(glmm_fit)
  coef_mat <- sm$coefficients$cond
  coef_tab <- as.data.frame(coef_mat, stringsAsFactors = FALSE)
  coef_tab$term <- rownames(coef_tab)
  rownames(coef_tab) <- NULL
  names(coef_tab) <- sub("^Std\\. Error$", "std.error", names(coef_tab))
  names(coef_tab) <- sub("^z value$", "statistic", names(coef_tab))
  names(coef_tab) <- sub("^Pr\\(>\\|z\\|\\)$", "p.value", names(coef_tab))
  names(coef_tab) <- sub("^Estimate$", "estimate", names(coef_tab))
  coef_tab <- coef_tab[coef_tab$term != "(Intercept)", , drop = FALSE]
  coef_tab <- coef_tab[, c("term", "estimate", "std.error", "statistic", "p.value"), drop = FALSE]
  coef_tab$irr <- exp(coef_tab$estimate)
  coef_tab$irr_low <- exp(coef_tab$estimate - 1.96 * coef_tab$std.error)
  coef_tab$irr_high <- exp(coef_tab$estimate + 1.96 * coef_tab$std.error)

  disp <- count_overdispersion_diagnostic(dat_model$count)
  varcorr <- glmm_varcorr_table(glmm_fit)
  r2_icc <- glmm_r2_icc_table(glmm_fit, dat_model, varcorr, glmm_family)
  warnings_tab <- glmm_warning_table(dat_model, vif_tab, varcorr, glmm_fit, fit_warnings, random_effects)
  summary_df <- data.frame(
    analyse_niveau = unique(dat_model$analyse_niveau)[1],
    doel_label = unique(dat_model$doel_label)[1],
    doel_slug = unique(dat_model$doel_slug)[1],
    glmm_family = glmm_family,
    random_effects = glmm_random_effect_label(random_effects),
    covariaten = paste(chosen, collapse = ", "),
    covariaten_vervallen = paste(design$dropped, collapse = ", "),
    n_plots = length(unique(dat_model$plot_id)),
    n_plot_jaren = nrow(dat_model),
    eerste_jaar = min(dat_model$jaar, na.rm = TRUE),
    laatste_jaar = max(dat_model$jaar, na.rm = TRUE),
    totaal_territoria = sum(dat_model$count, na.rm = TRUE),
    totaal_territoria_per_km2 = sum(dat_model$territoria_per_km2, na.rm = TRUE),
    gemiddelde = disp$count_mean,
    variantie = disp$count_variance,
    variantie_gemiddelde = disp$variance_mean_ratio,
    overdispersie = disp$overdispersion_interpretatie,
    overdispersie_advies = disp$overdispersion_advies,
    icc_benadering = r2_icc$Waarde[r2_icc$Maat == "ICC benadering"],
    marginal_r2_benadering = r2_icc$Waarde[r2_icc$Maat == "Marginal R2 benadering"],
    conditional_r2_benadering = r2_icc$Waarde[r2_icc$Maat == "Conditional R2 benadering"],
    model_waarschuwingen = paste(warnings_tab$waarschuwing, collapse = " | "),
    respons = "territoria_per_km2_via_poisson_offset_op_oppervlakte",
    aic = stats::AIC(glmm_fit),
    stringsAsFactors = FALSE
  )

  list(
    dataset = dat,
    model_data = dat_model,
    coefficients = coef_tab,
    summary = summary_df,
    diagnostics = rbind_fill_base(r2_icc, glmm_vif_diagnostic_table(vif_tab), warnings_tab),
    random_effects = varcorr,
    vif = vif_tab,
    warnings = warnings_tab,
    fit = glmm_fit,
    covariates = chosen
  )
}

build_soort_kenmerken_catalog <- function(tbls) {
  sk <- tbls$soorten_kenmerken
  dd <- tbls$soorten_kenmerken_datadictionary
  hc <- tbls$soorten_kenmerken_hoofdcategorien
  if (is.null(sk) || is.null(dd) || is.null(hc) || !nrow(sk) || !nrow(dd)) {
    return(data.frame())
  }

  catalog <- merge(
    unique(sk[, c("hoofdcategorie_id", "code")]),
    dd,
    by.x = "code",
    by.y = "veld",
    all.x = TRUE
  )
  catalog <- merge(
    catalog,
    hc[, c("id", "code", "beschrijving")],
    by.x = "hoofdcategorie_id",
    by.y = "id",
    all.x = TRUE,
    suffixes = c("", "_hoofdcategorie")
  )
  catalog$kenmerk_label <- ifelse(
    !is.na(catalog$betekenis_nederlands) & nzchar(catalog$betekenis_nederlands),
    catalog$betekenis_nederlands,
    ifelse(!is.na(catalog$betekenis) & nzchar(catalog$betekenis), catalog$betekenis, catalog$code)
  )
  catalog$hoofdcategorie_label <- ifelse(
    !is.na(catalog$beschrijving) & nzchar(catalog$beschrijving),
    paste0(catalog$code_hoofdcategorie, " - ", catalog$beschrijving),
    as.character(catalog$hoofdcategorie_id)
  )
  catalog$status[is.na(catalog$status)] <- "active"
  catalog$code_type[is.na(catalog$code_type)] <- "detail"
  catalog <- catalog[catalog$status == "active", , drop = FALSE]
  catalog[order(catalog$hoofdcategorie_id, catalog$code_type, catalog$kenmerk_label), , drop = FALSE]
}

select_species_for_gee_trait_scope <- function(tbls, scope_type = c("all", "group", "richtlijn"), scope_value = NULL) {
  scope_type <- match.arg(scope_type)
  if (scope_type == "group") {
    group_row <- find_group_by_code(tbls, scope_value)
    group_mapping <- build_group_mapping(tbls)
    return(unique(group_mapping$soort_id[group_mapping$groep_100 == group_row$groep_100[[1]]]))
  }
  if (scope_type == "richtlijn") {
    richtlijn_row <- find_richtlijn_by_id(tbls, scope_value)
    richtlijn_mapping <- build_richtlijn_mapping(tbls)
    return(unique(richtlijn_mapping$soort_id[richtlijn_mapping$richtlijn_id == richtlijn_row$richtlijn_id[[1]]]))
  }
  unique(tbls$soorten$id)
}

trait_scope_label <- function(tbls, scope_type, scope_value) {
  if (scope_type == "group") {
    return(find_group_by_code(tbls, scope_value)$groep_titel[[1]])
  }
  if (scope_type == "richtlijn") {
    return(find_richtlijn_by_id(tbls, scope_value)$richtlijn_titel[[1]])
  }
  "Alle soorten"
}

build_gee_trait_dataset <- function(tbls, selected_kavels, year_from, year_to, species_ids) {
  basis <- prepare_analysis_basis_subset(tbls, selected_kavels, year_from, year_to)
  if (!nrow(basis)) {
    stop("Geen geldige plot-jaar-combinaties voor deze selectie.")
  }
  species_ids <- intersect(unique(as.integer(species_ids)), unique(tbls$soorten$id))
  if (!length(species_ids)) {
    stop("Geen soorten gevonden binnen deze kenmerkenselectie.")
  }

  basis$.join_key <- 1L
  species_df <- data.frame(soort_id = species_ids, .join_key = 1L)
  dat <- merge(basis, species_df, by = ".join_key", all = TRUE)
  dat$.join_key <- NULL
  counts <- tbls$territoria[
    tbls$territoria$soort_id %in% species_ids &
      tbls$territoria$jaar >= year_from &
      tbls$territoria$jaar <= year_to,
    c("plot_id", "jaar", "soort_id", "territoria")
  ]
  if (nrow(counts)) {
    counts <- aggregate(territoria ~ plot_id + jaar + soort_id, data = counts, FUN = sum, na.rm = TRUE)
    names(counts)[names(counts) == "territoria"] <- "count"
  } else {
    counts <- data.frame(plot_id = integer(), jaar = integer(), soort_id = integer(), count = numeric())
  }

  dat <- merge(dat, counts, by = c("plot_id", "jaar", "soort_id"), all.x = TRUE)
  dat$count <- ifelse(dat$geteld & is.na(dat$count), 0, dat$count)
  dat$count <- ifelse(!dat$geteld, NA_real_, dat$count)
  dat$territoria_per_km2 <- ifelse(
    dat$geteld &
      is.finite(dat$count) &
      is.finite(dat$oppervlakte_km2) &
      dat$oppervlakte_km2 > 0,
    dat$count / dat$oppervlakte_km2,
    NA_real_
  )
  dat <- add_territory_observation_status(dat, "count")
  dat$log_area <- ifelse(is.finite(dat$oppervlakte_km2) & dat$oppervlakte_km2 > 0, log(dat$oppervlakte_km2), NA_real_)
  dat$year_c <- dat$jaar - min(dat$jaar, na.rm = TRUE)
  dat$cluster_id <- interaction(dat$plot_id, dat$soort_id, drop = TRUE)
  soort_info <- tbls$soorten[, c("id", "euring_code", "soort_naam", "engelse_naam")]
  names(soort_info)[names(soort_info) == "id"] <- "soort_id"
  dat <- merge(dat, soort_info, by = "soort_id", all.x = TRUE)
  dat[order(dat$plot_id, dat$soort_id, dat$jaar), , drop = FALSE]
}

precheck_gee_trait_complexity <- function(dat_model, gee_corstr) {
  cluster_sizes <- as.integer(table(dat_model$cluster_id))
  n_clusters <- length(cluster_sizes)
  max_cluster <- max(cluster_sizes)
  n_rows <- nrow(dat_model)
  if (gee_corstr == "unstructured") {
    stop("Correlatiestructuur 'unstructured' is te zwaar voor kenmerkenanalyse. Kies ar1, exchangeable of independence.")
  }
  if (gee_corstr == "ar1" && (max_cluster > 80L || n_rows > 150000L)) {
    stop("Correlatiestructuur 'ar1' is te zwaar voor deze kenmerkenanalyse. Kies independence of verklein de selectie.")
  }
  invisible(list(n_clusters = n_clusters, max_cluster = max_cluster, n_rows = n_rows))
}

run_gee_trait_screening <- function(tbls, selected_kavels, year_from, year_to, scope_type = c("all", "group", "richtlijn"), scope_value = NULL, hoofdcategorie_id = NULL, code_types = c("main"), min_species_per_level = 5L, gee_corstr = "independence") {
  scope_type <- match.arg(scope_type)
  min_species_per_level <- suppressWarnings(as.integer(min_species_per_level)[1])
  if (!is.finite(min_species_per_level) || min_species_per_level < 3L) {
    min_species_per_level <- 5L
  }
  if (!requireNamespace("geepack", quietly = TRUE)) {
    stop("Package 'geepack' is niet beschikbaar.")
  }
  if (!requireNamespace("broom", quietly = TRUE)) {
    stop("Package 'broom' is niet beschikbaar.")
  }

  catalog <- build_soort_kenmerken_catalog(tbls)
  if (!nrow(catalog)) {
    stop("Geen soortkenmerken beschikbaar in de geladen SQL.")
  }
  if (!is.null(hoofdcategorie_id) && nzchar(as.character(hoofdcategorie_id))) {
    catalog <- catalog[catalog$hoofdcategorie_id == as.integer(hoofdcategorie_id), , drop = FALSE]
  }
  if (length(code_types)) {
    catalog <- catalog[catalog$code_type %in% code_types, , drop = FALSE]
  }
  if (!nrow(catalog)) {
    stop("Geen actieve kenmerken beschikbaar voor deze categorie en diepgang.")
  }

  species_ids <- select_species_for_gee_trait_scope(tbls, scope_type, scope_value)
  species_ids <- intersect(species_ids, unique(tbls$soorten_kenmerken$soort_id))
  dat <- build_gee_trait_dataset(tbls, selected_kavels, year_from, year_to, species_ids)
  dat_model_base <- dat[!is.na(dat$count) & is.finite(dat$log_area), , drop = FALSE]
  if (nrow(dat_model_base) < 100L) {
    stop("Te weinig bruikbare soort-plot-jaren voor kenmerkenanalyse.")
  }
  if (length(unique(dat_model_base$jaar)) < 3L) {
    stop("Te weinig unieke jaren voor kenmerkenanalyse.")
  }
  if (length(unique(dat_model_base$soort_id)) < (2L * as.integer(min_species_per_level))) {
    stop("Te weinig soorten voor de gekozen minimale groepsgrootte.")
  }
  precheck_gee_trait_complexity(dat_model_base, gee_corstr)

  trait_map <- unique(tbls$soorten_kenmerken[tbls$soorten_kenmerken$waarde %in% c(1L, 2L, 3L), c("soort_id", "code")])
  code_list <- unique(catalog$code)
  rows <- vector("list", length(code_list))
  used <- 0L

  for (code in code_list) {
    present_species <- unique(trait_map$soort_id[trait_map$code == code])
    in_scope_species <- unique(dat_model_base$soort_id)
    n_met <- length(intersect(in_scope_species, present_species))
    n_zonder <- length(setdiff(in_scope_species, present_species))
    if (n_met < min_species_per_level || n_zonder < min_species_per_level) {
      next
    }

    dat_model <- dat_model_base
    dat_model$trait_present <- as.integer(dat_model$soort_id %in% present_species)
    fit <- tryCatch({
      setTimeLimit(elapsed = 10, transient = TRUE)
      on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
      geepack::geeglm(
        formula = count ~ year_c + trait_present + year_c:trait_present + offset(log_area),
        family = stats::poisson(link = "log"),
        id = cluster_id,
        corstr = gee_corstr,
        control = geepack::geese.control(maxit = 20, epsilon = 1e-04, trace = FALSE),
        data = dat_model
      )
    }, error = function(e) e)
    if (inherits(fit, "error")) {
      next
    }
    coef_tab <- broom::tidy(fit)
    interaction_row <- coef_tab[coef_tab$term == "year_c:trait_present", , drop = FALSE]
    if (!nrow(interaction_row)) {
      next
    }
    cat_row <- catalog[catalog$code == code, , drop = FALSE][1, , drop = FALSE]
    used <- used + 1L
    estimate <- interaction_row$estimate[[1]]
    se <- interaction_row$std.error[[1]]
    rows[[used]] <- data.frame(
      code = code,
      kenmerk = cat_row$kenmerk_label[[1]],
      hoofdcategorie = cat_row$hoofdcategorie_label[[1]],
      code_type = cat_row$code_type[[1]],
      n_soorten_met_kenmerk = n_met,
      n_soorten_zonder_kenmerk = n_zonder,
      estimate = estimate,
      std.error = se,
      statistic = interaction_row$statistic[[1]],
      p.value = interaction_row$p.value[[1]],
      irr_jaar_interactie = exp(estimate),
      irr_low = exp(estimate - 1.96 * se),
      irr_high = exp(estimate + 1.96 * se),
      pct_verschil_trend_per_jaar = (exp(estimate) - 1) * 100,
      stringsAsFactors = FALSE
    )
  }

  if (!used) {
    stop("Geen kenmerken konden stabiel worden geschat. Verlaag de minimale groepsgrootte, kies main/sub, of vergroot de selectie.")
  }
  results <- do.call(rbind, rows[seq_len(used)])
  results$p_adj_bh <- stats::p.adjust(results$p.value, method = "BH")
  results <- results[order(results$p.value), , drop = FALSE]

  disp <- count_overdispersion_diagnostic(dat_model_base$count)
  summary_df <- data.frame(
    analyse_niveau = "Soortkenmerken",
    doel_label = trait_scope_label(tbls, scope_type, scope_value),
    doel_slug = paste0("kenmerken_", scope_type),
    gee_corstr = gee_corstr,
    covariaten = "year_c + kenmerk + year_c:kenmerk",
    covariaten_vervallen = "",
    n_plots = length(unique(dat_model_base$plot_id)),
    n_plot_jaren = length(unique(paste(dat_model_base$plot_id, dat_model_base$jaar))),
    n_soort_plot_jaren = nrow(dat_model_base),
    n_soorten = length(unique(dat_model_base$soort_id)),
    eerste_jaar = min(dat_model_base$jaar, na.rm = TRUE),
    laatste_jaar = max(dat_model_base$jaar, na.rm = TRUE),
    totaal_territoria = sum(dat_model_base$count, na.rm = TRUE),
    totaal_territoria_per_km2 = sum(dat_model_base$territoria_per_km2, na.rm = TRUE),
    gemiddelde = disp$count_mean,
    variantie = disp$count_variance,
    variantie_gemiddelde = disp$variance_mean_ratio,
    overdispersie = disp$overdispersion_interpretatie,
    overdispersie_advies = disp$overdispersion_advies,
    respons = "territoria_per_km2_via_poisson_offset_op_oppervlakte",
    n_kenmerken_getoetst = nrow(results),
    stringsAsFactors = FALSE
  )

  list(
    analysis_type = "trait_screening",
    dataset = dat,
    model_data = dat_model_base,
    coefficients = results,
    summary = summary_df,
    fit = NULL,
    covariates = c("year_c", "trait_present", "year_c:trait_present")
  )
}

run_glmm_trait_screening <- function(tbls, selected_kavels, year_from, year_to, scope_type = c("all", "group", "richtlijn"), scope_value = NULL, hoofdcategorie_id = NULL, code_types = c("main"), min_species_per_level = 5L, glmm_family = c("poisson", "nbinom2")) {
  scope_type <- match.arg(scope_type)
  glmm_family <- match.arg(glmm_family)
  min_species_per_level <- suppressWarnings(as.integer(min_species_per_level)[1])
  if (!is.finite(min_species_per_level) || min_species_per_level < 3L) {
    min_species_per_level <- 5L
  }
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    stop("Package 'glmmTMB' is niet beschikbaar. Installeer het eerst met install.packages('glmmTMB').")
  }

  catalog <- build_soort_kenmerken_catalog(tbls)
  if (!nrow(catalog)) {
    stop("Geen soortkenmerken beschikbaar in de geladen SQL.")
  }
  if (!is.null(hoofdcategorie_id) && nzchar(as.character(hoofdcategorie_id))) {
    catalog <- catalog[catalog$hoofdcategorie_id == as.integer(hoofdcategorie_id), , drop = FALSE]
  }
  if (length(code_types)) {
    catalog <- catalog[catalog$code_type %in% code_types, , drop = FALSE]
  }
  if (!nrow(catalog)) {
    stop("Geen actieve kenmerken beschikbaar voor deze categorie en diepgang.")
  }

  species_ids <- select_species_for_gee_trait_scope(tbls, scope_type, scope_value)
  species_ids <- intersect(species_ids, unique(tbls$soorten_kenmerken$soort_id))
  dat <- build_gee_trait_dataset(tbls, selected_kavels, year_from, year_to, species_ids)
  dat_model_base <- dat[!is.na(dat$count) & is.finite(dat$log_area), , drop = FALSE]
  if (nrow(dat_model_base) < 100L) {
    stop("Te weinig bruikbare soort-plot-jaren voor kenmerkenanalyse.")
  }
  if (nrow(dat_model_base) > 75000L) {
    stop("Deze GLMM-kenmerkenanalyse is te groot voor interactief gebruik. Verklein jaren, kavels of soortselectie.")
  }
  if (length(unique(dat_model_base$jaar)) < 3L) {
    stop("Te weinig unieke jaren voor kenmerkenanalyse.")
  }
  if (length(unique(dat_model_base$plot_id)) < 2L) {
    stop("Te weinig unieke plots voor kenmerkenanalyse.")
  }
  if (length(unique(dat_model_base$soort_id)) < (2L * as.integer(min_species_per_level))) {
    stop("Te weinig soorten voor de gekozen minimale groepsgrootte.")
  }

  dat_model_base$plot_id_factor <- factor(dat_model_base$plot_id)
  dat_model_base$soort_id_factor <- factor(dat_model_base$soort_id)
  trait_map <- unique(tbls$soorten_kenmerken[tbls$soorten_kenmerken$waarde %in% c(1L, 2L, 3L), c("soort_id", "code")])
  code_list <- unique(catalog$code)
  rows <- vector("list", length(code_list))
  used <- 0L
  family_obj <- if (glmm_family == "nbinom2") glmmTMB::nbinom2(link = "log") else stats::poisson(link = "log")

  for (code in code_list) {
    present_species <- unique(trait_map$soort_id[trait_map$code == code])
    in_scope_species <- unique(dat_model_base$soort_id)
    n_met <- length(intersect(in_scope_species, present_species))
    n_zonder <- length(setdiff(in_scope_species, present_species))
    if (n_met < min_species_per_level || n_zonder < min_species_per_level) {
      next
    }

    dat_model <- dat_model_base
    dat_model$trait_present <- as.integer(dat_model$soort_id %in% present_species)
    fit <- tryCatch({
      setTimeLimit(elapsed = 15, transient = TRUE)
      on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
      glmmTMB::glmmTMB(
        formula = count ~ year_c + trait_present + year_c:trait_present + offset(log_area) + (1 | plot_id_factor) + (1 | soort_id_factor),
        family = family_obj,
        data = dat_model,
        control = glmmTMB::glmmTMBControl(optCtrl = list(iter.max = 300, eval.max = 300))
      )
    }, error = function(e) e)
    if (inherits(fit, "error")) {
      next
    }

    coef_mat <- summary(fit)$coefficients$cond
    if (!("year_c:trait_present" %in% rownames(coef_mat))) {
      next
    }
    interaction_row <- coef_mat["year_c:trait_present", , drop = FALSE]
    estimate <- interaction_row[1, "Estimate"]
    se <- interaction_row[1, "Std. Error"]
    if (!is.finite(estimate) || !is.finite(se)) {
      next
    }

    cat_row <- catalog[catalog$code == code, , drop = FALSE][1, , drop = FALSE]
    used <- used + 1L
    rows[[used]] <- data.frame(
      code = code,
      kenmerk = cat_row$kenmerk_label[[1]],
      hoofdcategorie = cat_row$hoofdcategorie_label[[1]],
      code_type = cat_row$code_type[[1]],
      n_soorten_met_kenmerk = n_met,
      n_soorten_zonder_kenmerk = n_zonder,
      estimate = estimate,
      std.error = se,
      statistic = interaction_row[1, "z value"],
      p.value = interaction_row[1, "Pr(>|z|)"],
      irr_jaar_interactie = exp(estimate),
      irr_low = exp(estimate - 1.96 * se),
      irr_high = exp(estimate + 1.96 * se),
      pct_verschil_trend_per_jaar = (exp(estimate) - 1) * 100,
      stringsAsFactors = FALSE
    )
  }

  if (!used) {
    stop("Geen kenmerken konden stabiel worden geschat. Verlaag de minimale groepsgrootte, kies main/sub, of vergroot de selectie.")
  }
  results <- do.call(rbind, rows[seq_len(used)])
  results$p_adj_bh <- stats::p.adjust(results$p.value, method = "BH")
  results <- results[order(results$p.value), , drop = FALSE]

  disp <- count_overdispersion_diagnostic(dat_model_base$count)
  summary_df <- data.frame(
    analyse_niveau = "Soortkenmerken",
    doel_label = trait_scope_label(tbls, scope_type, scope_value),
    doel_slug = paste0("kenmerken_", scope_type),
    glmm_family = glmm_family,
    random_effects = "(1 | plot_id) + (1 | soort_id)",
    covariaten = "year_c + kenmerk + year_c:kenmerk",
    covariaten_vervallen = "",
    n_plots = length(unique(dat_model_base$plot_id)),
    n_plot_jaren = length(unique(paste(dat_model_base$plot_id, dat_model_base$jaar))),
    n_soort_plot_jaren = nrow(dat_model_base),
    n_soorten = length(unique(dat_model_base$soort_id)),
    eerste_jaar = min(dat_model_base$jaar, na.rm = TRUE),
    laatste_jaar = max(dat_model_base$jaar, na.rm = TRUE),
    totaal_territoria = sum(dat_model_base$count, na.rm = TRUE),
    totaal_territoria_per_km2 = sum(dat_model_base$territoria_per_km2, na.rm = TRUE),
    gemiddelde = disp$count_mean,
    variantie = disp$count_variance,
    variantie_gemiddelde = disp$variance_mean_ratio,
    overdispersie = disp$overdispersion_interpretatie,
    overdispersie_advies = disp$overdispersion_advies,
    respons = "territoria_per_km2_via_poisson_offset_op_oppervlakte",
    n_kenmerken_getoetst = nrow(results),
    stringsAsFactors = FALSE
  )

  list(
    analysis_type = "trait_screening",
    dataset = dat,
    model_data = dat_model_base,
    coefficients = results,
    summary = summary_df,
    fit = NULL,
    covariates = c("year_c", "trait_present", "year_c:trait_present")
  )
}

nmds_transform_matrix <- function(comm, transform = c("hellinger", "presence_absence", "log1p", "raw")) {
  transform <- match.arg(transform)
  if (transform == "raw") {
    return(comm)
  }
  if (transform == "presence_absence") {
    comm[] <- ifelse(comm > 0, 1, 0)
    return(comm)
  }
  if (transform == "log1p") {
    return(log1p(comm))
  }
  vegan::decostand(comm, method = "hellinger")
}

select_species_for_nmds <- function(tbls, selection_type = c("all", "group", "richtlijn", "trait"), selection_value = NULL) {
  selection_type <- match.arg(selection_type)
  if (selection_type == "group") {
    group_row <- find_group_by_code(tbls, selection_value)
    group_mapping <- build_group_mapping(tbls)
    return(unique(group_mapping$soort_id[group_mapping$groep_100 == group_row$groep_100[[1]]]))
  }
  if (selection_type == "richtlijn") {
    richtlijn_row <- find_richtlijn_by_id(tbls, selection_value)
    richtlijn_mapping <- build_richtlijn_mapping(tbls)
    return(unique(richtlijn_mapping$soort_id[richtlijn_mapping$richtlijn_id == richtlijn_row$richtlijn_id[[1]]]))
  }
  if (selection_type == "trait") {
    sk <- tbls$soorten_kenmerken
    return(unique(sk$soort_id[sk$code == selection_value & sk$waarde %in% c(1L, 2L, 3L)]))
  }
  unique(tbls$soorten$id)
}

nmds_selection_label <- function(tbls, selection_type, selection_value = NULL) {
  if (selection_type == "group") {
    return(find_group_by_code(tbls, selection_value)$groep_titel[[1]])
  }
  if (selection_type == "richtlijn") {
    return(find_richtlijn_by_id(tbls, selection_value)$richtlijn_titel[[1]])
  }
  if (selection_type == "trait") {
    catalog <- build_soort_kenmerken_catalog(tbls)
    row <- catalog[catalog$code == selection_value, , drop = FALSE]
    if (nrow(row)) {
      return(paste0(row$code[[1]], " - ", row$kenmerk_label[[1]]))
    }
    return(as.character(selection_value))
  }
  "Alle soorten"
}

run_nmds_subset <- function(tbls, selected_kavels, year_from, year_to, selection_type = c("all", "group", "richtlijn", "trait"), selection_value = NULL, transform = c("hellinger", "presence_absence", "log1p", "raw"), distance = c("bray", "jaccard", "euclidean"), dimensions = c(2L, 3L), trymax = 30L) {
  selection_type <- match.arg(selection_type)
  transform <- match.arg(transform)
  distance <- match.arg(distance)
  dimensions <- as.integer(dimensions)[1]
  if (!dimensions %in% c(2L, 3L)) {
    dimensions <- 2L
  }
  trymax <- as.integer(trymax)[1]
  if (!is.finite(trymax) || trymax < 10L) {
    trymax <- 30L
  }
  if (!requireNamespace("vegan", quietly = TRUE)) {
    stop("Package 'vegan' is niet beschikbaar. Installeer het eerst met install.packages('vegan').")
  }

  basis <- prepare_analysis_basis_subset(tbls, selected_kavels, year_from, year_to)
  if (!nrow(basis)) {
    stop("Geen geldige plot-jaar-combinaties voor deze selectie.")
  }
  basis_geteld <- basis[basis$geteld, , drop = FALSE]
  if (nrow(basis_geteld) < 4L) {
    stop("Te weinig getelde plot-jaren voor NMDS.")
  }

  species_ids <- select_species_for_nmds(tbls, selection_type, selection_value)
  selection_df <- tbls$soorten[tbls$soorten$id %in% species_ids, , drop = FALSE]
  selection_df$in_selectie <- TRUE
  if (!nrow(selection_df)) {
    stop("Geen soorten gevonden voor deze NMDS-selectie.")
  }

  species_matrix <- build_species_matrix_subset(tbls, basis_geteld, selection_df, year_from, year_to)
  species_matrix <- species_matrix[species_matrix$geteld & !is.na(species_matrix$territoria_per_km2), , drop = FALSE]
  species_matrix$sample_id <- paste(species_matrix$plot_id, species_matrix$jaar, sep = "_")
  comm <- stats::xtabs(territoria_per_km2 ~ sample_id + soort_id, data = species_matrix)
  comm <- matrix(as.numeric(comm), nrow = nrow(comm), ncol = ncol(comm), dimnames = dimnames(comm))
  comm <- comm[rowSums(comm, na.rm = TRUE) > 0, colSums(comm, na.rm = TRUE) > 0, drop = FALSE]
  if (nrow(comm) < 4L) {
    stop("Te weinig plot-jaren met territoria voor NMDS.")
  }
  if (ncol(comm) < 2L) {
    stop("Te weinig soorten met territoria voor NMDS.")
  }
  if (nrow(comm) > 2000L || ncol(comm) > 300L) {
    stop("Deze NMDS-selectie is te groot voor interactief gebruik. Verklein jaren, kavels of soortselectie.")
  }

  meta <- unique(species_matrix[, c("sample_id", "plot_id", "kavel_nummer", "jaar")])
  meta <- meta[match(rownames(comm), meta$sample_id), , drop = FALSE]
  comm_transformed <- nmds_transform_matrix(comm, transform)
  fit <- tryCatch({
    setTimeLimit(elapsed = 30, transient = TRUE)
    on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
    vegan::metaMDS(comm_transformed, distance = distance, k = dimensions, trymax = trymax, autotransform = FALSE, trace = FALSE)
  }, error = function(e) e)
  if (inherits(fit, "error")) {
    msg <- conditionMessage(fit)
    if (grepl("elapsed time limit", msg, fixed = TRUE)) {
      stop("De NMDS-berekening duurde te lang. Verklein jaren/kavels of kies een beperktere soortselectie.")
    }
    stop(msg)
  }

  site_scores <- as.data.frame(vegan::scores(fit, display = "sites"), stringsAsFactors = FALSE)
  site_scores$sample_id <- rownames(site_scores)
  site_scores <- merge(site_scores, meta, by = "sample_id", all.x = TRUE)
  site_scores <- site_scores[order(site_scores$jaar, site_scores$kavel_nummer, site_scores$plot_id), , drop = FALSE]
  rownames(site_scores) <- NULL

  species_scores <- as.data.frame(vegan::scores(fit, display = "species"), stringsAsFactors = FALSE)
  species_scores$soort_id <- as.integer(rownames(species_scores))
  species_scores <- merge(
    species_scores,
    tbls$soorten[, c("id", "euring_code", "soort_naam", "engelse_naam")],
    by.x = "soort_id",
    by.y = "id",
    all.x = TRUE
  )
  rownames(species_scores) <- NULL

  sample_totals <- data.frame(
    sample_id = rownames(comm),
    totaal_territoria_per_km2 = rowSums(comm),
    totaal_territoria = rowSums(comm),
    soortenrijkdom = rowSums(comm > 0),
    stringsAsFactors = FALSE
  )
  sample_totals <- merge(sample_totals, meta, by = "sample_id", all.x = TRUE)
  sample_totals <- sample_totals[order(sample_totals$jaar, sample_totals$kavel_nummer, sample_totals$plot_id), , drop = FALSE]
  rownames(sample_totals) <- NULL

  envfit_table <- data.frame()
  envfit_vars <- c("year_c", "stikstof_mean", "ahn_mean", "afstand_pad_m")
  env_meta <- cd_meta_for_nmds(tbls, meta, comm)
  usable_envfit_vars <- intersect(envfit_vars, names(env_meta))
  usable_envfit_vars <- usable_envfit_vars[vapply(env_meta[, usable_envfit_vars, drop = FALSE], function(x) {
    vals <- x[is.finite(x)]
    length(vals) >= 3L && stats::var(vals) > 0
  }, logical(1))]
  if (length(usable_envfit_vars)) {
    envfit_table <- tryCatch({
      envfit_fit <- vegan::envfit(fit, env_meta[, usable_envfit_vars, drop = FALSE], permutations = 999, na.rm = TRUE)
      vectors <- as.data.frame(vegan::scores(envfit_fit, display = "vectors"), stringsAsFactors = FALSE)
      vectors$variabele <- rownames(vectors)
      vectors$r2 <- envfit_fit$vectors$r
      vectors$p_waarde <- envfit_fit$vectors$pvals
      vectors[, c("variabele", setdiff(names(vectors), "variabele")), drop = FALSE]
    }, error = function(e) {
      data.frame(melding = paste("Envfit niet berekend:", conditionMessage(e)), stringsAsFactors = FALSE)
    })
  }

  summary_df <- data.frame(
    analyse_niveau = switch(selection_type, all = "Alle soorten", group = "Vogelgroep", richtlijn = "Rode/Oranje Lijst", trait = "Vogelkenmerk"),
    doel_label = nmds_selection_label(tbls, selection_type, selection_value),
    doel_slug = paste0("nmds_", selection_type, "_", tolower(gsub("[^a-z0-9]+", "_", nmds_selection_label(tbls, selection_type, selection_value)))),
    transform = transform,
    distance = distance,
    dimensions = dimensions,
    stress = fit$stress,
    n_plots = length(unique(meta$plot_id)),
    n_plot_jaren = nrow(comm),
    n_soorten = ncol(comm),
    eerste_jaar = min(meta$jaar, na.rm = TRUE),
    laatste_jaar = max(meta$jaar, na.rm = TRUE),
    totaal_territoria_per_km2 = sum(comm, na.rm = TRUE),
    totaal_territoria = sum(comm, na.rm = TRUE),
    respons = "territoria_per_km2",
    stringsAsFactors = FALSE
  )

  list(
    dataset = species_matrix,
    community_matrix = comm,
    transformed_matrix = comm_transformed,
    site_scores = site_scores,
    species_scores = species_scores,
    sample_totals = sample_totals,
    envfit = envfit_table,
    summary = summary_df,
    fit = fit
  )
}

cd_meta_for_nmds <- function(tbls, meta, comm) {
  env_meta <- meta
  env_meta$year_c <- env_meta$jaar - min(env_meta$jaar, na.rm = TRUE)
  env_meta <- add_numeric_covariate(env_meta, tbls$plot_jaar_ahn_dtm, "ahn_mean", "ahn_mean")
  env_meta <- add_numeric_covariate(env_meta, tbls$plot_jaar_stikstof, "stikstof_mean", "stikstof_mean")
  env_meta <- add_numeric_covariate(env_meta, tbls$plot_jaar_infra, "waarde", "afstand_pad_m", "afstand_pad_m")
  rownames(env_meta) <- rownames(comm)
  env_meta
}

build_community_matrix_subset <- function(tbls, selected_kavels, year_from, year_to, selection_type = c("all", "group", "richtlijn", "trait"), selection_value = NULL) {
  selection_type <- match.arg(selection_type)
  basis <- prepare_analysis_basis_subset(tbls, selected_kavels, year_from, year_to)
  if (!nrow(basis)) {
    stop("Geen geldige plot-jaar-combinaties voor deze selectie.")
  }
  basis_geteld <- basis[basis$geteld, , drop = FALSE]
  if (nrow(basis_geteld) < 4L) {
    stop("Te weinig getelde plot-jaren voor deze analyse.")
  }
  species_ids <- select_species_for_nmds(tbls, selection_type, selection_value)
  selection_df <- tbls$soorten[tbls$soorten$id %in% species_ids, , drop = FALSE]
  selection_df$in_selectie <- TRUE
  if (!nrow(selection_df)) {
    stop("Geen soorten gevonden voor deze selectie.")
  }

  species_matrix <- build_species_matrix_subset(tbls, basis_geteld, selection_df, year_from, year_to)
  species_matrix <- species_matrix[species_matrix$geteld & !is.na(species_matrix$territoria_per_km2), , drop = FALSE]
  species_matrix$sample_id <- paste(species_matrix$plot_id, species_matrix$jaar, sep = "_")
  comm <- stats::xtabs(territoria_per_km2 ~ sample_id + soort_id, data = species_matrix)
  comm <- matrix(as.numeric(comm), nrow = nrow(comm), ncol = ncol(comm), dimnames = dimnames(comm))
  comm <- comm[rowSums(comm, na.rm = TRUE) > 0, colSums(comm, na.rm = TRUE) > 0, drop = FALSE]
  if (nrow(comm) < 4L) {
    stop("Te weinig plot-jaren met territoria voor deze analyse.")
  }
  if (ncol(comm) < 2L) {
    stop("Te weinig soorten met territoria voor deze analyse.")
  }

  meta <- unique(species_matrix[, c("sample_id", "plot_id", "kavel_nummer", "jaar", "oppervlakte_km2")])
  meta <- meta[match(rownames(comm), meta$sample_id), , drop = FALSE]
  meta$totaal_territoria_per_km2 <- rowSums(comm)
  meta$totaal_territoria <- rowSums(comm)
  meta$soortenrijkdom <- rowSums(comm > 0)
  meta$year_c <- meta$jaar - min(meta$jaar, na.rm = TRUE)
  meta <- add_numeric_covariate(meta, tbls$plot_jaar_ahn_dtm, "ahn_mean", "ahn_mean")
  meta <- add_numeric_covariate(meta, tbls$plot_jaar_stikstof, "stikstof_mean", "stikstof_mean")
  meta <- add_numeric_covariate(meta, tbls$plot_jaar_infra, "waarde", "afstand_pad_m", "afstand_pad_m")
  rownames(meta) <- meta$sample_id
  list(
    species_matrix = species_matrix,
    community_matrix = comm,
    meta = meta,
    selection_label = nmds_selection_label(tbls, selection_type, selection_value),
    selection_type = selection_type
  )
}

community_summary_df <- function(prefix, community_data, year_from, year_to) {
  meta <- community_data$meta
  comm <- community_data$community_matrix
  data.frame(
    analyse_niveau = switch(community_data$selection_type, all = "Alle soorten", group = "Vogelgroep", richtlijn = "Rode/Oranje Lijst", trait = "Vogelkenmerk"),
    doel_label = community_data$selection_label,
    doel_slug = paste0(prefix, "_", community_data$selection_type, "_", tolower(gsub("[^a-z0-9]+", "_", community_data$selection_label))),
    n_plots = length(unique(meta$plot_id)),
    n_plot_jaren = nrow(comm),
    n_soorten = ncol(comm),
    eerste_jaar = min(meta$jaar, na.rm = TRUE),
    laatste_jaar = max(meta$jaar, na.rm = TRUE),
    totaal_territoria_per_km2 = sum(comm, na.rm = TRUE),
    totaal_territoria = sum(comm, na.rm = TRUE),
    respons = "territoria_per_km2",
    stringsAsFactors = FALSE
  )
}

run_rda_subset <- function(tbls, selected_kavels, year_from, year_to, selection_type = c("all", "group", "richtlijn", "trait"), selection_value = NULL, transform = c("hellinger", "presence_absence", "log1p", "raw"), condition = c("none", "year")) {
  selection_type <- match.arg(selection_type)
  transform <- match.arg(transform)
  condition <- match.arg(condition)
  if (!requireNamespace("vegan", quietly = TRUE)) {
    stop("Package 'vegan' is niet beschikbaar. Installeer het eerst met install.packages('vegan').")
  }
  cd <- build_community_matrix_subset(tbls, selected_kavels, year_from, year_to, selection_type, selection_value)
  comm <- nmds_transform_matrix(cd$community_matrix, transform)
  meta <- cd$meta
  env_vars <- c("year_c", "stikstof_mean", "ahn_mean", "afstand_pad_m")
  keep <- rownames(meta)[stats::complete.cases(meta[, env_vars, drop = FALSE])]
  comm <- comm[keep, , drop = FALSE]
  meta <- meta[keep, , drop = FALSE]
  if (nrow(comm) < 5L) {
    stop("Te weinig complete plot-jaren met omgevingsvariabelen voor RDA.")
  }
  if (identical(condition, "year")) {
    fit <- vegan::rda(comm ~ stikstof_mean + ahn_mean + afstand_pad_m + Condition(year_c), data = meta)
  } else {
    fit <- vegan::rda(comm ~ year_c + stikstof_mean + ahn_mean + afstand_pad_m, data = meta)
  }
  site_scores <- as.data.frame(vegan::scores(fit, display = "sites", choices = 1:2), stringsAsFactors = FALSE)
  site_scores$sample_id <- rownames(site_scores)
  site_scores <- merge(site_scores, meta, by = "sample_id", all.x = TRUE)
  species_scores <- as.data.frame(vegan::scores(fit, display = "species", choices = 1:2), stringsAsFactors = FALSE)
  species_scores$soort_id <- as.integer(rownames(species_scores))
  species_scores <- merge(species_scores, tbls$soorten[, c("id", "soort_naam", "engelse_naam", "euring_code")], by.x = "soort_id", by.y = "id", all.x = TRUE)
  constraints <- as.data.frame(vegan::scores(fit, display = "bp", choices = 1:2), stringsAsFactors = FALSE)
  constraints$variabele <- rownames(constraints)
  diagnostics <- rda_diagnostics_table(fit)
  summary_df <- community_summary_df("rda", cd, year_from, year_to)
  summary_df$transform <- transform
  summary_df$conditionering <- ifelse(identical(condition, "year"), "Condition(year_c)", "geen")
  summary_df$verklaarde_variatie <- sum(fit$CCA$eig) / sum(fit$CCA$eig, fit$CA$eig)
  list(dataset = cd$species_matrix, community_matrix = cd$community_matrix, meta = meta, site_scores = site_scores, species_scores = species_scores, constraints = constraints, diagnostics = diagnostics, summary = summary_df, fit = fit)
}

rda_diagnostics_table <- function(fit) {
  permutation_part <- function(by = NULL, label) {
    out <- tryCatch({
      tab <- as.data.frame(vegan::anova.cca(fit, by = by, permutations = 999), stringsAsFactors = FALSE)
      tab$term <- rownames(tab)
      names(tab) <- gsub("Pr\\(>F\\)", "p_waarde", names(tab))
      names(tab) <- gsub("^F$", "F_waarde", names(tab))
      tab$onderdeel <- label
      cols <- intersect(c("onderdeel", "term", "Df", "Variance", "F_waarde", "p_waarde"), names(tab))
      tab[, cols, drop = FALSE]
    }, error = function(e) {
      data.frame(onderdeel = label, term = "melding", p_waarde = NA_real_, melding = conditionMessage(e), stringsAsFactors = FALSE)
    })
    rownames(out) <- NULL
    out
  }
  perm <- rbind_fill_base(
    permutation_part(NULL, "permutatie totaalmodel"),
    permutation_part("axis", "permutatie assen"),
    permutation_part("term", "permutatie termen")
  )
  vif <- tryCatch({
    vals <- vegan::vif.cca(fit)
    data.frame(
      onderdeel = "VIF collineariteit",
      term = names(vals),
      Df = NA_real_,
      Variance = NA_real_,
      F_waarde = NA_real_,
      p_waarde = NA_real_,
      VIF = as.numeric(vals),
      beoordeling = ifelse(vals >= 10, "hoog", ifelse(vals >= 5, "matig", "laag")),
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    data.frame(onderdeel = "VIF collineariteit", term = "melding", melding = conditionMessage(e), stringsAsFactors = FALSE)
  })
  out <- rbind_fill_base(perm, vif)
  rownames(out) <- NULL
  out
}

rbind_fill_base <- function(...) {
  parts <- list(...)
  parts <- parts[vapply(parts, nrow, integer(1)) > 0]
  if (!length(parts)) {
    return(data.frame())
  }
  all_names <- unique(unlist(lapply(parts, names), use.names = FALSE))
  parts <- lapply(parts, function(x) {
    missing <- setdiff(all_names, names(x))
    for (nm in missing) {
      x[[nm]] <- NA
    }
    x[, all_names, drop = FALSE]
  })
  do.call(rbind, parts)
}

run_pls_subset <- function(tbls, selected_kavels, year_from, year_to, selection_type = c("all", "group", "richtlijn", "trait"), selection_value = NULL, transform = c("hellinger", "presence_absence", "log1p", "raw"), ncomp = 2L) {
  selection_type <- match.arg(selection_type)
  transform <- match.arg(transform)
  ncomp <- as.integer(ncomp)[1]
  if (!is.finite(ncomp) || ncomp < 1L) {
    ncomp <- 2L
  }
  if (!requireNamespace("pls", quietly = TRUE)) {
    stop("Package 'pls' is niet beschikbaar. Installeer het eerst met install.packages('pls').")
  }
  if (!requireNamespace("vegan", quietly = TRUE)) {
    stop("Package 'vegan' is niet beschikbaar. Installeer het eerst met install.packages('vegan').")
  }

  cd <- build_community_matrix_subset(tbls, selected_kavels, year_from, year_to, selection_type, selection_value)
  comm <- nmds_transform_matrix(cd$community_matrix, transform)
  meta <- cd$meta
  env_vars <- c("year_c", "stikstof_mean", "ahn_mean", "afstand_pad_m")
  keep <- rownames(meta)[stats::complete.cases(meta[, env_vars, drop = FALSE])]
  comm <- comm[keep, , drop = FALSE]
  meta <- meta[keep, , drop = FALSE]
  env_vars <- env_vars[vapply(meta[, env_vars, drop = FALSE], function(x) {
    vals <- x[is.finite(x)]
    length(vals) >= 3L && stats::var(vals) > 0
  }, logical(1))]
  if (length(env_vars) < 1L) {
    stop("Geen bruikbare omgevingsvariabelen met variatie voor PLS.")
  }
  if (nrow(comm) < 6L) {
    stop("Te weinig complete plot-jaren met omgevingsvariabelen voor PLS.")
  }
  if (ncol(comm) < 2L) {
    stop("Te weinig soorten met territoria voor PLS.")
  }

  X <- scale(as.matrix(meta[, env_vars, drop = FALSE]))
  Y <- scale(as.matrix(comm))
  max_comp <- min(nrow(X) - 1L, ncol(X), ncol(Y))
  if (max_comp < 1L) {
    stop("Te weinig dimensies voor PLS.")
  }
  ncomp <- min(ncomp, max_comp)
  fit <- pls::plsr(Y ~ X, ncomp = ncomp, validation = "LOO", method = "kernelpls", scale = FALSE)

  score_mat <- as.matrix(pls::scores(fit))[, seq_len(ncomp), drop = FALSE]
  site_scores <- as.data.frame(score_mat[, seq_len(min(2L, ncomp)), drop = FALSE], stringsAsFactors = FALSE)
  names(site_scores) <- paste0("PLS", seq_len(ncol(site_scores)))
  if (!("PLS2" %in% names(site_scores))) {
    site_scores$PLS2 <- 0
  }
  site_scores$sample_id <- rownames(score_mat)
  site_scores <- merge(site_scores, meta, by = "sample_id", all.x = TRUE)

  xload <- as.matrix(pls::loadings(fit))[, seq_len(ncomp), drop = FALSE]
  variable_loadings <- as.data.frame(xload[, seq_len(min(2L, ncomp)), drop = FALSE], stringsAsFactors = FALSE)
  names(variable_loadings) <- paste0("PLS", seq_len(ncol(variable_loadings)))
  if (!("PLS2" %in% names(variable_loadings))) {
    variable_loadings$PLS2 <- 0
  }
  variable_loadings$variabele <- rownames(xload)
  variable_loadings <- variable_loadings[, c("variabele", setdiff(names(variable_loadings), "variabele")), drop = FALSE]

  yload <- as.matrix(pls::Yloadings(fit))[, seq_len(ncomp), drop = FALSE]
  species_loadings <- as.data.frame(yload[, seq_len(min(2L, ncomp)), drop = FALSE], stringsAsFactors = FALSE)
  names(species_loadings) <- paste0("PLS", seq_len(ncol(species_loadings)))
  if (!("PLS2" %in% names(species_loadings))) {
    species_loadings$PLS2 <- 0
  }
  species_loadings$soort_id <- as.integer(rownames(yload))
  species_loadings <- merge(species_loadings, tbls$soorten[, c("id", "soort_naam", "engelse_naam", "euring_code")], by.x = "soort_id", by.y = "id", all.x = TRUE)

  fitted_y <- fitted(fit)[, , ncomp, drop = TRUE]
  y_r2 <- 1 - sum((Y - fitted_y)^2, na.rm = TRUE) / sum((Y - colMeans(Y, na.rm = TRUE))^2, na.rm = TRUE)
  vip_scores <- pls_vip_table(fit, X, Y, ncomp)
  rmsep <- pls_rmsep_table(fit, Y, ncomp)
  component_interpretation <- pls_component_interpretation_table(variable_loadings, ncomp)
  summary_df <- community_summary_df("pls", cd, year_from, year_to)
  summary_df$transform <- transform
  summary_df$ncomp <- ncomp
  if (nrow(rmsep) && "beste_keuze" %in% names(rmsep)) {
    best_component <- rmsep$componenten[which.min(rmsep$RMSEP_LOO)]
    summary_df$beste_componenten_rmsep <- best_component
  }
  summary_df$omgevingsvariabelen <- paste(env_vars, collapse = ", ")
  summary_df$verklaarde_y_variatie <- y_r2
  summary_df$verklaarde_x_variatie <- sum(pls::explvar(fit)[seq_len(ncomp)], na.rm = TRUE)
  list(
    dataset = cd$species_matrix,
    community_matrix = cd$community_matrix,
    transformed_matrix = comm,
    meta = meta,
    site_scores = site_scores,
    variable_loadings = variable_loadings,
    vip_scores = vip_scores,
    rmsep = rmsep,
    component_interpretation = component_interpretation,
    species_loadings = species_loadings,
    summary = summary_df,
    fit = fit
  )
}

pls_vip_table <- function(fit, X, Y, ncomp) {
  weights <- tryCatch(as.matrix(fit$loading.weights)[, seq_len(ncomp), drop = FALSE], error = function(e) NULL)
  if (is.null(weights)) {
    return(data.frame(melding = "VIP kon niet worden berekend.", stringsAsFactors = FALSE))
  }
  p <- nrow(weights)
  total_ss <- sum((Y - matrix(colMeans(Y, na.rm = TRUE), nrow(Y), ncol(Y), byrow = TRUE))^2, na.rm = TRUE)
  ss <- numeric(ncomp)
  prev_pred <- matrix(colMeans(Y, na.rm = TRUE), nrow(Y), ncol(Y), byrow = TRUE)
  prev_rss <- sum((Y - prev_pred)^2, na.rm = TRUE)
  for (a in seq_len(ncomp)) {
    pred <- fitted(fit)[, , a, drop = TRUE]
    rss <- sum((Y - pred)^2, na.rm = TRUE)
    ss[[a]] <- max(0, prev_rss - rss)
    prev_rss <- rss
  }
  if (!is.finite(total_ss) || total_ss <= 0 || sum(ss) <= 0) {
    return(data.frame(variabele = rownames(weights), VIP = NA_real_, beoordeling = "niet berekend", stringsAsFactors = FALSE))
  }
  vip <- vapply(seq_len(p), function(j) {
    w2 <- weights[j, ]^2
    denom <- colSums(weights^2)
    sqrt(p * sum(ss * w2 / denom, na.rm = TRUE) / sum(ss, na.rm = TRUE))
  }, numeric(1))
  data.frame(
    variabele = rownames(weights),
    VIP = vip,
    beoordeling = ifelse(vip >= 1, "belangrijk", "lager gewicht"),
    stringsAsFactors = FALSE
  )
}

pls_rmsep_table <- function(fit, Y, ncomp) {
  baseline <- matrix(colMeans(Y, na.rm = TRUE), nrow(Y), ncol(Y), byrow = TRUE)
  rows <- list(data.frame(componenten = 0L, RMSEP_LOO = sqrt(mean((Y - baseline)^2, na.rm = TRUE))))
  pred <- tryCatch(fit$validation$pred, error = function(e) NULL)
  if (is.null(pred)) {
    return(do.call(rbind, rows))
  }
  for (a in seq_len(ncomp)) {
    pred_a <- pred[, , a, drop = TRUE]
    rows[[length(rows) + 1L]] <- data.frame(componenten = a, RMSEP_LOO = sqrt(mean((Y - pred_a)^2, na.rm = TRUE)))
  }
  out <- do.call(rbind, rows)
  out$beste_keuze <- out$RMSEP_LOO == min(out$RMSEP_LOO, na.rm = TRUE)
  out
}

pls_component_interpretation_table <- function(variable_loadings, ncomp, top_n = 3L) {
  component_cols <- paste0("PLS", seq_len(ncomp))
  component_cols <- intersect(component_cols, names(variable_loadings))
  if (!length(component_cols)) {
    return(data.frame(melding = "Geen componentloadings beschikbaar.", stringsAsFactors = FALSE))
  }
  rows <- lapply(component_cols, function(component) {
    vals <- variable_loadings[[component]]
    names(vals) <- variable_loadings$variabele
    vals <- vals[is.finite(vals)]
    if (!length(vals)) {
      return(data.frame(
        component = component,
        dominante_variabelen = NA_character_,
        interpretatie_hulp = "Geen bruikbare loadingwaarden.",
        stringsAsFactors = FALSE
      ))
    }
    ord <- order(abs(vals), decreasing = TRUE)
    top <- vals[ord][seq_len(min(top_n, length(vals)))]
    data.frame(
      component = component,
      dominante_variabelen = paste(sprintf("%s (%+.3f)", names(top), top), collapse = "; "),
      interpretatie_hulp = "Gebruik deze dominante variabelen als aanwijzing voor ecologische interpretatie; dit is geen automatisch causaal label.",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

changepoint_add_uncertainty <- function(candidates_df, n_years) {
  if (!"rss" %in% names(candidates_df) || !nrow(candidates_df)) {
    return(candidates_df)
  }
  rss <- pmax(candidates_df$rss, .Machine$double.eps)
  candidates_df$aic_achtig <- n_years * log(rss / n_years) + 2 * 3
  candidates_df$delta_aic_achtig <- candidates_df$aic_achtig - min(candidates_df$aic_achtig, na.rm = TRUE)
  candidates_df$binnen_onzekerheidsinterval <- candidates_df$delta_aic_achtig <= 2
  candidates_df
}

changepoint_penalty_sensitivity <- function(annual, penalties = c("AIC", "BIC", "SIC", "MBIC")) {
  rows <- lapply(penalties, function(penalty) {
    out <- tryCatch({
      fit <- changepoint::cpt.mean(annual$waarde, method = "PELT", penalty = penalty, minseglen = 3L, class = TRUE)
      cpt_idx <- changepoint::cpts(fit)
      data.frame(
        penalty = penalty,
        knip_jaar = if (length(cpt_idx)) paste(annual$jaar[cpt_idx], collapse = ", ") else "geen",
        n_omslagpunten = length(cpt_idx),
        melding = NA_character_,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      data.frame(
        penalty = penalty,
        knip_jaar = NA_character_,
        n_omslagpunten = NA_integer_,
        melding = conditionMessage(e),
        stringsAsFactors = FALSE
      )
    })
    out
  })
  do.call(rbind, rows)
}

changepoint_build_series <- function(tbls, selected_kavels, year_from, year_to, selection_type, selection_value, source, metric) {
  cd <- build_community_matrix_subset(tbls, selected_kavels, year_from, year_to, selection_type, selection_value)
  meta <- cd$meta
  annual_counts <- aggregate(plot_id ~ jaar, data = meta, FUN = function(x) length(unique(x)))
  names(annual_counts)[2] <- "n_plot_jaren"

  if (identical(source, "community")) {
    annual <- aggregate(meta[[metric]], list(jaar = meta$jaar), mean, na.rm = TRUE)
    names(annual)[2] <- "waarde"
    annual <- merge(annual, annual_counts, by = "jaar", all.x = TRUE)
    annual$bron <- "jaarlijkse_tellingen"
    return(list(cd = cd, annual = annual, dataset = cd$species_matrix))
  }

  trim_results <- analyse_subset(tbls, selected_kavels, year_from, year_to)
  species_ids <- select_species_for_nmds(tbls, selection_type, selection_value)
  indices <- trim_results$species_results$indices
  indices <- indices[indices$soort_id %in% species_ids & is.finite(indices$index_100) & indices$index_100 > 0, , drop = FALSE]
  if (!nrow(indices)) {
    stop("Geen bruikbare TRIM-indexen voor deze changepoint-selectie.")
  }

  if (identical(source, "trim_index")) {
    annual <- aggregate(index_100 ~ jaar, data = indices, FUN = mean)
    names(annual)[2] <- "waarde"
    annual$bron <- "gemiddelde_trim_index"
  } else {
    indices$log_index_100 <- log(indices$index_100)
    annual <- aggregate(log_index_100 ~ jaar, data = indices, FUN = mean)
    names(annual)[2] <- "log_waarde"
    annual$waarde <- exp(annual$log_waarde)
    annual$log_waarde <- NULL
    annual$bron <- "msi_geometrisch_gemiddelde_trim_index"
  }
  n_species <- aggregate(soort_id ~ jaar, data = indices, FUN = function(x) length(unique(x)))
  names(n_species)[2] <- "n_soorten_index"
  annual <- merge(annual, n_species, by = "jaar", all.x = TRUE)
  annual <- merge(annual, annual_counts, by = "jaar", all.x = TRUE)
  list(cd = cd, annual = annual, dataset = trim_results$species_matrix)
}

run_changepoint_subset <- function(tbls, selected_kavels, year_from, year_to, selection_type = c("all", "group", "richtlijn", "trait"), selection_value = NULL, source = c("community", "trim_index", "msi"), metric = c("totaal_territoria_per_km2", "soortenrijkdom", "totaal_territoria"), method = c("level", "trend", "multi"), penalty = c("MBIC", "BIC", "SIC", "AIC")) {
  selection_type <- match.arg(selection_type)
  source <- match.arg(source)
  metric <- match.arg(metric)
  method <- match.arg(method)
  penalty <- match.arg(penalty)
  if (metric == "totaal_territoria") {
    metric <- "totaal_territoria_per_km2"
  }
  metric_label <- switch(source,
    community = metric,
    trim_index = "gemiddelde_TRIM_index_100",
    msi = "MSI_100"
  )
  if (!requireNamespace("changepoint", quietly = TRUE)) {
    stop("Package 'changepoint' is niet beschikbaar. Installeer het eerst met install.packages('changepoint').")
  }
  series <- changepoint_build_series(tbls, selected_kavels, year_from, year_to, selection_type, selection_value, source, metric)
  cd <- series$cd
  annual <- series$annual
  annual <- annual[is.finite(annual$waarde), , drop = FALSE]
  annual <- annual[order(annual$jaar), , drop = FALSE]
  if (nrow(annual) < 8L) {
    stop("Te weinig jaren voor changepoint-analyse.")
  }
  candidates <- seq(3L, nrow(annual) - 3L)
  sensitivity <- changepoint_penalty_sensitivity(annual)
  sensitivity_label <- paste(paste0(sensitivity$penalty, "=", sensitivity$knip_jaar), collapse = " | ")
  if (identical(method, "multi")) {
    fit <- changepoint::cpt.mean(annual$waarde, method = "PELT", penalty = penalty, minseglen = 3L, class = TRUE)
    cpt_idx <- changepoint::cpts(fit)
    cpt_years <- annual$jaar[cpt_idx]
    annual$changepoint <- annual$jaar %in% cpt_years
    annual$periode <- cut(
      annual$jaar,
      breaks = c(-Inf, cpt_years, Inf),
      labels = paste0("periode_", seq_len(length(cpt_years) + 1L)),
      right = TRUE
    )
    candidates_df <- aggregate(waarde ~ periode, data = annual, FUN = mean)
    names(candidates_df)[2] <- "gemiddelde_waarde"
    n_years <- aggregate(jaar ~ periode, data = annual, FUN = length)
    names(n_years)[2] <- "n_jaren"
    candidates_df <- merge(candidates_df, n_years, by = "periode", all.x = TRUE)
    candidates_df$knip_jaar <- c(cpt_years, NA_integer_)[seq_len(nrow(candidates_df))]
    summary_df <- community_summary_df("changepoint", cd, year_from, year_to)
    summary_df$invoerbron <- source
    summary_df$metric <- metric_label
    summary_df$methode <- paste0("changepoint::cpt.mean_PELT_", penalty, "_meerdere_omslagpunten_minseglen_3")
    summary_df$penalty <- penalty
    summary_df$knip_jaar <- if (length(cpt_years)) paste(cpt_years, collapse = ", ") else "geen"
    summary_df$n_omslagpunten <- length(cpt_years)
    summary_df$onzekerheidsinterval_omslagjaar <- NA_character_
    summary_df$penalty_gevoeligheid <- sensitivity_label
    summary_df$min_plot_jaren_per_jaar <- min(annual$n_plot_jaren, na.rm = TRUE)
    summary_df$dekking_waarschuwing <- ifelse(min(annual$n_plot_jaren, na.rm = TRUE) < 5L, "minder_dan_5_plotjaren_in_minstens_een_jaar", "voldoende_minimale_jaardekking")
    return(list(dataset = series$dataset, annual = annual, candidates = candidates_df, diagnostics = summary_df, sensitivity = sensitivity, summary = summary_df, fit = fit))
  }
  if (identical(method, "trend")) {
    rows <- lapply(candidates, function(i) {
      knip <- annual$jaar[[i]]
      dat <- annual
      dat$post_knip <- pmax(0, dat$jaar - knip)
      fit_i <- stats::lm(waarde ~ jaar + post_knip, data = dat)
      coef_i <- stats::coef(fit_i)
      slope_voor <- unname(coef_i[["jaar"]])
      slope_verandering <- unname(coef_i[["post_knip"]])
      data.frame(
        knip_jaar = knip,
        rss = sum(stats::residuals(fit_i)^2),
        slope_voor = slope_voor,
        slope_na = slope_voor + slope_verandering,
        slope_verandering = slope_verandering
      )
    })
    candidates_df <- do.call(rbind, rows)
    candidates_df <- changepoint_add_uncertainty(candidates_df, nrow(annual))
    best <- candidates_df[which.min(candidates_df$rss), , drop = FALSE]
    annual$post_knip <- pmax(0, annual$jaar - best$knip_jaar[[1]])
    best_fit <- stats::lm(waarde ~ jaar + post_knip, data = annual)
    annual$fit <- stats::fitted(best_fit)
    annual$changepoint <- annual$jaar == best$knip_jaar[[1]]
    annual$periode <- ifelse(annual$jaar <= best$knip_jaar[[1]], "voor_knip", "na_knip")
    uncertainty_years <- candidates_df$knip_jaar[candidates_df$binnen_onzekerheidsinterval]
    summary_df <- community_summary_df("changepoint", cd, year_from, year_to)
    summary_df$invoerbron <- source
    summary_df$metric <- metric_label
    summary_df$methode <- "gesegmenteerde lineaire trendbreuk"
    summary_df$penalty <- NA_character_
    summary_df$knip_jaar <- best$knip_jaar[[1]]
    summary_df$onzekerheidsinterval_omslagjaar <- paste(range(uncertainty_years, na.rm = TRUE), collapse = "-")
    summary_df$penalty_gevoeligheid <- sensitivity_label
    summary_df$min_plot_jaren_per_jaar <- min(annual$n_plot_jaren, na.rm = TRUE)
    summary_df$dekking_waarschuwing <- ifelse(min(annual$n_plot_jaren, na.rm = TRUE) < 5L, "minder_dan_5_plotjaren_in_minstens_een_jaar", "voldoende_minimale_jaardekking")
    summary_df$slope_voor <- best$slope_voor[[1]]
    summary_df$slope_na <- best$slope_na[[1]]
    summary_df$slope_verandering <- best$slope_verandering[[1]]
    return(list(dataset = series$dataset, annual = annual, candidates = candidates_df[order(candidates_df$rss), , drop = FALSE], diagnostics = summary_df, sensitivity = sensitivity, summary = summary_df, fit = best_fit))
  }
  rows <- lapply(candidates, function(i) {
    left <- annual$waarde[seq_len(i)]
    right <- annual$waarde[(i + 1L):nrow(annual)]
    rss <- sum((left - mean(left))^2) + sum((right - mean(right))^2)
    data.frame(knip_jaar = annual$jaar[[i]], rss = rss, mean_voor = mean(left), mean_na = mean(right), verschil = mean(right) - mean(left))
  })
  candidates_df <- do.call(rbind, rows)
  candidates_df <- changepoint_add_uncertainty(candidates_df, nrow(annual))
  best <- candidates_df[which.min(candidates_df$rss), , drop = FALSE]
  fit <- changepoint::cpt.mean(annual$waarde, method = "PELT", penalty = penalty, minseglen = 3L, class = TRUE)
  cpt_idx <- changepoint::cpts(fit)
  cpt_years <- annual$jaar[cpt_idx]
  if (!length(cpt_years)) {
    cpt_years <- best$knip_jaar[[1]]
  }
  annual$changepoint <- annual$jaar %in% cpt_years
  annual$periode <- cut(
    annual$jaar,
    breaks = c(-Inf, cpt_years, Inf),
    labels = paste0("periode_", seq_len(length(cpt_years) + 1L)),
    right = TRUE
  )
  uncertainty_years <- candidates_df$knip_jaar[candidates_df$binnen_onzekerheidsinterval]
  summary_df <- community_summary_df("changepoint", cd, year_from, year_to)
  summary_df$invoerbron <- source
  summary_df$metric <- metric_label
  summary_df$methode <- paste0("changepoint::cpt.mean_PELT_", penalty)
  summary_df$penalty <- penalty
  summary_df$knip_jaar <- paste(cpt_years, collapse = ", ")
  summary_df$onzekerheidsinterval_omslagjaar <- paste(range(uncertainty_years, na.rm = TRUE), collapse = "-")
  summary_df$penalty_gevoeligheid <- sensitivity_label
  summary_df$min_plot_jaren_per_jaar <- min(annual$n_plot_jaren, na.rm = TRUE)
  summary_df$dekking_waarschuwing <- ifelse(min(annual$n_plot_jaren, na.rm = TRUE) < 5L, "minder_dan_5_plotjaren_in_minstens_een_jaar", "voldoende_minimale_jaardekking")
  summary_df$verschil <- best$verschil[[1]]
  list(dataset = series$dataset, annual = annual, candidates = candidates_df[order(candidates_df$rss), , drop = FALSE], diagnostics = summary_df, sensitivity = sensitivity, summary = summary_df, fit = fit)
}

run_sem_subset <- function(tbls, selected_kavels, year_from, year_to, selection_type = c("all", "group", "richtlijn", "trait"), selection_value = NULL) {
  selection_type <- match.arg(selection_type)
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    stop("Package 'lavaan' is niet beschikbaar. Installeer het eerst met install.packages('lavaan').")
  }
  cd <- build_community_matrix_subset(tbls, selected_kavels, year_from, year_to, selection_type, selection_value)
  dat <- cd$meta
  vars <- c("soortenrijkdom", "totaal_territoria_per_km2", "year_c", "stikstof_mean", "ahn_mean", "afstand_pad_m")
  dat <- dat[stats::complete.cases(dat[, vars, drop = FALSE]), , drop = FALSE]
  if (nrow(dat) < 10L) {
    stop("Te weinig complete plot-jaren voor SEM-verkenning.")
  }
  dat$log1p_totaal_territoria_per_km2 <- log1p(dat$totaal_territoria_per_km2)
  sem_dat <- dat[, c("soortenrijkdom", "log1p_totaal_territoria_per_km2", "year_c", "stikstof_mean", "ahn_mean", "afstand_pad_m"), drop = FALSE]
  usable_predictors <- c("year_c", "stikstof_mean", "ahn_mean", "afstand_pad_m")
  usable_predictors <- usable_predictors[vapply(sem_dat[usable_predictors], function(x) {
    vals <- x[is.finite(x)]
    length(vals) >= 3L && stats::var(vals) > 0
  }, logical(1))]
  if (!length(usable_predictors)) {
    stop("Geen bruikbare verklarende SEM-variabelen met variatie in deze selectie.")
  }
  sem_dat <- sem_dat[, unique(c("soortenrijkdom", "log1p_totaal_territoria_per_km2", usable_predictors)), drop = FALSE]
  sem_dat[] <- lapply(sem_dat, function(x) as.numeric(scale(x)))
  richness_rhs <- paste(usable_predictors, collapse = " + ")
  total_rhs <- paste(c("soortenrijkdom", usable_predictors), collapse = " + ")
  model <- paste0(
    "soortenrijkdom ~ ", richness_rhs, "\n",
    "log1p_totaal_territoria_per_km2 ~ ", total_rhs, "\n",
    if ("year_c" %in% usable_predictors && "stikstof_mean" %in% usable_predictors) "stikstof_mean ~ year_c\n" else ""
  )
  fit <- lavaan::sem(model, data = sem_dat, missing = "fiml", fixed.x = FALSE)
  pe <- lavaan::parameterEstimates(fit, standardized = TRUE)
  paths <- pe[pe$op == "~", c("lhs", "rhs", "est", "se", "z", "pvalue", "std.all"), drop = FALSE]
  names(paths) <- c("response", "predictor", "estimate", "std.error", "statistic", "p.value", "std.all")
  fit_measures <- lavaan::fitMeasures(fit, c("chisq", "df", "pvalue", "cfi", "rmsea", "srmr"))
  summary_df <- community_summary_df("sem", cd, year_from, year_to)
  summary_df$modeltype <- "lavaan_sem_verkenning"
  summary_df$n_complete_plot_jaren <- nrow(dat)
  summary_df$cfi <- unname(fit_measures[["cfi"]])
  summary_df$rmsea <- unname(fit_measures[["rmsea"]])
  summary_df$srmr <- unname(fit_measures[["srmr"]])
  diagnostics <- data.frame(
    maat = names(fit_measures),
    waarde = as.numeric(fit_measures),
    interpretatie = c("lager is beter", "vrijheidsgraden", "p-waarde chi-kwadraat", "hoger is beter", "lager is beter", "lager is beter"),
    stringsAsFactors = FALSE
  )
  list(dataset = cd$species_matrix, model_data = dat, paths = paths, fit_measures = as.data.frame(as.list(fit_measures)), diagnostics = diagnostics, summary = summary_df, fit = fit)
}

run_betadiversity_subset <- function(tbls, selected_kavels, year_from, year_to, selection_type = c("all", "group", "richtlijn", "trait"), selection_value = NULL, transform = NULL, distance = NULL) {
  selection_type <- match.arg(selection_type)
  transform <- "presence_absence"
  distance <- "sorensen"
  if (!requireNamespace("betapart", quietly = TRUE)) {
    stop("Package 'betapart' is niet beschikbaar. Installeer het eerst met install.packages('betapart').")
  }
  if (!requireNamespace("vegan", quietly = TRUE)) {
    stop("Package 'vegan' is niet beschikbaar. Installeer het eerst met install.packages('vegan').")
  }
  cd <- build_community_matrix_subset(tbls, selected_kavels, year_from, year_to, selection_type, selection_value)
  comm_pa <- ifelse(cd$community_matrix > 0, 1, 0)
  beta_pair <- betapart::beta.pair(comm_pa, index.family = "sorensen")
  d <- beta_pair$beta.sor
  mat <- as.matrix(d)
  meta <- cd$meta
  gemiddelde_beta <- mean(mat[lower.tri(mat)], na.rm = TRUE)
  sim_mat <- as.matrix(beta_pair$beta.sim)
  sne_mat <- as.matrix(beta_pair$beta.sne)
  gemiddelde_turnover <- mean(sim_mat[lower.tri(sim_mat)], na.rm = TRUE)
  gemiddelde_nestedness <- mean(sne_mat[lower.tri(sne_mat)], na.rm = TRUE)
  annual <- lapply(sort(unique(meta$jaar)), function(yr) {
    ids <- rownames(meta)[meta$jaar == yr]
    val <- if (length(ids) >= 2L) mean(mat[ids, ids][lower.tri(mat[ids, ids])], na.rm = TRUE) else NA_real_
    sim_val <- if (length(ids) >= 2L) mean(sim_mat[ids, ids][lower.tri(sim_mat[ids, ids])], na.rm = TRUE) else NA_real_
    sne_val <- if (length(ids) >= 2L) mean(sne_mat[ids, ids][lower.tri(sne_mat[ids, ids])], na.rm = TRUE) else NA_real_
    data.frame(jaar = yr, beta_sorensen = val, beta_turnover = sim_val, beta_nestedness = sne_val, n_plot_jaren = length(ids))
  })
  annual <- do.call(rbind, annual)
  summary_df <- community_summary_df("betadiversity", cd, year_from, year_to)
  summary_df$transform <- "presence_absence"
  summary_df$distance <- "sorensen"
  summary_df$methode <- "betapart::beta.pair"
  summary_df$gemiddelde_beta <- gemiddelde_beta
  summary_df$gemiddelde_turnover <- gemiddelde_turnover
  summary_df$gemiddelde_nestedness <- gemiddelde_nestedness
  diagnostics <- data.frame(
    maat = c("Methode", "Transformatie", "Afstandsmaat", "Gemiddelde beta Sorensen", "Gemiddelde turnover", "Gemiddelde nestedness"),
    waarde = c("betapart::beta.pair", transform, distance, gemiddelde_beta, gemiddelde_turnover, gemiddelde_nestedness),
    stringsAsFactors = FALSE
  )
  list(dataset = cd$species_matrix, distance_matrix = mat, turnover_matrix = sim_mat, nestedness_matrix = sne_mat, annual = annual, meta = meta, diagnostics = diagnostics, summary = summary_df, beta_pair = beta_pair)
}

load_dagwaarnemingen_bmp_lazy <- function(tbls) {
  if (!is.null(tbls$dagwaarnemingen_bmp) && nrow(tbls$dagwaarnemingen_bmp)) {
    return(tbls$dagwaarnemingen_bmp)
  }
  if (is.null(tbls$sql_path) || !file.exists(tbls$sql_path)) {
    stop("SQL-pad ontbreekt; dagwaarnemingen kunnen niet lazy worden gelezen.")
  }
  cache_path <- file.path(tempdir(), "meijendel_dagwaarnemingen_bmp_cache.rds")
  signature <- make_cache_signature(tbls$sql_path)
  if (file.exists(cache_path)) {
    cache <- tryCatch(readRDS(cache_path), error = function(e) NULL)
    required_cols <- c("bezoek_id", "plot_id", "jaar", "dagvanjaar", "bezoekduur_min", "gunstig")
    if (!is.null(cache) && identical(cache$signature, signature) && !is.null(cache$data) && all(required_cols %in% names(cache$data))) {
      return(cache$data)
    }
  }
  out <- read_dagwaarnemingen_bmp_fast(tbls$sql_path)
  out$id <- to_integer(out$id)
  out$bezoek_id <- to_integer(out$bezoek_id)
  out$plot_id <- to_integer(out$plot_id)
  out$soort_id <- to_integer(out$soort_id)
  out$jaar <- to_integer(out$jaar)
  out$dagvanjaar <- to_integer(out$dagvanjaar)
  out$aantal <- to_numeric(out$aantal)
  out$broedcode <- to_integer(out$broedcode)
  out$cluster_territorium <- to_integer(out$cluster_territorium)
  out$in_plot <- to_integer(out$in_plot)
  out <- out[out$plot_id %in% tbls$plots$plot_id, , drop = FALSE]
  saveRDS(list(signature = signature, data = out), cache_path)
  out
}

load_dagbezoeken_bmp_lazy <- function(tbls) {
  if (!is.null(tbls$dagbezoeken_bmp) && nrow(tbls$dagbezoeken_bmp)) {
    return(tbls$dagbezoeken_bmp)
  }
  if (is.null(tbls$sql_path) || !file.exists(tbls$sql_path)) {
    stop("SQL-pad ontbreekt; dagbezoeken kunnen niet lazy worden gelezen.")
  }
  cache_path <- file.path(tempdir(), "meijendel_dagbezoeken_bmp_cache.rds")
  signature <- make_cache_signature(tbls$sql_path)
  if (file.exists(cache_path)) {
    cache <- tryCatch(readRDS(cache_path), error = function(e) NULL)
    if (!is.null(cache) && identical(cache$signature, signature) && !is.null(cache$data)) {
      return(cache$data)
    }
  }
  out <- read_dagbezoeken_bmp_fast(tbls$sql_path)
  out$bezoek_id <- to_integer(out$bezoek_id)
  out$plot_id <- to_integer(out$plot_id)
  out$jaar <- to_integer(out$jaar)
  out$dagvanjaar <- to_integer(out$dagvanjaar)
  out$bezoekduur_min <- to_numeric(out$bezoekduur_min)
  out$gunstig <- to_integer(out$gunstig)
  out$aantal_soorten <- to_integer(out$aantal_soorten)
  out$aantal_records <- to_integer(out$aantal_records)
  out <- out[out$plot_id %in% tbls$plots$plot_id, , drop = FALSE]
  saveRDS(list(signature = signature, data = out), cache_path)
  out
}

detection_effort_diagnostic <- function(tbls, selected_kavels, year_from, year_to, species_ids = NULL, min_visits = 2L) {
  min_visits <- as.integer(min_visits)[1]
  if (!is.finite(min_visits) || min_visits < 1L) {
    min_visits <- 2L
  }
  plot_ids <- unique(tbls$plots$plot_id[tbls$plots$kavel_nummer %in% selected_kavels])
  visits <- load_dagbezoeken_bmp_lazy(tbls)
  visits <- visits[
    visits$plot_id %in% plot_ids &
      visits$jaar >= year_from &
      visits$jaar <= year_to,
    , drop = FALSE
  ]
  visits$site_id <- paste(visits$plot_id, visits$jaar, sep = "_")
  if (!nrow(visits)) {
    return(list(
      summary = data.frame(Maat = "Melding", Waarde = "Geen dagbezoeken beschikbaar voor deze selectie.", check.names = FALSE),
      site_effort = data.frame(),
      observations_without_territory = data.frame()
    ))
  }

  visit_counts <- aggregate(bezoek_id ~ site_id + plot_id + jaar, data = visits, FUN = length)
  names(visit_counts)[4] <- "n_bezoeken"
  visit_counts <- merge(visit_counts, tbls$plots[, c("plot_id", "kavel_nummer")], by = "plot_id", all.x = TRUE)

  obs_without_territory <- data.frame()
  obs_count <- NA_integer_
  if (!is.null(species_ids) && length(species_ids)) {
    obs <- load_dagwaarnemingen_bmp_lazy(tbls)
    obs <- obs[
      obs$bezoek_id %in% visits$bezoek_id &
        obs$soort_id %in% species_ids &
        obs$in_plot %in% c(1L, NA),
      , drop = FALSE
    ]
    terr <- unique(tbls$territoria[
      tbls$territoria$plot_id %in% plot_ids &
        tbls$territoria$jaar >= year_from &
        tbls$territoria$jaar <= year_to &
        tbls$territoria$soort_id %in% species_ids &
        tbls$territoria$territoria > 0,
      c("plot_id", "jaar", "soort_id")
    ])
    if (nrow(obs)) {
      obs$key <- paste(obs$plot_id, obs$jaar, obs$soort_id, sep = "_")
      terr$key <- paste(terr$plot_id, terr$jaar, terr$soort_id, sep = "_")
      obs_without_territory <- obs[!obs$key %in% terr$key, , drop = FALSE]
      obs_count <- nrow(obs_without_territory)
    } else {
      obs_count <- 0L
    }
  }

  first_day <- suppressWarnings(min(visits$dagvanjaar, na.rm = TRUE))
  last_day <- suppressWarnings(max(visits$dagvanjaar, na.rm = TRUE))
  duration_mean <- if ("bezoekduur_min" %in% names(visits)) mean(visits$bezoekduur_min, na.rm = TRUE) else NA_real_
  unfavorable_share <- if ("gunstig" %in% names(visits)) mean(visits$gunstig == 1L, na.rm = TRUE) else NA_real_
  pct_min_visits <- mean(visit_counts$n_bezoeken >= min_visits, na.rm = TRUE) * 100

  summary <- data.frame(
    Maat = c(
      "Plot-jaren met dagbezoeken",
      "Bezoeken",
      "Gem. bezoeken per plot-jaar",
      paste0("Plot-jaren met >= ", min_visits, " bezoeken"),
      "Eerste bezoekdag",
      "Laatste bezoekdag",
      "Gem. bezoekduur (min)",
      "Ongunstige bezoeken",
      "Waarnemingen zonder territorium"
    ),
    Waarde = c(
      nrow(visit_counts),
      nrow(visits),
      round(mean(visit_counts$n_bezoeken, na.rm = TRUE), 2),
      paste0(round(pct_min_visits, 1), "%"),
      if (is.finite(first_day)) first_day else NA,
      if (is.finite(last_day)) last_day else NA,
      if (is.finite(duration_mean)) round(duration_mean, 1) else NA,
      if (is.finite(unfavorable_share)) paste0(round(unfavorable_share * 100, 1), "%") else NA,
      if (is.na(obs_count)) "n.v.t. voor alle soorten zonder specifieke soortselectie" else obs_count
    ),
    check.names = FALSE
  )
  list(summary = summary, site_effort = visit_counts, observations_without_territory = obs_without_territory)
}

add_detection_effort_to_analysis <- function(analyse, tbls, selected_kavels, year_from, year_to, species_ids = NULL, min_visits = 2L) {
  diag <- tryCatch(
    detection_effort_diagnostic(tbls, selected_kavels, year_from, year_to, species_ids = species_ids, min_visits = min_visits),
    error = function(e) list(
      summary = data.frame(Maat = "Melding", Waarde = paste("Telinspanning/detectie niet beschikbaar:", conditionMessage(e)), check.names = FALSE),
      site_effort = data.frame(),
      observations_without_territory = data.frame()
    )
  )
  analyse$detection_effort <- diag$summary
  analyse$detection_site_effort <- diag$site_effort
  analyse$observations_without_territory <- diag$observations_without_territory
  analyse
}

run_occupancy_subset <- function(tbls, selected_kavels, year_from, year_to, selection_type = c("all", "group", "richtlijn", "trait"), selection_value = NULL, min_visits = 2L, detection_covariates = c("dagvanjaar", "bezoekduur_min", "gunstig"), site_covariates = c("year_c")) {
  selection_type <- match.arg(selection_type)
  min_visits <- as.integer(min_visits)[1]
  if (!is.finite(min_visits) || min_visits < 2L) {
    min_visits <- 2L
  }
  if (!requireNamespace("unmarked", quietly = TRUE)) {
    stop("Package 'unmarked' is niet beschikbaar. Installeer het eerst met install.packages('unmarked').")
  }
  cd <- build_community_matrix_subset(tbls, selected_kavels, year_from, year_to, selection_type, selection_value)
  species_ids <- select_species_for_nmds(tbls, selection_type, selection_value)
  visits <- load_dagbezoeken_bmp_lazy(tbls)
  if (is.null(visits) || !nrow(visits)) {
    stop("Geen dagbezoeken/dagwaarnemingen beschikbaar voor detectiegecorrigeerde occupancy.")
  }
  obs <- load_dagwaarnemingen_bmp_lazy(tbls)
  if (!nrow(obs)) {
    stop("Geen dagwaarnemingen beschikbaar voor detectiegecorrigeerde occupancy.")
  }
  plot_ids <- unique(cd$meta$plot_id)
  visits <- visits[
    visits$plot_id %in% plot_ids &
      visits$jaar >= year_from &
      visits$jaar <= year_to,
    , drop = FALSE
  ]
  visits <- visits[order(visits$plot_id, visits$jaar, visits$dagvanjaar, visits$bezoek_id), , drop = FALSE]
  if (nrow(visits) < 20L) {
    stop("Te weinig dagbezoeken voor detectiegecorrigeerde occupancy.")
  }
  obs <- obs[
    obs$bezoek_id %in% visits$bezoek_id &
      obs$soort_id %in% species_ids &
      obs$in_plot %in% c(1L, NA),
    , drop = FALSE
  ]
  detected_visits <- unique(obs$bezoek_id)
  visits$detected <- as.integer(visits$bezoek_id %in% detected_visits)
  visits$site_id <- paste(visits$plot_id, visits$jaar, sep = "_")
  visit_counts <- aggregate(bezoek_id ~ site_id, data = visits, FUN = length)
  visits <- visits[visits$site_id %in% visit_counts$site_id[visit_counts$bezoek_id >= min_visits], , drop = FALSE]
  if (!nrow(visits)) {
    stop(sprintf("Geen plot-jaren met minstens %s dagbezoeken. Detectiecorrectie is dan niet verantwoord.", min_visits))
  }
  site_meta <- unique(visits[, c("site_id", "plot_id", "jaar")])
  site_meta <- merge(
    site_meta,
    cd$meta[, intersect(c("plot_id", "jaar", "kavel_nummer", "stikstof_mean", "ahn_mean", "afstand_pad_m"), names(cd$meta)), drop = FALSE],
    by = c("plot_id", "jaar"),
    all.x = TRUE
  )
  site_meta$year_c <- site_meta$jaar - min(site_meta$jaar, na.rm = TRUE)
  site_meta <- site_meta[order(site_meta$plot_id, site_meta$jaar), , drop = FALSE]
  max_visits <- max(as.integer(table(visits$site_id)))
  y <- matrix(NA_integer_, nrow = nrow(site_meta), ncol = max_visits)
  day_mat <- duration_mat <- favorable_mat <- matrix(NA_real_, nrow = nrow(site_meta), ncol = max_visits)
  rownames(y) <- site_meta$site_id
  for (i in seq_len(nrow(site_meta))) {
    part <- visits[visits$site_id == site_meta$site_id[[i]], , drop = FALSE]
    y[i, seq_len(nrow(part))] <- part$detected
    day_mat[i, seq_len(nrow(part))] <- part$dagvanjaar
    duration_mat[i, seq_len(nrow(part))] <- if ("bezoekduur_min" %in% names(part)) part$bezoekduur_min else NA_real_
    favorable_mat[i, seq_len(nrow(part))] <- if ("gunstig" %in% names(part)) as.integer(part$gunstig == 0L) else NA_real_
  }
  if (sum(y, na.rm = TRUE) == 0L) {
    stop("Geen detecties van de gekozen soortselectie in de dagwaarnemingen.")
  }
  obs_covs <- list()
  det_terms <- character()
  if ("dagvanjaar" %in% detection_covariates && any(is.finite(day_mat))) {
    obs_covs$dagvanjaar <- day_mat
    det_terms <- c(det_terms, "dagvanjaar")
  }
  if ("bezoekduur_min" %in% detection_covariates && any(is.finite(duration_mat))) {
    obs_covs$bezoekduur_min <- duration_mat
    det_terms <- c(det_terms, "bezoekduur_min")
  }
  if ("gunstig" %in% detection_covariates && any(is.finite(favorable_mat))) {
    obs_covs$gunstig_bezoek <- favorable_mat
    det_terms <- c(det_terms, "gunstig_bezoek")
  }
  obs_covs_arg <- if (length(obs_covs)) obs_covs else NULL
  allowed_site_covariates <- c("year_c", "stikstof_mean", "ahn_mean", "afstand_pad_m")
  site_covariates <- unique(site_covariates[site_covariates %in% allowed_site_covariates])
  if (!length(site_covariates)) {
    site_covariates <- "year_c"
  }
  site_covariates <- site_covariates[vapply(site_meta[, site_covariates, drop = FALSE], function(x) {
    vals <- x[is.finite(x)]
    length(vals) >= 3L && stats::var(vals) > 0
  }, logical(1))]
  if (!length(site_covariates)) {
    site_covariates <- "year_c"
  }
  complete_sites <- stats::complete.cases(site_meta[, site_covariates, drop = FALSE])
  site_meta <- site_meta[complete_sites, , drop = FALSE]
  y <- y[complete_sites, , drop = FALSE]
  for (nm in names(obs_covs_arg)) {
    obs_covs_arg[[nm]] <- obs_covs_arg[[nm]][complete_sites, , drop = FALSE]
  }
  if (nrow(site_meta) < 5L || sum(y, na.rm = TRUE) == 0L) {
    stop("Te weinig complete plot-jaren met sitecovariaten voor occupancy.")
  }
  site_cov_data <- site_meta[, site_covariates, drop = FALSE]
  umf <- unmarked::unmarkedFrameOccu(y = y, siteCovs = site_cov_data, obsCovs = obs_covs_arg)
  det_formula <- if (length(det_terms)) paste(det_terms, collapse = " + ") else "1"
  site_formula <- paste(site_covariates, collapse = " + ")
  fit <- unmarked::occu(stats::as.formula(paste0("~ ", det_formula, " ~ ", site_formula)), data = umf)
  coef_tab <- tryCatch({
    parts <- fit@estimates@estimates
    rows <- lapply(names(parts), function(part) {
      est_obj <- parts[[part]]
      est <- est_obj@estimates
      se <- sqrt(diag(est_obj@covMat))
      z <- est / se
      data.frame(
        component = part,
        term = names(est),
        estimate = unname(est),
        std.error = unname(se),
        statistic = unname(z),
        p.value = 2 * stats::pnorm(abs(z), lower.tail = FALSE),
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, rows)
  }, error = function(e) {
    data.frame(component = character(), term = character(), estimate = numeric(), std.error = numeric(), statistic = numeric(), p.value = numeric())
  })
  annual <- aggregate(rowSums(y, na.rm = TRUE) > 0, list(jaar = site_meta$jaar), mean)
  names(annual)[2] <- "naieve_detectie_occupancy"
  annual$n_plot_jaren <- as.integer(table(site_meta$jaar)[as.character(annual$jaar)])
  occ <- data.frame(
    site_id = site_meta$site_id,
    plot_id = site_meta$plot_id,
    kavel_nummer = site_meta$kavel_nummer,
    jaar = site_meta$jaar,
    n_bezoeken = rowSums(!is.na(y)),
    n_detecties = rowSums(y, na.rm = TRUE),
    detected = rowSums(y, na.rm = TRUE) > 0,
    stringsAsFactors = FALSE
  )
  summary_df <- community_summary_df("occupancy", cd, year_from, year_to)
  summary_df$modeltype <- "unmarked_occu_detectiegecorrigeerd"
  summary_df$n_sites_met_herhaalde_bezoeken <- nrow(site_meta)
  summary_df$min_bezoeken <- min_visits
  summary_df$max_bezoeken <- max_visits
  summary_df$detectiecovariaten <- det_formula
  summary_df$sitecovariaten <- site_formula
  summary_df$gemiddelde_occupancy <- mean(occ$detected, na.rm = TRUE)
  analyse <- list(dataset = cd$species_matrix, occupancy = occ, annual = annual, coefficients = coef_tab, summary = summary_df, fit = fit, detection_matrix = y, unmarked_frame = umf)
  add_detection_effort_to_analysis(analyse, tbls, selected_kavels, year_from, year_to, species_ids = species_ids, min_visits = min_visits)
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

lambda_period_specs <- function() {
  data.frame(
    periode = c("1959-1972", "1973-1983", "1984-heden"),
    start_jaar = c(1959L, 1973L, 1984L),
    eind_jaar = c(1972L, 1983L, Inf),
    t0_jaar = c(1959L, 1973L, 1984L),
    kleur = c("#2563eb", "#059669", "#d97706"),
    stringsAsFactors = FALSE
  )
}

classificeer_lambda_status <- function(valid_years, consecutive_pairs, zero_share, positive_years, pre_present = NULL, post_present = NULL, periode_present = NULL) {
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
  if (is.null(periode_present)) {
    periode_present <- c(pre_present, post_present)
  }
  if (valid_years >= 12L &&
      consecutive_pairs >= 10L &&
      zero_share <= 0.33 &&
      all(periode_present %in% TRUE)) {
    return("geschikt_voor_T0_MSI")
  }
  "geschikt_voor_T0_soortanalyse"
}

lambda_status_reason <- function(valid_years, consecutive_pairs, zero_share, positive_years, periode_present = NULL) {
  redenen <- character()
  if (!is.finite(valid_years) || valid_years < 10L) {
    redenen <- c(redenen, sprintf("te weinig geldige jaren (%s)", ifelse(is.finite(valid_years), valid_years, "NA")))
  }
  if (!is.finite(consecutive_pairs) || consecutive_pairs < 2L) {
    redenen <- c(redenen, "minder dan twee opeenvolgende positieve jaren")
  } else if (consecutive_pairs < 8L) {
    redenen <- c(redenen, sprintf("te weinig geldige positieve jaarparen (%s)", consecutive_pairs))
  }
  if (!is.finite(zero_share) || zero_share > 0.50) {
    redenen <- c(redenen, sprintf("nul-aandeel te hoog (%s%%)", ifelse(is.finite(zero_share), round(100 * zero_share, 1), "NA")))
  }
  if (!is.finite(positive_years) || positive_years < 5L) {
    redenen <- c(redenen, sprintf("te weinig positieve jaren (%s)", ifelse(is.finite(positive_years), positive_years, "NA")))
  }
  if (!is.null(periode_present) && length(periode_present) && !all(periode_present %in% TRUE)) {
    redenen <- c(redenen, "niet in alle T0-perioden positief aanwezig")
  }
  if (!length(redenen)) {
    return("bruikbaar volgens huidige criteria")
  }
  paste(redenen, collapse = "; ")
}

bereken_lambda_jaarreeks <- function(df, id_cols, value_col = "count_adjusted") {
  if (!nrow(df)) {
    return(df)
  }

  specs <- lambda_period_specs()
  df <- df[df$jaar >= min(specs$start_jaar), , drop = FALSE]
  if (!nrow(df)) {
    return(df)
  }

  df$periode <- vapply(df$jaar, function(jaar) {
    hit <- specs$periode[jaar >= specs$start_jaar & jaar <= specs$eind_jaar]
    if (length(hit)) hit[[1]] else NA_character_
  }, character(1))
  df <- df[!is.na(df$periode), , drop = FALSE]
  df$periode <- factor(df$periode, levels = specs$periode)
  df$voorkeur_t0_jaar <- specs$t0_jaar[match(as.character(df$periode), specs$periode)]
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
      periode_1959_1972_aanwezig = logical(),
      periode_1973_1983_aanwezig = logical(),
      periode_1984_heden_aanwezig = logical(),
      pre_1984_aanwezig = logical(),
      post_1984_aanwezig = logical(),
      gemiddeld_lambda = numeric(),
      gemiddelde_verandering_pct = numeric(),
      analyse_categorie = character(),
      status_reden = character(),
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
    periode_1959_1972_present <- any(part$periode == "1959-1972" & part$count_adjusted > 0, na.rm = TRUE)
    periode_1973_1983_present <- any(part$periode == "1973-1983" & part$count_adjusted > 0, na.rm = TRUE)
    periode_1984_heden_present <- any(part$periode == "1984-heden" & part$count_adjusted > 0, na.rm = TRUE)
    pre_present <- periode_1959_1972_present || periode_1973_1983_present
    post_present <- periode_1984_heden_present
    periode_present <- c(periode_1959_1972_present, periode_1973_1983_present, periode_1984_heden_present)
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
      periode_1959_1972_aanwezig = periode_1959_1972_present,
      periode_1973_1983_aanwezig = periode_1973_1983_present,
      periode_1984_heden_aanwezig = periode_1984_heden_present,
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
        post_present = post_present,
        periode_present = periode_present
      ),
      status_reden = lambda_status_reason(valid_years, consecutive_pairs, zero_share, positive_years, periode_present),
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

analyse_lambda_richtlijnen_subset <- function(lambda_species, richtlijn_mapping) {
  summary_df <- lambda_species$summary
  yearly_df <- lambda_species$yearly
  empty_index <- data.frame(
    richtlijn_id = integer(),
    richtlijn_titel = character(),
    richtlijn_volgorde = integer(),
    jaar = integer(),
    periode = character(),
    n_soorten = integer(),
    t0_index = numeric(),
    lambda = numeric(),
    log_lambda = numeric(),
    stringsAsFactors = FALSE
  )
  empty_summary <- data.frame(
    richtlijn_id = integer(),
    richtlijn_titel = character(),
    richtlijn_volgorde = integer(),
    eerste_jaar = integer(),
    laatste_jaar = integer(),
    n_indexjaren = integer(),
    geldige_jaarparen = integer(),
    gemiddeld_lambda = numeric(),
    gemiddelde_verandering_pct = numeric(),
    stringsAsFactors = FALSE
  )
  empty_comp <- data.frame(
    richtlijn_id = integer(),
    richtlijn_titel = character(),
    richtlijn_volgorde = integer(),
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
    richtlijn_mapping,
    by = "soort_id",
    all = FALSE
  )

  if (!nrow(merged)) {
    return(list(index = empty_index, summary = empty_summary, composition = empty_comp))
  }

  merged$log_t0_index <- log(merged$t0_index)
  richtlijn_index <- aggregate(
    log_t0_index ~ richtlijn_id + richtlijn_titel + richtlijn_volgorde + jaar + periode,
    data = merged,
    FUN = mean
  )
  n_species <- aggregate(soort_id ~ richtlijn_id + jaar + periode, data = merged, FUN = function(x) length(unique(x)))
  names(n_species)[4] <- "n_soorten"
  richtlijn_index <- merge(richtlijn_index, n_species, by = c("richtlijn_id", "jaar", "periode"), all.x = TRUE)
  richtlijn_index$t0_index <- exp(richtlijn_index$log_t0_index)
  richtlijn_index <- bereken_lambda_jaarreeks(richtlijn_index, id_cols = c("richtlijn_id"), value_col = "t0_index")

  summary_rows <- lapply(split(richtlijn_index, richtlijn_index$richtlijn_id), function(part) {
    mean_log_lambda <- safe_mean(part$log_lambda)
    mean_lambda <- if (is.finite(mean_log_lambda)) exp(mean_log_lambda) else NA_real_
    pct_change <- if (is.finite(mean_log_lambda)) (exp(mean_log_lambda) - 1) * 100 else NA_real_

    data.frame(
      richtlijn_id = part$richtlijn_id[[1]],
      richtlijn_titel = part$richtlijn_titel[[1]],
      richtlijn_volgorde = part$richtlijn_volgorde[[1]],
      eerste_jaar = min(part$jaar, na.rm = TRUE),
      laatste_jaar = max(part$jaar, na.rm = TRUE),
      n_indexjaren = sum(is.finite(part$t0_index), na.rm = TRUE),
      geldige_jaarparen = sum(is.finite(part$lambda), na.rm = TRUE),
      gemiddeld_lambda = mean_lambda,
      gemiddelde_verandering_pct = pct_change,
      stringsAsFactors = FALSE
    )
  })

  composition <- unique(merged[, c("richtlijn_id", "richtlijn_titel", "richtlijn_volgorde", "soort_id", "euring_code", "soort_naam", "engelse_naam")])
  composition <- composition[order(composition$richtlijn_volgorde, composition$soort_naam), , drop = FALSE]

  list(
    index = richtlijn_index[order(richtlijn_index$richtlijn_volgorde, richtlijn_index$jaar), , drop = FALSE],
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
  richtlijn_mapping <- build_richtlijn_mapping(tbls)
  lambda_richtlijnen <- analyse_lambda_richtlijnen_subset(lambda_species, richtlijn_mapping)

  list(
    basis = basis,
    selection = selection_df,
    species_matrix = species_matrix,
    species_results = lambda_species,
    group_results = lambda_groups,
    richtlijn_results = lambda_richtlijnen
  )
}
MEIJENDEL_PARSER_CACHE_VERSION <- 6L
