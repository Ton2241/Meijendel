#!/usr/bin/env Rscript
run_trim_period_recovery <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==3L);repo<-normalizePath(args[1],mustWork=TRUE);parent<-normalizePath(args[2],mustWork=TRUE);root<-args[3]
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 for(n in c('trim_trend_contract.R','trim_bootstrap_core.R','trim_bridge_core.R','run_trim_bootstrap_batch.R','build_trim_bootstrap_bundle.R','validate_trim_bootstrap_bundle.R','trim_period_uncertainty.R'))source(file.path(repo,'R',n))
 validate_trim_bootstrap_engine(file.path(parent,'input'),repo)
 cx<-readRDS(file.path(parent,'input/context.rds'));m<-jsonlite::read_json(file.path(parent,'input/bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(bundle_sha256_file(file.path(parent,'input/context.rds'))==m$context_sha256)
 ids<-sort(unique(cx$species_matrix$soort_id));stopifnot(length(ids)==156L)
 oldidentity<-readRDS(file.path(parent,'input/identity.rds'));stopifnot(oldidentity$software_id==paste0('R-',getRversion(),'_rtrim-',utils::packageVersion('rtrim')))
 dir.create(root,recursive=TRUE,showWarnings=FALSE)
 identity<-list(run_id='period-recovery-2025-500-20261103',source_hash=m$source_hash,config_hash=digest::digest(list(parent=m$context_sha256,core=bundle_sha256_file(file.path(repo,'R/trim_period_uncertainty.R')),script=bundle_sha256_file(file.path(repo,'R/run_trim_period_recovery.R'))),algo='sha256'),code_commit=system2('git',c('-C',repo,'rev-parse','HEAD'),stdout=TRUE)[1],software_id=paste0('R-',getRversion(),'_rtrim-',utils::packageVersion('rtrim')))
 identity_path<-file.path(root,'identity.rds')
 if(file.exists(identity_path)){old<-readRDS(identity_path);stopifnot(old$config_hash==identity$config_hash,old$source_hash==identity$source_hash,old$software_id==identity$software_id);identity<-old} else saveRDS(identity,identity_path)
 for(from in seq.int(1L,500L,5L)) {
  to<-from+4L;path<-file.path(parent,'batches',sprintf('batch-%06d-%06d.rds',from,to));pm<-readRDS(paste0(path,'.manifest.rds'));stopifnot(bundle_sha256_file(path)==pm$output_sha256,identical(pm$identity,oldidentity))
  old<-readRDS(path)$results
  output<-file.path(root,'batches',basename(path))
  result<-run_trim_bootstrap_batch(identity,from:to,output,replicate_fn=function(n){
   r<-old[[as.character(n)]];stopifnot(identical(r$draw,make_stratified_cluster_draw(cx$clusters,n,cx$config$run_seed)))
   rows<-list();ix<-list();j<-0L
   for(id in ids)for(period in c('pre','post')){
    v<-recover_independent_period(r,id,period,cx);j<-j+1L
    rows[[j]]<-data.frame(soort_id=id,period=period,ok=v$ok,reason=v$reason,model=v$model,refitted=v$refitted,refit_attempts=v$refit_attempts,method=v$method)
    if(nrow(v$index))ix[[j]]<-cbind(data.frame(soort_id=id,period=period),v$index)
   }
   value<-list(replicate_id=n,draw=r$draw,periods=do.call(rbind,rows),indices=do.call(rbind,ix),parent_batch_sha256=pm$output_sha256)
   cat('PERIOD_RECOVERY_DONE',n,'refits',sum(value$periods$refitted),'\n');flush.console();value
  },worker_id=Sys.info()[['nodename']])
  if(length(result$errors))stop('Herstelbatchfouten: ',paste(names(result$errors),collapse=','))
  cat('PERIOD_BATCH_DONE',from,to,'runtime',result$runtime_seconds,'\n');flush.console();rm(result,old);gc()
 }
 cat('PERIOD_RECOVERY_500_COMPLETE\n')
}
if(sys.nframe()==0L)run_trim_period_recovery()
