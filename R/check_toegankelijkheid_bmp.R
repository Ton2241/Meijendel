#!/usr/bin/env Rscript
# Onafhankelijke controles op de uitgevoerde modellen en bronproducten.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1L)
root<-args[1];out<-file.path(root,"outputs")
.libPaths(c(file.path(root,"runtime/R-library"),.libPaths()))
library(data.table)
x<-readRDS(file.path(out,"analyse.rds"));d<-x$dat;e<-as.data.table(x$results);m<-as.data.table(x$modelstatus)
m[status=="ok"&nzchar(waarschuwingen),status:="numerieke_waarschuwing"]
fwrite(m,file.path(out,"modelstatus.csv"))
x$modelstatus<-m
saveRDS(x,file.path(out,"analyse.rds"),compress=TRUE)
stopifnot(!anyDuplicated(d[,.(soort_id,plot_id,jaar)]),all(d$jaar>=1984&d$jaar<=2025),
 !any(c(3503L,3514L)%in%d$plot_id),uniqueN(d$soort_id)==156L,
 max(abs(x$shares$coverage-1))<1e-5,all(d[geteld==TRUE]$count_raw>=0),
 all(is.na(d[geteld==FALSE]$count_raw)))
# Een gehele geldige soort-kavel-jaarcombinatie wordt eenmaal gebruikt.
stopifnot(nrow(d[geteld==TRUE])==134097L)
bad<-e[inferentie_bruikbaar==TRUE & (!convergentie|kavels<10L|kavels_minstens_10pct<5L|blootgestelde_blokken<2L)]
stopifnot(nrow(bad)==0L)

# Onafhankelijke schatter: gewone Poisson-GLM met expliciete dummy's voor Merel.
z<-d[soort_naam=="Merel"&geteld==TRUE]
g<-glm(count_raw~tijd_decennium:afgesloten_10pp+tijd_decennium:seizoen_10pp+
 tijd_decennium:dagkaart_10pp+factor(plot_id)+factor(jaar),data=z,family=poisson(),
 control=glm.control(maxit=100))
a<-e[soort_naam=="Merel"&periode=="1984-2025"&variant=="basis"]
diff<-max(abs(a$beta-unname(coef(g)[a$term])))
stopifnot(isTRUE(g$converged),diff<1e-6)

# Basis en gecorrigeerd model moeten exact dezelfde invoerrijen ontvangen.
for(pair in list(c("habitat_zelfde_steekproef_basis","habitat"),
 c("inspanning_zelfde_steekproef_basis","inspanning_beheer"),
 c("timing_teller_zelfde_steekproef_basis","timing_teller"),
 c("habitatontwikkeling_zelfde_steekproef_basis","habitatontwikkeling"))) {
 a<-m[variant==pair[1],.(soort_id,periode,n_invoer)]
 b<-m[variant==pair[2],.(soort_id,periode,n_invoer)]
 z<-merge(a,b,by=c("soort_id","periode"));stopifnot(all(z$n_invoer.x==z$n_invoer.y))
}

grid<-CJ(soort_id=sort(unique(d$soort_id)),periode=c("1984-2025","2009-2025"),
 term=c("tijd_decennium:afgesloten_10pp","tijd_decennium:seizoen_10pp","tijd_decennium:dagkaart_10pp"))
base<-merge(grid,e[variant=="basis"],by=c("soort_id","periode","term"),all.x=TRUE)
base<-merge(base,unique(d[,.(soort_id,naam=soort_naam)]),by="soort_id",all.x=TRUE)
base[,uitkomst:=ifelse(is.na(beta),"niet_schatbaar_of_term_vervallen",ifelse(!inferentie_bruikbaar,
 "onvoldoende_model_of_ruimtelijke_steun",ifelse(laag>1,"positief_interval",ifelse(hoog<1,"negatief_interval","interval_omvat_een"))))]
base[,klasse_beslisgrens:=ifelse(is.na(laag)|!inferentie_bruikbaar,"niet_beoordeelbaar",
 ifelse(laag>1.1,"boven_110",ifelse(hoog<1/1.1,"onder_091","grens_niet_onderscheiden")))]
