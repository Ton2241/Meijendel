#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(glmmTMB)
  library(MASS)
})

args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args) >= 1L) args[[1L]] else file.path(getwd(), "wintertellingen")
login_path <- if (length(args) >= 2L) args[[2L]] else Sys.getenv("MEIJENDEL_MYSQL_LOGIN_PATH", "meijendel_root")
database <- if (length(args) >= 3L) args[[3L]] else Sys.getenv("MEIJENDEL_MYSQL_DATABASE", "Meijendel")
mysql_host <- Sys.getenv("MEIJENDEL_MYSQL_HOST", "127.0.0.1")
mysql_port <- Sys.getenv("MEIJENDEL_MYSQL_PORT", "3306")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

query_mysql <- function(sql) {
  out <- tempfile(fileext = ".tsv")
  on.exit(unlink(out), add = TRUE)
  status <- system2(
    "mysql",
    c(sprintf("--login-path=%s", login_path), "--protocol=tcp", sprintf("--host=%s", mysql_host),
      sprintf("--port=%s", mysql_port), "--batch", "--raw", database, "--execute", shQuote(sql)),
    stdout = out,
    stderr = out
  )
  if (!identical(status, 0L)) stop("MySQL-query mislukt: ", paste(readLines(out, warn = FALSE), collapse = "\n"))
  read.delim(out, sep = "\t", quote = "", na.strings = "NULL", check.names = FALSE,
             stringsAsFactors = FALSE, encoding = "UTF-8")
}

write_csv <- function(x, name) {
  write.csv(x, file.path(output_dir, name), row.names = FALSE, na = "")
}

season_expr <- "CASE WHEN MONTH(b.bezoek_datum) >= 9 THEN YEAR(b.bezoek_datum) ELSE YEAR(b.bezoek_datum) - 1 END"

visits <- query_mysql(sprintf(
  paste(
    "SELECT b.bezoek_id,b.plot_id,COALESCE(p.kavel_nummer,p.plot_nr,p.plot_id) AS plot_label,",
    "b.bezoek_datum,MONTH(b.bezoek_datum) AS maand,%s AS seizoen_start,",
    "b.bezoekduur_min,b.tellingtype,b.telomschrijving,b.waterstand,b.sneeuw,b.ijs,",
    "a.oppervlakte_km2",
    "FROM dagbezoeken_wv b",
    "JOIN plots p ON p.plot_id=b.plot_id",
    "LEFT JOIN plot_jaar_oppervlak a ON a.plot_id=b.plot_id AND a.jaar=YEAR(b.bezoek_datum)",
    "WHERE (MONTH(b.bezoek_datum)>=9 OR MONTH(b.bezoek_datum)<=3)",
    "AND %s BETWEEN 2000 AND 2024"
  ), season_expr, season_expr
))

counts <- query_mysql(sprintf(
  paste(
    "SELECT w.bezoek_id,w.soort_id,SUM(w.aantal) AS aantal,COUNT(*) AS bronregels,MAX(w.aantal) AS max_bronregel",
    "FROM dagwaarnemingen_wv w",
    "JOIN dagbezoeken_wv b ON b.bezoek_id=w.bezoek_id",
    "WHERE (MONTH(b.bezoek_datum)>=9 OR MONTH(b.bezoek_datum)<=3)",
    "AND %s BETWEEN 2000 AND 2024",
    "GROUP BY w.bezoek_id,w.soort_id"
  ), season_expr
))

species <- query_mysql("SELECT id AS soort_id,euring_code,TRIM(soort_naam) AS soort_naam,TRIM(latijnse_naam) AS latijnse_naam FROM soorten")
families <- query_mysql(paste(
  "SELECT sf.soort_id,GROUP_CONCAT(DISTINCT f.familienaam_nl ORDER BY f.familienaam_nl SEPARATOR '; ') AS familie",
  "FROM soort_familie sf JOIN familie f ON f.id=sf.familie_id GROUP BY sf.soort_id"
))
evg_wetland <- query_mysql("SELECT DISTINCT vogel_id AS soort_id FROM evg_vogel_landschapgroep WHERE groepsnummer IN (100,200)")

# Historische codes die inhoudelijk dezelfde soort representeren. De gebruiker
# heeft Canadese gans expliciet gelijkgesteld aan Grote Canadese Gans.
taxon_map <- data.frame(
  bron_soort_id = c(644L, 646L, 645L),
  soort_id = c(25L, 25L, 158L),
  reden = c("Canadese gans = Grote Canadese Gans", "ondersoort maxima = Grote Canadese Gans",
            "historische Gele Kwikstaart-complexcode = Gele Kwikstaart"),
  stringsAsFactors = FALSE
)
counts$bron_soort_id <- counts$soort_id
mapped <- match(counts$soort_id, taxon_map$bron_soort_id)
counts$soort_id[!is.na(mapped)] <- taxon_map$soort_id[mapped[!is.na(mapped)]]
counts_sum <- aggregate(cbind(aantal, bronregels) ~ bezoek_id + soort_id, data = counts, FUN = sum)
counts_max <- aggregate(max_bronregel ~ bezoek_id + soort_id, data = counts, FUN = max)
counts <- merge(counts_sum, counts_max, by = c("bezoek_id", "soort_id"), sort = FALSE)

