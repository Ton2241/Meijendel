#!/usr/bin/env Rscript
# Gezamenlijke gevoeligheidsproef; geen bootstrap of wijziging van hoofdroute.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3L)
repo<-normalizePath(args[[1]],mustWork=TRUE);cache_path<-normalizePath(args[[2]],mustWork=TRUE);out<-args[[3]]
source(path.expand('~/Documents/GitHub/Meijendel/R/trial_storage.R'));out<-trial_output(out)
e<-new.env(parent=globalenv());e$commandArgs<-function(trailingOnly=FALSE)paste0("--file=",repo,"/R/trim_soorten_en_msi_evg.R")
for(f in c("trim_soorten_en_msi_evg.R","trim_bootstrap_core.R","trim_bridge_core.R","audit_trim_bridge_windows.R","build_trim_bootstrap_bundle.R"))sys.source(file.path(repo,"R",f),envir=e)
stopifnot(digest::digest(file=cache_path,algo="sha256")=="071e66821f706ae1c0c37b11b3295ddde84a1872b194f9a09f43e595b50252d8")
cache<-readRDS(cache_path);t<-e$apply_meijendel_plot_scope(cache$data,character());t$plots$kavel_nummer<-e$normalize_kavel_nummer(t$plots$kavel_nummer)
b<-e$prepare_analysis_basis(t,2025L);sm<-e$build_species_matrix(t,b,2025L);cl<-e$build_cluster_definition_from_basis(b,e$derive_bridge_plot_sets)
sm<-e$restrict_species_matrix_to_bootstrap_clusters(sm,cl);sm<-merge(sm,cl[c("plot_id","bootstrap_cluster_id")],by="plot_id")
base_manifest<-jsonlite::read_json(file.path(repo,"trim/bootstrap/bridge_zero_20261102/audit_manifest.json"),simplifyVector=TRUE)
fixed_ids<-as.integer(base_manifest$fixed_species_ids);stopifnot(length(fixed_ids)==33L,!anyDuplicated(fixed_ids))
base_plots<-cl$bootstrap_cluster_id[cl$primary_bridge_plot]
stopifnot(length(base_plots)==33L)
draw<-data.frame(source_cluster_id=cl$bootstrap_cluster_id,bootstrap_site_id=cl$bootstrap_cluster_id,draw_position=seq_len(nrow(cl)))
periods<-e$resolve_trim_periods(2025L)
fits<-lapply(fixed_ids,function(id){
 sp<-sm[sm$soort_id==id,]
 pre<-e$bootstrap_model_index(e$fit_first_working_trim_model(sp[sp$jaar%in%periods$pre$years,]))
 post<-e$bootstrap_model_index(e$fit_first_working_trim_model(sp[sp$jaar%in%periods$post$years,]))
 stopifnot(length(pre)==26L,length(post)==42L,all(is.finite(c(pre,post))),all(c(pre,post)>0))
 list(pre=pre,post=post)
});names(fits)<-fixed_ids
no_support<-function(ids)prod(vapply(split(cl$bootstrap_cluster_id,cl$stratum),function(stratum){n<-length(stratum);((n-sum(stratum%in%ids))/n)^n},numeric(1)))
get_totals<-function(f,method){
 if(!isTRUE(f$ok))return(NULL)
 if(method=="window_poisson")return(f$totals)
 v<-as.numeric(f$model$tt_imp)
 stopifnot(length(v)==length(f$totals),all(is.finite(v)),all(v>=0),isTRUE(all.equal(v,as.numeric(colSums(f$model$imputed)),tolerance=1e-8)))
 stats::setNames(v,names(f$totals))
}
rows<-list();influence<-list();series<-list();coverage<-list()
for(width in c(3L,5L,7L,10L)){
 pre_years<-seq.int(1984L-width,1983L);post_years<-seq.int(1986L,1985L+width)
 stopifnot(!any(c(1984L,1985L)%in%c(pre_years,post_years)))
 window_plots<-e$derive_bridge_plot_sets(b,pre_years,post_years)$common_any_year
 if(width==3L)stopifnot(setequal(window_plots,base_plots))
 for(scope in c("baseline_plots","window_common")){
  plot_ids<-if(scope=="baseline_plots")base_plots else window_plots
  for(id in fixed_ids){
   sp<-sm[sm$soort_id==id,];main<-fits[[as.character(id)]]
   z<-sp[sp$bootstrap_cluster_id%in%plot_ids&sp$jaar%in%c(pre_years,post_years)&sp$geteld&is.finite(sp$count_adjusted),]
   paired<-intersect(unique(z$bootstrap_cluster_id[z$jaar%in%pre_years]),unique(z$bootstrap_cluster_id[z$jaar%in%post_years]))
   q<-z[z$bootstrap_cluster_id%in%paired,]
   a<-unique(q$bootstrap_cluster_id[q$jaar%in%pre_years&q$count_adjusted>0]);bb<-unique(q$bootstrap_cluster_id[q$jaar%in%post_years&q$count_adjusted>0])
   ppre<-no_support(a);ppost<-no_support(bb);pany<-ppre+ppost-no_support(union(a,bb))
   annual_support<-lapply(c(pre_years,post_years),function(y)unique(z$bootstrap_cluster_id[z$jaar==y&z$count_adjusted>0]))
   annual_risk<-vapply(annual_support,no_support,numeric(1))
   annual_worst_year<-c(pre_years,post_years)[which.max(annual_risk)]
   coverage[[length(coverage)+1L]]<-data.frame(width=width,pre=paste(range(pre_years),collapse="-"),post=paste(range(post_years),collapse="-"),scope=scope,soort_id=id,soort_naam=t$soorten$soort_naam[match(id,t$soorten$id)],n_plot_pool=length(plot_ids),n_paired=length(paired),positive_pre=length(a),positive_post=length(bb),observed_pre=sum(z$jaar%in%pre_years),observed_post=sum(z$jaar%in%post_years),p_zero_pre=ppre,p_zero_post=ppost,p_zero_either=pany,annual_failure_probability_lower_bound=max(annual_risk),annual_worst_year=annual_worst_year,min_positive_plots_year=min(lengths(annual_support)))
   for(method in c("yearly_unrounded","window_poisson")){
    fn<-if(method=="yearly_unrounded")e$fit_bridge_calibration_trim else e$fit_bridge_calibration_window
    f<-fn(sp,draw,plot_ids,pre_years,post_years);totals<-get_totals(f,method)
    br<-e$compute_empirical_bridge(main$pre,main$post,totals,pre_years,post_years)
    reason<-if(isTRUE(f$ok))br$reason else f$reason
    imputed_share<-NA_real_
    if(isTRUE(f$ok)&&method=="yearly_unrounded"){
     obs<-tapply(z$count_adjusted,z$jaar,sum);shares<-1-as.numeric(obs[names(totals)])/as.numeric(totals)
     imputed_share<-max(shares[is.finite(shares)],0)
    }
    rows[[length(rows)+1L]]<-data.frame(width=width,scope=scope,method=method,soort_id=id,level_ratio=br$level_ratio,bridge_factor=br$bridge_factor,trend_pct=e$combined_pct_trend(main$pre,main$post,br$bridge_factor),status=br$status,reason=reason,max_annual_imputed_share=imputed_share)
    ser<-c(main$pre,main$post*br$bridge_factor)
    series[[length(series)+1L]]<-data.frame(width=width,scope=scope,method=method,soort_id=id,jaar=as.integer(names(ser)),index_value=as.numeric(ser),bridge_variant=paste0("window_",width),coverage_variant=scope)
    if(scope=="baseline_plots"&&id%in%c(150L,162L))for(pid in plot_ids){
     loo<-fn(sp,draw,setdiff(plot_ids,pid),pre_years,post_years);tt<-get_totals(loo,method)
     lb<-e$compute_empirical_bridge(main$pre,main$post,tt,pre_years,post_years)
     influence[[length(influence)+1L]]<-data.frame(width=width,scope=scope,method=method,soort_id=id,omitted_plot=pid,kavel=paste0("M",t$plots$kavel_nummer[match(pid,t$plots$plot_id)]),bridge_factor=lb$bridge_factor,relative_change=lb$bridge_factor/br$bridge_factor-1,valid=is.finite(lb$bridge_factor))
    }
   }
  }
 }
 cat("WINDOW_DONE",width,"\n")
}
points<-do.call(rbind,rows);coverage<-do.call(rbind,coverage);influence<-do.call(rbind,influence);ix<-do.call(rbind,series)
stopifnot(nrow(points)==33L*4L*2L*2L,nrow(coverage)==33L*4L*2L,!anyDuplicated(points[c("width","scope","method","soort_id")]))
# Referentie met de eerdere onafhankelijk gecontroleerde vergelijking.
previous<-read.csv(file.path(repo,"trim/bootstrap/bridge_zero_20261102/sensitivity/fits.csv"))
for(id in c(150L,162L))for(method in c("yearly_unrounded","window_poisson")){
 prev<-previous[previous$soort_id==id&previous$plot_set=="primary"&previous$method==method,]
 now<-points[points$soort_id==id&points$width==3&points$scope=="baseline_plots"&points$method==method,]
 stopifnot(nrow(prev)==1,nrow(now)==1,isTRUE(all.equal(prev$level_ratio,now$level_ratio,tolerance=1e-8)))
}
defs<-Filter(function(d)d$variant=="robuust",e$build_bootstrap_group_definitions(e$build_group_mapping(t),e$build_functional_group_mapping(t),fixed_ids))
groups<-list()
for(width in c(3L,5L,7L,10L))for(scope in c("baseline_plots","window_common"))for(method in c("yearly_unrounded","window_poisson")){
 s<-ix[ix$width==width&ix$scope==scope&ix$method==method,]
 g<-e$build_bootstrap_group_results(s,defs,0L);g$width<-width;g$scope<-scope;g$method<-method;groups[[length(groups)+1L]]<-g
}
groups<-do.call(rbind,groups)
summary_rows<-list()
for(scope in c("baseline_plots","window_common"))for(width in c(3L,5L,7L,10L)){
 cv<-coverage[coverage$scope==scope&coverage$width==width,]
 yr<-points[points$scope==scope&points$width==width&points$method=="yearly_unrounded",]
 wi<-points[points$scope==scope&points$width==width&points$method=="window_poisson",]
 cmp<-merge(yr[c("soort_id","bridge_factor")],wi[c("soort_id","bridge_factor")],by="soort_id",suffixes=c("_yr","_wi"))
 delta<-abs(cmp$bridge_factor_wi/cmp$bridge_factor_yr-1);delta<-delta[is.finite(delta)]
 summary_rows[[length(summary_rows)+1L]]<-data.frame(width=width,pre=cv$pre[1],post=cv$post[1],scope=scope,n_plot_pool=cv$n_plot_pool[1],n_species=length(fixed_ids),annual_initial_valid=sum(yr$status=="formele_brug"),window_initial_valid=sum(wi$status=="formele_brug"),p_zero_witte=cv$p_zero_either[cv$soort_id==162],p_zero_veld=cv$p_zero_either[cv$soort_id==150],annual_failure_lower_bound_witte=cv$annual_failure_probability_lower_bound[cv$soort_id==162],annual_failure_lower_bound_veld=cv$annual_failure_probability_lower_bound[cv$soort_id==150],max_p_zero=max(cv$p_zero_either),median_method_factor_difference=median(delta),max_method_factor_difference=max(delta))
}
summary<-do.call(rbind,summary_rows)
status<-read.csv(file.path(repo,"trim/soorten/soorten_modelstatus.csv"))
inventory<-status[c("soort_id","soort_naam","pre_model_gelukt","post_model_gelukt","analyse_categorie")]
inventory$in_deze_venstervergelijking<-inventory$soort_id%in%fixed_ids
stopifnot(nrow(inventory)==156L,sum(inventory$in_deze_venstervergelijking)==33L,nrow(summary)==8L)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(n in c("points","coverage","influence","groups","summary","inventory"))write.csv(get(n),file.path(out,paste0(n,".csv")),row.names=FALSE,na="")
jsonlite::write_json(list(format="trim-long-window-sensitivity-v1",source_hash=cache$identity$sql_sha256,cache_sha256=digest::digest(file=cache_path,algo="sha256"),code_sha256=digest::digest(file=file.path(repo,"R/audit_trim_bridge_long_windows.R"),algo="sha256"),engine_sha256=digest::digest(file=file.path(repo,"R/trim_bridge_core.R"),algo="sha256"),source_period="1958-2025",fixed_species_ids=fixed_ids,widths=c(3,5,7,10),post_start=1986,pre_end=1983,publication_status="gevoeligheidsproef_geen_bootstrapinterval"),file.path(out,"manifest.json"),auto_unbox=TRUE,pretty=TRUE)
cat("LONG_WINDOW_SENSITIVITY_READY\n")
