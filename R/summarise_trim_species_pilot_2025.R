#!/usr/bin/env Rscript
# Eén regel per soort; spreiding is diagnostisch, geen formeel interval.
species_pilot_detail <- function(species, baseline, planned=50L) {
  ids <- sort(unique(baseline$soort_id))
  stopifnot(setequal(ids,unique(species$soort_id)))
  reason_counts <- function(x) { x <- x[!is.na(x)&nzchar(x)]; tt<-sort(table(x),decreasing=TRUE); paste(names(tt),as.integer(tt),sep='=',collapse=' | ') }
  spread <- function(x) { x<-x[is.finite(x)]; c(n=length(x),median=if(length(x))median(x) else NA_real_,sd=if(length(x)>1)sd(x) else NA_real_,min=if(length(x))min(x) else NA_real_,max=if(length(x))max(x) else NA_real_) }
  rows <- lapply(ids,function(id) {
    b <- baseline[baseline$soort_id==id & baseline$bridge_variant=='primary_5yr',]
    stopifnot(nrow(b)==1L)
    row <- b[,c('soort_id','soort_naam','pre_ok','post_ok','pre_model','post_model','pre_model_years','post_model_years','pre_reason','post_reason')]
    row$beoogde_herhalingen <- planned
    for (v in c('primary_5yr','reference_3yr')) {
      d <- species[species$soort_id==id & species$bridge_variant==v,]
      stopifnot(nrow(d)==planned,identical(sort(d$replicate_id),seq_len(planned)))
      prefix <- if(v=='primary_5yr') 'vijfjaar' else 'driejaar'
      point <- baseline$estimate_pct_per_year[baseline$soort_id==id & baseline$bridge_variant==v]
      row[[paste0(prefix,'_punt_pct_jaar')]] <- point
      sp <- spread(d$estimate_pct_per_year)
      for(n in names(sp)) row[[paste0(prefix,'_',n)]] <- unname(sp[[n]])
      row[[paste0(prefix,'_nulvensters')]] <- sum(d$bridge_reason=='nul_totaal_volledig_venster',na.rm=TRUE)
      row[[paste0(prefix,'_uitvalredenen')]] <- reason_counts(d$result_reason[!is.finite(d$estimate_pct_per_year)])
      row[[paste0(prefix,'_brugredenen')]] <- reason_counts(d$bridge_reason)
    }
    d <- species[species$soort_id==id & species$bridge_variant=='primary_5yr',]
    for(period in c('pre','post')) {
      row[[paste0(period,'_model_gelukt_n')]] <- sum(d[[paste0(period,'_ok')]])
      row[[paste0(period,'_index_onvolledig_of_niet_positief_n')]] <- sum(d[[paste0(period,'_ok')]] & !is.finite(d[[paste0(period,'_estimate_pct_per_year')]]))
      row[[paste0(period,'_modellen')]] <- reason_counts(d[[paste0(period,'_model')]])
      sp <- spread(d[[paste0(period,'_estimate_pct_per_year')]])
      for(n in names(sp)) row[[paste0(period,'_',n)]] <- unname(sp[[n]])
    }
    row$duiding <- if(!is.finite(row$vijfjaar_punt_pct_jaar)) 'lange_trend_niet_beschikbaar' else if(row$vijfjaar_n==planned) 'alle_50_berekenbaar' else if(row$vijfjaar_n>=ceiling(.95*planned)) 'beperkte_uitval_geen_formeel_interval' else 'veel_uitval_geen_formeel_interval'
    row
  })
  out <- do.call(rbind,rows)
  out[order(out$soort_naam),]
}