source_species <- species
source_species$canoniek_soort_id <- source_species$soort_id
mapped <- match(source_species$soort_id, taxon_map$bron_soort_id)
source_species$canoniek_soort_id[!is.na(mapped)] <- taxon_map$soort_id[mapped[!is.na(mapped)]]
observed_ids <- sort(unique(counts$soort_id))
analysis_species <- species[species$soort_id %in% observed_ids, ]
analysis_species <- merge(analysis_species, families, by = "soort_id", all.x = TRUE, sort = FALSE)

source_ids <- aggregate(soort_id ~ canoniek_soort_id, source_species[source_species$canoniek_soort_id %in% observed_ids, ],
                        FUN = function(x) paste(sort(unique(x)), collapse = ";"))
names(source_ids)[2] <- "bron_soort_ids"
analysis_species <- merge(analysis_species, source_ids, by.x = "soort_id", by.y = "canoniek_soort_id",
                          all.x = TRUE, sort = FALSE)

water_families <- c(
  "Aalscholvers", "Eenden", "Futen", "Ganzen", "Kluten", "Meeuwen",
  "Plevieren", "Rallen", "Reigers", "Scholeksters", "Strandlopers", "Zwanen"
)
water_names <- c(
  "IJsduiker", "Roodkeelduiker", "Jan-van-gent", "Kleine Zilverreiger",
  "Grote Zilverreiger", "Ooievaar", "Zwarte Ooievaar", "Kolgans", "Brandgans",
  "Wilde Zwaan", "Kleine Zwaan", "Smient", "Brilduiker", "Nonnetje",
  "Middelste Zaagbek", "Grote Zaagbek", "IJseend", "Grote toppereend",
  "Zwarte zee-eend", "Grote zee-eend", "Bokje", "Bonte Strandloper",
  "Drieteenstrandloper", "Kanoetstrandloper", "Kleine strandloper",
  "Krombekstrandloper", "Zwarte ruiter", "Groenpootruiter", "Goudplevier",
  "Grutto", "Rosse grutto", "Steenloper", "Watersnip", "Witgat", "Oeverloper",
  "Wulp", "Regenwulp", "Tureluur", "Bosruiter", "IJsvogel", "Baardmannetje",
  "Blauwborst", "Cetti's Zanger", "Kleine Karekiet", "Rietgors", "Oeverpieper",
  "Waterpieper", "Grote Gele Kwikstaart", "Roerdomp", "Porseleinhoen"
)
family_is_water <- vapply(strsplit(ifelse(is.na(analysis_species$familie), "", analysis_species$familie), "; ", fixed = TRUE),
                          function(x) any(x %in% water_families), logical(1))
evg_is_water <- analysis_species$soort_id %in% evg_wetland$soort_id
name_is_water <- analysis_species$soort_naam %in% water_names
analysis_species$soortgroep <- ifelse(family_is_water | evg_is_water | name_is_water, "water_wetland", "overige_vogels")
# Houtsnip staat voor het dashboardfilter bij de overige vogels. Deze ecologische
# indeling heeft geen invloed op de geldigheid van nullen.
analysis_species$soortgroep[analysis_species$soort_naam == "Houtsnip"] <- "overige_vogels"
analysis_species$toewijzingsbron <- ifelse(
  analysis_species$soort_naam == "Houtsnip", "inhoudelijke uitzondering",
  ifelse(evg_is_water, "bestaande EVG-water/rietgroep",
         ifelse(family_is_water, "bestaande soortfamilie",
                ifelse(name_is_water, "expliciete water-/wetlandlijst", "standaard alle vogelsoorten")))
)
analysis_species$protocolgroep <- "alle_volledige_bezoeken"
analysis_species$geldige_tellingtypen <- "Alle vogelsoorten; Watervogels en wetlandsoorten"
analysis_species$telkarakteristiek <- ifelse(
  analysis_species$soortgroep == "water_wetland", "water- of wetlandsoort", "overige vogelsoort"
)
analysis_species <- analysis_species[order(analysis_species$soort_naam), ]

protocol_matrix <- analysis_species[, c(
  "soort_id", "soort_naam", "latijnse_naam", "bron_soort_ids", "familie",
  "soortgroep", "protocolgroep", "geldige_tellingtypen", "toewijzingsbron"
)]
protocol_matrix$matrixversie <- "winterprotocol-v1-technisch"
protocol_matrix$toelichting <- "Volgens de vaste telregel worden tijdens ieder volledig regulier winterbezoek alle waargenomen vogels genoteerd; tellingtype blijft modelcovariaat."
write_csv(protocol_matrix, "winter_soortprotocol.csv")

