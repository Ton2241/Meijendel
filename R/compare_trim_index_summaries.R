#!/usr/bin/env Rscript
# Descriptive summaries of frozen indices. Never refit bird-count models here.
index_summary_valid <- function(ix,years) {
 nrow(ix)==length(years)&&!anyDuplicated(ix$jaar)&&setequal(ix$jaar,years)&&
 all(is.finite(ix$index_value))&&all(ix$index_value>=0)
}
index_summary_fit <- function(ix,years) {
 invalid<-function(reason)list(ok=FALSE,pct=NA_real_,reason=reason)
 if(!index_summary_valid(ix,years))return(invalid('ongeldige_of_onvolledige_jaarindex'))
 if(sum(ix$index_value)<=0)return(invalid('geheel_nulreeks'))
 ix<-ix[order(ix$jaar),];warnings<-character()
 f<-tryCatch(withCallingHandlers(stats::glm(index_value~I(jaar-mean(jaar)),data=ix,
  family=stats::quasipoisson(link='log')),warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')}),error=function(e)NULL)
 if(is.null(f)||!isTRUE(f$converged)||any(!is.finite(stats::coef(f))))return(invalid('indexsamenvatting_niet_geconvergeerd'))
 pct<-100*expm1(unname(stats::coef(f)[2]));prediction<-as.numeric(stats::predict(f,type='response'))
 if(!is.finite(pct)||any(!is.finite(prediction)))return(invalid('ongeldige_samenvatting'))
 list(ok=TRUE,pct=pct,reason='berekenbaar',prediction=data.frame(jaar=ix$jaar,index_value=prediction),warnings=unique(warnings))
}
index_summary_windows <- function(ix,years,width=5L) {
 result<-list(ok=FALSE,width=width,first_mean=NA_real_,last_mean=NA_real_,net_pct=NA_real_,annual_pct=NA_real_,delta_years=NA_real_,endpoint_status='ongeldige_of_onvolledige_jaarindex')
 if(!index_summary_valid(ix,years))return(result)
 years<-sort(years);stopifnot(width>=1,length(years)>=2*width,all(diff(years)==1))
 first<-head(years,width);last<-tail(years,width)
 a<-mean(ix$index_value[match(first,ix$jaar)]);b<-mean(ix$index_value[match(last,ix$jaar)])
 result$ok<-TRUE;result$first_mean<-a;result$last_mean<-b;result$delta_years<-mean(last)-mean(first)
 result$endpoint_status<-if(a==0)'nul_begingemiddelde' else if(b==0)'nul_eindgemiddelde' else 'berekenbaar'
 if(a>0)result$net_pct<-100*(b/a-1)
 if(a>0&&b>0)result$annual_pct<-100*expm1(log(b/a)/result$delta_years)
 result
}
index_summary_disagrees <- function(a,b) {
 is.finite(a)&is.finite(b)&abs(a)>.5&abs(b)>.5&sign(a)!=sign(b)
}
index_summary_gap <- function(a,b) {
 is.finite(a)&is.finite(b)&abs(a-b)>pmax(1,.2*abs(a))
}
run_index_summary_comparison <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==3L);repo<-normalizePath(args[1],mustWork=TRUE);run<-normalizePath(args[2],mustWork=TRUE);out<-args[3]
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 source(file.path(repo,'R/trim_bootstrap_core.R'));source(file.path(repo,'R/merge_trim_bootstrap_batches.R'))
 m<-jsonlite::read_json(file.path(run,'input/bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(digest::digest(file=file.path(run,'input/context.rds'),algo='sha256')==m$context_sha256)
 cx<-readRDS(file.path(run,'input/context.rds'));stopifnot(identical(range(cx$species_matrix$jaar),c(1958L,2025L)),nrow(cx$clusters)==52L)
 ids<-c(150L,64L,173L,214L);base<-read.csv(file.path(run,'baseline.csv'));base<-base[base$bridge_variant=='primary_5yr'&base$soort_id%in%ids,]
 old_curves_path<-file.path(repo,'trim/bootstrap/zero_policy_20261103/curves.csv')
 old_curves<-read.csv(old_curves_path);old_curves<-old_curves[old_curves$series=='jaarindex',]
 paths<-list.files(file.path(run,'batches'),pattern='^batch-[0-9]+-[0-9]+\\.rds$',full.names=TRUE)
 merged<-merge_trim_bootstrap_batches(paths,expected_ids=1:50)
 # No baseline count-model refit: reuse the previously frozen four original curves.
 results<-c(list(list(replicate_id=0L,species=base,indices=old_curves)),merged$results)
 rows<-list();curves<-list();hashes<-list()
 for(r in results) {
  if(r$replicate_id>0)hashes[[as.character(r$replicate_id)]]<-draw_hash_text(r$draw)
  for(id in ids) {
   target<-cx$species_targets[[as.character(id)]];years<-c(target$pre$years,target$post$years);stopifnot(identical(as.integer(years),1958:2025))
   s<-r$species[r$species$soort_id==id&r$species$bridge_variant=='primary_5yr',];stopifnot(nrow(s)==1L)
   ix<-r$indices[r$indices$soort_id==id,]
   if(r$replicate_id>0)ix<-ix[ix$bridge_variant=='primary_5yr'&ix$coverage_variant=='volledig_netwerk',]
   valid_bridge<-isTRUE(s$pre_ok)&&isTRUE(s$post_ok)&&is.finite(s$bridge_factor)&&s$bridge_factor>0
   if(!valid_bridge)ix$index_value<-NA_real_
   f<-index_summary_fit(ix,years)
   pre<-index_summary_fit(ix[ix$jaar%in%target$pre$years,],target$pre$years)
   post<-index_summary_fit(ix[ix$jaar%in%target$post$years,],target$post$years)
   for(w in c(3L,5L,7L)) {
    e<-index_summary_windows(ix,years,w)
    rows[[length(rows)+1L]]<-data.frame(soort_id=id,soort_naam=base$soort_naam[match(id,base$soort_id)],replicate_id=r$replicate_id,width=w,
     first_year=min(years),last_year=max(years),q_pct=f$pct,pre_q_pct=pre$pct,post_q_pct=post$pct,
     first_mean=e$first_mean,last_mean=e$last_mean,net_pct=e$net_pct,endpoint_annual_pct=e$annual_pct,
     n_zero_index=sum(ix$index_value==0,na.rm=TRUE),endpoint_status=e$endpoint_status,
     q_reason=if(valid_bridge)f$reason else paste0('brug_of_periodemodel:',s$result_reason),
     gap_flag=index_summary_gap(f$pct,e$annual_pct),opposite=index_summary_disagrees(f$pct,e$annual_pct))
   }
   if(r$replicate_id==0L){
    a<-ix[c('jaar','index_value')];a$soort_id<-id;a$series<-'jaarindex';curves[[length(curves)+1L]]<-a
    if(f$ok){a<-f$prediction;a$soort_id<-id;a$series<-'exponentiele_samenvatting';curves[[length(curves)+1L]]<-a}
   }
  }
 }
 estimates<-do.call(rbind,rows);curves<-do.call(rbind,curves)
 prior<-read.csv(file.path(repo,'trim/bootstrap/pilot_2025_50_20261102/main_index_zeros/per_species.csv'))
 summary<-do.call(rbind,lapply(ids,function(id){
  e<-estimates[estimates$soort_id==id&estimates$width==5,];b<-e[e$replicate_id==0,];x<-e[e$replicate_id>0,];p<-prior[prior$soort_id==id,]
  finite<-function(v)v[is.finite(v)];med<-function(v)if(length(finite(v)))median(finite(v)) else NA_real_
  paired<-is.finite(x$q_pct)&is.finite(x$endpoint_annual_pct)
  stopifnot(sum(is.finite(x$q_pct))==p$n_quasi,abs(med(x$q_pct)-p$median_quasi)<1e-8)
  data.frame(soort_id=id,soort_naam=b$soort_naam,q_baseline=b$q_pct,endpoint_net_baseline=b$net_pct,endpoint_annual_baseline=b$endpoint_annual_pct,
   pre_q_baseline=b$pre_q_pct,post_q_baseline=b$post_q_pct,n_q=sum(is.finite(x$q_pct)),n_endpoint_net=sum(is.finite(x$net_pct)),n_endpoint_annual=sum(is.finite(x$endpoint_annual_pct)),n_paired=sum(paired),
   q_median=med(x$q_pct),q_min=min(finite(x$q_pct)),q_max=max(finite(x$q_pct)),
   endpoint_net_median=med(x$net_pct),endpoint_net_min=min(finite(x$net_pct)),endpoint_net_max=max(finite(x$net_pct)),
   endpoint_annual_median=med(x$endpoint_annual_pct),paired_difference_median=med(x$q_pct[paired]-x$endpoint_annual_pct[paired]),
   n_gap=sum(x$gap_flag),n_opposite=sum(x$opposite),baseline_gap=b$gap_flag,period_opposite=index_summary_disagrees(b$pre_q_pct,b$post_q_pct))
 }))
 coverage<-do.call(rbind,lapply(ids,function(id)do.call(rbind,lapply(list(1958:1962,2021:2025),function(ys){
  d<-cx$species_matrix;d<-d[d$soort_id==id&d$jaar%in%ys&d$geteld%in%TRUE,]
  data.frame(soort_id=id,first_year=min(ys),last_year=max(ys),counted_cells=nrow(d),counted_plots=length(unique(d$plot_id)),positive_cells=sum(d$count_adjusted>0),adjusted_sum=sum(d$count_adjusted))
 }))))
 dir.create(out,recursive=TRUE,showWarnings=FALSE)
 write.csv(coverage,file.path(out,'coverage.csv'),row.names=FALSE)
 for(n in c('estimates','curves','summary'))write.csv(get(n),file.path(out,paste0(n,'.csv')),row.names=FALSE,na='')
 jsonlite::write_json(list(source_period='1958-2025',species_ids=ids,replicate_ids=1:50,source_hash=m$source_hash,context_sha256=m$context_sha256,
  baseline_curves_sha256=digest::digest(file=old_curves_path,algo='sha256'),criteria_sha256=digest::digest(file=file.path(repo,'trim/bootstrap/index_summary_20261103/CRITERIA.md'),algo='sha256'),
  script_sha256=digest::digest(file=file.path(repo,'R/compare_trim_index_summaries.R'),algo='sha256'),draw_hashes=hashes,
  baseline_metadata_sha256=digest::digest(file=file.path(run,'baseline.csv'),algo='sha256'),prior_summary_sha256=digest::digest(file=file.path(repo,'trim/bootstrap/pilot_2025_50_20261102/main_index_zeros/per_species.csv'),algo='sha256'),R_version=R.version.string,count_models_refitted=0,formal_intervals=FALSE),file.path(out,'manifest.json'),auto_unbox=TRUE,pretty=TRUE)
 for(id in ids){
  p<-curves[curves$soort_id==id,];q<-p[p$series=='jaarindex',];f<-p[p$series!='jaarindex',]
  denom<-mean(q$index_value[q$jaar%in%1979:1983]);q$index_value<-100*q$index_value/denom;f$index_value<-100*f$index_value/denom
  png(file.path(out,paste0('curve_',id,'.png')),width=1700,height=900,res=140)
  par(mfrow=c(1,2),mar=c(4,4,3,1),oma=c(3,1,3,1))
  for(recent in c(FALSE,TRUE)){
   a<-if(recent)q[q$jaar>=2005,] else q;b<-if(recent)f[f$jaar>=2005,] else f
   plot(range(a$jaar),c(0,max(c(a$index_value,b$index_value))*1.05),type='n',xlab='Jaar',ylab='Index (gemiddeld 1979–1983 = 100)',main=if(recent)'2005–2025' else '1958–2025')
   lines(a$jaar,a$index_value,col='#343434');points(a$jaar,a$index_value,pch=16,cex=.5,col='#343434');lines(b$jaar,b$index_value,col='#D55E00',lwd=2)
   for(ys in list(1958:1962,2021:2025))if(any(ys%in%a$jaar))segments(min(ys),mean(q$index_value[q$jaar%in%ys]),max(ys),mean(q$index_value[q$jaar%in%ys]),col='#0072B2',lwd=4)
   abline(h=0,col='gray70')
  }
  mtext(paste0(summary$soort_naam[match(id,summary$soort_id)],' — bestaande index en beschrijvende samenvatting'),outer=TRUE,side=3,line=1,font=2,cex=1.1)
  par(fig=c(0,1,.01,.09),oma=c(0,0,0,0),new=TRUE,mar=c(0,0,0,0));plot.new()
  legend('center',legend=c('Bestaande jaarindex','Exponentiële samenvatting','Vijfjaarsgemiddelden begin/einde'),col=c('#343434','#D55E00','#0072B2'),lty=1,lwd=c(1,2,4),bty='n',horiz=TRUE);dev.off()
 }
 print(summary);cat('INDEX_SUMMARY_COMPARISON_READY\n')
}
if(sys.nframe()==0L)run_index_summary_comparison()
