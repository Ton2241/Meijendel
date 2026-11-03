#!/usr/bin/env Rscript
# Separate 2025 endpoint metric. Does not activate canonical production intervals.
fixed_endpoint_estimate <- function(ix,expected_years,pre_ok=TRUE,post_ok=TRUE,bridge_ok=TRUE,width=5L) {
 invalid<-function(status)list(status=status,estimate=NA_real_,first_mean=NA_real_,last_mean=NA_real_)
 if(!isTRUE(pre_ok))return(invalid('pre_model_niet_schatbaar'))
 if(!isTRUE(post_ok))return(invalid('post_model_niet_schatbaar'))
 if(!isTRUE(bridge_ok))return(invalid('brug_niet_schatbaar'))
 first<-1958L+seq_len(width)-1L;last<-2025L-width+seq_len(width)
 if(!all(c(first,last)%in%expected_years))return(invalid('vaste_vensterjaren_ontbreken'))
 if(!index_summary_valid(ix,expected_years))return(invalid('index_onvolledig_of_ongeldig'))
 a<-mean(ix$index_value[match(first,ix$jaar)]);b<-mean(ix$index_value[match(last,ix$jaar)])
 if(a==0)return(list(status='nul_begingemiddelde',estimate=NA_real_,first_mean=a,last_mean=b))
 value<-100*(b/a-1)
 if(!is.finite(value))return(invalid('verandering_niet_eindig'))
 list(status=if(b==0)'nul_eindgemiddelde' else 'berekenbaar',estimate=value,first_mean=a,last_mean=b)
}
endpoint_interval_diagnostic <- function(theta,draws,planned) {
 stopifnot(length(draws)==planned,planned>=2L)
 valid<-is.finite(draws)&draws>= -100;n<-sum(valid)
 constant<-n==planned&&length(unique(draws))==1L
 complete<-is.finite(theta)&&theta>= -100&&n==planned&&!constant
 status<-if(!is.finite(theta)||theta< -100)'baseline_niet_schatbaar' else if(n<planned)'uitval_geen_band' else if(constant)'constante_verdeling_geen_band' else if(planned<500)'pilot_geen_formeel_interval' else if(planned<2000)'validatie_geen_formeel_interval' else 'kandidaat_vereist_dekkingsbeoordeling'
 band<-if(complete)unname(stats::quantile(draws,c(.025,.975),type=7)) else c(NA_real_,NA_real_)
 data.frame(n_valid=n,valid_fraction=n/planned,complete_non_degenerate=complete,status=status,
  diagnostic_low=band[1],diagnostic_high=band[2],ci95_low=NA_real_,ci95_high=NA_real_,
  diagnostic_method=if(complete)'percentile_type7_geen_formeel_interval' else NA_character_)
}
endpoint_interval_stable <- function(previous,current) {
 if(length(previous)!=2L||length(current)!=2L||any(!is.finite(c(previous,current))))return(FALSE)
 width<-diff(current);is.finite(width)&&width>0&&all(abs(current-previous)<.1&abs(current-previous)<.05*width)
}
run_endpoint_assessment <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)%in%3:4);repo<-normalizePath(args[1],mustWork=TRUE);run<-normalizePath(args[2],mustWork=TRUE);out<-args[3];planned<-if(length(args)==4)as.integer(args[4]) else 50L
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 for(f in c('compare_trim_index_summaries.R','trim_bootstrap_core.R','merge_trim_bootstrap_batches.R'))source(file.path(repo,'R',f))
 m<-jsonlite::read_json(file.path(run,'input/bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(digest::digest(file=file.path(run,'input/context.rds'),algo='sha256')==m$context_sha256)
 cx<-readRDS(file.path(run,'input/context.rds'));stopifnot(identical(range(cx$species_matrix$jaar),c(1958L,2025L)),nrow(cx$clusters)==52L)
 base<-read.csv(file.path(run,'baseline.csv'));base<-base[base$bridge_variant=='primary_5yr',];ids<-base$soort_id;stopifnot(length(ids)==156,!anyDuplicated(ids),setequal(ids,unique(cx$species_matrix$soort_id)))
 source_index_path<-file.path(repo,'trim/soorten/soortindices_per_jaar.csv');source_ix<-read.csv(source_index_path)
 baseline_ix<-source_ix[c('soort_id','jaar','index_100')];names(baseline_ix)[3]<-'index_value'
 for(id in ids){
  s<-base[base$soort_id==id,];use<-baseline_ix$soort_id==id&baseline_ix$jaar>=1984
  baseline_ix$index_value[use]<-if(is.finite(s$bridge_factor)&&s$bridge_factor>0)baseline_ix$index_value[use]*s$bridge_factor else NA_real_
 }
 # Validate frozen-source reconstruction before using any new metric.
 errors<-numeric()
 for(id in ids[is.finite(base$estimate_pct_per_year)]){
  d<-baseline_ix[baseline_ix$soort_id==id,];f<-stats::lm(log(index_value)~jaar,data=d)
  errors<-c(errors,abs(100*expm1(unname(stats::coef(f)[2]))-base$estimate_pct_per_year[match(id,ids)]))
 }
 stopifnot(length(errors)==70,max(errors)<1e-8)
 old<-read.csv(file.path(repo,'trim/bootstrap/zero_policy_20261103/curves.csv'));old<-old[old$series=='jaarindex',]
 z<-merge(old,baseline_ix,by=c('soort_id','jaar'));stopifnot(nrow(z)==272,max(abs(z$index_value.x-z$index_value.y))<1e-8)
 paths<-list.files(file.path(run,'batches'),pattern='^batch-[0-9]+-[0-9]+\\.rds$',full.names=TRUE)
 merged<-merge_trim_bootstrap_batches(paths,expected_ids=seq_len(planned))
 results<-c(list(list(replicate_id=0L,species=base,indices=baseline_ix)),merged$results)
 blocks<-list();hashes<-list()
 for(r in results){
  rows<-list()
  if(r$replicate_id>0)hashes[[as.character(r$replicate_id)]]<-draw_hash_text(r$draw)
  for(id in ids){
   s<-r$species[r$species$soort_id==id&r$species$bridge_variant=='primary_5yr',];stopifnot(nrow(s)==1)
   ix<-r$indices[r$indices$soort_id==id,]
   if(r$replicate_id>0)ix<-ix[ix$bridge_variant=='primary_5yr'&ix$coverage_variant=='volledig_netwerk',]
   t<-cx$species_targets[[as.character(id)]];years<-c(t$pre$years,t$post$years)
   for(w in c(3L,5L,7L)){
    e<-fixed_endpoint_estimate(ix,years,s$pre_ok,s$post_ok,is.finite(s$bridge_factor)&&s$bridge_factor>0,w)
    rows[[length(rows)+1L]]<-data.frame(soort_id=id,replicate_id=r$replicate_id,width=w,estimate_net_pct=e$estimate,status=e$status,
     first_mean=e$first_mean,last_mean=e$last_mean,n_target_years=length(years),pre_ok=s$pre_ok,post_ok=s$post_ok,
     bridge_ok=is.finite(s$bridge_factor)&&s$bridge_factor>0,pre_reason=s$pre_reason,post_reason=s$post_reason,bridge_reason=s$bridge_reason)
   }
  }
  blocks[[length(blocks)+1L]]<-do.call(rbind,rows)
 }
 estimates<-do.call(rbind,blocks);rm(blocks,rows);gc()
 coverage<-do.call(rbind,lapply(ids,function(id)do.call(rbind,lapply(list(1958:1962,2021:2025),function(ys){
  d<-cx$species_matrix;d<-d[d$soort_id==id&d$jaar%in%ys&d$geteld%in%TRUE&is.finite(d$count_adjusted),]
  data.frame(soort_id=id,first_year=min(ys),last_year=max(ys),n_counted_cells=nrow(d),n_counted_plots=length(unique(d$plot_id)),n_positive_plots=length(unique(d$plot_id[d$count_adjusted>0])))
 }))))
 summaries<-list()
 for(id in ids)for(w in c(3L,5L,7L)){
  e<-estimates[estimates$soort_id==id&estimates$width==w,];b<-e[e$replicate_id==0,];x<-e[e$replicate_id>0,];stopifnot(identical(x$replicate_id,seq_len(planned)))
  v<-x$estimate_net_pct;f<-v[is.finite(v)];band<-endpoint_interval_diagnostic(b$estimate_net_pct,v,planned)
  gate<-if(band$complete_non_degenerate)'kandidaat_500_intervalvalidatie' else if(is.finite(b$estimate_net_pct)&&band$n_valid>=ceiling(.95*planned)&&band$n_valid<planned)'alleen_500_uitvalonderzoek' else 'niet_gereed_intervalvalidatie'
  frequencies<-sort(table(x$status),decreasing=TRUE)
  summaries[[length(summaries)+1L]]<-cbind(data.frame(soort_id=id,soort_naam=base$soort_naam[match(id,ids)],width=w,
   baseline_net_pct=b$estimate_net_pct,baseline_status=b$status,baseline_first_mean=b$first_mean,baseline_last_mean=b$last_mean,
   n_planned=planned,n_zero_start=sum(x$status=='nul_begingemiddelde'),n_zero_end=sum(x$status=='nul_eindgemiddelde'),
   n_model_failure=sum(!x$pre_ok|!x$post_ok),n_bridge_failure=sum(!x$bridge_ok),
   n_missing_window=sum(x$status=='vaste_vensterjaren_ontbreken'),
   finite_median=if(length(f))median(f) else NA_real_,finite_min=if(length(f))min(f) else NA_real_,finite_max=if(length(f))max(f) else NA_real_,
   gate_500=gate,reasons=paste(names(frequencies),frequencies,sep='=',collapse=';')),band)
 }
 summary<-do.call(rbind,summaries);primary<-summary[summary$width==5,];names(primary)[names(primary)=='status']<-'interval_status'
 first<-coverage[coverage$first_year==1958,];last<-coverage[coverage$first_year==2021,]
 primary$n_source_positive_begin_plots<-first$n_positive_plots[match(primary$soort_id,first$soort_id)]
 primary$n_source_positive_end_plots<-last$n_positive_plots[match(primary$soort_id,last$soort_id)]
 primary$scarce_endpoint_support<-primary$n_source_positive_begin_plots<2|primary$n_source_positive_end_plots<2
 for(w in c(3L,7L)){v<-summary[summary$width==w,];primary[[paste0('baseline_',w,'yr_net_pct')]]<-v$baseline_net_pct[match(primary$soort_id,v$soort_id)]}
 primary$window_direction_sensitive<-vapply(primary$soort_id,function(id){v<-summary$baseline_net_pct[summary$soort_id==id];if(!all(is.finite(v)))return(NA);min(v)<0&&max(v)>0},logical(1))
 # This is evidence about support, never a hidden species filter.
 dir.create(out,recursive=TRUE,showWarnings=FALSE)
 for(n in c('estimates','summary','primary','coverage'))write.csv(get(n),file.path(out,paste0(n,'.csv')),row.names=FALSE,na='')
 jsonlite::write_json(list(source_period='1958-2025',species=156,planned_replicates=planned,clusters=52,source_hash=m$source_hash,context_sha256=m$context_sha256,
  source_indices_sha256=digest::digest(file=source_index_path,algo='sha256'),baseline_sha256=digest::digest(file=file.path(run,'baseline.csv'),algo='sha256'),
  script_sha256=digest::digest(file=file.path(repo,'R/trim_endpoint_bootstrap.R'),algo='sha256'),criteria_sha256=digest::digest(file=file.path(repo,'trim/bootstrap/endpoint_all_2025_50_20261103/CRITERIA.md'),algo='sha256'),
  criteria_commit='b2d45c6a',baseline_70_max_error=max(errors),baseline_four_curve_max_error=max(abs(z$index_value.x-z$index_value.y)),draw_hashes=hashes,
  dependency_sha256=as.list(setNames(vapply(c('compare_trim_index_summaries.R','trim_bootstrap_core.R','merge_trim_bootstrap_batches.R'),function(n)digest::digest(file=file.path(repo,'R',n),algo='sha256'),character(1)),c('compare_trim_index_summaries.R','trim_bootstrap_core.R','merge_trim_bootstrap_batches.R'))),formal_intervals=FALSE,count_models_refitted=0,assessment_only=TRUE,source_replicates_from_saved_batches=planned,bootstrap_started_500=planned>=500L,R_version=R.version.string),file.path(out,'manifest.json'),auto_unbox=TRUE,pretty=TRUE)
 print(table(primary$gate_500));print(table(primary$baseline_status));cat('ENDPOINT_ALL_SPECIES_ASSESSMENT_READY\n')
}
if(sys.nframe()==0L)run_endpoint_assessment()