visits$protocol <- ifelse(grepl("^Alle vogelsoorten", visits$tellingtype), "alle",
                          ifelse(grepl("^Watervogels", visits$tellingtype), "water", "overig"))
visits$volledig <- tolower(visits$telomschrijving) == "volledig"
visits$bezoek_datum <- as.Date(visits$bezoek_datum)
visits$maand_f <- factor(visits$maand, levels = c(9, 10, 11, 12, 1, 2, 3),
                         labels = c("sep", "okt", "nov", "dec", "jan", "feb", "mrt"))
visits$seizoen <- factor(visits$seizoen_start, levels = 2000:2024)
visits$season_c <- visits$seizoen_start - 2000
visits$plot_id <- factor(visits$plot_id)

# Per kavel en wintermaand telt één regulier volledig analysebezoek mee: het
# bezoek dat het dichtst bij de 15e ligt. Enkelvoudige tellingen buiten het
# voorkeursweekend blijven behouden. Bekende bronincidenten worden hieronder
# expliciet en reproduceerbaar afgehandeld.
combine_visit_rules <- data.frame(
  bezoek_id = 8078L,
  doel_bezoek_id = 8079L,
  reden = "telefoonuitval; digitale en handmatige delen vormen samen één telling",
  stringsAsFactors = FALSE
)
preferred_visit_rules <- data.frame(
  bezoek_id = c(4605L, 6036L),
  reden = c(
    "latere correctieregistratie van dubbel ingevoerde telling op 2014-10-11",
    "volledige registratie behouden; bezoek 6037 bevat één dubbele soortregel"
  ),
  stringsAsFactors = FALSE
)
manual_exclusions <- data.frame(
  bezoek_id = integer(),
  reden = character(),
  stringsAsFactors = FALSE
)

rule_ids <- unique(c(
  combine_visit_rules$bezoek_id,
  combine_visit_rules$doel_bezoek_id,
  preferred_visit_rules$bezoek_id,
  manual_exclusions$bezoek_id
))
if (length(rule_ids) && !all(rule_ids %in% visits$bezoek_id)) {
  stop("Minimaal één bezoek-id uit de winterselectieregels ontbreekt in de bron.")
}

combined_match <- match(counts$bezoek_id, combine_visit_rules$bezoek_id)
counts$bezoek_id[!is.na(combined_match)] <-
  combine_visit_rules$doel_bezoek_id[combined_match[!is.na(combined_match)]]
counts_sum <- aggregate(cbind(aantal, bronregels) ~ bezoek_id + soort_id, data = counts, FUN = sum)
counts_max <- aggregate(max_bronregel ~ bezoek_id + soort_id, data = counts, FUN = max)
counts <- merge(counts_sum, counts_max, by = c("bezoek_id", "soort_id"), sort = FALSE)

eligible_visits <- visits[
  visits$volledig &
    visits$protocol %in% c("alle", "water") &
    !visits$bezoek_id %in% combine_visit_rules$bezoek_id &
    !visits$bezoek_id %in% manual_exclusions$bezoek_id,
]
eligible_visits$afstand_maandmidden <-
  abs(as.integer(format(eligible_visits$bezoek_datum, "%d")) - 15L)
eligible_visits$selectiesleutel <- paste(
  eligible_visits$plot_id,
  eligible_visits$seizoen_start,
  eligible_visits$maand,
  sep = ":"
)
eligible_visits <- eligible_visits[order(
  eligible_visits$selectiesleutel,
  eligible_visits$afstand_maandmidden,
  eligible_visits$bezoek_datum,
  eligible_visits$bezoek_id
), ]
selected_ids <- eligible_visits$bezoek_id[!duplicated(eligible_visits$selectiesleutel)]

for (preferred_id in preferred_visit_rules$bezoek_id) {
  preferred_key <- eligible_visits$selectiesleutel[
    match(preferred_id, eligible_visits$bezoek_id)
  ]
  selected_keys <- eligible_visits$selectiesleutel[
    match(selected_ids, eligible_visits$bezoek_id)
  ]
  selected_ids <- c(selected_ids[selected_keys != preferred_key], preferred_id)
}

visits$analyse_geselecteerd <- visits$bezoek_id %in% selected_ids
analysis_visits <- visits[visits$analyse_geselecteerd, ]
expected_incident_selection <- c(4605L, 5382L, 5375L, 5391L, 6036L, 8079L)
if (!all(expected_incident_selection %in% analysis_visits$bezoek_id)) {
  stop("De geselecteerde bezoeken voor bekende meervoudige kavelmaanden wijken af.")
}
duplicate_groups <- table(eligible_visits$selectiesleutel)
duplicate_groups <- sum(duplicate_groups > 1L)
regular_complete_visits <- sum(
  visits$volledig & visits$protocol %in% c("alle", "water")
)

