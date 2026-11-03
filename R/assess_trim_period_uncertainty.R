#!/usr/bin/env Rscript
period_distribution_500 <- function(theta,v,reference=FALSE) {
 stopifnot(length(v)==500L)
 s<-endpoint_interval_diagnostic(theta,v,500L)
 bounds<-function(n){d<-endpoint_interval_diagnostic(theta,v[seq_len(n)],n);c(d$diagnostic_low,d$diagnostic_high)}
 latest<-endpoint_interval_stable(bounds(375L),bounds(500L));previous<-endpoint_interval_stable(bounds(250L),bounds(375L))
 if(reference){s$status<-'referentie100_definitie_geen_band';s$diagnostic_low<-s$diagnostic_high<-NA_real_;s$complete_non_degenerate<-FALSE;latest<-previous<-FALSE}
 cbind(s,data.frame(latest_stable=latest,both_stable=latest&&previous))
}
assess_trim_period_uncertainty <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==4L);repo<-normalizePath(args[1],mustWork=TRUE);parent<-normalizePath(args[2],mustWork=TRUE);recovery<-normalizePath(args[3],mustWork=TRUE);out<-args[4]
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 for(n in c('compare_trim_index_summaries.R','trim_endpoint_bootstrap.R','trim_period_uncertainty.R','trim_bootstrap_core.R','merge_trim_bootstrap_batches.R','build_trim_bootstrap_bundle.R','validate_trim_bootstrap_bundle.R'))source(file.path(repo,'R',n))
 validate_trim_bootstrap_engine(file.path(parent,'input'),repo);cx<-readRDS(file.path(parent,'input/context.rds'));pm<-jsonlite::read_json(file.path(parent,'input/bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(bundle_sha256_file(file.path(parent,'input/context.rds'))==pm$context_sha256)
 identity<-readRDS(file.path(recovery,'identity.rds'))
 expected<-digest::digest(list(parent=pm$context_sha256,core=bundle_sha256_file(file.path(repo,'R/trim_period_uncertainty.R')),script=bundle_sha256_file(file.path(repo,'R/run_trim_period_recovery.R'))),algo='sha256');stopifnot(identity$config_hash==expected)
 ids<-sort(unique(cx$species_matrix$soort_id));stopifnot(length(ids)==156L)
 names_species<-read.csv(file.path(repo,'trim/bootstrap/endpoint_2025_500_window_check_20261103/per_species.csv'))
 source<-read.csv(file.path(repo,'trim/soorten/soortindices_per_jaar.csv'));names(source)[names(source)=='index_100']<-'index_value'
 pk<-expand.grid(period=c('pre','post'),soort_id=ids,stringsAsFactors=FALSE);yk<-expand.grid(jaar=1958:2025,soort_id=ids,stringsAsFactors=FALSE)
 P<-matrix(NA_real_,nrow(pk),501L);Y<-matrix(NA_real_,nrow(yk),501L);PS<-matrix('',nrow(pk),501L);OK<-matrix(FALSE,nrow(pk),501L)
 meta<-vector('list',nrow(pk));references<-rep(NA_integer_,nrow(pk));targets<-vector('list',nrow(pk))
 for(i in seq_len(nrow(pk))) {
  id<-pk$soort_id[i];period<-pk$period[i];t<-cx$species_targets[[as.character(id)]][[period]];years<-t$years;targets[[i]]<-years
  ix<-source[source$soort_id==id&source$jaar%in%years,c('jaar','index_value')]
  positive<-ix$jaar[is.finite(ix$index_value)&ix$index_value>0];ref<-if(length(positive))min(positive) else NA_integer_;references[i]<-ref
  b<-period_endpoint_estimate(ix,years,t$ok);P[i,1]<-b$estimate;PS[i,1]<-b$status;OK[i,1]<-isTRUE(t$ok)
  positions<-(match(id,ids)-1L)*68L+match(years,1958:2025);Y[positions,1]<-fixed_reference_indices(ix,years,ref,t$ok)
  positive_plots<-function(ys){d<-cx$species_matrix;d<-d[d$soort_id==id&d$jaar%in%ys&d$geteld%in%TRUE&is.finite(d$count_adjusted)&d$count_adjusted>0,];length(unique(d$plot_id))}
  meta[[i]]<-data.frame(soort_id=id,soort_naam=names_species$soort_naam[match(id,names_species$soort_id)],period=period,period_calendar_start=if(period=='pre')1958L else 1984L,period_calendar_end=if(period=='pre')1983L else 2025L,model_start=if(length(years))min(years) else NA_integer_,model_end=if(length(years))max(years) else NA_integer_,n_model_years=length(years),baseline_model_ok=isTRUE(t$ok),baseline_model_reason=t$reason,reference_year=ref,first_window=if(length(years)>=10L)paste(head(years,5),collapse=';') else '',last_window=if(length(years)>=10L)paste(tail(years,5),collapse=';') else '',source_positive_begin_plots=positive_plots(head(years,5)),source_positive_end_plots=positive_plots(tail(years,5)))
 }
 refits<-0L;methods<-list();batchmanifests<-list();parenthashes<-list()
 for(from in seq.int(1L,500L,5L)) {
  path<-file.path(recovery,'batches',sprintf('batch-%06d-%06d.rds',from,from+4L));z<-merge_trim_bootstrap_batches(path,from:(from+4L));stopifnot(identical(z$identity,identity));batchmanifests[[length(batchmanifests)+1L]]<-readRDS(paste0(path,'.manifest.rds'))
  originalpath<-file.path(parent,'batches',basename(path));ph<-bundle_sha256_file(originalpath);parenthashes[[basename(path)]]<-ph
  for(r in z$results) {
   n<-r$replicate_id;stopifnot(identical(r$draw,make_stratified_cluster_draw(cx$clusters,n,cx$config$run_seed)),r$parent_batch_sha256==ph,nrow(r$periods)==312L)
   refits<-refits+sum(r$periods$refitted);methods[[length(methods)+1L]]<-as.data.frame(table(r$periods$method),stringsAsFactors=FALSE)
   # Split once per draw; no dependence on another period or a calibration bridge.
   splitix<-split(r$indices,paste(r$indices$soort_id,r$indices$period,sep=':'))
   for(i in seq_len(nrow(pk))) {
    id<-pk$soort_id[i];period<-pk$period[i];k<-which(r$periods$soort_id==id&r$periods$period==period);stopifnot(length(k)==1L)
    ok<-isTRUE(r$periods$ok[k]);ix<-splitix[[paste(id,period,sep=':')]];if(is.null(ix))ix<-data.frame(jaar=integer(),index_value=numeric())
    years<-targets[[i]];b<-period_endpoint_estimate(ix,years,ok);P[i,n+1L]<-b$estimate;PS[i,n+1L]<-b$status;OK[i,n+1L]<-ok
    positions<-(match(id,ids)-1L)*68L+match(years,1958:2025);Y[positions,n+1L]<-fixed_reference_indices(ix,years,references[i],ok)
   }
  }
 }
 rows<-lapply(seq_len(nrow(pk)),function(i)cbind(meta[[i]],data.frame(n_planned=500L,baseline_net_pct=P[i,1],baseline_status=PS[i,1],n_model_failure=sum(!OK[i,-1]),n_zero_end=sum(PS[i,-1]=='nul_eindgemiddelde'),n_zero_start=sum(PS[i,-1]=='nul_begingemiddelde'),reasons=paste(names(table(PS[i,-1])),table(PS[i,-1]),sep='=',collapse=';')),period_distribution_500(P[i,1],P[i,-1])))
 periods<-do.call(rbind,rows);rows<-vector('list',nrow(yk))
 d<-cx$species_matrix;d<-d[d$geteld%in%TRUE&is.finite(d$count_adjusted),];counted<-table(paste(d$soort_id,d$jaar,sep=':'));positive<-table(paste(d$soort_id[d$count_adjusted>0],d$jaar[d$count_adjusted>0],sep=':'))
 source_n<-function(tab,key){v<-unname(tab[key]);if(length(v)&&is.finite(v))as.integer(v) else 0L}
 for(i in seq_len(nrow(yk))) {
  id<-yk$soort_id[i];year<-yk$jaar[i];period<-if(year<1984)'pre' else 'post';pi<-which(pk$soort_id==id&pk$period==period);inside<-year%in%targets[[pi]];isref<-is.finite(references[pi])&&year==references[pi]
  s<-period_distribution_500(Y[i,1],Y[i,-1],reference=isref)
  if(!inside)s$status<-'buiten_bevroren_modeljaren' else if(!OK[pi,1])s$status<-'baseline_model_niet_schatbaar'
  rows[[i]]<-cbind(data.frame(soort_id=id,soort_naam=names_species$soort_naam[match(id,names_species$soort_id)],period=period,jaar=year,inside_model_years=inside,reference_year=references[pi],is_reference=isref,baseline_index=Y[i,1],n_planned=500L,n_model_failure=if(inside)sum(!OK[pi,-1]) else NA_integer_,n_zero_indices=sum(Y[i,-1]==0,na.rm=TRUE),n_counted_source_cells=source_n(counted,paste(id,year,sep=':')),n_positive_source_plots=source_n(positive,paste(id,year,sep=':'))),s)
 }
 annual<-do.call(rbind,rows);stopifnot(nrow(periods)==312L,nrow(annual)==10608L)
 dir.create(out,recursive=TRUE,showWarnings=FALSE)
 write.csv(periods,file.path(out,'periods.csv'),row.names=FALSE,na='');write.csv(annual,file.path(out,'annual_indices.csv'),row.names=FALSE,na='')
 saveRDS(list(period_keys=pk,annual_keys=yk,period_values=P,annual_values=Y,period_status=PS,period_model_ok=OK),file.path(out,'period_annual_draws.rds'))
 mt<-do.call(rbind,methods);mt<-aggregate(Freq~Var1,mt,sum)
 jsonlite::write_json(list(species=156L,period='1958-2025',replicates=500L,period_rows=312L,annual_rows=10608L,recovery_model_fits=refits,retrieval_methods=mt,recovery_identity=identity,parent_context_sha256=pm$context_sha256,parent_batch_hashes=parenthashes,criteria_commit='e7f68940',criteria_sha256=bundle_sha256_file(file.path(repo,'trim/bootstrap/species_2025_2000_20261103/CRITERIA.md')),assessment_script_sha256=bundle_sha256_file(file.path(repo,'R/assess_trim_period_uncertainty.R')),period_helper_sha256=bundle_sha256_file(file.path(repo,'R/trim_period_uncertainty.R')),pointwise_annual_bands=TRUE,simultaneous_bands=FALSE,formal_intervals=FALSE,batch_errors=sum(vapply(batchmanifests,`[[`,numeric(1),'error_count')),runtime_seconds=sum(vapply(batchmanifests,`[[`,numeric(1),'runtime_seconds'))),file.path(out,'period_manifest.json'),auto_unbox=TRUE,pretty=TRUE)
 print(table(periods$status));print(table(annual$status));cat('INDEPENDENT_PERIOD_ANNUAL_ASSESSMENT_COMPLETE\n')
}
if(sys.nframe()==0L)assess_trim_period_uncertainty()
