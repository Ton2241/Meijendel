#!/usr/bin/env Rscript
# Experimental species model. Observations, expected counts and uncertainty stay distinct.
random_plot_moments <- function(eta,link_var,unknown,tau2) {
 mu<-exp(eta+ifelse(unknown,tau2/2,0))
 data.frame(expected=mu,link_se=sqrt(pmax(link_var,0)+ifelse(unknown,tau2,0)),
  unknown_site=unknown,unknown_site_sd=ifelse(unknown,mu*sqrt(expm1(tau2)),0))
}

predict_random_plot <- function(f,newdata) {
 nd<-newdata;known<-as.character(nd$plot_id)%in%levels(f$data$site)
 if(any(!nd$stratum%in%levels(f$data$stratum)))stop('onbekend_stratum')
 nd$stratum<-factor(nd$stratum,levels=levels(f$data$stratum))
 # Placeholder only constructs X; its random-effect columns are explicitly zeroed.
 ids<-as.character(nd$plot_id);ids[!known]<-levels(f$data$site)[1]
 nd$site<-factor(ids,levels=levels(f$data$site));nd$year_c<-nd$jaar-f$center
 X<-stats::predict(f$model,newdata=nd,type='lpmatrix')
 X[!known,f$re_columns]<-0
 eta<-as.numeric(X%*%stats::coef(f$model));v<-rowSums((X%*%stats::vcov(f$model)) * X)
 random_plot_moments(eta,v,!known,f$tau2)
}