audit <- data.frame(
  kenmerk = c(
    "analyseperiode", "bezoeken_wintermaanden", "volledige_bezoeken", "onvolledige_bezoeken",
    "bezoeken_alle_vogels", "bezoeken_waterprotocol", "bezoeken_overig_protocol",
    "bezoeken_zonder_telduur", "eerste_seizoen", "laatste_volledige_seizoen",
    "volledige_reguliere_bezoeken", "kavelmaanden_met_meerdere_tellingen",
    "samengevoegde_aanvullingsbezoeken", "niet_geselecteerde_meervoudige_bezoeken",
    "handmatig_uitgesloten_afwijkende_teldata", "geselecteerde_analysebezoeken",
    "canonieke_soorten", "samengevoegde_broncodes", "modelversie"
  ),
  waarde = c(
    "2000/01-2024/25", nrow(visits), sum(visits$volledig), sum(!visits$volledig),
    sum(visits$protocol == "alle"), sum(visits$protocol == "water"), sum(visits$protocol == "overig"),
    sum(is.na(visits$bezoekduur_min)), min(visits$seizoen_start), max(visits$seizoen_start),
    regular_complete_visits, duplicate_groups + nrow(combine_visit_rules),
    nrow(combine_visit_rules),
    regular_complete_visits - nrow(combine_visit_rules) - nrow(analysis_visits),
    nrow(manual_exclusions), nrow(analysis_visits),
    nrow(analysis_species), nrow(taxon_map), "winter-alle-soorten-v3-maandselectie"
  ),
  stringsAsFactors = FALSE
)
write_csv(audit, "winter_audit_samenvatting.csv")

coverage <- aggregate(
  cbind(geldige_bezoeken = rep.int(1L, nrow(analysis_visits)),
        geldige_plots = rep.int(1L, nrow(analysis_visits))) ~ seizoen_start + maand,
  data = analysis_visits,
  FUN = sum
)
plot_coverage <- aggregate(plot_id ~ seizoen_start + maand,
                           data = analysis_visits,
                           FUN = function(x) length(unique(x)))
coverage$geldige_plots <- plot_coverage$plot_id[match(
  paste(coverage$seizoen_start, coverage$maand),
  paste(plot_coverage$seizoen_start, plot_coverage$maand)
)]
coverage$seizoen <- sprintf("%02d/%02d", coverage$seizoen_start %% 100, (coverage$seizoen_start + 1) %% 100)
write_csv(coverage, "winter_dekking.csv")

positive_scan <- merge(counts, analysis_species[, c("soort_id", "soort_naam", "soortgroep", "protocolgroep")], by = "soort_id", all.x = TRUE)
positive_scan <- merge(
  positive_scan,
  analysis_visits[, c("bezoek_id", "seizoen_start", "plot_id")],
  by = "bezoek_id"
)
positive_stats <- do.call(rbind, lapply(split(positive_scan, positive_scan$soort_id), function(x) {
  data.frame(
    soort_id = x$soort_id[[1]],
    winters_met_detectie = length(unique(x$seizoen_start)),
    bezoeken_met_detectie = length(unique(x$bezoek_id)),
    plots_met_detectie = length(unique(x$plot_id)),
    totaal_geregistreerd = sum(x$aantal), maximum_bezoektotaal = max(x$aantal),
    stringsAsFactors = FALSE
  )
}))
suitability <- merge(
  analysis_species[, c("soort_id", "soort_naam")],
  positive_stats,
  by = "soort_id",
  all.x = TRUE,
  sort = FALSE
)
stat_columns <- c(
  "winters_met_detectie", "bezoeken_met_detectie", "plots_met_detectie",
  "totaal_geregistreerd", "maximum_bezoektotaal"
)
for (column in stat_columns) suitability[[column]][is.na(suitability[[column]])] <- 0
suitability$voorlopige_klasse <- with(suitability, ifelse(
  winters_met_detectie >= 20 & bezoeken_met_detectie >= 300 & plots_met_detectie >= 15, "kansrijk",
  ifelse(winters_met_detectie >= 15 & bezoeken_met_detectie >= 100, "nader_beoordelen", "alleen_beschrijvend")
))
suitability$protocolgroep <- analysis_species$protocolgroep[match(suitability$soort_id, analysis_species$soort_id)]
suitability$soortgroep <- analysis_species$soortgroep[match(suitability$soort_id, analysis_species$soort_id)]
suitability$opmerking <- ifelse(
  suitability$voorlopige_klasse == "alleen_beschrijvend",
  "Onvoldoende positieve bezoeken of winters voor de volledige modelvalidatie; beschrijvende uitvoer blijft beschikbaar.",
  "Door naar volledige aantals-, detectie-, extremen-, telduur- en convergentiecontrole."
)
suitability <- suitability[order(suitability$voorlopige_klasse, -suitability$bezoeken_met_detectie), ]
write_csv(suitability, "winter_geschiktheid_alle_soorten.csv")

