#!/usr/bin/env Rscript
long_2000_summary <- function(theta,v) {
 stopifnot(length(v)==2000L)
 b<-endpoint_interval_diagnostic(theta,v,2000L)
 bounds<-function(n){s<-endpoint_interval_diagnostic(theta,v[seq_len(n)],n);c(s$diagnostic_low,s$diagnostic_high)}
 latest<-endpoint_interval_stable(bounds(1500L),bounds(2000L));previous<-endpoint_interval_stable(bounds(1000L),bounds(1500L))
 gate<-if(!is.finite(theta))'baseline_niet_schatbaar' else if(b$n_valid<2000)'uitval_geen_band' else if(!b$complete_non_degenerate)'constante_verdeling_geen_band' else if(latest&&previous)'numeriek_stabiele_kandidaat' else 'numeriek_nog_onrustig'
 cbind(b,data.frame(gate=gate,latest_stable=latest,previous_stable=previous,both_stable=latest&&previous))
}
assess_trim_2025_2000 <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==4L);repo<-normalizePath(args[1],mustWork=TRUE);parent<-normalizePath(args[2],mustWork=TRUE);root<-normalizePath(args[3],mustWork=TRUE);out<-args[4]
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 for(n in c('compare_trim_index_summaries.R','trim_endpoint_bootstrap.R','trim_bootstrap_core.R','merge_trim_bootstrap_batches.R','build_trim_bootstrap_bundle.R','validate_trim_bootstrap_bundle.R'))source(file.path(repo,'R',n))
 dir.create(out,recursive=TRUE,showWarnings=FALSE)
 validate_trim_bootstrap_engine(file.path(parent,'input'),repo);validate_trim_bootstrap_engine(file.path(root,'input'),repo)
 m<-jsonlite::read_json(file.path(root,'input/bundle_manifest.json'),simplifyVector=TRUE);pm<-jsonlite::read_json(file.path(parent,'input/bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(bundle_sha256_file(file.path(root,'input/context.rds'))==m$context_sha256,bundle_sha256_file(file.path(parent,'input/context.rds'))==pm$context_sha256,m$parent_context_sha256==pm$context_sha256)
 cx<-readRDS(file.path(root,'input/context.rds'));ids<-sort(unique(cx$species_matrix$soort_id));stopifnot(length(ids)==32L,nrow(cx$clusters)==52L)
 prov<-read.csv(file.path(root,'parent_batches.csv'));stopifnot(nrow(prov)==100L)
 for(i in seq_len(nrow(prov)))stopifnot(bundle_sha256_file(file.path(parent,'batches',prov$file[i]))==prov$sha256[i])
 old<-read.csv(file.path(parent,'window_assessment/raw_assessment/estimates.csv'));allids<-sort(unique(old$soort_id));stopifnot(length(allids)==156L,nrow(old)==234468L)
 chunks<-list(old);j<-1L;newhashes<-list();resources<-list()
 for(from in seq.int(501L,2000L,5L)) {
  path<-file.path(root,'batches',sprintf('batch-%06d-%06d.rds',from,from+4L));z<-merge_trim_bootstrap_batches(path,from:(from+4L))
  stopifnot(identical(z$identity,readRDS(file.path(root,'input/identity.rds'))))
  resources[[length(resources)+1L]]<-readRDS(paste0(path,'.manifest.rds'));rows<-list();k<-0L
  for(r in z$results){
   stopifnot(identical(r$draw,make_stratified_cluster_draw(cx$clusters,r$replicate_id,cx$config$run_seed)));newhashes[[as.character(r$replicate_id)]]<-draw_hash_text(r$draw)
   for(id in ids){
    s<-r$species[r$species$soort_id==id&r$species$bridge_variant=='primary_5yr',];stopifnot(nrow(s)==1L)
    ix<-r$indices[r$indices$soort_id==id&r$indices$bridge_variant=='primary_5yr'&r$indices$coverage_variant=='volledig_netwerk',];t<-cx$species_targets[[as.character(id)]];years<-c(t$pre$years,t$post$years)
    for(w in c(3L,5L,7L)){
     e<-fixed_endpoint_estimate(ix,years,s$pre_ok,s$post_ok,is.finite(s$bridge_factor)&&s$bridge_factor>0,w);k<-k+1L
     rows[[k]]<-data.frame(soort_id=id,replicate_id=r$replicate_id,width=w,estimate_net_pct=e$estimate,status=e$status,first_mean=e$first_mean,last_mean=e$last_mean,outside_problem_years=e$outside_problem_years,n_outside_problem_years=e$n_outside_problem_years,n_target_years=length(years),pre_ok=s$pre_ok,post_ok=s$post_ok,bridge_ok=is.finite(s$bridge_factor)&&s$bridge_factor>0,pre_reason=s$pre_reason,post_reason=s$post_reason,bridge_reason=s$bridge_reason)
    }
   }
  }
  j<-j+1L;chunks[[j]]<-do.call(rbind,rows)
 }
 e<-do.call(rbind,chunks);rm(chunks,rows);gc();stopifnot(nrow(e)==378468L)
 stopifnot(isTRUE(all.equal(e[e$replicate_id<=500,],old,check.attributes=FALSE)))
 oldsummary<-read.csv(file.path(repo,'trim/bootstrap/endpoint_2025_500_window_check_20261103/per_species.csv'));rows<-list();checkpoints<-list();j<-0L
 for(id in allids)for(w in c(3L,5L,7L)){
  z<-e[e$soort_id==id&e$width==w,];b<-z[z$replicate_id==0,];v<-z$estimate_net_pct[z$replicate_id>0];n<-if(id%in%ids)2000L else 500L
  stopifnot(identical(z$replicate_id,0:n))
  band<-if(n==2000L)long_2000_summary(b$estimate_net_pct,v) else {
   s<-endpoint_interval_diagnostic(b$estimate_net_pct,v,n);cbind(s,data.frame(gate=if(!is.finite(b$estimate_net_pct))'geen_lange_baseline_500' else if(s$n_valid<500)'lange_uitval_500' else 'bestaand500_geen2000uitbreiding',latest_stable=FALSE,previous_stable=FALSE,both_stable=FALSE))
  }
  x<-z[z$replicate_id>0,];j<-j+1L
  rows[[j]]<-cbind(data.frame(soort_id=id,soort_naam=oldsummary$soort_naam[match(id,oldsummary$soort_id)],width=w,n_planned=n,baseline_net_pct=b$estimate_net_pct,baseline_status=b$status,n_zero_end=sum(x$status=='nul_eindgemiddelde'),n_zero_start=sum(x$status=='nul_begingemiddelde'),n_model_failure=sum(!x$pre_ok|!x$post_ok),n_bridge_failure=sum(!x$bridge_ok),n_draws_with_outside_index_problems=sum(x$n_outside_problem_years>0),reasons=paste(names(table(x$status)),table(x$status),sep='=',collapse=';')),band)
  if(id%in%ids&&w==5L)for(nc in c(500L,1000L,1500L,2000L))checkpoints[[length(checkpoints)+1L]]<-cbind(data.frame(soort_id=id,replicates=nc),endpoint_interval_diagnostic(b$estimate_net_pct,v[seq_len(nc)],nc))
 }
 sensitivity<-do.call(rbind,rows);primary<-sensitivity[sensitivity$width==5L,]
 for(n in c('n_source_positive_begin_plots','n_source_positive_end_plots','scarce_endpoint_support','window_direction_sensitive'))primary[[n]]<-oldsummary[[n]][match(primary$soort_id,oldsummary$soort_id)]
 write.csv(primary,file.path(out,'long_per_species.csv'),row.names=FALSE,na='');write.csv(sensitivity,file.path(out,'long_window_sensitivity.csv'),row.names=FALSE,na='');write.csv(do.call(rbind,checkpoints),file.path(out,'long_checkpoints.csv'),row.names=FALSE,na='')
 write.csv(e[e$width==5L,],file.path(out,'long_primary_estimates.csv'),row.names=FALSE,na='')
 write.csv(e,file.path(out,'long_all_estimates.csv'),row.names=FALSE,na='')
 jsonlite::write_json(list(species=156L,extended_species=32L,period='1958-2025',new_draws=1500L,parent_draws_reused=500L,parent_batches=prov,parent_manifest_sha256=bundle_sha256_file(file.path(parent,'input/bundle_manifest.json')),extension_manifest_sha256=bundle_sha256_file(file.path(root,'input/bundle_manifest.json')),new_draw_hashes=newhashes,criteria_commit='e7f68940',criteria_sha256=bundle_sha256_file(file.path(repo,'trim/bootstrap/species_2025_2000_20261103/CRITERIA.md')),assessment_script_sha256=bundle_sha256_file(file.path(repo,'R/assess_trim_2025_2000.R')),first500_unchanged=TRUE,formal_intervals=FALSE,batch_count=length(resources),batch_errors=sum(vapply(resources,`[[`,numeric(1),'error_count')),new_batch_runtime_seconds=sum(vapply(resources,`[[`,numeric(1),'runtime_seconds')),peak_R_memory_mb=max(vapply(resources,`[[`,numeric(1),'peak_memory_mb')),max_system_swap_growth_bytes=max(vapply(resources,`[[`,numeric(1),'swap_growth_bytes'))),file.path(out,'long_manifest.json'),auto_unbox=TRUE,pretty=TRUE)
 print(table(primary$gate));cat('LONG_2000_ASSESSMENT_COMPLETE\n')
}
if(sys.nframe()==0L)assess_trim_2025_2000()
