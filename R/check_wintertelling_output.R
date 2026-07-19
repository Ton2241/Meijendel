#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args)) args[[1L]] else file.path(getwd(), "wintertellingen")

read_required <- function(name) {
  path <- file.path(output_dir, name)
  if (!file.exists(path) || file.info(path)$size <= 0) stop("Ontbrekende winteroutput: ", path)
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

annual <- read_required("winter_jaarindex.csv")
months <- read_required("winter_maandpatroon.csv")
plots <- read_required("winter_plotgebruik.csv")
decisions <- read_required("winter_pilot_besluit.csv")
audit <- read_required("winter_audit_samenvatting.csv")
suitability <- read_required("winter_geschiktheid_alle_soorten.csv")

required_species <- c("Koolmees", "Merel", "Buizerd", "Houtsnip", "Koperwiek",
                      "Tjiftjaf", "Meerkoet", "Kuifeend", "Dodaars", "Aalscholver")
stopifnot(
  nrow(decisions) == length(required_species),
  setequal(decisions$soort_naam, required_species),
  all(decisions$advies %in% c("betrouwbaar", "indicatief", "alleen_beschrijvend")),
  all(decisions$geldige_bezoeken > 0),
  all(decisions$winters == 25),
  nrow(annual) == 25 * length(required_species),
  !anyDuplicated(annual[c("soort_id", "seizoen_start")]),
  setequal(unique(annual$seizoen_start), 2000:2024),
  all(is.finite(annual$index)),
  all(annual$index_ondergrens <= annual$index),
  all(annual$index_bovengrens >= annual$index),
  nrow(months) == 7 * length(required_species),
  !anyDuplicated(months[c("soort_id", "maand")]),
  setequal(unique(months$maand), c("sep", "okt", "nov", "dec", "jan", "feb", "mrt")),
  all(is.finite(months$maandindex)),
  nrow(plots) > 0,
  all(plots$geldige_bezoeken > 0),
  all(plots$waarnemingsfrequentie >= 0 & plots$waarnemingsfrequentie <= 1),
  nrow(audit) >= 10,
  nrow(suitability) >= length(required_species)
)

cat(sprintf(
  "Winteroutput groen: %d soorten, %d jaarindices, %d maandindices, %d plotregels; status %s.\n",
  nrow(decisions), nrow(annual), nrow(months), nrow(plots),
  paste(sprintf("%s=%d", names(table(decisions$advies)), as.integer(table(decisions$advies))), collapse = ", ")
))
