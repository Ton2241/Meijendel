args <- commandArgs(trailingOnly = TRUE)

user_lib <- file.path(Sys.getenv("HOME"), "Library/R/arm64/4.5/library")
if (dir.exists(user_lib)) {
  .libPaths(c(user_lib, .libPaths()))
}

suppressPackageStartupMessages(library(mgcv))

sql_path <- if (length(args) >= 1L) args[[1]] else "/Users/ton/Documents/GitHub/Meijendel/Meijendel.sql"
out_dir <- if (length(args) >= 2L) args[[2]] else "/Users/ton/Documents/GitHub/Meijendel/trim_msi_evg"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

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

  c(fields, substring(tuple_text, start, n))
}

decode_sql_value <- function(x) {
  x <- trimws(x)
  if (identical(x, "NULL")) return(NA_character_)
  if (nchar(x) >= 2L && substr(x, 1L, 1L) == "'" && substr(x, nchar(x), nchar(x)) == "'") {
    x <- substring(x, 2L, nchar(x) - 1L)
    x <- gsub("\\\\'", "'", x)
    x <- gsub("\\\\\\\\", "\\\\", x)
  }
  x
}

read_insert_table <- function(path, table, keep_columns = NULL) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  prefix <- paste0("INSERT INTO `", table, "` ")
  starts <- which(startsWith(lines, prefix))
  if (!length(starts)) stop(sprintf("Geen INSERT-blokken gevonden voor tabel '%s'.", table))

  out <- list()
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
    rows <- lapply(tuples, function(tuple) vapply(split_fields(tuple), decode_sql_value, character(1)))
    df <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
    names(df) <- columns
    if (!is.null(keep_columns)) df <- df[keep_columns]
    out[[length(out) + 1L]] <- df
  }

  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

make_group_titles <- function(evg_groepen) {
  groep_100 <- sort(unique((evg_groepen$groepsnummer %/% 100L) * 100L))
  data.frame(
    groep_100 = groep_100,
    groep_titel = vapply(groep_100, function(g) {
      rows <- evg_groepen[(evg_groepen$groepsnummer %/% 100L) * 100L == g, , drop = FALSE]
      rows$landschap_groep[which.min(rows$groepsnummer)]
    }, character(1)),
    stringsAsFactors = FALSE
  )
}

build_landelijke_msi <- function(trends, evg_groepen, evg_koppeling) {
  mapping <- unique(data.frame(
    soort_id = evg_koppeling$vogel_id,
    groep_100 = (evg_koppeling$groepsnummer %/% 100L) * 100L,
    stringsAsFactors = FALSE
  ))
  mapping <- merge(mapping, make_group_titles(evg_groepen), by = "groep_100", all.x = TRUE)

  landelijke <- trends[trends$regio == "Landelijk" & is.finite(trends$waarde) & trends$waarde > 0, ]
  landelijke <- merge(landelijke, mapping, by = "soort_id", all.x = FALSE)

  soort_index <- do.call(
    rbind,
    lapply(split(landelijke, paste(landelijke$groep_100, landelijke$soort_id, sep = "_")), function(df) {
      df <- df[order(df$jaar), ]
      base <- df$waarde[[1]]
      if (!is.finite(base) || base <= 0) return(NULL)
      df$index_100 <- 100 * df$waarde / base
      df
    })
  )

  msi <- aggregate(log(index_100) ~ groep_100 + groep_titel + jaar, data = soort_index, FUN = mean, na.rm = TRUE)
  names(msi)[names(msi) == "log(index_100)"] <- "log_index"
  n_soorten <- aggregate(soort_id ~ groep_100 + jaar, data = soort_index, FUN = function(x) length(unique(x)))
  names(n_soorten)[3] <- "n_soorten"
  msi <- merge(msi, n_soorten, by = c("groep_100", "jaar"), all.x = TRUE)
  msi$msi <- exp(msi$log_index)
  msi$periode <- "Landelijk"
  msi[order(msi$groep_100, msi$jaar), ]
}

fit_gam_msi <- function(msi) {
  out <- list()

  for (g in sort(unique(msi$groep_100))) {
    df <- msi[msi$groep_100 == g, ]
    df <- df[order(df$jaar), ]
    df$log_msi <- log(df$msi)
    k_value <- max(3L, min(8L, nrow(df) - 1L))

    fit <- tryCatch(
      mgcv::gam(log_msi ~ s(jaar, k = k_value), data = df, method = "REML"),
      error = function(e) NULL
    )

    if (is.null(fit)) {
      df$gam_fit_log <- NA_real_
      df$gam_fit_se <- NA_real_
    } else {
      pred <- predict(fit, newdata = df, se.fit = TRUE, type = "link")
      df$gam_fit_log <- as.numeric(pred$fit)
      df$gam_fit_se <- as.numeric(pred$se.fit)
    }

    df$gam_fit_msi <- exp(df$gam_fit_log)
    df$gam_fit_lower <- exp(df$gam_fit_log - 1.96 * df$gam_fit_se)
    df$gam_fit_upper <- exp(df$gam_fit_log + 1.96 * df$gam_fit_se)
    out[[as.character(g)]] <- df
  }

  do.call(rbind, out)
}

trends <- read_insert_table(sql_path, "trends", c("soort_id", "regio", "jaar", "waarde"))
evg_groepen <- read_insert_table(sql_path, "evg_vogelgroepen", c("groepsnummer", "landschap_groep"))
evg_koppeling <- read_insert_table(sql_path, "evg_vogel_landschapgroep", c("groepsnummer", "vogel_id"))

trends$soort_id <- as.integer(trends$soort_id)
trends$jaar <- as.integer(trends$jaar)
trends$waarde <- as.numeric(trends$waarde)
evg_groepen$groepsnummer <- as.integer(evg_groepen$groepsnummer)
evg_koppeling$groepsnummer <- as.integer(evg_koppeling$groepsnummer)
evg_koppeling$vogel_id <- as.integer(evg_koppeling$vogel_id)

landelijke_msi <- build_landelijke_msi(trends, evg_groepen, evg_koppeling)
landelijke_gam <- fit_gam_msi(landelijke_msi)

write.csv(landelijke_msi, file.path(out_dir, "msi_landelijk_per_groep_per_jaar.csv"), row.names = FALSE)
write.csv(landelijke_gam, file.path(out_dir, "gam_voorspellingen_landelijk_msi_groepen.csv"), row.names = FALSE)

cat("Klaar.\n")
cat("Landelijke MSI-output:", out_dir, "\n")
