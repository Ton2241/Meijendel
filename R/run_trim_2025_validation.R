#!/usr/bin/env Rscript
validation_2025_context <- function(parent,run_id) {
 x<-parent;x$config$planned_replicates<-500L;x$config$analysis_end_year<-2025L;x$config$run_id<-run_id;x
}
run_trim_2025_validation <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==3L);repo<-normalizePath(args[1],mustWork=TRUE);parent_run<-normalizePath(args[2],mustWork=TRUE);root<-args[3]
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 for(n in c('trim_trend_contract.R','trim_bootstrap_core.R','trim_bridge_core.R','run_trim_bootstrap_batch.R','build_trim_bootstrap_bundle.R','validate_trim_bootstrap_bundle.R','merge_trim_bootstrap_batches.R'))source(file.path(repo,'R',n))
 pm<-jsonlite::read_json(file.path(parent_run,'input/bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(bundle_sha256_file(file.path(parent_run,'input/context.rds'))==pm$context_sha256,pm$analysis_end_year==2025,pm$species_count==156,pm$cluster_count==52)
 parent<-readRDS(file.path(parent_run,'input/context.rds'));oldid<-readRDS(file.path(parent_run,'input/identity.rds'))
 software<-paste0('R-',getRversion(),'_rtrim-',utils::packageVersion('rtrim'));stopifnot(software==oldid$software_id)
 run_id<-'species-validation-2025-500-20261103';context<-validation_2025_context(parent,run_id)
 stopifnot(identical(context[names(context)!='config'],parent[names(parent)!='config']))
 bundle<-file.path(root,'input');dir.create(root,recursive=TRUE,showWarnings=FALSE)
 if(!dir.exists(bundle)) {
  commit<-system2('git',c('-C',repo,'rev-parse','HEAD'),stdout=TRUE)[1]
  identity<-list(run_id=run_id,source_hash=pm$source_hash,config_hash=digest::digest(context$config,algo='sha256'),code_commit=commit,software_id=software)
  write_trim_bootstrap_bundle(context,identity,bundle,metadata=list(analysis_end_year=2025L,planned_replicates=500L,publication_status='validatie_niet_publiceren',species_count=156L,cluster_count=52L,
   parent_run_id=pm$run_id,parent_context_sha256=pm$context_sha256,cache_sha256=pm$cache_sha256,engine_sha256=as.list(trim_bootstrap_engine_hashes(repo))))
  stopifnot(file.copy(file.path(parent_run,'baseline.csv'),file.path(root,'baseline.csv'),overwrite=FALSE))
 }
 m<-jsonlite::read_json(file.path(bundle,'bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(bundle_sha256_file(file.path(bundle,'context.rds'))==m$context_sha256,bundle_sha256_file(file.path(bundle,'identity.rds'))==m$identity_sha256,
  identical(readRDS(file.path(bundle,'context.rds')),context),m$planned_replicates==500,bundle_sha256_file(file.path(root,'baseline.csv'))==bundle_sha256_file(file.path(parent_run,'baseline.csv')))
 validate_trim_bootstrap_engine(bundle,repo);identity<-readRDS(file.path(bundle,'identity.rds'))
 original<-merge_trim_bootstrap_batches(list.files(file.path(parent_run,'batches'),pattern='^batch-[0-9]+-[0-9]+\\.rds$',full.names=TRUE),1:50)$results
 fatal<-FALSE
 for(from in seq.int(1L,500L,5L)) {
  to<-min(from+4L,500L);file<-file.path(root,'batches',sprintf('batch-%06d-%06d.rds',from,to))
  result<-run_trim_bootstrap_batch(identity,from:to,file,replicate_fn=function(id){
   if(fatal)stop('Gestopt na reproduceerbaarheidsfout')
   value<-run_trim_bootstrap_replicate(context,id)
   if(id<=50L)stopifnot(identical(value$draw,original[[id]]$draw))
   if(id<=2L){
    checks<-vapply(c('species','indices'),function(n)isTRUE(all.equal(value[[n]],original[[id]][[n]],tolerance=1e-10)),logical(1))
    if(!all(checks)){fatal<<-TRUE;stop('Eerste replicatie wijkt inhoudelijk af van opgeslagen pilot')}
    cat('REPRODUCTION_PASS',id,'\n')
   }
   cat('REPLICATE_DONE',id,format(Sys.time(),tz='UTC',usetz=TRUE),'\n');flush.console();value
  },worker_id=Sys.info()[['nodename']])
  if(length(result$errors))stop('Batch bevat fouten; geen vervolgbatch: ',paste(names(result$errors),collapse=','))
  cat('BATCH_DONE',from,to,'runtime',result$runtime_seconds,'peak_R_MB',result$peak_memory_mb,'swap_growth',result$swap_growth_bytes,'\n');flush.console()
  rm(result);gc()
 }
 cat('VALIDATION_500_COMPLETE\n')
}
if(sys.nframe()==0L)run_trim_2025_validation()
