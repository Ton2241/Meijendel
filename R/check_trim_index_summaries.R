#!/usr/bin/env Rscript
source('R/compare_trim_index_summaries.R')
years<-1958:2025;ix<-data.frame(jaar=years,index_value=2*exp(.03*(years-1958)))
f<-index_summary_fit(ix,years);stopifnot(f$ok,abs(f$pct-100*expm1(.03))<1e-7)
e<-index_summary_windows(ix,years,5);stopifnot(e$ok,abs(e$annual_pct-f$pct)<1e-7,e$delta_years==63)
constant<-ix;constant$index_value<-3;stopifnot(abs(index_summary_fit(constant,years)$pct)<1e-7,abs(index_summary_windows(constant,years,5)$net_pct)<1e-7)
scaled<-ix;scaled$index_value<-ix$index_value*100;stopifnot(abs(index_summary_fit(scaled,years)$pct-f$pct)<1e-7)
z<-ix;z$index_value[z$jaar>=2021]<-0;e<-index_summary_windows(z,years,5);stopifnot(e$ok,e$net_pct== -100,is.na(e$annual_pct),e$endpoint_status=='nul_eindgemiddelde',index_summary_fit(z,years)$ok)
z$index_value<-0;stopifnot(!index_summary_fit(z,years)$ok,is.na(index_summary_windows(z,years,5)$net_pct))
z<-ix;z$index_value[z$jaar<=1962]<-0;e<-index_summary_windows(z,years,5);stopifnot(is.na(e$net_pct),e$endpoint_status=='nul_begingemiddelde')
for(bad in list(ix[-1,],rbind(ix,ix[1,]),transform(ix,index_value=replace(index_value,1,NA_real_)),transform(ix,index_value=replace(index_value,1,-1)))){
 stopifnot(!index_summary_fit(bad,years)$ok,!index_summary_windows(bad,years,5)$ok)
}
stopifnot(index_summary_disagrees(3,-3),!index_summary_disagrees(.1,-.1),index_summary_gap(5,6.01),!index_summary_gap(5,6))
cat('Indexsamenvatting: exponentieel/constant, schaalinvariant, nullen, vaste vensters en ontbrekende/dubbele jaren: OK\n')
