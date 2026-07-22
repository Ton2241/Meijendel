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
protocols <- read_required("winter_soortprotocol.csv")

required_species <- c("Koolmees", "Merel", "Buizerd", "Houtsnip", "Koperwiek",
                      "Tjiftjaf", "Meerkoet", "Kuifeend", "Dodaars", "Aalscholver")
stopifnot(
  nrow(decisions) >= 200,
  all(required_species %in% decisions$soort_naam),
  nrow(protocols) == nrow(decisions),
  nrow(suitability) == nrow(decisions),
  !anyDuplicated(decisions$soort_id),
  !anyDuplicated(decisions$soort_naam),
  !anyDuplicated(protocols$soort_id),
  all(decisions$advies %in% c("betrouwbaar", "indicatief", "alleen_beschrijvend")),
  all(decisions$modellen_geconvergeerd[decisions$advies %in% c("betrouwbaar", "indicatief")]),
  all(decisions$voorspellingen_geldig[decisions$advies %in% c("betrouwbaar", "indicatief")]),
  all(decisions$protocolgroep == "alle_volledige_bezoeken"),
  all(decisions$soortgroep %in% c("overige_vogels", "water_wetland")),
  all(decisions$geldige_bezoeken > 0),
  all(decisions$winters == 25),
  nrow(annual) == 25 * nrow(decisions),
  !anyDuplicated(annual[c("soort_id", "seizoen_start")]),
  setequal(unique(annual$seizoen_start), 2000:2024),
  all(is.finite(annual$gemiddeld_per_bezoek)),
  all(annual$waarnemingsfrequentie >= 0 & annual$waarnemingsfrequentie <= 1),
  all(is.finite(annual$index[annual$modelstatus %in% c("betrouwbaar", "indicatief")])),
  all(annual$index_ondergrens[annual$modelstatus %in% c("betrouwbaar", "indicatief")] <= annual$index[annual$modelstatus %in% c("betrouwbaar", "indicatief")]),
  all(annual$index_bovengrens[annual$modelstatus %in% c("betrouwbaar", "indicatief")] >= annual$index[annual$modelstatus %in% c("betrouwbaar", "indicatief")]),
  nrow(months) == 7 * nrow(decisions),
  !anyDuplicated(months[c("soort_id", "maand")]),
  setequal(unique(months$maand), c("sep", "okt", "nov", "dec", "jan", "feb", "mrt")),
  all(is.finite(months$gemiddeld_per_bezoek)),
  all(months$waarnemingsfrequentie >= 0 & months$waarnemingsfrequentie <= 1),
  all(is.finite(months$maandindex[months$modelstatus %in% c("betrouwbaar", "indicatief")])),
  nrow(plots) > 0,
  all(plots$geldige_bezoeken > 0),
  all(plots$waarnemingsfrequentie >= 0 & plots$waarnemingsfrequentie <= 1),
  nrow(audit) >= 10,
  all(protocols$matrixversie == "winterprotocol-v1-technisch"),
  all(protocols$protocolgroep == "alle_volledige_bezoeken"),
  all(protocols$geldige_tellingtypen == "Alle vogelsoorten; Watervogels en wetlandsoorten"),
  "Grote Canadese Gans" %in% decisions$soort_naam,
  !any(decisions$soort_naam %in% c("Canadese gans spec.", "Grote Canadese gans (maxima)")),
  grepl("25", protocols$bron_soort_ids[protocols$soort_naam == "Grote Canadese Gans"]),
  grepl("644", protocols$bron_soort_ids[protocols$soort_naam == "Grote Canadese Gans"]),
  grepl("646", protocols$bron_soort_ids[protocols$soort_naam == "Grote Canadese Gans"])
)

cat(sprintf(
  "Winteroutput groen: %d soorten, %d jaarregels, %d maandregels, %d plotregels; status %s.\n",
  nrow(decisions), nrow(annual), nrow(months), nrow(plots),
  paste(sprintf("%s=%d", names(table(decisions$advies)), as.integer(table(decisions$advies))), collapse = ", ")
))
