#!/usr/bin/env Rscript
assess_trim_period_2000 <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==4L);repo<-normalizePath(args[1]);parent<-normalizePath(args[2]);prior<-normalizePath(args[3]);root<-normalizePath(args[4])
 source(path.expand('~/Documents/GitHub/Meijendel/R/trial_storage.R'));root<-trial_output(root)
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 for(n in c('compare_trim_index_summaries.R','trim_endpoint_bootstrap.R','trim_period_uncertainty.R','assess_trim_period_uncertainty.R','trim_bootstrap_core.R','merge_trim_bootstrap_batches.R','build_trim_bootstrap_bundle.R'))source(file.path(repo,'R',n))
 cx<-readRDS(file.path(parent,'input/context.rds'));identity<-readRDS(file.path(root,'identity.rds'));config<-readRDS(file.path(root,'config.rds'));keys<-read.csv(file.path(root,'selected_periods.csv'))
 oldpath<-file.path(prior,'assessment/period_annual_draws.rds');stopifnot(config$first500==bundle_sha256_file(oldpath),config$script==bundle_sha256_file(file.path(repo,'R/run_trim_period_2000.R')),config$criteria==bundle_sha256_file(file.path(repo,'trim/bootstrap/periods_2025_2000_20261104/CRITERIA.md')),config$parent_context==bundle_sha256_file(file.path(parent,'input/context.rds')))
 old<-readRDS(oldpath);pk<-old$period_keys;yk<-old$annual_keys
 widen<-function(m,fill) cbind(m,matrix(fill,nrow(m),1500L))
 P<-widen(old$period_values,NA_real_);Y<-widen(old$annual_values,NA_real_);PS<-widen(old$period_status,'');OK<-widen(old$period_model_ok,FALSE);REFOK<-widen(old$annual_reference_ok,FALSE)
 archive<-file.path(repo,'trim/bootstrap/species_2025_2000_20261103');periods<-read.csv(file.path(archive,'periods.csv'));annual<-read.csv(file.path(archive,'annual_indices.csv'))
 kp<-paste(pk$soort_id,pk$period);selected<-which(kp%in%paste(keys$soort_id,keys$period));stopifnot(length(selected)==141L)
 stopifnot(identical(kp,paste(periods$soort_id,periods$period)),identical(paste(yk$soort_id,yk$jaar),paste(annual$soort_id,annual$jaar)))
 references<-periods$reference_year;targets<-lapply(seq_len(nrow(pk)),function(i)cx$species_targets[[as.character(pk$soort_id[i])]][[pk$period[i]]]$years)
 methods<-list();batchmanifests<-list();parenthashes<-list()
 for(from in seq.int(501L,2000L,5L)){
  path<-file.path(root,'batches',sprintf('batch-%06d-%06d.rds',from,from+4L));z<-merge_trim_bootstrap_batches(path,from:(from+4L));stopifnot(identical(z$identity,identity));batchmanifests[[length(batchmanifests)+1L]]<-readRDS(paste0(path,'.manifest.rds'))
  oldbatch<-file.path(prior,'batches',basename(path));ph<-bundle_sha256_file(oldbatch);parenthashes[[basename(path)]]<-ph
  for(r in z$results){n<-r$replicate_id;stopifnot(identical(r$draw,make_stratified_cluster_draw(cx$clusters,n,cx$config$run_seed)),r$parent_batch_sha256==ph,nrow(r$periods)==length(selected));methods[[length(methods)+1L]]<-r$periods[,c('method','reused','refitted','fit_attempts')]
   ixsplit<-split(r$indices,paste(r$indices$soort_id,r$indices$period));rk<-paste(r$periods$soort_id,r$periods$period)
   for(i in selected){k<-match(kp[i],rk);stopifnot(!is.na(k));ok<-isTRUE(r$periods$ok[k]);ix<-ixsplit[[kp[i]]];if(is.null(ix))ix<-data.frame(jaar=integer(),index_value=numeric())
    b<-period_endpoint_estimate(ix,targets[[i]],ok);P[i,n+1L]<-b$estimate;PS[i,n+1L]<-b$status;OK[i,n+1L]<-ok
    positions<-which(yk$soort_id==pk$soort_id[i]&yk$jaar%in%targets[[i]]);v<-fixed_reference_indices(ix,targets[[i]],references[i],ok)
    Y[positions,n+1L]<-v[as.character(yk$jaar[positions])];REFOK[i,n+1L]<-isTRUE(is.finite(v[as.character(references[i])]))
   }
  }
 }
 # The first 500 draw columns and baseline are protected, including all NA/zero patterns.
 for(pair in list(list(P,old$period_values),list(Y,old$annual_values),list(PS,old$period_status),list(OK,old$period_model_ok),list(REFOK,old$annual_reference_ok)))stopifnot(identical(pair[[1]][,1:501],pair[[2]]))
 checks<-list();j<-0L
 checkpoint<-function(type,id,period,year,theta,v,reference=FALSE){
  for(n in c(500L,1000L,1500L,2000L)){s<-endpoint_interval_diagnostic(theta,v[seq_len(n)],n);if(reference)s$diagnostic_low<-s$diagnostic_high<-NA_real_
   j<<-j+1L;checks[[j]]<<-data.frame(type=type,soort_id=id,period=period,jaar=year,n_planned=n,n_valid=s$n_valid,diagnostic_low=s$diagnostic_low,diagnostic_high=s$diagnostic_high)
  }
 }
 for(i in selected){v<-P[i,-1];s<-period_distribution(P[i,1],v);periods[i,names(s)]<-s;periods$n_planned[i]<-2000L;periods$n_model_failure[i]<-sum(!OK[i,-1]);periods$n_reference_failure_for_annual_indices[i]<-sum(OK[i,-1]&!REFOK[i,-1]);periods$n_zero_end[i]<-sum(PS[i,-1]=='nul_eindgemiddelde');periods$n_zero_start[i]<-sum(PS[i,-1]=='nul_begingemiddelde');f<-table(PS[i,-1]);periods$reasons[i]<-paste(names(f),f,sep='=',collapse=';');checkpoint('period',pk$soort_id[i],pk$period[i],NA_integer_,P[i,1],v)}
 for(i in seq_len(nrow(annual))){pi<-match(paste(annual$soort_id[i],annual$period[i]),kp);if(!pi%in%selected)next
  v<-Y[i,-1];inside<-annual$inside_model_years[i];ref<-annual$is_reference[i];s<-period_distribution(Y[i,1],v,reference=ref)
  if(!annual$baseline_model_ok[i])s$status<-'baseline_model_niet_schatbaar' else if(!inside)s$status<-'buiten_bevroren_modeljaren'
  annual[i,names(s)]<-s;annual$n_planned[i]<-2000L;annual$n_model_failure[i]<-if(inside)sum(!OK[pi,-1]) else NA_integer_;annual$n_reference_failure[i]<-if(inside)sum(OK[pi,-1]&!REFOK[pi,-1]) else NA_integer_;annual$n_year_index_missing_or_invalid[i]<-if(inside)sum(OK[pi,-1]&REFOK[pi,-1]&!is.finite(v)) else NA_integer_;annual$n_zero_indices[i]<-sum(v==0,na.rm=TRUE)
  if(inside)checkpoint('annual',annual$soort_id[i],annual$period[i],annual$jaar[i],Y[i,1],v,ref)
 }
 inside<-annual$inside_model_years;stopifnot(all(with(annual[inside,],n_valid+n_model_failure+n_reference_failure+n_year_index_missing_or_invalid)==annual$n_planned[inside]))
 stopifnot(nrow(periods)==312L,nrow(annual)==10608L,length(unique(periods$soort_id))==156L,all(is.na(periods$ci95_low)),all(is.na(annual$ci95_low)))
 out<-file.path(root,'assessment');dir.create(out,recursive=TRUE,showWarnings=FALSE)
 write.csv(periods,file.path(out,'periods.csv'),row.names=FALSE,na='');write.csv(annual,file.path(out,'annual_indices.csv'),row.names=FALSE,na='');write.csv(do.call(rbind,checks),file.path(out,'checkpoints.csv'),row.names=FALSE,na='')
 saveRDS(list(period_keys=pk,annual_keys=yk,period_values=P,annual_values=Y,period_status=PS,period_model_ok=OK,annual_reference_ok=REFOK),file.path(out,'period_annual_draws.rds'))
 methods<-do.call(rbind,methods);mt<-as.data.frame(table(methods$method))
 jsonlite::write_json(list(run_id=identity$run_id,species=156L,period='1958-2025',selected_periods=141L,selected_species=89L,retained_500_periods=171L,new_replicate_ids=c(501L,2000L),first500_preserved_exact=TRUE,criteria_commit='32123615',criteria_sha256=config$criteria,identity=identity,parent_context_sha256=config$parent_context,first500_sha256=config$first500,parent_batch_hashes=parenthashes,retrieval_methods=mt,reused_period_results=sum(methods$reused),recovery_fits=sum(methods$refitted),new_period_calculations=sum(!methods$reused),new_fit_attempts=sum(methods$fit_attempts[!methods$reused]),recovery_fit_attempts=sum(methods$fit_attempts[methods$reused]),fit_attempts=sum(methods$fit_attempts),batch_errors=sum(vapply(batchmanifests,`[[`,numeric(1),'error_count')),runtime_seconds=sum(vapply(batchmanifests,`[[`,numeric(1),'runtime_seconds')),pointwise_annual_bands=TRUE,simultaneous_bands=FALSE,formal_intervals=FALSE,assessment_script_sha256=bundle_sha256_file(file.path(repo,'R/assess_trim_period_2000.R'))),file.path(out,'period_manifest.json'),auto_unbox=TRUE,pretty=TRUE)
 print(table(periods$n_planned,periods$status));print(table(annual$n_planned,annual$status));cat('INDEPENDENT_PERIOD_2000_ASSESSMENT_COMPLETE\n')
}
if(sys.nframe()==0L)assess_trim_period_2000()