fit_random_plot <- function(df,analysis_years,reference,k=5L,time=TRUE) {
 invalid<-function(reason)list(ok=FALSE,reason=reason)
 years<-sort(unique(as.integer(analysis_years)))
 d<-df[df$geteld%in%TRUE&df$jaar%in%years&is.finite(df$count_adjusted),,drop=FALSE]
 if(!nrow(d)||any(d$count_adjusted<0))return(invalid('geen_geldige_tellingen'))
 if(sum(d$count_adjusted)<=0)return(invalid('geen_positieve_periode'))
 if(length(unique(d$plot_id))<2L)return(invalid('te_weinig_kavels'))
 if(time&&length(unique(d$jaar))<k)return(invalid('te_weinig_jaren_voor_vaste_spline'))
 d$site<-factor(as.character(d$plot_id));d$stratum<-factor(d$stratum)
 center<-mean(years);d$year_c<-d$jaar-center;s<-mgcv::s
 formula<-if(nlevels(d$stratum)>1L) {
  if(time)count_adjusted~stratum+s(year_c,k=k,bs='cr')+s(site,bs='re') else count_adjusted~stratum+s(site,bs='re')
 } else {
  if(time)count_adjusted~s(year_c,k=k,bs='cr')+s(site,bs='re') else count_adjusted~s(site,bs='re')
 }
 warnings<-character()
 model<-tryCatch(withCallingHandlers(mgcv::gam(formula,data=d,family=stats::quasipoisson(link='log'),method='REML',control=mgcv::gam.control(maxit=200)),warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')}),error=function(e)e)
 if(inherits(model,'error'))return(invalid(conditionMessage(model)))
 if(!zero_count_fit_converged(model))return(invalid('niet_volledig_geconvergeerd'))
 re<-Filter(function(x)inherits(x,'random.effect'),model$smooth)
 if(length(re)!=1L)return(invalid('onbekende_randomstructuur'))
 vc<-NULL;invisible(utils::capture.output(vc<-tryCatch(mgcv::gam.vcomp(model),error=function(e)NULL)))
 if(is.list(vc)&&is.matrix(vc$vc))vc<-vc$vc
 key<-re[[1]]$label
 tau2<-if(is.matrix(vc)&&key%in%rownames(vc))vc[key,'std.dev']^2 else if(is.numeric(vc)&&key%in%names(vc))vc[[key]]^2 else NA_real_
 if(!is.finite(tau2)||tau2<0)return(invalid('ongeldige_kavelvariantie'))
 f<-list(ok=TRUE,model=model,data=d,center=center,tau2=tau2,re_columns=re[[1]]$first.para:re[[1]]$last.para,
  warnings=unique(warnings),reason=NA_character_)
 grid<-merge(reference,data.frame(jaar=years),by=NULL)
 p<-tryCatch(predict_random_plot(f,grid),error=function(e)e)
 if(inherits(p,'error'))return(invalid(conditionMessage(p)))
 if(any(!is.finite(p$expected))||any(p$expected<=0)||any(!is.finite(p$link_se))||any(!is.finite(p$unknown_site_sd)))return(invalid('ongeldige_verwachting_of_onzekerheid'))
 v<-tapply(p$expected,grid$jaar,sum);v<-as.numeric(v[as.character(years)]);names(v)<-as.character(years)
 f$totals<-v;f$index<-100*v/v[1];f$prediction<-cbind(grid,p)
 f
}

random_plot_cv <- function(df,years,reference,k=5L) {
 d<-df[df$geteld%in%TRUE&df$jaar%in%years&is.finite(df$count_adjusted),,drop=FALSE]
 fold<-((d$jaar-min(years))%/%3L)%%5L+1L
 rows<-list()
 for(j in 1:5)for(time in c(TRUE,FALSE)) {
  train<-d[fold!=j,,drop=FALSE];test<-d[fold==j,,drop=FALSE]
  status<-'berekenbaar';loss<-NA_real_;unknown<-NA_integer_;unc<-NA_real_
  f<-fit_random_plot(train,years,reference,k,time)
  if(!f$ok)status<-f$reason else if(!nrow(test))status<-'geen_testcellen' else {
   p<-tryCatch(predict_random_plot(f,test),error=function(e)NULL)
   if(is.null(p)||any(!is.finite(p$expected))||any(p$expected<=0))status<-'ongeldige_testvoorspelling' else {
    y<-test$count_adjusted;mu<-p$expected;v<-2*mu;positive<-y>0
    v[positive]<-2*(y[positive]*log(y[positive]/mu[positive])-y[positive]+mu[positive])
    loss<-sum(v);unknown<-sum(p$unknown_site);unc<-mean(p$link_se)
   }
  }
  rows[[length(rows)+1L]]<-data.frame(fold=j,model=if(time)'tijd' else 'referentie',status=status,n_test=nrow(test),n_zero_test=sum(test$count_adjusted==0),n_unknown_site=unknown,deviance=loss,mean_link_se=unc)
 }
 do.call(rbind,rows)
}

random_trial_close <- function(primary,alternative) {
 if(any(!is.finite(c(primary,alternative))))return(FALSE)
 direction<-abs(primary)<=.5|abs(alternative)<=.5|sign(primary)==sign(alternative)
 all(abs(primary-alternative)<=pmax(1,.2*abs(primary)) & direction)
}

run_random_plot_trial <- function(args=commandArgs(trailingOnly=TRUE)) {
 stopifnot(length(args)==3L)
 repo<-normalizePath(args[1],mustWork=TRUE);run<-normalizePath(args[2],mustWork=TRUE);out<-args[3]
 source(path.expand('~/Documents/GitHub/Meijendel/R/trial_storage.R'));out<-trial_output(out)
 .libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
 for(f in c('trim_trend_contract.R','trim_bootstrap_core.R','trim_bridge_core.R','merge_trim_bootstrap_batches.R','compare_trim_zero_count_models.R'))source(file.path(repo,'R',f),local=environment(fit_random_plot))
 criteria<-file.path(repo,'trim/bootstrap/random_kavel_20261103/CRITERIA.md')
 m<-jsonlite::read_json(file.path(run,'input/bundle_manifest.json'),simplifyVector=TRUE)
 stopifnot(digest::digest(file=file.path(run,'input/context.rds'),algo='sha256')==m$context_sha256)
 cx<-readRDS(file.path(run,'input/context.rds'));stopifnot(range(cx$species_matrix$jaar)==c(1958L,2025L))
 base<-read.csv(file.path(run,'baseline.csv'));base<-base[base$bridge_variant=='primary_5yr',]
 ids<-base$soort_id[match(c('Veldleeuwerik','Torenvalk','Tapuit','Koolmees'),base$soort_naam)]
 names_by_id<-setNames(base$soort_naam,base$soort_id)
 cl<-cx$clusters;identity<-data.frame(source_cluster_id=cl$bootstrap_cluster_id,bootstrap_site_id=cl$bootstrap_cluster_id,draw_position=seq_len(nrow(cl)))
 paths<-list.files(file.path(run,'batches'),pattern='^batch-[0-9]+-[0-9]+\\.rds$',full.names=TRUE)
 merged<-merge_trim_bootstrap_batches(paths,expected_ids=1:50)
 results<-c(list(list(replicate_id=0L,draw=identity)),merged$results)
 identity_info<-list(criteria_sha256=digest::digest(file=criteria,algo='sha256'),script_sha256=digest::digest(file=file.path(repo,'R/trim_random_plot_trial.R'),algo='sha256'),context_sha256=m$context_sha256,source_hash=m$source_hash,rtrim=as.character(utils::packageVersion('rtrim')),mgcv=as.character(utils::packageVersion('mgcv')))
 dir.create(out,recursive=TRUE,showWarnings=FALSE)
 if(file.exists(file.path(out,'run_identity.rds')))stopifnot(identical(identity_info,readRDS(file.path(out,'run_identity.rds')))) else saveRDS(identity_info,file.path(out,'run_identity.rds'))
 fit_parts<-function(d,target,ref,k=5L,time=TRUE) {
  f<-lapply(c('pre','post'),function(part)fit_random_plot(d[d$jaar%in%target[[part]]$years,],target[[part]]$years,ref,k,time));names(f)<-c('pre','post');f
 }
 calibrate<-function(sp,draw,variant)fit_bridge_calibration_window(sp,draw,variant$plot_ids,variant$pre_years,variant$post_years)
 describe<-function(f,cal,variant,target) {
  pre<-if(f$pre$ok)f$pre$index else NULL;post<-if(f$post$ok)f$post$index else NULL
  b<-compute_empirical_bridge(pre,post,if(cal$ok)cal$totals else NULL,variant$pre_years,variant$post_years)
  required<-c(target$pre$years,target$post$years)
  list(long=combined_pct_trend(pre,post,b$bridge_factor,required_years=required),
   pre=combined_pct_trend(pre,numeric(),1,required_years=target$pre$years),
   post=combined_pct_trend(post,numeric(),1,required_years=target$post$years),bridge=b,
   values=c(pre,post*b$bridge_factor))
 }
 for(r in results) {
  path<-file.path(out,sprintf('replicate-%03d.rds',r$replicate_id))
  if(file.exists(path))next
  estimates<-list();curves<-list();diags<-list();cv<-list();sensitivity<-list()
  for(id in ids) {
   sp<-cx$species_matrix[cx$species_matrix$soort_id==id,];target<-cx$species_targets[[as.character(id)]]
   d<-apply_cluster_draw(sp,r$draw)
   d$stratum<-cl$stratum[match(d$source_cluster_id,cl$bootstrap_cluster_id)]
   ref<-unique(d[c('plot_id','stratum')]);stopifnot(nrow(ref)==52L)
   v5<-cx$bridge_variants$primary_5yr;v3<-cx$bridge_variants$reference_3yr
   cal5<-calibrate(sp,r$draw,v5);cal3<-calibrate(sp,r$draw,v3)
   f<-fit_parts(d,target,ref);desc<-describe(f,cal5,v5,target);alt<-describe(f,cal3,v3,target)
   reason<-if(!f$pre$ok)paste0('pre:',f$pre$reason) else if(!f$post$ok)paste0('post:',f$post$reason) else if(!cal5$ok)cal5$reason else desc$bridge$reason
   estimates[[length(estimates)+1L]]<-data.frame(soort_id=id,soort_naam=unname(names_by_id[as.character(id)]),replicate_id=r$replicate_id,long_pct=desc$long,pre_pct=desc$pre,post_pct=desc$post,bridge3_long_pct=alt$long,level_ratio=desc$bridge$level_ratio,reason=reason)
   if(length(desc$values))curves[[length(curves)+1L]]<-data.frame(soort_id=id,replicate_id=r$replicate_id,jaar=as.integer(names(desc$values)),index_value=as.numeric(desc$values))
   for(part in c('pre','post')) {
    ft<-f[[part]];input<-d[d$jaar%in%target[[part]]$years&d$geteld%in%TRUE&is.finite(d$count_adjusted),]
    zero_sites<-if(nrow(input)){z<-aggregate(count_adjusted~plot_id,input,sum);sum(z$count_adjusted==0)} else 0L
    diags[[length(diags)+1L]]<-data.frame(soort_id=id,replicate_id=r$replicate_id,period=part,ok=ft$ok,reason=if(ft$ok)NA_character_ else ft$reason,
     n_input=nrow(input),n_used=if(ft$ok)nrow(ft$data) else NA_integer_,n_zero_input=sum(input$count_adjusted==0),n_zero_used=if(ft$ok)sum(ft$data$count_adjusted==0) else NA_integer_,n_zero_only_sites=zero_sites,
     tau2=if(ft$ok)ft$tau2 else NA_real_,n_unknown_reference_cells=if(ft$ok)sum(ft$prediction$unknown_site) else NA_integer_,warnings=if(ft$ok)paste(ft$warnings,collapse=' | ') else '')
    if(ft$ok)stopifnot(nrow(input)==nrow(ft$data),sum(input$count_adjusted==0)==sum(ft$data$count_adjusted==0))
    if(r$replicate_id==0L){a<-random_plot_cv(input,target[[part]]$years,ref);a$soort_id<-id;a$period<-part;cv[[length(cv)+1L]]<-a}
   }
   if(r$replicate_id==0L) {
    for(k in c(3L,7L)) {
     sf<-fit_parts(d,target,ref,k=k);sd<-describe(sf,cal5,v5,target)
     sensitivity[[length(sensitivity)+1L]]<-data.frame(soort_id=id,variant=paste0('k',k),long_pct=sd$long,pre_pct=sd$pre,post_pct=sd$post)
    }
    sensitivity[[length(sensitivity)+1L]]<-data.frame(soort_id=id,variant='bridge3',long_pct=alt$long,pre_pct=alt$pre,post_pct=alt$post)
    hist<-d[d$source_cluster_id%in%cx$historical_cluster_ids,];hr<-unique(hist[c('plot_id','stratum')]);stopifnot(nrow(hr)==17L)
    hd<-r$draw[r$draw$source_cluster_id%in%cx$historical_cluster_ids,];hv<-v5;hv$plot_ids<-intersect(hv$plot_ids,cx$historical_cluster_ids)
    hf<-fit_parts(hist,target,hr);hc<-calibrate(sp,hd,hv);hh<-describe(hf,hc,hv,target)
    sensitivity[[length(sensitivity)+1L]]<-data.frame(soort_id=id,variant='historische17',long_pct=hh$long,pre_pct=hh$pre,post_pct=hh$post)
   }
  }
  bind<-function(x)if(length(x))do.call(rbind,x) else data.frame()
  state<-list(identity=identity_info,replicate_id=r$replicate_id,draw_hash=draw_hash_text(r$draw),estimates=bind(estimates),curves=bind(curves),diagnostics=bind(diags),cv=bind(cv),sensitivity=bind(sensitivity))
  saveRDS(state,paste0(path,'.partial'));stopifnot(file.rename(paste0(path,'.partial'),path))
  cat('RANDOM_TRIAL_DONE',r$replicate_id,'\n');gc()
 }
 states<-lapply(0:50,function(i)readRDS(file.path(out,sprintf('replicate-%03d.rds',i))))
 stopifnot(all(vapply(states,function(x)identical(x$identity,identity_info),logical(1))))
 bindpart<-function(n)do.call(rbind,Filter(function(x)nrow(x)>0,lapply(states,`[[`,n)))
 estimates<-bindpart('estimates');curves<-bindpart('curves');diagnostics<-bindpart('diagnostics');cv<-bindpart('cv');sensitivity<-bindpart('sensitivity')
 summary<-list()
 for(id in ids) {
  e<-estimates[estimates$soort_id==id,];base_e<-e[e$replicate_id==0,];rep_e<-e[e$replicate_id>0,]
  c<-cv[cv$soort_id==id,];s<-sensitivity[sensitivity$soort_id==id,]
  Dtime<-all(vapply(c('k3','k7'),function(v){x<-s[s$variant==v,];random_trial_close(c(base_e$long_pct,base_e$pre_pct,base_e$post_pct),c(x$long_pct,x$pre_pct,x$post_pct))},logical(1)))
  x<-s[s$variant=='bridge3',];Dbridge<-random_trial_close(base_e$long_pct,x$long_pct)
  x<-s[s$variant=='historische17',];Dcoverage<-random_trial_close(c(base_e$long_pct,base_e$pre_pct,base_e$post_pct),c(x$long_pct,x$pre_pct,x$post_pct))
  A<-is.finite(base_e$long_pct)&&sum(is.finite(rep_e$long_pct))>=48L
  B<-nrow(c)==20L&&all(c$status=='berekenbaar')
  C<-FALSE;ratio_pre<-ratio_post<-NA_real_;wins<-0L
  if(B) {
   paired<-merge(c[c$model=='tijd',],c[c$model=='referentie',],by=c('fold','period'),suffixes=c('_time','_ref'))
   stopifnot(nrow(paired)==10L,all(paired$n_test_time==paired$n_test_ref))
   wins<-sum(paired$deviance_time<=paired$deviance_ref)
   pr<-paired[paired$period=='pre',];po<-paired[paired$period=='post',]
   ratio_pre<-sum(pr$deviance_time)/sum(pr$deviance_ref);ratio_post<-sum(po$deviance_time)/sum(po$deviance_ref)
   C<-sum(paired$deviance_time)<sum(paired$deviance_ref)&&ratio_pre<=1.1&&ratio_post<=1.1&&wins>=6L
  }
  summary[[length(summary)+1L]]<-data.frame(soort_id=id,soort_naam=base_e$soort_naam,baseline_long_pct=base_e$long_pct,n_valid=sum(is.finite(rep_e$long_pct)),median_pct=if(any(is.finite(rep_e$long_pct)))median(rep_e$long_pct,na.rm=TRUE) else NA_real_,min_pct=if(any(is.finite(rep_e$long_pct)))min(rep_e$long_pct,na.rm=TRUE) else NA_real_,max_pct=if(any(is.finite(rep_e$long_pct)))max(rep_e$long_pct,na.rm=TRUE) else NA_real_,A=A,B=B,C=C,D_time=Dtime,D_bridge=Dbridge,D_coverage=Dcoverage,D=Dtime&&Dbridge&&Dcoverage,all_criteria=A&&B&&C&&Dtime&&Dbridge&&Dcoverage,cv_ratio_pre=ratio_pre,cv_ratio_post=ratio_post,cv_fold_wins=wins)
 }
 summary<-do.call(rbind,summary)
 for(n in c('estimates','curves','diagnostics','cv','sensitivity','summary'))write.csv(get(n),file.path(out,paste0(n,'.csv')),row.names=FALSE,na='')
 jsonlite::write_json(c(identity_info,list(source_period='1958-2025',species_ids=ids,replicate_ids=1:50,publication_status='pilot_geen_formele_intervallen',criteria_commit='c3fc5dfb',draw_hashes=lapply(states[-1],function(x)x$draw_hash))),file.path(out,'manifest.json'),auto_unbox=TRUE,pretty=TRUE)
 cat('RANDOM_PLOT_TRIAL_READY\n');print(summary)
}
if(sys.nframe()==0L)run_random_plot_trial()
