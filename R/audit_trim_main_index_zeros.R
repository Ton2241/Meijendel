#!/usr/bin/env Rscript
# Beoordeling van nuljaartotalen; wijzigt geen analyse- of publicatieroute.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)%in%c(3L,4L))
refresh_status <- length(args)==4L && args[4]=="--refresh-status"
if(length(args)==4L&&!refresh_status)stop("Onbekende optie")
repo <- normalizePath(args[1],mustWork=TRUE)
run <- normalizePath(args[2],mustWork=TRUE)
out <- args[3]
source(path.expand('~/Documents/GitHub/Meijendel/R/trial_storage.R'));out<-trial_output(out)
.libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
stopifnot(as.character(utils::packageVersion('rtrim'))=='2.3.1')
for(f in c('trim_trend_contract.R','trim_bootstrap_core.R','trim_bridge_core.R')) source(file.path(repo,'R',f))
m <- jsonlite::read_json(file.path(run,'input/bundle_manifest.json'),simplifyVector=TRUE)
stopifnot(digest::digest(file=file.path(run,'input/context.rds'),algo='sha256')==m$context_sha256)
cx <- readRDS(file.path(run,'input/context.rds'))
stopifnot(range(cx$species_matrix$jaar)==c(1958,2025),length(unique(cx$species_matrix$soort_id))==156L,nrow(cx$clusters)==52L)
baseline <- read.csv(file.path(run,'baseline.csv'),stringsAsFactors=FALSE)
baseline <- baseline[baseline$bridge_variant=='primary_5yr',]
names_by_id <- setNames(baseline$soort_naam,baseline$soort_id)
eligible <- baseline$soort_id[is.finite(baseline$estimate_pct_per_year)]
if(refresh_status) {
 # Never apply the frozen 2025 assessment to a newer or differently selected table.
 expected_labels <- vapply(cx$config$periods,function(years)paste(range(years),collapse='-'),character(1))
 for(usable in c(FALSE,TRUE)) {
  filename <- if(usable)'soorten_trendoverzicht_bruikbare_tijdreeks.csv' else 'soorten_trendoverzicht.csv'
  tab <- read.csv(file.path(repo,'trim/soorten',filename),stringsAsFactors=FALSE)
  expected_ids <- baseline$soort_id[if(usable)baseline$pre_ok&baseline$post_ok else baseline$pre_ok|baseline$post_ok]
  if(!setequal(tab$soort_id,expected_ids)||anyDuplicated(tab$soort_id)||
     !all(tab$trend_pre_periode==expected_labels[['pre']])||!all(tab$trend_post_periode==expected_labels[['post']]))
   stop('Statuscorrectie vereist dezelfde 2025-bronselectie; vernieuwde of afwijkende tabel geweigerd.',call.=FALSE)
 }
}
qtrend <- function(ix,target) {
 if(!setequal(ix$jaar,target)||any(!is.finite(ix$index_value))||any(ix$index_value<0)||sum(ix$index_value)<=0)return(NA_real_)
 f <- tryCatch(suppressWarnings(stats::glm(index_value~I(jaar-mean(jaar)),data=ix,family=stats::quasipoisson(link='log'))),error=function(e)NULL)
 if(is.null(f)||!isTRUE(f$converged))return(NA_real_)
 100*expm1(unname(stats::coef(f)[2]))
}
# Only alternative descriptive summary; GLM standard errors are NOT used.
# The unchanged plot bootstrap remains the source of exploratory dispersion.
paths <- list.files(file.path(run,'batches'),pattern='^batch-[0-9]+-[0-9]+\\.rds$',full.names=TRUE)
source(file.path(repo,'R/merge_trim_bootstrap_batches.R'))
merged <- merge_trim_bootstrap_batches(paths,expected_ids=1:50)
checks <- list(); candidates <- list(); cases <- list(); source_zeros <- list()
for(r in merged$results) {
 s <- r$species[r$species$bridge_variant=='primary_5yr',]
 for(i in seq_len(nrow(s))) {
  id <- s$soort_id[i];ix <- r$indices[r$indices$soort_id==id&r$indices$bridge_variant=='primary_5yr',]
  target <- cx$species_targets[[as.character(id)]];required <- c(target$pre$years,target$post$years)
  if(s$result_reason[i]=='index_onvolledig_of_niet_positief') checks[[length(checks)+1L]] <- data.frame(soort_id=id,replicate_id=r$replicate_id,in_original_longtrend=id%in%eligible,n_zero=sum(ix$index_value==0,na.rm=TRUE),n_negative=sum(ix$index_value<0,na.rm=TRUE),n_nonfinite=sum(!is.finite(ix$index_value)),missing_year=!setequal(ix$jaar,required))
  qt <- if(s$pre_ok[i]&&s$post_ok[i]&&is.finite(s$bridge_factor[i]))qtrend(ix,required) else NA_real_
  candidates[[length(candidates)+1L]] <- data.frame(soort_id=id,replicate_id=r$replicate_id,old=s$estimate_pct_per_year[i],quasi=qt)
 }
 # Refit just two named diagnostic replicates, retaining the exact original draw.
 if(r$replicate_id%in%1:2) {
  sp <- cx$species_matrix[cx$species_matrix$soort_id==150,]
  drawn <- apply_cluster_draw(sp,r$draw)
  ft <- fit_first_working_trim_model(drawn[drawn$jaar%in%cx$config$periods$post,],analysis_years=cx$species_targets[['150']]$post$years)
  stopifnot(ft$ok)
  f <- ft$model;idx <- rtrim::index(f,which='both');yr <- ft$year_map$jaar[match(idx$time,ft$year_map$trim_year)]
  zero <- idx$imputed==0
  for(y in yr[zero]) cases[[length(cases)+1L]] <- data.frame(soort_id=150,replicate_id=r$replicate_id,jaar=y,imputed_index=idx$imputed[yr==y],fitted_index=idx$fitted[yr==y])
  orig <- rtrim::overall(f,which='imputed')$slope$mul
  f10 <- f;f10$tt_imp <- 10*f$tt_imp;f10$var_tt_imp <- 100*f$var_tt_imp
  f1 <- f;f1$tt_imp[f1$tt_imp<1e-6] <- 1
  one <- rtrim::overall(f1,which='imputed')$slope$mul
  stopifnot(isTRUE(all.equal(orig,one,tolerance=1e-12)))
  checks_case <- data.frame(replicate_id=r$replicate_id,period='1984-2025',zero_years=paste(yr[zero],collapse=';'),overall_imputed_pct=100*(orig-1),overall_fitted_pct=100*(rtrim::overall(f,which='fitted')$slope$mul-1),overall_imputed_scaled10_pct=100*(rtrim::overall(f10,which='imputed')$slope$mul-1),zero_to_one_reproduces_overall=TRUE)
  if(!exists('scale_checks'))scale_checks<-list()
  scale_checks[[length(scale_checks)+1L]]<-checks_case
 }
}
d <- do.call(rbind,candidates);checks <- do.call(rbind,checks)
per_species <- do.call(rbind,lapply(split(d,d$soort_id),function(x) {
 med <- function(v)if(any(is.finite(v)))median(v[is.finite(v)]) else NA_real_
 both <- is.finite(x$old)&is.finite(x$quasi)
 data.frame(soort_id=x$soort_id[1],soort_naam=unname(names_by_id[as.character(x$soort_id[1])]),in_original_longtrend=x$soort_id[1]%in%eligible,n_old=sum(is.finite(x$old)),n_quasi=sum(is.finite(x$quasi)),median_old=med(x$old),median_quasi=med(x$quasi),median_paired_difference_pct_points=med(x$quasi[both]-x$old[both]))
}))
original <- list(); contracts <- list()
for(id in sort(unique(cx$species_matrix$soort_id))) {
 sp <- cx$species_matrix[cx$species_matrix$soort_id==id,]
 for(period in c('pre','post')) {
  t <- cx$species_targets[[as.character(id)]][[period]]
  if(!isTRUE(t$ok))next
  ft <- fit_first_working_trim_model(sp[sp$jaar%in%t$years,],analysis_years=t$years);stopifnot(ft$ok)
  v <- as.numeric(ft$model$tt_imp)
  contract <- trim_overall_contract(ft,periode=period)
  contracts[[length(contracts)+1L]] <- cbind(data.frame(soort_id=id,period_key=period),contract)
  original[[length(original)+1L]] <- data.frame(soort_id=id,soort_naam=unname(names_by_id[as.character(id)]),period=period,first_year=min(ft$year_map$jaar),last_year=max(ft$year_map$jaar),n_zero=sum(v==0),n_under_threshold=sum(v<1e-6),zero_years=paste(ft$year_map$jaar[v<1e-6],collapse=';'),current_formality=contract$trend_formaliteit,current_status=contract$trend_status)
 }
}
original <- do.call(rbind,original)
contracts <- do.call(rbind,contracts)
sp <- cx$species_matrix[cx$species_matrix$soort_id==150,]
for(y in c(2015:2019,2021)) {
 q <- sp[sp$jaar==y&sp$geteld%in%TRUE,]
 source_zeros[[length(source_zeros)+1L]] <- data.frame(soort_id=150,jaar=y,n_counted_plots=length(unique(q$plot_id)),n_positive_plots=length(unique(q$plot_id[q$count_adjusted>0])),adjusted_sum=sum(q$count_adjusted))
}
a <- per_species[per_species$in_original_longtrend,]
z <- checks[checks$in_original_longtrend,]
summary <- list(source_period='1958-2025',species=156,original_period_models=nrow(original),original_zero_period_models=sum(original$n_zero>0),original_zero_species=length(unique(original$soort_id[original$n_zero>0])),original_zero_flagged_formal=sum(original$n_zero>0&original$current_formality=='formeel'),bootstrap_index_failure_cases_original70=nrow(z),bootstrap_index_failure_species_original70=length(unique(z$soort_id)),all_index_failures_original70_have_actual_zero=all(z$n_zero>0),any_index_failures_original70_missing_year=any(z$missing_year),ols_all50_species=sum(a$n_old==50),quasi_all50_species=sum(a$n_quasi==50),ols_atleast48_species=sum(a$n_old>=48),quasi_atleast48_species=sum(a$n_quasi>=48),publication_status='beoordeling_geen_methodewijziging_geen_formele_intervallen')
dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(n in c('per_species','original','checks','contracts'))write.csv(get(n),file.path(out,paste0(n,'.csv')),row.names=FALSE,na='')
write.csv(do.call(rbind,cases),file.path(out,'skylark_index_cases.csv'),row.names=FALSE)
write.csv(do.call(rbind,scale_checks),file.path(out,'overall_scale_checks.csv'),row.names=FALSE)
write.csv(do.call(rbind,source_zeros),file.path(out,'skylark_source_zeros.csv'),row.names=FALSE)
jsonlite::write_json(c(summary,list(source_hash=m$source_hash,context_sha256=m$context_sha256,script_sha256=digest::digest(file=file.path(repo,'R/audit_trim_main_index_zeros.R'),algo='sha256'),rtrim_version='2.3.1')),file.path(out,'manifest.json'),auto_unbox=TRUE,pretty=TRUE)
if(refresh_status) {
  # Correct only current source-period inference, leaving source/model/index fields intact.
  paths <- file.path(repo,'trim/soorten',c('soorten_trendoverzicht.csv','soorten_trendoverzicht_bruikbare_tijdreeks.csv'))
  protected <- file.path(repo,'trim/soorten',c('soortindices_per_jaar.csv','soortindices_bruikbare_tijdreeks.csv','soorten_modelstatus.csv','soorten_brugfactoren.csv'))
  hashes <- vapply(protected,function(f)digest::digest(file=f,algo='sha256'),character(1))
  changed <- list()
  blocked <- contracts[contracts$trend_status=='nuljaartotaal_herbeoordelen',]
  stopifnot(nrow(blocked)==45L,length(unique(blocked$soort_id))==40L)
  for(path in paths) {
    tab <- read.csv(path,stringsAsFactors=FALSE,check.names=FALSE)
    before <- tab
    write.csv(before,file.path(out,paste0('before_',basename(path))),row.names=FALSE,na='')
    for(i in seq_len(nrow(blocked))) {
      row <- which(tab$soort_id==blocked$soort_id[i]);if(!length(row))next
      stopifnot(length(row)==1L)
      prefix <- paste0('trend_',blocked$period_key[i],'_')
      replacement <- trim_prefix_contract(blocked[i,setdiff(names(blocked),c('soort_id','period_key')),drop=FALSE],prefix)
      fields <- paste0(prefix,c('formaliteit','status','pct_per_jaar','se_pct','ci95_laag_pct','ci95_hoog_pct','p','klasse','duiding_type','methode'))
      changed[[length(changed)+1L]] <- data.frame(file=basename(path),soort_id=tab$soort_id[row],period=blocked$period_key[i],old_pct=tab[[paste0(prefix,'pct_per_jaar')]][row],old_formality=tab[[paste0(prefix,'formaliteit')]][row],new_formality=replacement[[paste0(prefix,'formaliteit')]],new_status=replacement[[paste0(prefix,'status')]])
      for(field in fields)tab[row,field] <- replacement[[field]]
    }
    expected_fields <- unlist(lapply(c('pre','post'),function(part)paste0('trend_',part,'_',c('formaliteit','status','pct_per_jaar','se_pct','ci95_laag_pct','ci95_hoog_pct','p','klasse','duiding_type','methode'))))
    stopifnot(identical(tab[setdiff(names(tab),expected_fields)],before[setdiff(names(before),expected_fields)]))
    for(part in c('pre','post')) {
      keep <- !tab$soort_id%in%blocked$soort_id[blocked$period_key==part]
      fields <- intersect(names(tab),paste0('trend_',part,'_',c('formaliteit','status','pct_per_jaar','se_pct','ci95_laag_pct','ci95_hoog_pct','p','klasse','duiding_type','methode')))
      stopifnot(identical(tab[keep,fields],before[keep,fields]))
    }
    write.csv(tab,path,row.names=FALSE,na='NA')
  }
  stopifnot(identical(hashes,vapply(protected,function(f)digest::digest(file=f,algo='sha256'),character(1))))
  write.csv(do.call(rbind,changed),file.path(out,'status_changes.csv'),row.names=FALSE,na='')
  jsonlite::write_json(as.list(hashes),file.path(out,'unchanged_source_outputs.json'),auto_unbox=TRUE,pretty=TRUE)
}
print(summary)
