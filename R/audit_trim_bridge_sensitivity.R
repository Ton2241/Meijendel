#!/usr/bin/env Rscript
# Verdieping van methodeverschillen; geen bootstrap van hoofdmodellen.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==3L)
repo <- normalizePath(args[[1L]],mustWork=TRUE); cache_path <- normalizePath(args[[2L]],mustWork=TRUE); out <- args[[3L]]
e <- new.env(parent=globalenv()); e$commandArgs <- function(trailingOnly=FALSE)paste0("--file=",repo,"/R/trim_soorten_en_msi_evg.R")
for(f in c("trim_soorten_en_msi_evg.R","trim_bootstrap_core.R","trim_bridge_core.R","audit_trim_bridge_windows.R","build_trim_bootstrap_bundle.R"))sys.source(file.path(repo,"R",f),envir=e)
stopifnot(digest::digest(file=cache_path,algo="sha256")=="071e66821f706ae1c0c37b11b3295ddde84a1872b194f9a09f43e595b50252d8")
cache <- readRDS(cache_path); t <- e$apply_meijendel_plot_scope(cache$data,character());t$plots$kavel_nummer<-e$normalize_kavel_nummer(t$plots$kavel_nummer)
b<-e$prepare_analysis_basis(t,2025L); sm<-e$build_species_matrix(t,b,2025L); cl<-e$build_cluster_definition_from_basis(b,e$derive_bridge_plot_sets)
sm<-e$restrict_species_matrix_to_bootstrap_clusters(sm,cl);sm<-merge(sm,cl[c("plot_id","bootstrap_cluster_id")],by="plot_id")
draw<-data.frame(source_cluster_id=cl$bootstrap_cluster_id,bootstrap_site_id=cl$bootstrap_cluster_id,draw_position=seq_len(nrow(cl)))
primary<-cl$bootstrap_cluster_id[cl$primary_bridge_plot];strict<-cl$bootstrap_cluster_id[cl$strict_bridge_plot]
years<-c(1981:1983,1986:1988)
ratio<-function(f)if(isTRUE(f$ok))mean(f$totals[as.character(1986:1988)])/mean(f$totals[as.character(1981:1983)]) else NA_real_
unrounded_totals<-function(f){
 if(!isTRUE(f$ok))return(NULL)
 v<-as.numeric(f$model$tt_imp)
 stopifnot(length(v)==length(f$totals),all(is.finite(v)),all(v>=0))
 stats::setNames(v,names(f$totals))
}
unrounded_ratio<-function(f){v<-unrounded_totals(f);if(is.null(v))NA_real_ else mean(v[as.character(1986:1988)])/mean(v[as.character(1981:1983)])}
name_of<-function(id)t$soorten$soort_naam[match(id,t$soorten$id)]
kavel_of<-function(id)paste0("M",t$plots$kavel_nummer[match(id,t$plots$plot_id)])
no_support_probability<-function(ids){
 prod(vapply(split(cl$bootstrap_cluster_id,cl$stratum),function(stratum){n<-length(stratum);k<-sum(stratum%in%ids);((n-k)/n)^n},numeric(1)))
}
annual_rows<-list();site_rows<-list();fit_rows<-list();influence_rows<-list();zero_rows<-list();imputation_rows<-list()
for(id in c(150L,162L)){
 sp<-sm[sm$soort_id==id,];obs<-sp[sp$bootstrap_cluster_id%in%primary&sp$jaar%in%years&sp$geteld&is.finite(sp$count_adjusted),]
 before<-unique(obs$bootstrap_cluster_id[obs$jaar<1984]);after<-unique(obs$bootstrap_cluster_id[obs$jaar>=1986]);paired<-intersect(before,after)
 for(pid in primary){
  z<-obs[obs$bootstrap_cluster_id==pid,];pre<-z[z$jaar<1984,];post<-z[z$jaar>=1986,]
  site_rows[[length(site_rows)+1L]]<-data.frame(soort_id=id,soort_naam=name_of(id),plot_id=pid,kavel=kavel_of(pid),stratum=cl$stratum[match(pid,cl$plot_id)],n_pre=nrow(pre),n_post=nrow(post),sum_pre=sum(pre$count_adjusted),sum_post=sum(post$count_adjusted),raw_pre=sum(pre$count_raw),raw_post=sum(post$count_raw),strict=pid%in%strict,paired=pid%in%paired)
 }
 complete_species<-as.integer(names(which(table(obs$bootstrap_cluster_id)==6L)))
 sets<-list(primary=primary,paired=paired,strict=strict,species_complete=complete_species)
 for(set_name in names(sets)){
  ids<-sets[[set_name]];z<-obs[obs$bootstrap_cluster_id%in%ids,]
  yr<-e$fit_bridge_calibration_trim(sp,draw,ids,1981:1983,1986:1988)
  wi<-e$fit_bridge_calibration_window(sp,draw,ids,1981:1983,1986:1988)
  raw_ratio<-mean(tapply(z$count_adjusted,z$jaar,sum)[as.character(1986:1988)])/mean(tapply(z$count_adjusted,z$jaar,sum)[as.character(1981:1983)])
  for(method in c("yearly_trim","yearly_unrounded","window_poisson","observed_sum")){
   f<-if(method%in%c("yearly_trim","yearly_unrounded"))yr else wi
   fit_rows[[length(fit_rows)+1L]]<-data.frame(soort_id=id,soort_naam=name_of(id),plot_set=set_name,n_plots=length(ids),method=method,level_ratio=if(method=="observed_sum")raw_ratio else if(method=="yearly_unrounded")unrounded_ratio(f) else ratio(f),reason=if(method=="observed_sum")"geen_correctie_voor_ontbrekende_cellen" else if(is.null(f$reason))NA_character_ else f$reason)
  }
  if(set_name=="primary" && isTRUE(yr$ok)){
   m<-yr$model
   stopifnot(isTRUE(all.equal(as.numeric(colSums(m$imputed)),as.numeric(m$tt_imp),tolerance=1e-8)))
   missing<-which(is.na(m$f),arr.ind=TRUE)
   if(nrow(missing))for(k in seq_len(nrow(missing))){
    a<-missing[k,1];j<-missing[k,2];pid<-as.integer(m$site_id[a])
    imputation_rows[[length(imputation_rows)+1L]]<-data.frame(soort_id=id,soort_naam=name_of(id),plot_id=pid,kavel=kavel_of(pid),jaar=years[match(m$time.id[j],1:6)],imputed_value=m$imputed[a,j])
   }
  }
  for(y in years){
   a<-z[z$jaar==y,];obs_sum<-sum(a$count_adjusted)
   total<-if(isTRUE(yr$ok))unname(yr$totals[as.character(y)]) else NA_real_
   unrounded<-if(isTRUE(yr$ok))unname(unrounded_totals(yr)[as.character(y)]) else NA_real_
   annual_rows[[length(annual_rows)+1L]]<-data.frame(soort_id=id,soort_naam=name_of(id),plot_set=set_name,jaar=y,n_observed=nrow(a),n_positive=sum(a$count_adjusted>0),observed_raw=sum(a$count_raw),observed_adjusted=obs_sum,yearly_imputed_total=total,yearly_unrounded_total=unrounded,added_by_imputation=unrounded-obs_sum,output_rounding=total-unrounded,window_total=if(isTRUE(wi$ok))unname(wi$totals[as.character(y)]) else NA_real_)
  }
  # Op de volledig getelde set is de waargenomen ratio een directe benchmark.
  if(set_name=="species_complete" && length(ids)>0 && all(table(z$jaar)==length(ids))){
   if(isTRUE(yr$ok))stopifnot(isTRUE(all.equal(unrounded_ratio(yr),raw_ratio,tolerance=1e-6)))
   if(isTRUE(wi$ok))stopifnot(isTRUE(all.equal(ratio(wi),raw_ratio,tolerance=1e-6)))
  }
 }
 full_yr<-e$fit_bridge_calibration_trim(sp,draw,primary,1981:1983,1986:1988);full_wi<-e$fit_bridge_calibration_window(sp,draw,primary,1981:1983,1986:1988)
 for(pid in primary){
  for(method in c("yearly_trim","yearly_unrounded","window_poisson")){
   fn<-if(method%in%c("yearly_trim","yearly_unrounded"))e$fit_bridge_calibration_trim else e$fit_bridge_calibration_window
   f<-fn(sp,draw,setdiff(primary,pid),1981:1983,1986:1988)
   original<-if(method=="yearly_trim")ratio(full_yr) else if(method=="yearly_unrounded")unrounded_ratio(full_yr) else ratio(full_wi)
   current<-if(method=="yearly_unrounded")unrounded_ratio(f) else ratio(f)
   influence_rows[[length(influence_rows)+1L]]<-data.frame(soort_id=id,soort_naam=name_of(id),omitted_plot=pid,kavel=kavel_of(pid),method=method,level_ratio=current,relative_change=current/original-1,reason=if(is.null(f$reason))NA_character_ else f$reason)
  }
 }
 used<-obs[obs$bootstrap_cluster_id%in%paired,]
 support_pre<-unique(used$bootstrap_cluster_id[used$jaar<1984&used$count_adjusted>0]);support_post<-unique(used$bootstrap_cluster_id[used$jaar>=1986&used$count_adjusted>0])
 pp<-no_support_probability(support_pre);pq<-no_support_probability(support_post);pb<-no_support_probability(union(support_pre,support_post))
 zero_rows[[length(zero_rows)+1L]]<-data.frame(soort_id=id,soort_naam=name_of(id),n_positive_pre=length(support_pre),n_positive_post=length(support_post),positive_pre=paste(support_pre,collapse=";"),positive_post=paste(support_post,collapse=";"),p_miss_pre=pp,p_miss_post=pq,p_miss_either=pp+pq-pb,expected_per_50=50*(pp+pq-pb),expected_per_2000=2000*(pp+pq-pb))
 # Identificeer de nulvensters in de eerdere 50 trekkingen, zonder modelfits.
 for(i in 1:50){
  d<-e$make_stratified_cluster_draw(cl,i,20260920L)
  if(!any(d$source_cluster_id%in%support_pre)||!any(d$source_cluster_id%in%support_post))cat("LOST_WINDOW_SUPPORT",id,i,"pre",!any(d$source_cluster_id%in%support_pre),"post",!any(d$source_cluster_id%in%support_post),"\n")
 }
}
# Ook de overige vaste soorten: 50 succesvolle proeven bewijzen geen nulkans.
fixed_ids<-jsonlite::read_json(file.path(repo,"trim/bootstrap/bridge_zero_20261102/audit_manifest.json"),simplifyVector=TRUE)$fixed_species_ids
zero_rows<-lapply(fixed_ids,function(id){
 z<-sm[sm$soort_id==id & sm$bootstrap_cluster_id%in%primary & sm$jaar%in%years & sm$geteld & is.finite(sm$count_adjusted),]
 paired<-intersect(unique(z$bootstrap_cluster_id[z$jaar<1984]),unique(z$bootstrap_cluster_id[z$jaar>=1986]));z<-z[z$bootstrap_cluster_id%in%paired,]
 a<-unique(z$bootstrap_cluster_id[z$jaar<1984 & z$count_adjusted>0]);b<-unique(z$bootstrap_cluster_id[z$jaar>=1986 & z$count_adjusted>0])
 pp<-no_support_probability(a);pq<-no_support_probability(b);pb<-no_support_probability(union(a,b))
 data.frame(soort_id=id,soort_naam=name_of(id),n_positive_pre=length(a),n_positive_post=length(b),positive_pre=paste(a,collapse=";"),positive_post=paste(b,collapse=";"),p_miss_pre=pp,p_miss_post=pq,p_miss_either=pp+pq-pb,expected_per_50=50*(pp+pq-pb),expected_per_2000=2000*(pp+pq-pb))
})
dir.create(out,recursive=TRUE,showWarnings=FALSE)
outputs<-list(annual=do.call(rbind,annual_rows),sites=do.call(rbind,site_rows),fits=do.call(rbind,fit_rows),influence=do.call(rbind,influence_rows),zero_probability=do.call(rbind,zero_rows),imputation_cells=do.call(rbind,imputation_rows))
for(n in names(outputs))write.csv(outputs[[n]],file.path(out,paste0(n,".csv")),row.names=FALSE,na="")
jsonlite::write_json(list(format="trim-bridge-sensitivity-v1",cache_sha256=digest::digest(file=cache_path,algo="sha256"),source_hash=cache$identity$sql_sha256,code_sha256=digest::digest(file=file.path(repo,"R/audit_trim_bridge_sensitivity.R"),algo="sha256"),bridge_engine_sha256=digest::digest(file=file.path(repo,"R/trim_bridge_core.R"),algo="sha256"),seed=20260920L,source_period="1958-2025",calibration_years=years,detailed_species_ids=c(150,162),boundary_probability_species_ids=fixed_ids,cluster_strata=as.list(table(cl$stratum))),file.path(out,"manifest.json"),auto_unbox=TRUE,pretty=TRUE)
print(outputs$fits,row.names=FALSE);print(outputs$zero_probability[order(-outputs$zero_probability$p_miss_either),][1:7,],row.names=FALSE)
for(id in c(150,162)){z<-outputs$influence[outputs$influence$soort_id==id,];cat("INFLUENCE",id,"\n");print(head(z[order(-abs(z$relative_change)),],10),row.names=FALSE)}
