#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(glmmTMB)
  library(MASS)
})

args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args) >= 1L) args[[1L]] else file.path(getwd(), "wintertellingen")
login_path <- if (length(args) >= 2L) args[[2L]] else Sys.getenv("MEIJENDEL_MYSQL_LOGIN_PATH", "meijendel_root")
database <- if (length(args) >= 3L) args[[3L]] else Sys.getenv("MEIJENDEL_MYSQL_DATABASE", "Meijendel")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

query_mysql <- function(sql) {
  out <- tempfile(fileext = ".tsv")
  on.exit(unlink(out), add = TRUE)
  status <- system2(
    "mysql",
    c(sprintf("--login-path=%s", login_path), "--batch", "--raw", database, "--execute", shQuote(sql)),
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

species <- query_mysql("SELECT id AS soort_id,euring_code,soort_naam,latijnse_naam FROM soorten")

pilot <- data.frame(
  soort_naam = c("Koolmees", "Merel", "Buizerd", "Houtsnip", "Koperwiek",
                 "Tjiftjaf", "Meerkoet", "Kuifeend", "Dodaars", "Aalscholver"),
  protocolgroep = c(rep("land", 6), rep("water", 4)),
  telkarakteristiek = c(
    "algemene landvogel", "algemene landvogel", "zichtbare soort met lage aantallen",
    "cryptische soort", "fluctuerende groepsvogel", "sterk seizoensgebonden soort",
    "algemene watervogel", "groepsvormende watervogel", "watervogel met lage aantallen",
    "mobiele groepsvormende watervogel"
  ),
  stringsAsFactors = FALSE
)
pilot <- merge(pilot, species, by = "soort_naam", all.x = TRUE, sort = FALSE)
if (anyNA(pilot$soort_id)) stop("Niet alle pilotsoorten zijn aan soorten gekoppeld.")

visits$protocol <- ifelse(grepl("^Alle vogelsoorten", visits$tellingtype), "alle",
                          ifelse(grepl("^Watervogels", visits$tellingtype), "water", "overig"))
visits$volledig <- tolower(visits$telomschrijving) == "volledig"
visits$maand_f <- factor(visits$maand, levels = c(9, 10, 11, 12, 1, 2, 3),
                         labels = c("sep", "okt", "nov", "dec", "jan", "feb", "mrt"))
visits$seizoen <- factor(visits$seizoen_start, levels = 2000:2024)
visits$season_c <- visits$seizoen_start - 2000
visits$plot_id <- factor(visits$plot_id)

audit <- data.frame(
  kenmerk = c(
    "analyseperiode", "bezoeken_wintermaanden", "volledige_bezoeken", "onvolledige_bezoeken",
    "bezoeken_alle_vogels", "bezoeken_waterprotocol", "bezoeken_overig_protocol",
    "bezoeken_zonder_telduur", "eerste_seizoen", "laatste_volledige_seizoen",
    "pilotsoorten", "modelversie"
  ),
  waarde = c(
    "2000/01-2024/25", nrow(visits), sum(visits$volledig), sum(!visits$volledig),
    sum(visits$protocol == "alle"), sum(visits$protocol == "water"), sum(visits$protocol == "overig"),
    sum(is.na(visits$bezoekduur_min)), min(visits$seizoen_start), max(visits$seizoen_start),
    nrow(pilot), "winterpilot-v1"
  ),
  stringsAsFactors = FALSE
)
write_csv(audit, "winter_audit_samenvatting.csv")

coverage <- aggregate(
  cbind(geldige_bezoeken = as.integer(visits$volledig & visits$protocol %in% c("alle", "water")),
        geldige_plots = as.integer(visits$volledig & visits$protocol %in% c("alle", "water"))) ~ seizoen_start + maand,
  data = visits,
  FUN = sum
)
plot_coverage <- aggregate(plot_id ~ seizoen_start + maand,
                           data = visits[visits$volledig & visits$protocol %in% c("alle", "water"), ],
                           FUN = function(x) length(unique(x)))
coverage$geldige_plots <- plot_coverage$plot_id[match(
  paste(coverage$seizoen_start, coverage$maand),
  paste(plot_coverage$seizoen_start, plot_coverage$maand)
)]
coverage$seizoen <- sprintf("%02d/%02d", coverage$seizoen_start %% 100, (coverage$seizoen_start + 1) %% 100)
write_csv(coverage, "winter_dekking.csv")

positive_scan <- merge(counts, species, by = "soort_id", all.x = TRUE)
positive_scan <- merge(positive_scan, visits[, c("bezoek_id", "seizoen_start", "plot_id")], by = "bezoek_id", all.x = TRUE)
suitability <- do.call(rbind, lapply(split(positive_scan, positive_scan$soort_id), function(x) {
  data.frame(
    soort_id = x$soort_id[[1]], soort_naam = x$soort_naam[[1]],
    winters_met_detectie = length(unique(x$seizoen_start)),
    bezoeken_met_detectie = length(unique(x$bezoek_id)),
    plots_met_detectie = length(unique(x$plot_id)),
    totaal_geregistreerd = sum(x$aantal), maximum_bezoektotaal = max(x$aantal),
    stringsAsFactors = FALSE
  )
}))
suitability$voorlopige_klasse <- with(suitability, ifelse(
  winters_met_detectie >= 20 & bezoeken_met_detectie >= 300 & plots_met_detectie >= 15, "kansrijk",
  ifelse(winters_met_detectie >= 15 & bezoeken_met_detectie >= 100, "nader_beoordelen", "alleen_beschrijvend")
))
suitability$opmerking <- "Protocolgroep en geldige nullen moeten nog inhoudelijk per soort worden vastgesteld."
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

for (i in seq_len(nrow(pilot))) {
  sp <- pilot[i, ]
  eligible_protocol <- if (sp$protocolgroep == "water") c("alle", "water") else "alle"
  dat <- visits[visits$volledig & visits$protocol %in% eligible_protocol, ]
  cnt <- counts[counts$soort_id == sp$soort_id, c("bezoek_id", "aantal", "bronregels", "max_bronregel")]
  dat <- merge(dat, cnt, by = "bezoek_id", all.x = TRUE, sort = FALSE)
  dat$aantal[is.na(dat$aantal)] <- 0
  dat$bronregels[is.na(dat$bronregels)] <- 0
  dat$detectie <- as.integer(dat$aantal > 0)
  dat$protocol <- factor(dat$protocol)
  dat$plot_id <- factor(dat$plot_id)
  dat$seizoen <- factor(dat$seizoen_start, levels = sort(unique(dat$seizoen_start)))
  dat$maand_f <- factor(dat$maand_f, levels = c("sep", "okt", "nov", "dec", "jan", "feb", "mrt"))

  has_protocol_contrast <- nlevels(droplevels(dat$protocol)) > 1L
  count_formula <- if (has_protocol_contrast) aantal ~ seizoen + maand_f + protocol + (1 | plot_id) else aantal ~ seizoen + maand_f + (1 | plot_id)
  binary_formula <- if (has_protocol_contrast) detectie ~ seizoen + maand_f + protocol + (1 | plot_id) else detectie ~ seizoen + maand_f + (1 | plot_id)
  trend_count_formula <- if (has_protocol_contrast) aantal ~ season_c + maand_f + protocol + (1 | plot_id) else aantal ~ season_c + maand_f + (1 | plot_id)
  trend_binary_formula <- if (has_protocol_contrast) detectie ~ season_c + maand_f + protocol + (1 | plot_id) else detectie ~ season_c + maand_f + (1 | plot_id)
  count_model <- safe_fit(count_formula, dat, nbinom2())
  binary_model <- safe_fit(binary_formula, dat, binomial())
  trend_count <- safe_fit(trend_count_formula, dat, nbinom2())
  trend_binary <- safe_fit(trend_binary_formula, dat, binomial())
  cap <- floor(as.numeric(quantile(dat$aantal, 0.99, names = FALSE)))
  dat$aantal_trim <- pmin(dat$aantal, cap)
  trend_trim_formula <- if (has_protocol_contrast) aantal_trim ~ season_c + maand_f + protocol + (1 | plot_id) else aantal_trim ~ season_c + maand_f + (1 | plot_id)
  trend_trim <- safe_fit(trend_trim_formula, dat, nbinom2())
  short <- dat[dat$seizoen_start >= 2012 & !is.na(dat$bezoekduur_min) & dat$bezoekduur_min > 0, ]
  short_formula <- if (has_protocol_contrast) aantal ~ season_c + maand_f + protocol + log1p(bezoekduur_min) + (1 | plot_id) else aantal ~ season_c + maand_f + log1p(bezoekduur_min) + (1 | plot_id)
  trend_short <- if (nrow(short) >= 300) safe_fit(short_formula, short, nbinom2()) else structure(list(error = "onvoldoende bezoeken"), class = "winter_fit_error")

  tc <- trend_percent(trend_count)
  tb <- trend_percent(trend_binary)
  tt <- trend_percent(trend_trim)
  ts <- trend_percent(trend_short)
  same_direction <- is.finite(tc[["estimate"]]) && is.finite(tb[["estimate"]]) &&
    (abs(tc[["estimate"]]) < 0.5 || abs(tb[["estimate"]]) < 0.25 || sign(tc[["estimate"]]) == sign(tb[["estimate"]]))
  robust_extremes <- is.finite(tt[["estimate"]]) && abs(tc[["estimate"]] - tt[["estimate"]]) <= 2.0
  robust_duration <- !is.finite(ts[["estimate"]]) || abs(tc[["estimate"]] - ts[["estimate"]]) <= 3.0
  core_ok <- fit_ok(count_model) && fit_ok(binary_model) && fit_ok(trend_count) && fit_ok(trend_binary)
  klasse <- if (core_ok && same_direction && robust_extremes && robust_duration && sum(dat$detectie) >= 200) {
    "betrouwbaar"
  } else if (core_ok && sum(dat$detectie) >= 100) {
    "indicatief"
  } else {
    "alleen_beschrijvend"
  }

  if (fit_ok(count_model) && fit_ok(binary_model)) {
    ai <- predict_balanced(count_model, dat, "count")
    bi <- predict_balanced(binary_model, dat, "binary")
    cov <- aggregate(cbind(geldige_bezoeken = dat$detectie, detecties = dat$detectie) ~ seizoen_start,
                     data = dat, FUN = sum)
    cov$geldige_bezoeken <- as.integer(table(dat$seizoen_start)[as.character(cov$seizoen_start)])
    plots <- aggregate(plot_id ~ seizoen_start, data = dat, FUN = function(x) length(unique(x)))
    cov$geldige_plots <- plots$plot_id[match(cov$seizoen_start, plots$seizoen_start)]
    ai <- merge(ai, bi[, c("seizoen_start", "schatting", "ondergrens", "bovengrens")],
                by = "seizoen_start", suffixes = c("_aantal", "_detectie"))
    ai <- merge(ai, cov, by = "seizoen_start", all.x = TRUE)
    ai$soort_id <- sp$soort_id
    ai$soort_naam <- sp$soort_naam
    ai$seizoen <- sprintf("%02d/%02d", ai$seizoen_start %% 100, (ai$seizoen_start + 1) %% 100)
    ai$modelstatus <- klasse
    annual_out[[length(annual_out) + 1L]] <- ai

    cm <- predict_months(count_model, dat, "count")
    bm <- predict_months(binary_model, dat, "binary")
    names(cm)[2:4] <- paste0(c("schatting", "ondergrens", "bovengrens"), "_aantal")
    names(bm)[2:4] <- paste0(c("schatting", "ondergrens", "bovengrens"), "_detectie")
    mo <- merge(cm, bm, by = "maand")
    month_ref <- mean(mo$schatting_aantal)
    mo$maandindex <- if (is.finite(month_ref) && month_ref > 0) 100 * mo$schatting_aantal / month_ref else NA_real_
    mo$soort_id <- sp$soort_id
    mo$soort_naam <- sp$soort_naam
    mo$modelstatus <- klasse
    month_out[[length(month_out) + 1L]] <- mo
  }

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
    protocolgroep = sp$protocolgroep, telkarakteristiek = sp$telkarakteristiek,
    geldige_bezoeken = nrow(dat), detecties = sum(dat$detectie),
    winters = length(unique(dat$seizoen_start)), plots = length(unique(dat$plot_id)),
    maximum_bezoektotaal = max(dat$aantal), pct_nul = 100 * mean(dat$aantal == 0),
    trend_aantal_pct_per_jaar = tc[["estimate"]], trend_aantal_laag = tc[["lower"]], trend_aantal_hoog = tc[["upper"]],
    trend_detectie_pct_per_jaar = tb[["estimate"]], trend_detectie_laag = tb[["lower"]], trend_detectie_hoog = tb[["upper"]],
    trend_getrimd_pct_per_jaar = tt[["estimate"]], trend_vanaf_2012_pct_per_jaar = ts[["estimate"]],
    zelfde_trendrichting = same_direction, robuust_tegen_extremen = robust_extremes,
    robuust_met_telduur = robust_duration, modellen_geconvergeerd = core_ok,
    advies = klasse, stringsAsFactors = FALSE
  )
}

annual <- do.call(rbind, annual_out)
months <- do.call(rbind, month_out)
plots <- do.call(rbind, plot_out)
decisions <- do.call(rbind, decision_out)

annual <- annual[, c(
  "soort_id", "soort_naam", "seizoen_start", "seizoen", "index", "index_ondergrens", "index_bovengrens",
  "schatting_aantal", "ondergrens_aantal", "bovengrens_aantal", "schatting_detectie", "ondergrens_detectie",
  "bovengrens_detectie", "geldige_bezoeken", "geldige_plots", "detecties", "modelstatus"
)]
write_csv(annual, "winter_jaarindex.csv")
write_csv(months, "winter_maandpatroon.csv")
write_csv(plots, "winter_plotgebruik.csv")
write_csv(decisions, "winter_pilot_besluit.csv")

cat(sprintf("Winterpilot gereed: %d soorten, %d jaarindexregels, %d maandregels.\n",
            nrow(decisions), nrow(annual), nrow(months)))
