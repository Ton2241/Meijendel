args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "pq_ecologische_gradienten.R"
))

taxa <- data.frame(
  taxon_id = 1:10,
  wetenschappelijke_naam = c(
    "Pioniera", "Graminea", "Aquatica", "Ruderalia", "Silvatica",
    "Fruticosa", "Bryophyta test", "Kaal land", "Onbekenda", "Broadus species"
  ),
  naam_zonder_auteur = c(
    "Pioniera", "Graminea", "Aquatica", "Ruderalia", "Silvatica",
    "Fruticosa", "Bryophyta test", "Kaal land", "Onbekenda", "Broadus species"
  ),
  weergavenaam = c(
    "Pioniera", "Graminea", "Aquatica", "Ruderalia", "Silvatica",
    "Fruticosa", "Bryophyta test", "Kaal land", "Onbekenda", "Broadus species"
  ),
  groep_naam = c(
    rep("Vaatplanten", 6), "Mossen en levermossen", NA,
    "Vaatplanten", "Vaatplanten"
  ),
  stringsAsFactors = FALSE
)
aliases <- data.frame(
  taxon_id = c(1L, 9L),
  bron_wetenschappelijke_naam = c("Pioniera alias", "Onbekenda alias"),
  stringsAsFactors = FALSE
)
ecodbase <- data.frame(
  WETNAAM = c(
    "Pioniera alias", "Graminea", "Aquatica", "Ruderalia", "Silvatica",
    "Fruticosa", "Broadus species s.l."
  ),
  TYPE = rep("H", 7),
  ECOTP_01 = c("P63", "G63", "W17", "R67", "H63", "H63", "G63"),
  ECOTP_02 = NA_character_,
  SOC_GRP_ND = NA_character_,
  SOC_GRP_DG = NA_character_,
  LV_VORM1 = c(NA, NA, "A", NA, NA, NA, NA),
  LV_VORM2 = NA_character_,
  LV_VORM3 = NA_character_,
  GR_VORM1 = c(60, 50, 10, 60, 80, 70, 50),
  GR_VORM2 = NA_real_,
  GR_VORM3 = NA_real_,
  stringsAsFactors = FALSE
)

mapping <- build_pq_taxon_gradient_mapping(taxa, aliases, ecodbase)
stopifnot(setequal(unique(mapping$gradient), pq_gradient_levels()))
stopifnot(identical(
  mapping$gradient[mapping$taxon_id == 1L], "open_pionier"
))
stopifnot(identical(
  mapping$match_method[mapping$taxon_id == 1L], "alias_bronkoppeling"
))
stopifnot(identical(
  mapping$gradient[mapping$taxon_id == 2L], "duingrasland_mos_korstmos"
))
stopifnot(identical(mapping$gradient[mapping$taxon_id == 3L], "nat_riet"))
stopifnot(identical(mapping$gradient[mapping$taxon_id == 4L], "struweel_ruigte"))
stopifnot(identical(mapping$gradient[mapping$taxon_id == 5L], "bomen_bos"))
stopifnot(setequal(
  mapping$gradient[mapping$taxon_id == 6L], c("struweel_ruigte", "bomen_bos")
))
stopifnot(all(mapping$weight[mapping$taxon_id == 6L] == .5))
stopifnot(identical(
  mapping$gradient[mapping$taxon_id == 7L], "duingrasland_mos_korstmos"
))
stopifnot(identical(mapping$gradient[mapping$taxon_id == 8L], "open_pionier"))
stopifnot(!8L %in% mapping$taxon_id[mapping$match_method == "synbiosys_exact"])
stopifnot(!9L %in% mapping$taxon_id)
stopifnot(identical(
  mapping$match_method[mapping$taxon_id == 10L], "synbiosys_binomial"
))

opname <- data.frame(
  opname_id = 1:4,
  jaar = c(2000L, 2000L, 2005L, 2000L),
  stringsAsFactors = FALSE
)
opname_plot <- data.frame(
  opname_id = 1:4,
  plot_id = c(10L, 10L, 10L, 20L),
  stringsAsFactors = FALSE
)
waarneming <- data.frame(
  opname_id = c(1L, 1L, 2L, 2L, 3L, 3L, 4L),
  taxon_id = c(1L, 2L, 1L, 9L, 1L, 2L, 9L),
  abundantie_percentage = c(40, 60, 20, 80, 20, 80, 100),
  stringsAsFactors = FALSE
)
scores <- build_pq_gradient_scores(
  opname, waarneming, opname_plot, mapping, min_mapped_share = .5
)
row_2000 <- scores[scores$plot_id == 10L & scores$jaar == 2000L, ]
stopifnot(nrow(row_2000) == 1L)
stopifnot(row_2000$n_opnamen == 2L)
stopifnot(abs(row_2000$open_pionier_cover - 30) < 1e-12)
stopifnot(abs(row_2000$duingrasland_mos_korstmos_cover - 30) < 1e-12)
stopifnot(abs(row_2000$mapped_cover_share - .6) < 1e-12)
stopifnot(row_2000$score_valid)
row_2005 <- scores[scores$plot_id == 10L & scores$jaar == 2005L, ]
stopifnot(row_2005$score_valid)
stopifnot(abs(row_2005$open_pionier_share - .2) < 1e-12)
stopifnot(abs(row_2005$duingrasland_mos_korstmos_share - .8) < 1e-12)

intervals <- build_pq_gradient_intervals(scores)
stopifnot(nrow(intervals) == 1L)
stopifnot(intervals$plot_id == 10L)
stopifnot(intervals$start_year == 2000L)
stopifnot(intervals$end_year == 2005L)
stopifnot(intervals$interval_years == 5L)
stopifnot(abs(intervals$open_pionier_change_per_year - (-.06)) < 1e-12)

summary <- summarise_pq_gradient_intervals(intervals)
stopifnot(nrow(summary) == 1L)
stopifnot(summary$interval_years == 5L)
stopifnot(summary$n_intervals == 1L)
stopifnot(summary$n_plots == 1L)

change_summary <- summarise_pq_gradient_changes(intervals)
stopifnot(nrow(change_summary) == 5L)
open_change <- change_summary[change_summary$gradient == "open_pionier", ]
stopifnot(open_change$n_intervals == 1L)
stopifnot(open_change$n_nonzero == 1L)
stopifnot(open_change$n_plots_nonzero == 1L)

gap_scores <- rbind(scores, scores[scores$plot_id == 10L & scores$jaar == 2000L, ])
gap_scores$jaar[nrow(gap_scores)] <- 2003L
gap_scores$score_valid[gap_scores$plot_id == 10L & gap_scores$jaar == 2003L] <- FALSE
gap_intervals <- build_pq_gradient_intervals(gap_scores)
stopifnot(!any(gap_intervals$plot_id == 10L))

bird_plotyears <- data.frame(
  plot_id = c(10L, 10L, 10L),
  jaar = c(2005L, 2006L, 2008L)
)
response_coverage <- summarise_pq_interval_response_coverage(
  intervals, bird_plotyears, lags = 0:3
)
stopifnot(identical(response_coverage$lag_years, 0:3))
stopifnot(identical(response_coverage$n_intervals, c(1L, 1L, 0L, 1L)))
stopifnot(identical(response_coverage$n_plots, c(1L, 1L, 0L, 1L)))

cat("OK: ecologische PQ-gradiënten en intervallen\n")