comparisons<-list()
for(v in c("habitat","habitat_overlap","inspanning_beheer","timing_teller")) {
 a<-e[variant==v,.(soort_id,periode,term,beta_variant=beta,bruikbaar_variant=inferentie_bruikbaar,
  laag_variant=laag,hoog_variant=hoog)]
 z<-merge(base,a,by=c("soort_id","periode","term"),all.x=TRUE)
 z[,variant_toets:=v]
 z[,vergelijkbaar:=inferentie_bruikbaar==TRUE&bruikbaar_variant==TRUE]
 z[,tekenwisseling:=ifelse(vergelijkbaar,sign(beta)!=sign(beta_variant),NA)]
 comparisons[[v]]<-z
}
paired<-rbindlist(comparisons,fill=TRUE)
fwrite(paired,file.path(out,"gevoeligheid_per_soort.csv"))
fwrite(paired[,.(soorten=uniqueN(soort_id),vergelijkbaar=sum(vergelijkbaar,na.rm=TRUE),
 tekenwisselingen=sum(tekenwisseling,na.rm=TRUE)),by=.(periode,term,variant_toets)],file.path(out,"gevoeligheid_samenvatting.csv"))
fwrite(base,file.path(out,"alle_soorten_hoofdresultaten.csv"))
fwrite(base[,.N,by=.(periode,term,uitkomst)],file.path(out,"uitkomsten_volledig.csv"))
leave<-e[grepl("^weglaat_",variant),.(min_beta=min(beta),max_beta=max(beta),
 blokproeven=.N,bruikbare_blokproeven=sum(inferentie_bruikbaar),teken_stabiel=min(beta)>0|max(beta)<0),by=.(soort_id,periode,term)]
fwrite(leave,file.path(out,"geografische_weglaatproeven.csv"))
corr<-e[grepl("^corridor_",variant),.(buffers=.N,bruikbare_buffers=sum(inferentie_bruikbaar),
 min_beta=min(beta),max_beta=max(beta),teken_stabiel=min(beta)>0|max(beta)<0),by=.(soort_id,periode)]
fwrite(corr,file.path(out,"corridor_gevoeligheid.csv"))
area<-unique(d[,.(plot_id,kavel_nummer,jaar,oppervlakte_km2)])[,.(minimum=min(oppervlakte_km2),maximum=max(oppervlakte_km2)),by=.(plot_id,kavel_nummer)]
fwrite(area,file.path(out,"oppervlaktecontrole.csv"))
stopifnot(all(area$maximum/area$minimum<=1.01))
checks<-list(status="geslaagd",canonieke_geldige_waarden=134097,scope_kavels=uniqueN(d$plot_id),
 vogelkavels=uniqueN(d[geteld==TRUE]$plot_id),soorten=uniqueN(d$soort_id),
 glm_merel_maximaal_betaverschil=diff,gelijke_invoer_bij_covariaattoetsen=TRUE,
 oppervlakte_geen_wijziging_boven_1pct=TRUE,scenario_toets="maximale terugprojectie en kaartstand geven voor 1984-2025 exact dezelfde vaste covariaten; gebeurteniseffect niet identificeerbaar")
jsonlite::write_json(checks,file.path(out,"controlebewijs.json"),pretty=TRUE,auto_unbox=TRUE)

# Kaart met alle vier statusaandelen en de afzonderlijke nabijheidsmaat.
library(sf)
map<-st_read(file.path(out,"kavelcontrasten.gpkg"),layer="kavels",quiet=TRUE)
map<-merge(map,as.data.frame(x$shares),by="plot_id")
png(file.path(out,"kavelcontrasten.png"),width=2400,height=1800,res=180,type="quartz")
par(mfrow=c(2,3),mar=c(1,1,3,1),oma=c(0,0,2,0))
pal<-colorRampPalette(c("#f7fbff","#2171b5"))(10)
fields<-c("toegankelijk_aandeel","afgesloten_aandeel","toegankelijk_buiten_broedseizoen_aandeel","toegankelijk_met_toegangskaart_aandeel","buffer100_10pp")
titles<-c("Vrij toegankelijk","Afgesloten","Buiten broedseizoen toegankelijk","Toegang met dagkaart","Binnen 100 m van corridor")
for(i in seq_along(fields)) {
 value<-map[[fields[i]]];if(fields[i]=="buffer100_10pp")value<-value/10
 plot(st_geometry(map),col=pal[pmin(10,pmax(1,ceiling(value*10)))],border="grey40",main=titles[i],cex.main=.95)
 pts<-st_coordinates(st_point_on_surface(st_geometry(map)))
 text(pts[,1],pts[,2],map$kavel_nummer,cex=.48,col=ifelse(value>.65,"white","black"))
}
plot.new();legend("center",legend=paste0(seq(0,90,10),"–",seq(10,100,10),"% van kavel"),fill=pal,bty="n",cex=.9)
mtext("Kaartstand november 2026 · 53 kavels binnen de analysescope",outer=TRUE,cex=1.05,font=2)
dev.off()
print(checks)
