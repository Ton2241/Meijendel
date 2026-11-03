#!/usr/bin/env Rscript
source('R/compare_trim_index_summaries.R')
source('R/trim_endpoint_bootstrap.R')
y<-1958:2025;d<-data.frame(jaar=y,index_value=exp(.02*(y-1958)))
e<-fixed_endpoint_estimate(d,y);stopifnot(e$status=='berekenbaar',abs(e$estimate-100*expm1(.02*63))<1e-8)
scaled<-d;scaled$index_value<-17*scaled$index_value;stopifnot(abs(fixed_endpoint_estimate(scaled,y)$estimate-e$estimate)<1e-8)
z<-d;z$index_value[z$jaar>=2021]<-0;e<-fixed_endpoint_estimate(z,y);stopifnot(e$estimate== -100,e$status=='nul_eindgemiddelde')
z$index_value[z$jaar<=1962]<-0;stopifnot(is.na(fixed_endpoint_estimate(z,y)$estimate),fixed_endpoint_estimate(z,y)$status=='nul_begingemiddelde')
stopifnot(fixed_endpoint_estimate(d,y,bridge_ok=FALSE)$status=='brug_niet_schatbaar',fixed_endpoint_estimate(d,y,pre_ok=FALSE)$status=='pre_model_niet_schatbaar')
stopifnot(fixed_endpoint_estimate(d[-1,],y[-1])$status=='vaste_vensterjaren_ontbreken')
# All required endpoint AND bridge years remain strict; other index gaps are separate.
for(year in c(1958L,1962L,2021L,2025L,1979L,1983L,1986L,1990L)) {
 j<-match(year,y)
 for(bad in list(d[-j,],rbind(d,d[j,]),transform(d,index_value=replace(index_value,j,-1)),transform(d,index_value=replace(index_value,j,NA_real_))))stopifnot(!is.finite(fixed_endpoint_estimate(bad,y)$estimate))
 stopifnot(fixed_endpoint_estimate(d,y[y!=year])$status=='vaste_vensterjaren_ontbreken')
}
for(year in c(1967L,1977L,1984L,1985L,2000L)) {
 j<-match(year,y)
 for(other in list(d[-j,],rbind(d,d[j,]),transform(d,index_value=replace(index_value,j,-1)),transform(d,index_value=replace(index_value,j,NA_real_)))) {
  v<-fixed_endpoint_estimate(other,y)
  stopifnot(is.finite(v$estimate),abs(v$estimate-fixed_endpoint_estimate(d,y)$estimate)<1e-8,
   identical(v$outside_problem_years,as.character(year)),v$n_outside_problem_years==1L)
 }
}
# Width-specific endpoints: 1963 is irrelevant to width 5, required for width 7.
stopifnot(is.finite(fixed_endpoint_estimate(d[d$jaar!=1963,],y,width=5)$estimate),
 !is.finite(fixed_endpoint_estimate(d[d$jaar!=1963,],y,width=7)$estimate))
stopifnot(fixed_endpoint_estimate(d,y,post_ok=FALSE)$status=='post_model_niet_schatbaar')

s<-endpoint_interval_diagnostic(0,seq(-20,20,length.out=50),50);stopifnot(is.finite(s$diagnostic_low),is.na(s$ci95_low),s$status=='pilot_geen_formeel_interval',s$complete_non_degenerate)
s<-endpoint_interval_diagnostic(0,c(NA,seq(-20,20,length.out=49)),50);stopifnot(is.na(s$diagnostic_low),s$n_valid==49,!s$complete_non_degenerate,s$status=='uitval_geen_band')
s<-endpoint_interval_diagnostic(-100,rep(-100,50),50);stopifnot(is.na(s$diagnostic_low),s$status=='constante_verdeling_geen_band')
stopifnot(endpoint_interval_diagnostic(0,seq(-20,20,length.out=500),500)$status=='validatie_geen_formeel_interval',endpoint_interval_diagnostic(0,seq(-20,20,length.out=2000),2000)$status=='kandidaat_vereist_dekkingsbeoordeling')
large<-endpoint_interval_diagnostic(1e15,seq(1e15,1e15+500,length.out=50),50);stopifnot(large$complete_non_degenerate,is.finite(large$diagnostic_low))
s<-endpoint_interval_diagnostic(NA_real_,seq(-20,20,length.out=50),50);stopifnot(is.na(s$diagnostic_low),s$status=='baseline_niet_schatbaar')
stopifnot(endpoint_interval_stable(c(-1,1),c(-.96,1.04)),!endpoint_interval_stable(c(-1,1),c(-.8,1.2)))
stopifnot(!endpoint_interval_stable(c(-100,-100),c(-100,-100)))
cat('Endpointcontract: vaste jaren, nullen, ontbrekend, uitval, degeneratie, schaal en geen automatische95%-vrijgave: OK\n')