if(sys.nframe()==0L) {
  args <- commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3L)
  repo <- normalizePath(args[[1L]],mustWork=TRUE);run <- normalizePath(args[[2L]],mustWork=TRUE);out <- args[[3L]]
  source(file.path(repo,'R/summarise_trim_bootstrap_pilot.R'))
  source(file.path(repo,'R/merge_trim_bootstrap_batches.R'))
  paths <- list.files(file.path(run,'batches'),pattern='^batch-[0-9]+-[0-9]+\\.rds$',full.names=TRUE)
  summary <- summarise_trim_bootstrap_pilot(paths,1:50)
  stopifnot(summary$run$error_count==0L)
  merged <- merge_trim_bootstrap_batches(paths,expected_ids=1:50)
  species <- pilot_bind_rows(lapply(merged$results,`[[`,'species'))
  baseline <- read.csv(file.path(run,'baseline.csv'),stringsAsFactors=FALSE)
  detail <- species_pilot_detail(species,baseline)
  stopifnot(nrow(detail)==156L,!anyDuplicated(detail$soort_id),nrow(species)==156L*50L*2L)
  names(summary$species)[names(summary$species)=="publication_gate"] <- "rekenkundige_95_procent_controle_geen_publicatiebesluit"
  write_trim_bootstrap_pilot_summary(summary,out)
  write.csv(detail,file.path(out,'per_soort.csv'),row.names=FALSE,na='')
  write.csv(baseline,file.path(out,'oorspronkelijke_berekening.csv'),row.names=FALSE,na='')
  fmt <- function(x)ifelse(is.finite(x),sprintf('%.3f',x),'—')
  period_label <- function(s) { if(is.na(s)||!nzchar(s)) return('—'); paste(range(as.integer(strsplit(s,';',fixed=TRUE)[[1L]])),collapse='–') }
  lines <- c('# Pilot per vogelsoort — gegevens 1958–2025','',
    '50 gezamenlijke, gestratificeerde trekkingen van volledige kavelgeschiedenissen. Hoofdvariant: venstermethode 1979–1983/1986–1990; vergelijking: 1981–1983/1986–1988. Alle 156 soorten blijven zichtbaar.','',
    'Een trendwaarde is de beschrijvende gemiddelde jaarlijkse verandering van de samengestelde index, in procenten. Min–max is uitsluitend de waargenomen spreiding van berekenbare herhalingen. Het is geen 95%-onzekerheidsmarge. Uitgevallen herhalingen tellen mee in de noemer 50.','',
    'De percentages zijn beschrijvende OLS-regressies van log(index) op kalenderjaar; zij vervangen de formele periodetrends van rtrim::overall niet. De kolommen vóór en vanaf 1984 tonen hoeveel afzonderlijke indexhellingen berekenbaar zijn. De exacte modeljaren, redenen en spreiding per periode staan in per_soort.csv. Ontbrekende trendwaarden zijn geen nul.','',
    '| Soort | Modeljaren vóór / vanaf 1984 | Vijfjaar: punt (%/jr) | Gelukt 5jr / 3jr | Min–max 5jr | Indexhelling vóór / vanaf 1984 | Beperking lange trend |',
    '|---|---|---:|---:|---:|---:|---|')
  for(i in seq_len(nrow(detail))) {
    r <- detail[i,];reason <- if(r$duiding=='alle_50_berekenbaar') 'Alleen pilot; geen formeel interval' else if(nzchar(r$vijfjaar_uitvalredenen))r$vijfjaar_uitvalredenen else r$duiding
    reason <- gsub('|',';',reason,fixed=TRUE)
    lines <- c(lines,sprintf('| %s | %s / %s | %s | %d/50 / %d/50 | %s – %s | %d/50 / %d/50 | %s |',r$soort_naam,period_label(r$pre_model_years),period_label(r$post_model_years),fmt(r$vijfjaar_punt_pct_jaar),r$vijfjaar_n,r$driejaar_n,fmt(r$vijfjaar_min),fmt(r$vijfjaar_max),r$pre_n,r$post_n,reason))
  }
  writeLines(lines,file.path(out,'PER_SOORT.md'))
  manifest <- jsonlite::read_json(file.path(run,'input/bundle_manifest.json'),simplifyVector=TRUE)
  repro <- readLines(file.path(run,'reproducibility/result.txt'),warn=FALSE)
  stopifnot(any(grepl('REPRODUCIBILITY_EXACT_1_2=TRUE',repro,fixed=TRUE)))
  manifest$reproducibility_exact_replicates_1_2 <- TRUE
  manifest$baseline_sha256 <- digest::digest(file=file.path(run,'baseline.csv'),algo='sha256')
  manifest$builder_script_sha256 <- digest::digest(file=file.path(repo,'R/build_trim_species_pilot_2025.R'),algo='sha256')
  manifest$report_code_commit <- system2('git',c('-C',repo,'rev-parse','HEAD'),stdout=TRUE)[[1L]]
  manifest$report_script_sha256 <- digest::digest(file=file.path(repo,'R/summarise_trim_species_pilot_2025.R'),algo='sha256')
  manifest$batches <- lapply(paths,function(p)list(file=basename(p),sha256=digest::digest(file=p,algo='sha256')))
  manifest$report_status <- '50_replicaties_diagnostiek_geen_formele_intervallen'
  jsonlite::write_json(manifest,file.path(out,'manifest.json'),auto_unbox=TRUE,pretty=TRUE)
  cat('SPECIES_PILOT_REPORT_READY\n')
}
