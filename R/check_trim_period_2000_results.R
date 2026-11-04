#!/usr/bin/env Rscript
.libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3L);repo<-normalizePath(args[1]);prior<-normalizePath(args[2]);root<-normalizePath(args[3]);out<-file.path(root,'assessment')
old<-readRDS(file.path(prior,'assessment/period_annual_draws.rds'));z<-readRDS(file.path(out,'period_annual_draws.rds'));p<-read.csv(file.path(out,'periods.csv'));a<-read.csv(file.path(out,'annual_indices.csv'));keys<-read.csv(file.path(root,'selected_periods.csv'))
stopifnot(nrow(p)==312L,nrow(a)==10608L,length(unique(p$soort_id))==156L,identical(old$period_keys,z$period_keys),identical(old$annual_keys,z$annual_keys))
for(n in c('period_values','annual_values','period_status','period_model_ok','annual_reference_ok'))stopifnot(identical(z[[n]][,1:501],old[[n]]))
selected<-paste(p$soort_id,p$period)%in%paste(keys$soort_id,keys$period);stopifnot(sum(selected)==141L,all(p$n_planned[selected]==2000),all(p$n_planned[!selected]==500))
archive<-file.path(repo,'trim/bootstrap/species_2025_2000_20261103');op<-read.csv(file.path(archive,'periods.csv'));oa<-read.csv(file.path(archive,'annual_indices.csv'))
stopifnot(identical(p[!selected,],op[!selected,]))
asel<-paste(a$soort_id,a$period)%in%paste(keys$soort_id,keys$period);stopifnot(identical(a[!asel,],oa[!asel,]),all(a$n_planned[asel]==2000))
# Independent numerical recomputation, without the production diagnostic helpers.
check<-function(row,values,reference=FALSE){
 n<-as.integer(row$n_planned);theta<-values[1];v<-values[seq_len(n)+1];valid<-is.finite(v)&v>= -100;stopifnot(sum(valid)==row$n_valid)
 eligible<-is.finite(theta)&&theta>= -100&&all(valid)&&length(unique(v))>1L&&!reference
 stopifnot(identical(is.finite(row$diagnostic_low),eligible),identical(is.finite(row$diagnostic_high),eligible))
 if(eligible){bounds<-function(k)if(all(is.finite(v[1:k]))&&length(unique(v[1:k]))>1L)unname(quantile(v[1:k],c(.025,.975),type=7)) else c(NA_real_,NA_real_)
  stopifnot(isTRUE(all.equal(bounds(n),c(row$diagnostic_low,row$diagnostic_high),tolerance=1e-10)))
  pts<-if(n==2000)c(1000,1500,2000) else c(250,375,500)
  stable<-function(b,c)all(is.finite(c(b,c)))&&diff(c)>0&&all(abs(c-b)<.1)&all(abs(c-b)<.05*diff(c))
  latest<-stable(bounds(pts[2]),bounds(pts[3]));both<-latest&&stable(bounds(pts[1]),bounds(pts[2]));stopifnot(identical(latest,row$latest_stable),identical(both,row$both_stable))
 } else stopifnot(!row$both_stable,!row$latest_stable)
 stopifnot(is.na(row$ci95_low),is.na(row$ci95_high))
}
for(i in 1:nrow(p))check(p[i,],z$period_values[i,])
for(i in 1:nrow(a))check(a[i,],z$annual_values[i,],a$is_reference[i])
inside<-a$inside_model_years;stopifnot(all(with(a[inside,],n_valid+n_model_failure+n_reference_failure+n_year_index_missing_or_invalid)==a$n_planned[inside]))
source(file.path(repo,'R/run_trim_bootstrap_batch.R'))
paths<-list.files(file.path(root,'batches'),pattern='\\.rds$',full.names=TRUE);paths<-paths[!grepl('manifest',paths)];stopifnot(length(paths)==300L)
allids<-integer();methods<-list();identity<-readRDS(file.path(root,'identity.rds'))
for(path in paths){m<-readRDS(paste0(path,'.manifest.rds'));b<-readRDS(path);stopifnot(batch_sha256_file(path)==m$output_sha256,identical(m$identity,identity),identical(b$identity,identity),length(b$errors)==0L,identical(sort(as.integer(names(b$results))),m$replicate_ids));allids<-c(allids,m$replicate_ids)}
stopifnot(identical(allids,501:2000))
result<-list(species=156L,periods=312L,annual_positions=10608L,batches=300L,draw_ids='501-2000',first500_preserved=TRUE,unselected_rows_preserved=TRUE,all_bounds_independently_recomputed=TRUE,all_stability_flags_independently_recomputed=TRUE,formal_intervals=FALSE,period_bands=sum(is.finite(p$diagnostic_low)),stable_period_bands=sum(p$both_stable),annual_bands=sum(is.finite(a$diagnostic_low)),stable_annual_bands=sum(a$both_stable))
jsonlite::write_json(result,file.path(out,'result_verification.json'),auto_unbox=TRUE,pretty=TRUE);print(result);cat('INDEPENDENT_2000_RESULT_CHECK_OK\n')
