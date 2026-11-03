#!/usr/bin/env Rscript
# Count expectations and annual indices are distinct outputs, never replacements.
zero_count_fit_converged <- function(f) {
 isTRUE(f$converged) && (is.null(f$outer.info$conv) || identical(f$outer.info$conv,'full convergence'))
}
fit_zero_count_curve <- function(df,analysis_years,shape=c('linear','smooth'),k=5L) {
 shape <- match.arg(shape);years <- sort(unique(as.integer(analysis_years)))
 invalid <- function(reason)list(ok=FALSE,reason=reason)
 d <- df[df$geteld%in%TRUE & df$jaar%in%years & is.finite(df$count_adjusted),,drop=FALSE]
 if(!nrow(d)||any(d$count_adjusted<0))return(invalid('geen_geldige_tellingen'))
 totals <- aggregate(count_adjusted~plot_id,d,sum)
 active <- totals$plot_id[totals$count_adjusted>0]
 d <- d[d$plot_id%in%active,,drop=FALSE]
 if(length(active)<2L||length(unique(d$jaar[d$count_adjusted>0]))<3L)return(invalid('te_weinig_positieve_informatie'))
 if(shape=='smooth'&&length(unique(d$jaar))<k)return(invalid('te_weinig_jaren_voor_vaste_spline'))
 d$site <- factor(d$plot_id);center <- mean(years);d$year_c <- d$jaar-center
 s <- mgcv::s;warnings <- character()
 f <- tryCatch(withCallingHandlers(
  if(shape=='linear')stats::glm(count_adjusted~site+year_c,data=d,family=stats::quasipoisson(link='log'),control=stats::glm.control(maxit=200)) else
   mgcv::gam(count_adjusted~site+s(year_c,k=k,bs='cr'),data=d,family=stats::quasipoisson(link='log'),method='REML',control=mgcv::gam.control(maxit=200)),
  warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')}),error=function(e)e)
 if(inherits(f,'error'))return(invalid(conditionMessage(f)))
 if(!zero_count_fit_converged(f))return(invalid('telmodel_niet_volledig_geconvergeerd'))
 grid <- expand.grid(site=levels(d$site),jaar=years,KEEP.OUT.ATTRS=FALSE)
 grid$site <- factor(grid$site,levels=levels(d$site));grid$year_c <- grid$jaar-center
 pred <- tryCatch(as.numeric(stats::predict(f,newdata=grid,type='response')),error=function(e)NULL)
 if(length(pred)!=nrow(grid)||any(!is.finite(pred))||any(pred<=0))return(invalid('ongeldige_modelverwachting'))
 v <- tapply(pred,grid$jaar,sum);v <- as.numeric(v[as.character(years)]);names(v)<-as.character(years)
 list(ok=TRUE,model=f,data=d,totals=v,index=100*v/v[1],center=center,
  unobserved_years=as.integer(setdiff(years,unique(d$jaar))),
  extrapolated_years=years[years<min(d$jaar)|years>max(d$jaar)],
  reason=NA_character_,warnings=unique(warnings),shape=shape)
}

zero_count_cv <- function(df,years,shape) {
 # Fixed three-year time blocks, distributed over five folds; no favourable fold selection.
 d <- df[df$geteld%in%TRUE&is.finite(df$count_adjusted)&df$jaar%in%years,,drop=FALSE]
 active <- aggregate(count_adjusted~plot_id,d,sum);d<-d[d$plot_id%in%active$plot_id[active$count_adjusted>0],,drop=FALSE]
 fold <- ((d$jaar-min(years))%/%3L)%%5L+1L
 rows <- lapply(1:5,function(j) {
  train <- d[fold!=j,,drop=FALSE];test<-d[fold==j,,drop=FALSE]
  status <- 'berekenbaar';dev <- NA_real_
  if(!nrow(test)||!nrow(train))status<-'geen_test_of_trainingscellen'
  if(status=='berekenbaar') {
   support<-aggregate(count_adjusted~plot_id,train,sum)
   if(any(!unique(test$plot_id)%in%support$plot_id[support$count_adjusted>0]))status<-'onvoldoende_positieve_trainingssteun'
  }
  if(status=='berekenbaar') {
   f<-fit_zero_count_curve(train,years,shape)
   if(!f$ok)status<-f$reason else {
    test$site<-factor(test$plot_id,levels=levels(f$data$site));test$year_c<-test$jaar-f$center
    mu<-tryCatch(as.numeric(stats::predict(f$model,newdata=test,type='response')),error=function(e)NULL)
    if(length(mu)!=nrow(test)||any(!is.finite(mu))||any(mu<=0))status<-'ongeldige_testverwachting' else {
     y<-test$count_adjusted;loss<-2*mu;pos<-y>0
     loss[pos]<-2*(y[pos]*log(y[pos]/mu[pos])-y[pos]+mu[pos]);dev<-sum(loss)
    }
   }
  }
  data.frame(fold=j,status=status,n_test=nrow(test),deviance=dev)
 });do.call(rbind,rows)
}

zero_index_pct_trend <- function(ix,years) {
 if(!setequal(ix$jaar,years)||any(!is.finite(ix$index_value))||any(ix$index_value<0)||sum(ix$index_value)<=0)return(NA_real_)
 f<-tryCatch(suppressWarnings(stats::glm(index_value~I(jaar-mean(jaar)),data=ix,family=stats::quasipoisson(link='log'))),error=function(e)NULL)
 if(is.null(f)||!isTRUE(f$converged))return(NA_real_)
 100*expm1(unname(stats::coef(f)[2]))
}

plot_zero_count_curves <- function(curves,names_by_id,out) {
 for(id in unique(curves$soort_id)) {
  d<-curves[curves$soort_id==id,]
  # A shared anchor, rather than each fitted curve's first-year prediction,
  # makes shape comparison interpretable. This scaling changes no slope.
  d$plot_value<-NA_real_
  for(series in unique(d$series)) {
   z<-d$series==series
   anchor<-mean(d$index_value[z&d$jaar%in%1979:1983])
   d$plot_value[z]<-100*d$index_value[z]/anchor
  }
  cols<-c(jaarindex='#343434',telmodel_linear='#0072B2',telmodel_smooth='#D55E00')
  grDevices::png(file.path(out,paste0('curve_',id,'.png')),width=1700,height=900,res=140)
  graphics::par(mfrow=c(1,2),mar=c(4,4,3,1),oma=c(3,1,3,1))
  for(recent in c(FALSE,TRUE)) {
   v<-if(recent)d[d$jaar>=2005,] else d
   ymax<-max(v$plot_value[is.finite(v$plot_value)],0)*1.05
   graphics::plot(range(v$jaar),c(0,if(ymax>0)ymax else 1),type='n',xlab='Jaar',ylab='Index (gemiddeld 1979–1983 = 100)',main=if(recent)'2005–2025' else 'Volledige reeks')
   for(series in names(cols)) {
    z<-v[v$series==series,];z<-z[order(z$jaar),]
    graphics::lines(z$jaar,z$plot_value,col=cols[[series]],lwd=if(series=='jaarindex')1 else 2)
    if(series=='jaarindex')graphics::points(z$jaar,z$plot_value,pch=16,cex=.5,col=cols[[series]])
   }
   graphics::abline(h=0,col='gray70');if(!recent)graphics::abline(v=1983.5,lty=3,col='gray50')
  }
  graphics::mtext(paste0(unname(names_by_id[as.character(id)]),' — gegevens tot en met 2025'),outer=TRUE,side=3,line=1,font=2,cex=1.2)
  graphics::par(fig=c(0,1,.01,.09),oma=c(0,0,0,0),new=TRUE,mar=c(0,0,0,0));graphics::plot.new()
  graphics::legend('center',legend=c('Jaarindex: tellingen en aanvulling','Verwachting: lineair telmodel','Verwachting: beperkte tijdsspline'),col=cols,lty=1,lwd=c(1,2,2),bty='n',horiz=TRUE,cex=.85)
  grDevices::dev.off()
 }
}

compare_zero_count_models_cli <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==3L)
 repo<-normalizePath(args[1],mustWork=TRUE);run<-normalizePath(args[2],mustWork=TRUE);out<-args[3]
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 for(f in c('trim_trend_contract.R','trim_bootstrap_core.R','trim_bridge_core.R','merge_trim_bootstrap_batches.R'))source(file.path(repo,'R',f),local=TRUE)
 manifest<-jsonlite::read_json(file.path(run,'input/bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(digest::digest(file=file.path(run,'input/context.rds'),algo='sha256')==manifest$context_sha256)
 cx<-readRDS(file.path(run,'input/context.rds'));stopifnot(max(cx$species_matrix$jaar)==2025L)
 baseline<-read.csv(file.path(run,'baseline.csv'));baseline<-baseline[baseline$bridge_variant=='primary_5yr',]
 selected<-baseline$soort_id[match(c('Veldleeuwerik','Torenvalk','Tapuit','Koolmees'),baseline$soort_naam)];stopifnot(length(selected)==4L,!anyNA(selected))
 sm<-cx$species_matrix[cx$species_matrix$soort_id%in%selected,]
 name_of<-setNames(baseline$soort_naam,baseline$soort_id)
 paths<-list.files(file.path(run,'batches'),pattern='^batch-[0-9]+-[0-9]+\\.rds$',full.names=TRUE)
 merged<-merge_trim_bootstrap_batches(paths,expected_ids=1:50)
 cl<-cx$clusters
 identity_draw<-data.frame(source_cluster_id=cl$bootstrap_cluster_id,bootstrap_site_id=cl$bootstrap_cluster_id,draw_position=seq_len(nrow(cl)))
 all_results<-c(list(list(replicate_id=0L,draw=identity_draw)),merged$results)
 estimates<-list();curves<-list();diagnostics<-list();cvrows<-list();sensitivity<-list();coverage<-list()
 variant<-cx$bridge_variants$primary_5yr
 for(r in all_results) {
  for(id in selected) {
   sp<-sm[sm$soort_id==id,];drawn<-apply_cluster_draw(sp,r$draw);target<-cx$species_targets[[as.character(id)]]
   required<-c(target$pre$years,target$post$years)
   cal<-fit_bridge_calibration_window(sp,r$draw,variant$plot_ids,variant$pre_years,variant$post_years)
   ratio<-if(cal$ok)mean(values_for_years(cal$totals,variant$post_years))/mean(values_for_years(cal$totals,variant$pre_years)) else NA_real_
   indices<-NULL;old<-NA_real_
   if(r$replicate_id==0L) {
    fits<-lapply(c('pre','post'),function(part)fit_first_working_trim_model(drawn[drawn$jaar%in%target[[part]]$years,],analysis_years=target[[part]]$years));names(fits)<-c('pre','post')
    idx<-lapply(fits,bootstrap_model_index)
    br<-compute_empirical_bridge(idx$pre,idx$post,if(cal$ok)cal$totals else NULL,variant$pre_years,variant$post_years)
    v<-c(idx$pre,idx$post*br$bridge_factor)
    indices<-data.frame(jaar=as.integer(names(v)),index_value=as.numeric(v))
    old<-combined_pct_trend(idx$pre,idx$post,br$bridge_factor,required_years=required)
    expected<-baseline$estimate_pct_per_year[baseline$soort_id==id]
    stopifnot(isTRUE(all.equal(old,expected,tolerance=1e-8)))
   } else {
    row<-r$species[r$species$soort_id==id&r$species$bridge_variant=='primary_5yr',]
    indices<-r$indices[r$indices$soort_id==id&r$indices$bridge_variant=='primary_5yr',c('jaar','index_value')]
    old<-row$estimate_pct_per_year
    if(is.finite(row$level_ratio))stopifnot(isTRUE(all.equal(ratio,row$level_ratio,tolerance=1e-8)))
   }
   add_estimate<-function(method,value,reason=NA_character_)data.frame(soort_id=id,soort_naam=unname(name_of[as.character(id)]),replicate_id=r$replicate_id,method=method,trend_pct_per_year=value,reason=reason,level_ratio=ratio)
   estimates[[length(estimates)+1L]]<-add_estimate('log_jaarindex',old)
   estimates[[length(estimates)+1L]]<-add_estimate('quasi_jaarindex',zero_index_pct_trend(indices,required))
   if(r$replicate_id==0L)curves[[length(curves)+1L]]<-data.frame(soort_id=id,jaar=indices$jaar,series='jaarindex',index_value=indices$index_value)
   for(shape in c('linear','smooth')) {
    fits<-list()
    for(part in c('pre','post')) {
     d<-drawn[drawn$jaar%in%target[[part]]$years,]
     f<-fit_zero_count_curve(d,target[[part]]$years,shape);fits[[part]]<-f
     diagnostic<-data.frame(soort_id=id,replicate_id=r$replicate_id,period=part,shape=shape,ok=f$ok,reason=if(f$ok)NA_character_ else f$reason,
      n_observed=if(f$ok)nrow(f$data) else NA_integer_,n_zero=if(f$ok)sum(f$data$count_adjusted==0) else NA_integer_,
      unobserved_years=if(f$ok)paste(f$unobserved_years,collapse=';') else '',extrapolated_years=if(f$ok)paste(f$extrapolated_years,collapse=';') else '',
      warnings=if(f$ok)paste(f$warnings,collapse=' | ') else '',deviance=if(f$ok)f$model$deviance else NA_real_,residual_df=if(f$ok)f$model$df.residual else NA_real_)
     diagnostics[[length(diagnostics)+1L]]<-diagnostic
     if(r$replicate_id==0L) {
      cv<-zero_count_cv(d,target[[part]]$years,shape);cv$soort_id<-id;cv$period<-part;cv$shape<-shape;cvrows[[length(cvrows)+1L]]<-cv
      if(shape=='smooth')for(k in c(3L,7L)) {
       sf<-fit_zero_count_curve(d,target[[part]]$years,'smooth',k=k)
       sensitivity[[length(sensitivity)+1L]]<-data.frame(soort_id=id,period=part,k=k,ok=sf$ok,period_pct=if(sf$ok)combined_pct_trend(sf$index,numeric(),1,required_years=target[[part]]$years) else NA_real_,mean_abs_index_difference=if(sf$ok&&f$ok)mean(abs(sf$index-f$index)) else NA_real_)
      }
     }
    }
    pre<-if(fits$pre$ok)fits$pre$index else NULL;post<-if(fits$post$ok)fits$post$index else NULL
    br<-compute_empirical_bridge(pre,post,if(cal$ok)cal$totals else NULL,variant$pre_years,variant$post_years)
    value<-combined_pct_trend(pre,post,br$bridge_factor,required_years=required)
    reason<-if(!fits$pre$ok)paste0('pre:',fits$pre$reason) else if(!fits$post$ok)paste0('post:',fits$post$reason) else if(!cal$ok)cal$reason else br$reason
    estimates[[length(estimates)+1L]]<-add_estimate(paste0('telmodel_',shape),value,reason)
    if(r$replicate_id==0L) {
     v<-c(pre,post*br$bridge_factor)
     curves[[length(curves)+1L]]<-data.frame(soort_id=id,jaar=as.integer(names(v)),series=paste0('telmodel_',shape),index_value=as.numeric(v))
    }
   }
  }
  cat('COMPARISON_DONE',r$replicate_id,'\n');if(r$replicate_id%%5L==0L)gc()
 }
 estimates<-do.call(rbind,estimates);curves<-do.call(rbind,curves);diagnostics<-do.call(rbind,diagnostics);cv<-do.call(rbind,cvrows);sensitivity<-do.call(rbind,sensitivity)
 stopifnot(nrow(estimates)==4L*51L*4L,nrow(diagnostics)==4L*51L*2L*2L)
 summaries<-do.call(rbind,lapply(split(estimates,list(estimates$soort_id,estimates$method),drop=TRUE),function(d) {
  b<-d[d$replicate_id==0L,];v<-d$trend_pct_per_year[d$replicate_id>0];v<-v[is.finite(v)]
  data.frame(soort_id=b$soort_id,soort_naam=b$soort_naam,method=b$method,baseline_pct=b$trend_pct_per_year,n_valid=length(v),median_pct=if(length(v))median(v) else NA_real_,min_pct=if(length(v))min(v) else NA_real_,max_pct=if(length(v))max(v) else NA_real_)
 }))
 cvsummary<-do.call(rbind,lapply(split(cv,list(cv$soort_id,cv$period,cv$shape),drop=TRUE),function(d)data.frame(soort_id=d$soort_id[1],period=d$period[1],shape=d$shape[1],n_folds_complete=sum(d$status=='berekenbaar'),n_test=sum(d$n_test),n_scored=sum(d$n_test[d$status=='berekenbaar']),mean_deviance=if(all(d$status=='berekenbaar'))sum(d$deviance)/sum(d$n_test) else NA_real_,status=if(all(d$status=='berekenbaar'))'volledig_berekend' else 'onvolledig_geen_modelrangorde')))
 dir.create(out,recursive=TRUE,showWarnings=FALSE)
 for(n in c('estimates','curves','diagnostics','cv','cvsummary','sensitivity','summaries'))write.csv(get(n),file.path(out,paste0(n,'.csv')),row.names=FALSE,na='')
 plot_zero_count_curves(curves,name_of,out)
 jsonlite::write_json(list(source_period='1958-2025',species_ids=selected,replicates=50,context_sha256=manifest$context_sha256,source_hash=manifest$source_hash,script_sha256=digest::digest(file=file.path(repo,'R/compare_trim_zero_count_models.R'),algo='sha256'),rtrim=as.character(utils::packageVersion('rtrim')),mgcv=as.character(utils::packageVersion('mgcv')),publication_status='gerichte_modelvergelijking_geen_methodevervanging_geen_formele_intervallen'),file.path(out,'manifest.json'),auto_unbox=TRUE,pretty=TRUE)
 cat('ZERO_COUNT_COMPARISON_READY\n')
}
if(sys.nframe()==0L)compare_zero_count_models_cli()
