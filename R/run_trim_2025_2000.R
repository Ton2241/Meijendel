#!/usr/bin/env Rscript
extension_2000_context <- function(parent,ids,run_id) {
 x<-parent;x$species_matrix<-parent$species_matrix[parent$species_matrix$soort_id%in%ids,,drop=FALSE]
 x$species_targets<-parent$species_targets[as.character(ids)]
 x$config$planned_replicates<-2000L;x$config$run_id<-run_id
 x$config$species_targets_sha256<-digest::digest(x$species_targets,algo='sha256');x
}
extension_parent_provenance <- function(paths) {
 data.frame(file=basename(paths),sha256=unname(vapply(paths,bundle_sha256_file,character(1))),row.names=NULL)
}
run_trim_2025_2000 <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==3L);repo<-normalizePath(args[1],mustWork=TRUE);parent_root<-normalizePath(args[2],mustWork=TRUE);root<-args[3]
 source(path.expand('~/Documents/GitHub/Meijendel/R/trial_storage.R'));root<-trial_output(root)
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 for(n in c('trim_trend_contract.R','trim_bootstrap_core.R','trim_bridge_core.R','run_trim_bootstrap_batch.R','build_trim_bootstrap_bundle.R','validate_trim_bootstrap_bundle.R','merge_trim_bootstrap_batches.R'))source(file.path(repo,'R',n))
 pm<-jsonlite::read_json(file.path(parent_root,'input/bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(bundle_sha256_file(file.path(parent_root,'input/context.rds'))==pm$context_sha256,pm$species_count==156L,pm$planned_replicates==500L,pm$analysis_end_year==2025L)
 validate_trim_bootstrap_engine(file.path(parent_root,'input'),repo)
 oldid<-readRDS(file.path(parent_root,'input/identity.rds'));parent<-readRDS(file.path(parent_root,'input/context.rds'))
 software<-paste0('R-',getRversion(),'_rtrim-',utils::packageVersion('rtrim'));stopifnot(software==oldid$software_id)
 selection<-read.csv(file.path(repo,'trim/bootstrap/endpoint_2025_500_window_check_20261103/per_species.csv'));ids<-sort(selection$soort_id[selection$gate=='kandidaat_2000_validatie']);stopifnot(length(ids)==32L,nrow(parent$clusters)==52L)
 context<-extension_2000_context(parent,ids,'species-extension-2025-2000-20261103');stopifnot(identical(context$clusters,parent$clusters),identical(context$config$run_seed,parent$config$run_seed))
 bundle<-file.path(root,'input');dir.create(root,recursive=TRUE,showWarnings=FALSE)
 if(!dir.exists(bundle)) {
  identity<-list(run_id=context$config$run_id,source_hash=pm$source_hash,config_hash=digest::digest(context$config,algo='sha256'),code_commit=system2('git',c('-C',repo,'rev-parse','HEAD'),stdout=TRUE)[1],software_id=software)
  write_trim_bootstrap_bundle(context,identity,bundle,metadata=list(analysis_end_year=2025L,planned_replicates=2000L,new_replicate_ids=c(501L,2000L),species_count=32L,cluster_count=52L,publication_status='validatie_niet_publiceren',parent_run_id=pm$run_id,parent_context_sha256=pm$context_sha256,parent_manifest_sha256=bundle_sha256_file(file.path(parent_root,'input/bundle_manifest.json')),selected_species_ids=ids,engine_sha256=as.list(trim_bootstrap_engine_hashes(repo))))
 }
 m<-jsonlite::read_json(file.path(bundle,'bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(identical(readRDS(file.path(bundle,'context.rds')),context),bundle_sha256_file(file.path(bundle,'context.rds'))==m$context_sha256,bundle_sha256_file(file.path(bundle,'identity.rds'))==m$identity_sha256)
 validate_trim_bootstrap_engine(bundle,repo);identity<-readRDS(file.path(bundle,'identity.rds'))
 parent_paths<-list.files(file.path(parent_root,'batches'),pattern='^batch-[0-9]+-[0-9]+\\.rds$',full.names=TRUE)
 saved<-merge_trim_bootstrap_batches(parent_paths,1:500)
 provenance<-extension_parent_provenance(parent_paths)
 provenance_path<-file.path(root,'parent_batches.csv')
 if(file.exists(provenance_path))stopifnot(identical(read.csv(provenance_path),provenance)) else write.csv(provenance,provenance_path,row.names=FALSE)
 # Reproduce saved results before new fits: preserve source/clusters and species selection semantics.
 marker<-file.path(root,'reproduction.rds')
 if(!file.exists(marker)) {
  for(i in 1:2) {
   value<-run_trim_bootstrap_replicate(context,i);stopifnot(identical(value$draw,saved$results[[i]]$draw))
   for(n in c('species','indices')) {
    a<-value[[n]];b<-saved$results[[i]][[n]];b<-b[b$soort_id%in%ids,,drop=FALSE];rownames(a)<-rownames(b)<-NULL
    stopifnot(isTRUE(all.equal(a,b,tolerance=1e-10)))
   }
   cat('REPRODUCTION_32_PASS',i,'\n');flush.console()
  }
  saveRDS(list(ids=ids,context_sha256=m$context_sha256,replicates=1:2),marker)
 } else stopifnot(readRDS(marker)$context_sha256==m$context_sha256)
 rm(saved);gc()
 for(from in seq.int(501L,2000L,5L)) {
  to<-from+4L;file<-file.path(root,'batches',sprintf('batch-%06d-%06d.rds',from,to))
  result<-run_trim_bootstrap_batch(identity,from:to,file,replicate_fn=function(id){
   value<-run_trim_bootstrap_replicate(context,id);stopifnot(identical(value$draw,make_stratified_cluster_draw(parent$clusters,id,parent$config$run_seed)))
   cat('REPLICATE_DONE',id,format(Sys.time(),tz='UTC',usetz=TRUE),'\n');flush.console();value
  },worker_id=Sys.info()[['nodename']])
  if(length(result$errors))stop('Batchfouten: ',paste(names(result$errors),collapse=','))
  cat('BATCH_DONE',from,to,'runtime',result$runtime_seconds,'peak_R_MB',result$peak_memory_mb,'swap_growth',result$swap_growth_bytes,'\n');flush.console();rm(result);gc()
 }
 cat('EXTENSION_2000_COMPLETE\n')
}
if(sys.nframe()==0L)run_trim_2025_2000()