safe_fit <- function(formula, data, family) {
  tryCatch(
    glmmTMB(formula, data = data, family = family,
            control = glmmTMBControl(optCtrl = list(iter.max = 1000, eval.max = 1000))),
    error = function(e) structure(list(error = conditionMessage(e)), class = "winter_fit_error")
  )
}

fit_ok <- function(model) {
  !inherits(model, "winter_fit_error") && isTRUE(model$sdr$pdHess) && model$fit$convergence == 0
}

fixed_draws <- function(model, newdata, fixed_formula, n = 600L) {
  beta <- fixef(model)$cond
  vc <- as.matrix(vcov(model)$cond)
  Xraw <- model.matrix(fixed_formula, newdata)
  X <- matrix(0, nrow = nrow(Xraw), ncol = length(beta), dimnames = list(NULL, names(beta)))
  shared <- intersect(colnames(Xraw), names(beta))
  X[, shared] <- Xraw[, shared, drop = FALSE]
  set.seed(20260719)
  draws <- MASS::mvrnorm(n, mu = beta, Sigma = vc)
  list(X = X, draws = draws)
}

predict_balanced <- function(model, data, response = c("count", "binary")) {
  response <- match.arg(response)
  seasons <- sort(unique(data$seizoen_start))
  months <- levels(data$maand_f)
  reference_protocol <- if ("alle" %in% data$protocol) "alle" else levels(data$protocol)[1]
  nd <- expand.grid(
    seizoen_start = seasons, maand_f = months, protocol = reference_protocol,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  nd$seizoen <- factor(nd$seizoen_start, levels = levels(data$seizoen))
  nd$maand_f <- factor(nd$maand_f, levels = levels(data$maand_f))
  nd$protocol <- factor(nd$protocol, levels = levels(data$protocol))
  fixed_formula <- if (nlevels(droplevels(data$protocol)) > 1L) {
    ~ seizoen + maand_f + protocol
  } else {
    ~ seizoen + maand_f
  }
  sim <- fixed_draws(model, nd, fixed_formula)
  link <- sim$X %*% t(sim$draws)
  values <- if (response == "count") exp(link) else plogis(link)
  by_season <- lapply(seasons, function(s) {
    idx <- nd$seizoen_start == s
    colMeans(values[idx, , drop = FALSE])
  })
  raw <- vapply(by_season, mean, numeric(1))
  lower <- vapply(by_season, quantile, numeric(1), probs = 0.025, names = FALSE)
  upper <- vapply(by_season, quantile, numeric(1), probs = 0.975, names = FALSE)
  ref_idx <- which(seasons %in% 2000:2004)
  index_draws <- do.call(rbind, by_season)
  ref <- colMeans(index_draws[ref_idx, , drop = FALSE])
  valid_draws <- is.finite(ref) & ref > 0 & apply(index_draws, 2, function(x) all(is.finite(x)))
  if (sum(valid_draws) < 100L) stop("Te weinig geldige simulaties voor indexnormalisatie.")
  index_draws <- index_draws[, valid_draws, drop = FALSE]
  ref <- ref[valid_draws]
  index_draws <- sweep(index_draws, 2, ref, "/") * 100
  data.frame(
    seizoen_start = seasons, schatting = raw, ondergrens = lower, bovengrens = upper,
    index = rowMeans(index_draws), index_ondergrens = apply(index_draws, 1, quantile, 0.025),
    index_bovengrens = apply(index_draws, 1, quantile, 0.975),
    stringsAsFactors = FALSE
  )
}

predict_months <- function(model, data, response = c("count", "binary")) {
  response <- match.arg(response)
  seasons <- sort(unique(data$seizoen_start))
  months <- levels(data$maand_f)
  reference_protocol <- if ("alle" %in% data$protocol) "alle" else levels(data$protocol)[1]
  nd <- expand.grid(
    seizoen_start = seasons, maand_f = months, protocol = reference_protocol,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  nd$seizoen <- factor(nd$seizoen_start, levels = levels(data$seizoen))
  nd$maand_f <- factor(nd$maand_f, levels = levels(data$maand_f))
  nd$protocol <- factor(nd$protocol, levels = levels(data$protocol))
  fixed_formula <- if (nlevels(droplevels(data$protocol)) > 1L) {
    ~ seizoen + maand_f + protocol
  } else {
    ~ seizoen + maand_f
  }
  sim <- fixed_draws(model, nd, fixed_formula)
  link <- sim$X %*% t(sim$draws)
  values <- if (response == "count") exp(link) else plogis(link)
  do.call(rbind, lapply(months, function(m) {
    vals <- colMeans(values[nd$maand_f == m, , drop = FALSE])
    data.frame(maand = m, schatting = mean(vals), ondergrens = quantile(vals, 0.025),
               bovengrens = quantile(vals, 0.975), stringsAsFactors = FALSE)
  }))
}

trend_percent <- function(model, term = "season_c") {
  if (!fit_ok(model) || !term %in% names(fixef(model)$cond)) return(c(estimate = NA, lower = NA, upper = NA))
  b <- fixef(model)$cond[[term]]
  se <- sqrt(vcov(model)$cond[term, term])
  100 * (exp(c(estimate = b, lower = b - 1.96 * se, upper = b + 1.96 * se)) - 1)
}

annual_out <- list()
month_out <- list()
plot_out <- list()
decision_out <- list()

empty_trend <- c(estimate = NA_real_, lower = NA_real_, upper = NA_real_)

for (i in seq_len(nrow(analysis_species))) {
  sp <- analysis_species[i, ]
  message(sprintf("Winteranalyse %d/%d: %s", i, nrow(analysis_species), sp$soort_naam))
  dat <- analysis_visits
  cnt <- counts[counts$soort_id == sp$soort_id, c("bezoek_id", "aantal", "bronregels", "max_bronregel")]
  dat <- merge(dat, cnt, by = "bezoek_id", all.x = TRUE, sort = FALSE)
  dat$aantal[is.na(dat$aantal)] <- 0
  dat$bronregels[is.na(dat$bronregels)] <- 0
  dat$detectie <- as.integer(dat$aantal > 0)
  dat$protocol <- factor(dat$protocol)
  dat$plot_id <- factor(dat$plot_id)
  dat$seizoen <- factor(dat$seizoen_start, levels = sort(unique(dat$seizoen_start)))
  dat$maand_f <- factor(dat$maand_f, levels = c("sep", "okt", "nov", "dec", "jan", "feb", "mrt"))

  preliminary <- suitability$voorlopige_klasse[match(sp$soort_id, suitability$soort_id)]
  model_tested <- preliminary != "alleen_beschrijvend"
  count_model <- binary_model <- trend_count <- trend_binary <- trend_trim <- trend_short <-
    structure(list(error = "niet getest wegens onvoldoende dekking"), class = "winter_fit_error")
  tc <- tb <- tt <- ts <- empty_trend
  same_direction <- robust_extremes <- robust_duration <- models_converged <- core_ok <- prediction_ok <- FALSE

  if (model_tested) {
    has_protocol_contrast <- nlevels(droplevels(dat$protocol)) > 1L
    count_formula <- if (has_protocol_contrast) aantal ~ seizoen + maand_f + protocol + (1 | plot_id) else aantal ~ seizoen + maand_f + (1 | plot_id)
    binary_formula <- if (has_protocol_contrast) detectie ~ seizoen + maand_f + protocol + (1 | plot_id) else detectie ~ seizoen + maand_f + (1 | plot_id)
    trend_count_formula <- if (has_protocol_contrast) aantal ~ season_c + maand_f + protocol + (1 | plot_id) else aantal ~ season_c + maand_f + (1 | plot_id)
    trend_binary_formula <- if (has_protocol_contrast) detectie ~ season_c + maand_f + protocol + (1 | plot_id) else detectie ~ season_c + maand_f + (1 | plot_id)
    count_model <- safe_fit(count_formula, dat, nbinom2())
    binary_model <- safe_fit(binary_formula, dat, binomial())
    trend_count <- safe_fit(trend_count_formula, dat, nbinom2())
    trend_binary <- safe_fit(trend_binary_formula, dat, binomial())
    cap <- max(1, floor(as.numeric(quantile(dat$aantal, 0.99, names = FALSE))))
    dat$aantal_trim <- pmin(dat$aantal, cap)
    trend_trim_formula <- if (has_protocol_contrast) aantal_trim ~ season_c + maand_f + protocol + (1 | plot_id) else aantal_trim ~ season_c + maand_f + (1 | plot_id)
    trend_trim <- safe_fit(trend_trim_formula, dat, nbinom2())
    short <- dat[dat$seizoen_start >= 2012 & !is.na(dat$bezoekduur_min) & dat$bezoekduur_min > 0, ]
    short_formula <- if (has_protocol_contrast) aantal ~ season_c + maand_f + protocol + log1p(bezoekduur_min) + (1 | plot_id) else aantal ~ season_c + maand_f + log1p(bezoekduur_min) + (1 | plot_id)
    trend_short <- if (nrow(short) >= 300) safe_fit(short_formula, short, nbinom2()) else trend_short

    tc <- trend_percent(trend_count)
    tb <- trend_percent(trend_binary)
    tt <- trend_percent(trend_trim)
    ts <- trend_percent(trend_short)
    same_direction <- is.finite(tc[["estimate"]]) && is.finite(tb[["estimate"]]) &&
      (abs(tc[["estimate"]]) < 0.5 || abs(tb[["estimate"]]) < 0.25 || sign(tc[["estimate"]]) == sign(tb[["estimate"]]))
    robust_extremes <- is.finite(tt[["estimate"]]) && abs(tc[["estimate"]] - tt[["estimate"]]) <= 2.0
    robust_duration <- !is.finite(ts[["estimate"]]) || abs(tc[["estimate"]] - ts[["estimate"]]) <= 3.0
    models_converged <- fit_ok(count_model) && fit_ok(binary_model) && fit_ok(trend_count) && fit_ok(trend_binary)
    core_ok <- models_converged
  }

  model_annual <- model_month <- NULL
  if (core_ok) {
    predicted <- tryCatch({
      ai <- predict_balanced(count_model, dat, "count")
      bi <- predict_balanced(binary_model, dat, "binary")
      ai <- merge(ai, bi[, c("seizoen_start", "schatting", "ondergrens", "bovengrens")],
                  by = "seizoen_start", suffixes = c("_aantal", "_detectie"))
      cm <- predict_months(count_model, dat, "count")
      bm <- predict_months(binary_model, dat, "binary")
      names(cm)[2:4] <- paste0(c("schatting", "ondergrens", "bovengrens"), "_aantal")
      names(bm)[2:4] <- paste0(c("schatting", "ondergrens", "bovengrens"), "_detectie")
      mo <- merge(cm, bm, by = "maand")
      month_ref <- mean(mo$schatting_aantal)
      mo$maandindex <- if (is.finite(month_ref) && month_ref > 0) 100 * mo$schatting_aantal / month_ref else NA_real_
      list(annual = ai, month = mo)
    }, error = function(e) NULL)
    prediction_ok <- !is.null(predicted) &&
      all(is.finite(predicted$annual$index)) &&
      all(is.finite(predicted$annual$index_ondergrens)) &&
      all(is.finite(predicted$annual$index_bovengrens)) &&
      all(is.finite(predicted$month$maandindex))
    if (prediction_ok) {
      model_annual <- predicted$annual
      model_month <- predicted$month
    }
  }

  core_ok <- core_ok && prediction_ok
  klasse <- if (core_ok && same_direction && robust_extremes && robust_duration && sum(dat$detectie) >= 200) {
    "betrouwbaar"
  } else if (core_ok && sum(dat$detectie) >= 100) {
    "indicatief"
  } else {
    "alleen_beschrijvend"
  }
  reden_status <- if (!model_tested) {
    "onvoldoende winters of positieve bezoeken voor volledige modelvalidatie"
  } else if (!core_ok) {
    "minimaal één kernmodel, Hessiaan of voorspelling is niet stabiel"
  } else if (klasse == "betrouwbaar") {
    "kernmodellen en gevoeligheidscontroles groen"
  } else {
    "kernmodellen bruikbaar; minimaal één gevoeligheidscontrole vraagt terughoudendheid"
  }

  raw_annual <- aggregate(cbind(totaal_aantal = dat$aantal, detecties = dat$detectie) ~ seizoen_start,
                          data = dat, FUN = sum)
  raw_visits <- aggregate(bezoek_id ~ seizoen_start, data = dat, FUN = length)
  names(raw_visits)[2] <- "geldige_bezoeken"
  raw_plots <- aggregate(plot_id ~ seizoen_start, data = dat, FUN = function(x) length(unique(x)))
  names(raw_plots)[2] <- "geldige_plots"
  ai <- Reduce(function(x, y) merge(x, y, by = "seizoen_start", all = TRUE),
               list(raw_annual, raw_visits, raw_plots))
  ai$gemiddeld_per_bezoek <- ai$totaal_aantal / ai$geldige_bezoeken
  ai$waarnemingsfrequentie <- ai$detecties / ai$geldige_bezoeken
  for (nm in c("index", "index_ondergrens", "index_bovengrens", "schatting_aantal",
               "ondergrens_aantal", "bovengrens_aantal", "schatting_detectie",
               "ondergrens_detectie", "bovengrens_detectie")) ai[[nm]] <- NA_real_
  if (!is.null(model_annual)) {
    pos <- match(ai$seizoen_start, model_annual$seizoen_start)
    for (nm in c("index", "index_ondergrens", "index_bovengrens", "schatting_aantal",
                 "ondergrens_aantal", "bovengrens_aantal", "schatting_detectie",
                 "ondergrens_detectie", "bovengrens_detectie")) ai[[nm]] <- model_annual[[nm]][pos]
  }
  ai$soort_id <- sp$soort_id
  ai$soort_naam <- sp$soort_naam
  ai$seizoen <- sprintf("%02d/%02d", ai$seizoen_start %% 100, (ai$seizoen_start + 1) %% 100)
  ai$modelstatus <- klasse
  ai$weergavetype <- ifelse(klasse == "alleen_beschrijvend", "beschrijvend", "modelindex")
  annual_out[[length(annual_out) + 1L]] <- ai

  raw_month <- aggregate(cbind(totaal_aantal = dat$aantal, detecties = dat$detectie) ~ maand_f,
                         data = dat, FUN = sum)
  raw_month_visits <- aggregate(bezoek_id ~ maand_f, data = dat, FUN = length)
  names(raw_month_visits)[2] <- "geldige_bezoeken"
  mo <- merge(raw_month, raw_month_visits, by = "maand_f", all = TRUE)
  names(mo)[1] <- "maand"
  mo$maand <- as.character(mo$maand)
  mo$gemiddeld_per_bezoek <- mo$totaal_aantal / mo$geldige_bezoeken
  mo$waarnemingsfrequentie <- mo$detecties / mo$geldige_bezoeken
  for (nm in c("schatting_aantal", "ondergrens_aantal", "bovengrens_aantal",
               "schatting_detectie", "ondergrens_detectie", "bovengrens_detectie", "maandindex")) mo[[nm]] <- NA_real_
  if (!is.null(model_month)) {
    pos <- match(mo$maand, model_month$maand)
    for (nm in c("schatting_aantal", "ondergrens_aantal", "bovengrens_aantal",
                 "schatting_detectie", "ondergrens_detectie", "bovengrens_detectie", "maandindex")) mo[[nm]] <- model_month[[nm]][pos]
  }
  mo$soort_id <- sp$soort_id
  mo$soort_naam <- sp$soort_naam
  mo$modelstatus <- klasse
  mo$weergavetype <- ifelse(klasse == "alleen_beschrijvend", "beschrijvend", "modelindex")
  month_out[[length(month_out) + 1L]] <- mo

  pl <- aggregate(cbind(totaal_aantal = dat$aantal, detecties = dat$detectie) ~ plot_id + plot_label,
                  data = dat, FUN = sum)
  nv <- aggregate(bezoek_id ~ plot_id + plot_label, data = dat, FUN = length)
  names(nv)[3] <- "geldige_bezoeken"
  pl <- merge(pl, nv, by = c("plot_id", "plot_label"))
  pl$gemiddeld_per_bezoek <- pl$totaal_aantal / pl$geldige_bezoeken
  pl$waarnemingsfrequentie <- pl$detecties / pl$geldige_bezoeken
  pl$soort_id <- sp$soort_id
  pl$soort_naam <- sp$soort_naam
  pl$modelstatus <- klasse
  plot_out[[length(plot_out) + 1L]] <- pl

  decision_out[[length(decision_out) + 1L]] <- data.frame(
    soort_id = sp$soort_id, soort_naam = sp$soort_naam,
    soortgroep = sp$soortgroep, protocolgroep = sp$protocolgroep, telkarakteristiek = sp$telkarakteristiek,
    bron_soort_ids = sp$bron_soort_ids, voorlopige_klasse = preliminary,
    geldige_bezoeken = nrow(dat), detecties = sum(dat$detectie),
    winters = length(unique(dat$seizoen_start)), plots = length(unique(dat$plot_id)),
    maximum_bezoektotaal = max(dat$aantal), pct_nul = 100 * mean(dat$aantal == 0),
    trend_aantal_pct_per_jaar = tc[["estimate"]], trend_aantal_laag = tc[["lower"]], trend_aantal_hoog = tc[["upper"]],
    trend_detectie_pct_per_jaar = tb[["estimate"]], trend_detectie_laag = tb[["lower"]], trend_detectie_hoog = tb[["upper"]],
    trend_getrimd_pct_per_jaar = tt[["estimate"]], trend_vanaf_2012_pct_per_jaar = ts[["estimate"]],
    zelfde_trendrichting = same_direction, robuust_tegen_extremen = robust_extremes,
    robuust_met_telduur = robust_duration, modellen_geconvergeerd = models_converged,
    voorspellingen_geldig = prediction_ok,
    model_getest = model_tested, advies = klasse, reden_status = reden_status,
    stringsAsFactors = FALSE
  )

  if (i %% 10L == 0L) gc(verbose = FALSE)
}

annual <- do.call(rbind, annual_out)
months <- do.call(rbind, month_out)
plots <- do.call(rbind, plot_out)
decisions <- do.call(rbind, decision_out)

annual <- annual[, c(
  "soort_id", "soort_naam", "seizoen_start", "seizoen", "index", "index_ondergrens", "index_bovengrens",
  "schatting_aantal", "ondergrens_aantal", "bovengrens_aantal", "schatting_detectie", "ondergrens_detectie",
  "bovengrens_detectie", "totaal_aantal", "gemiddeld_per_bezoek", "waarnemingsfrequentie",
  "geldige_bezoeken", "geldige_plots", "detecties", "modelstatus", "weergavetype"
)]
write_csv(annual, "winter_jaarindex.csv")
write_csv(months, "winter_maandpatroon.csv")
write_csv(plots, "winter_plotgebruik.csv")
write_csv(decisions, "winter_pilot_besluit.csv")

cat(sprintf("Winteranalyse gereed: %d soorten, %d jaarregels, %d maandregels.\n",
            nrow(decisions), nrow(annual), nrow(months)))
