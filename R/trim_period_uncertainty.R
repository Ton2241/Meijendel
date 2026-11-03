# Independent, unbridged period/index assessment. No zero replacement.
period_endpoint_estimate <- function(ix,years,model_ok) {
 bad<-function(status)list(status=status,estimate=NA_real_,first_mean=NA_real_,last_mean=NA_real_)
 if(!isTRUE(model_ok))return(bad('periode_model_niet_schatbaar'))
 if(length(years)<10L||any(diff(years)!=1L))return(bad('te_korte_of_onderbroken_modelperiode'))
 first<-head(years,5L);last<-tail(years,5L);required<-c(first,last)
 if(!index_summary_valid(ix[ix$jaar%in%required,],required))return(bad('periodevenster_onvolledig_of_ongeldig'))
 a<-mean(ix$index_value[match(first,ix$jaar)]);b<-mean(ix$index_value[match(last,ix$jaar)])
 if(a==0)return(bad('nul_begingemiddelde'))
 v<-100*(b/a-1);if(!is.finite(v))return(bad('verandering_niet_eindig'))
 list(status=if(b==0)'nul_eindgemiddelde' else 'berekenbaar',estimate=v,first_mean=a,last_mean=b)
}
fixed_reference_indices <- function(ix,years,reference_year,model_ok) {
 ans<-setNames(rep(NA_real_,length(years)),as.character(years))
 if(!isTRUE(model_ok)||length(reference_year)!=1L||!is.finite(reference_year))return(ans)
 ref<-ix$index_value[which(ix$jaar==reference_year)]
 if(length(ref)!=1L||!is.finite(ref)||ref<=0)return(ans)
 for(y in years){v<-ix$index_value[which(ix$jaar==y)];if(length(v)==1L&&is.finite(v)&&v>=0)ans[as.character(y)]<-100*v/ref}
 ans
}
recover_independent_period <- function(r,id,period,context) {
 s<-r$species[r$species$soort_id==id&r$species$bridge_variant=='primary_5yr'&r$species$coverage_variant=='volledig_netwerk',];stopifnot(nrow(s)==1L)
 ok<-isTRUE(s[[paste0(period,'_ok')]]);reason<-s[[paste0(period,'_reason')]];t<-context$species_targets[[as.character(id)]][[period]]
 empty<-data.frame(jaar=integer(),index_value=numeric());result<-list(ok=ok,reason=reason,model=s[[paste0(period,'_model')]],refitted=FALSE,method='model_niet_schatbaar',index=empty)
 if(!ok)return(result)
 variants<-if(period=='pre')'primary_5yr' else r$species$bridge_variant[r$species$soort_id==id&r$species$coverage_variant=='volledig_netwerk'&is.finite(r$species$bridge_factor)&r$species$bridge_factor>0]
 if(length(variants)) {
  variant<-variants[1L];ix<-r$indices[r$indices$soort_id==id&r$indices$bridge_variant==variant&r$indices$coverage_variant=='volledig_netwerk',c('jaar','index_value')]
  ix<-ix[ix$jaar%in%t$years,,drop=FALSE]
  if(period=='post') {
   factor<-r$species$bridge_factor[r$species$soort_id==id&r$species$coverage_variant=='volledig_netwerk'&r$species$bridge_variant==variant];stopifnot(length(factor)==1L)
   ix$index_value<-ix$index_value/factor
  }
  result$method<-paste0('bewaard_',variant,if(period=='post')'_teruggeschaald' else '_ongebrrugd');result$index<-ix;return(result)
 }
 # Post fit was successful, but no unbridged indices were stored when both bridges failed.
 d<-context$species_matrix;d<-d[d$soort_id==id,,drop=FALSE];d<-apply_cluster_draw(d,r$draw);d<-d[d$jaar%in%context$config$periods[[period]],,drop=FALSE]
 f<-fit_first_working_trim_model(d,analysis_years=t$years);stopifnot(isTRUE(f$ok),identical(f$config,s[[paste0(period,'_model')]]))
 v<-bootstrap_model_index(f);saved<-s[[paste0(period,'_estimate_pct_per_year')]]
 estimate<-combined_pct_trend(v,numeric(),1,required_years=f$year_map$jaar)
 stopifnot(isTRUE(all.equal(estimate,saved,tolerance=1e-10)))
 result$refitted<-TRUE;result$method<-'zelfde_draw_model_hersteld_zonder_brug';result$index<-data.frame(jaar=as.integer(names(v)),index_value=as.numeric(v));result
}
