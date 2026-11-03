#!/usr/bin/env Rscript
endpoint_2000_decision <- function(theta,draws) {
 stopifnot(length(draws)==500L)
 s<-endpoint_interval_diagnostic(theta,draws,500L)
 b250<-endpoint_interval_diagnostic(theta,draws[1:250],250L)
 b375<-endpoint_interval_diagnostic(theta,draws[1:375],375L)
 latest<-endpoint_interval_stable(c(b375$diagnostic_low,b375$diagnostic_high),c(s$diagnostic_low,s$diagnostic_high))
 previous<-endpoint_interval_stable(c(b250$diagnostic_low,b250$diagnostic_high),c(b375$diagnostic_low,b375$diagnostic_high))
 gate<-if(!is.finite(theta))'geen_2000_langemaat' else if(s$n_valid<500)'geen_2000_interval_uitval' else if(!s$complete_non_degenerate)'geen_2000_interval_constante_verdeling' else 'kandidaat_2000_validatie'
 list(gate=gate,n_valid=s$n_valid,latest_stable=latest,both_stable=latest&&previous,
  low250=b250$diagnostic_low,high250=b250$diagnostic_high,low375=b375$diagnostic_low,high375=b375$diagnostic_high,
  low500=s$diagnostic_low,high500=s$diagnostic_high,
  last_low_shift=abs(s$diagnostic_low-b375$diagnostic_low),last_high_shift=abs(s$diagnostic_high-b375$diagnostic_high))
}
assess_trim_500_validation <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==3);repo<-normalizePath(args[1],mustWork=TRUE);run<-normalizePath(args[2],mustWork=TRUE);out<-args[3]
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 source(file.path(repo,'R/trim_endpoint_bootstrap.R'))
 run_endpoint_assessment(c(repo,run,file.path(out,'raw_assessment'),'500'))
 gc()
 p<-read.csv(file.path(out,'raw_assessment/primary.csv'));e<-read.csv(file.path(out,'raw_assessment/estimates.csv'));s<-read.csv(file.path(out,'raw_assessment/summary.csv'))
 pilot<-read.csv(file.path(repo,'trim/bootstrap/endpoint_all_2025_50_20261103/primary.csv'))
 previous_e<-read.csv(file.path(repo,'trim/bootstrap/endpoint_all_2025_50_20261103/estimates.csv'))
 first50<-e[e$replicate_id<=50,];stopifnot(identical(first50[c('soort_id','replicate_id','width','status')],previous_e[c('soort_id','replicate_id','width','status')]))
 stopifnot(isTRUE(all.equal(first50$estimate_net_pct,previous_e$estimate_net_pct,tolerance=1e-10)))
 rows<-lapply(seq_len(nrow(p)),function(i){
  row<-p[i,];v<-e[e$soort_id==row$soort_id&e$width==5&e$replicate_id>0,];stopifnot(identical(v$replicate_id,1:500))
  d<-endpoint_2000_decision(row$baseline_net_pct,v$estimate_net_pct)
  stopifnot(row$n_valid==d$n_valid);d$n_valid<-NULL
  cbind(row,data.frame(pilot50_n=pilot$n_valid[match(row$soort_id,pilot$soort_id)],pilot50_gate=pilot$gate_500[match(row$soort_id,pilot$soort_id)]),as.data.frame(d,stringsAsFactors=FALSE))
 })
 per_species<-do.call(rbind,rows);write.csv(per_species,file.path(out,'per_species.csv'),row.names=FALSE,na='')
 primary_estimates<-e[e$width==5,c('soort_id','replicate_id','estimate_net_pct','status','first_mean','last_mean','outside_problem_years','n_outside_problem_years')];write.csv(primary_estimates,file.path(out,'primary_estimates.csv'),row.names=FALSE,na='')
 write.csv(s,file.path(out,'window_sensitivity.csv'),row.names=FALSE,na='')
 manifests<-lapply(list.files(file.path(run,'batches'),pattern='\\.rds\\.manifest\\.rds$',full.names=TRUE),readRDS)
 stopifnot(length(manifests)==100L,all(vapply(manifests,function(m)m$error_count==0,logical(1))))
 resources<-list(batch_count=100L,replicates=500L,batch_errors=0L,runtime_seconds=sum(vapply(manifests,`[[`,numeric(1),'runtime_seconds')),
  peak_R_memory_mb=max(vapply(manifests,`[[`,numeric(1),'peak_memory_mb')),max_system_swap_growth_bytes=max(vapply(manifests,`[[`,numeric(1),'swap_growth_bytes')))
 jsonlite::write_json(resources,file.path(out,'resources.json'),auto_unbox=TRUE,pretty=TRUE)
 raw_manifest<-jsonlite::read_json(file.path(out,'raw_assessment/manifest.json'),simplifyVector=TRUE)
 jsonlite::write_json(list(source_period='1958-2025',species=156L,replicates=500L,run_bundle_sha256=digest::digest(file=file.path(run,'input/bundle_manifest.json'),algo='sha256'),
  metric_manifest=raw_manifest,validation_criteria_sha256=digest::digest(file=file.path(repo,'trim/bootstrap/endpoint_2025_500_window_check_20261103/CRITERIA.md'),algo='sha256'),
  original_500_criteria_sha256=digest::digest(file=file.path(repo,'trim/bootstrap/endpoint_2025_500_20261103/CRITERIA.md'),algo='sha256'),
  reassessment_criteria_commit='f238f144',assessment_script_sha256=digest::digest(file=file.path(repo,'R/assess_trim_500_validation.R'),algo='sha256'),first50_estimates_and_statuses_reproduced=TRUE,
  bootstrap_started_2000=FALSE,formal_intervals=FALSE),file.path(out,'manifest.json'),auto_unbox=TRUE,pretty=TRUE)
 print(table(per_species$gate));cat('ASSESSMENT_500_COMPLETE\n')
}
if(sys.nframe()==0L)assess_trim_500_validation()
