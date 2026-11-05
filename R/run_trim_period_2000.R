#!/usr/bin/env Rscript
# Independent period fits only; reuse saved 32-species output, never fit a bridge.
direct_independent_period <- function(data,draw,years) {
 d<-apply_cluster_draw(data,draw);d<-d[d$jaar%in%years,,drop=FALSE]
 f<-fit_first_working_trim_model(d,analysis_years=years)
 v<-if(isTRUE(f$ok))bootstrap_model_index(f) else NULL
 list(ok=isTRUE(f$ok),reason=f$reason,model=if(isTRUE(f$ok))f$config else NA_character_,
      refitted=FALSE,refit_attempts=length(f$attempts),method='nieuwe_zelfstandige_periodefit',
      index=data.frame(jaar=as.integer(names(v)),index_value=as.numeric(v)))
}
run_trim_period_2000 <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==4L);repo<-normalizePath(args[1],mustWork=TRUE)
 check_t7<-function(path,extra=character()) {
  guard<-system2('python3',shQuote(c(file.path(repo,'scripts/check_trim_t7_output.py'),path,extra)),stdout=TRUE,stderr=TRUE)
  if(!is.null(attr(guard,'status')))stop(paste(guard,collapse='\n'),call.=FALSE)
  guard[[1L]]
 }
 root<-check_t7(args[4],c('--check-child','identity.rds','--check-child','config.rds','--check-child','selected_periods.csv','--check-child','reproduction.rds','--check-child','batches'))
 parent<-normalizePath(args[2]);prior<-normalizePath(args[3])
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 for(n in c('trim_trend_contract.R','trim_bootstrap_core.R','trim_bridge_core.R','run_trim_bootstrap_batch.R','build_trim_bootstrap_bundle.R','validate_trim_bootstrap_bundle.R','trim_period_uncertainty.R'))source(file.path(repo,'R',n))
 validate_trim_bootstrap_engine(file.path(parent,'input'),repo);validate_trim_bootstrap_engine(file.path(prior,'input'),repo)
 pm<-jsonlite::read_json(file.path(parent,'input/bundle_manifest.json'),simplifyVector=TRUE);cx<-readRDS(file.path(parent,'input/context.rds'))
 stopifnot(bundle_sha256_file(file.path(parent,'input/context.rds'))==pm$context_sha256,pm$analysis_end_year==2025L,nrow(cx$clusters)==52L)
 software<-paste0('R-',getRversion(),'_rtrim-',utils::packageVersion('rtrim'));oldid<-readRDS(file.path(prior,'input/identity.rds'));stopifnot(oldid$software_id==software)
 prev<-file.path(repo,'trim/bootstrap/species_2025_2000_20261103');p<-read.csv(file.path(prev,'periods.csv'));a<-read.csv(file.path(prev,'annual_indices.csv'))
 keys<-unique(rbind(p[is.finite(p$diagnostic_low),c('soort_id','period')],a[is.finite(a$diagnostic_low),c('soort_id','period')]))
 keys<-keys[order(keys$soort_id,keys$period),];rownames(keys)<-NULL;stopifnot(nrow(keys)==141L,length(unique(keys$soort_id))==89L)
 criteria<-file.path(repo,'trim/bootstrap/periods_2025_2000_20261104/CRITERIA.md')
 config<-list(parent_context=pm$context_sha256,prior_manifest=bundle_sha256_file(file.path(prior,'input/bundle_manifest.json')),first500=bundle_sha256_file(file.path(prior,'assessment/period_annual_draws.rds')),keys=keys,
   criteria=bundle_sha256_file(criteria),script=bundle_sha256_file(file.path(repo,'R/run_trim_period_2000.R')),core=bundle_sha256_file(file.path(repo,'R/trim_period_uncertainty.R')))
 identity<-list(run_id='independent-periods-2025-2000-20261104',source_hash=pm$source_hash,config_hash=digest::digest(config,algo='sha256'),code_commit=system2('git',c('-C',repo,'rev-parse','HEAD'),stdout=TRUE)[1],software_id=software)
 dir.create(root,recursive=TRUE,showWarnings=FALSE)
 ip<-file.path(root,'identity.rds');if(file.exists(ip)){old<-readRDS(ip);stopifnot(old$config_hash==identity$config_hash,old$software_id==software);identity<-old} else {saveRDS(identity,ip);saveRDS(config,file.path(root,'config.rds'));write.csv(keys,file.path(root,'selected_periods.csv'),row.names=FALSE)}
 source_data<-split(cx$species_matrix,cx$species_matrix$soort_id)
 verify<-file.path(root,'reproduction.rds')
 if(!file.exists(verify)){
  oldpath<-file.path(prior,'period_recovery/batches/batch-000001-000005.rds');om<-readRDS(paste0(oldpath,'.manifest.rds'));stopifnot(bundle_sha256_file(oldpath)==om$output_sha256)
  old<-readRDS(oldpath)$results
  for(n in 1:2){r<-old[[as.character(n)]];draw<-make_stratified_cluster_draw(cx$clusters,n,cx$config$run_seed);stopifnot(identical(draw,r$draw))
   for(i in seq_len(nrow(keys))){id<-keys$soort_id[i];period<-keys$period[i];years<-cx$species_targets[[as.character(id)]][[period]]$years
    v<-direct_independent_period(source_data[[as.character(id)]],draw,years);s<-r$periods[r$periods$soort_id==id&r$periods$period==period,]
    stopifnot(nrow(s)==1L,identical(v$ok,s$ok),identical(v$model,s$model))
    ix<-r$indices[r$indices$soort_id==id&r$indices$period==period,c('jaar','index_value')];ix<-ix[order(ix$jaar),];v$index<-v$index[order(v$index$jaar),];rownames(ix)<-rownames(v$index)<-NULL
    stopifnot(isTRUE(all.equal(ix,v$index,tolerance=1e-10)),identical(is.na(ix$index_value),is.na(v$index$index_value)),identical(ix$index_value==0,v$index$index_value==0))
   };cat('REPRODUCED_141_PERIODS',n,'\n');flush.console()
  };saveRDS(list(identity=identity,replicates=1:2,periods=keys),verify);rm(old);gc()
 } else stopifnot(identical(readRDS(verify)$identity,identity))
 for(from in seq.int(501L,2000L,5L)){
  to<-from+4L;oldpath<-file.path(prior,'batches',sprintf('batch-%06d-%06d.rds',from,to));om<-readRDS(paste0(oldpath,'.manifest.rds'))
  stopifnot(bundle_sha256_file(oldpath)==om$output_sha256,identical(om$identity,oldid));old<-readRDS(oldpath)$results
  path<-file.path(root,'batches',basename(oldpath))
  path<-check_t7(path,'--batch')
  result<-run_trim_bootstrap_batch(identity,from:to,path,replicate_fn=function(n){
   r<-old[[as.character(n)]];draw<-make_stratified_cluster_draw(cx$clusters,n,cx$config$run_seed);stopifnot(identical(draw,r$draw))
   rows<-indices<-vector('list',nrow(keys))
   for(i in seq_len(nrow(keys))){id<-keys$soort_id[i];period<-keys$period[i];years<-cx$species_targets[[as.character(id)]][[period]]$years
    reused<-id%in%r$species$soort_id
    v<-if(reused)recover_independent_period(r,id,period,cx) else direct_independent_period(source_data[[as.character(id)]],draw,years)
    rows[[i]]<-data.frame(soort_id=id,period=period,ok=v$ok,reason=v$reason,model=v$model,method=v$method,reused=reused,refitted=v$refitted,fit_attempts=v$refit_attempts)
    if(nrow(v$index))indices[[i]]<-cbind(data.frame(soort_id=id,period=period),v$index)
   }
   value<-list(replicate_id=n,draw=draw,periods=do.call(rbind,rows),indices=do.call(rbind,indices),parent_batch_sha256=om$output_sha256)
   cat('PERIOD_DRAW_DONE',n,'new',sum(!value$periods$reused),'restored',sum(value$periods$refitted),'\n');flush.console();value
  },worker_id=Sys.info()[['nodename']])
  if(length(result$errors))stop('Batchfouten: ',paste(result$errors,collapse=';'))
  stopifnot(identical(result$identity,identity));cat('PERIOD_BATCH_DONE',from,to,'runtime',result$runtime_seconds,'swap_growth',result$swap_growth_bytes,'\n');flush.console();rm(old,result);gc()
 }
 cat('INDEPENDENT_PERIOD_2000_COMPLETE\n')
}
if(sys.nframe()==0L)run_trim_period_2000()
