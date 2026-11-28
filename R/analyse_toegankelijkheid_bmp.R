#!/usr/bin/env Rscript
# Alleen-lezen analyse van de kaartstand 2026 en de canonieke BMP-reeks.
# Uitvoer en pakketinstallaties uitsluitend in de geregistreerde T7-taakmap.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L)
repo <- normalizePath(getwd())
source(file.path(repo,"R/trial_storage.R"))
root <- trial_output(args[1])
out <- file.path(root,"outputs")
.libPaths(c(file.path(root,"runtime/R-library"),.libPaths()))
suppressPackageStartupMessages({library(data.table);library(sf);library(fixest)})
setFixest_nthreads(1)
source(file.path(repo,"R/trim_soorten_en_msi_evg.R"),local=TRUE)
queries <- list()
read_sql <- function(label, sql) {
  queries[[label]] <<- sql
  path <- file.path(out,paste0("bron_",label,".tsv"))
  err <- file.path(root,"tmp/mysql-error.txt")
  code <- system2("/usr/local/mysql/bin/mysql",c("--login-path=meijendel_root","--batch","--database=Meijendel","-e",shQuote(sql)),stdout=path,stderr=err)
  if(code!=0L) stop(paste(readLines(err),collapse="\n"))
  as.data.frame(fread(path,na.strings=c("NULL","\\N")))
}
tables <- c("plots","plot_analyse_scope","soorten","plot_jaar_oppervlak","plot_jaar_teller","territoria","bronnen","sovon_bmp_plotjaar")
tbls <- setNames(lapply(tables,function(n) read_sql(n,paste0("SELECT ",if(n=="plots") "plot_id,plot_naam,kavel_nummer,geom_sha256,ST_AsText(geom) AS geom_wkt" else "*"," FROM `",n,"`;"))),tables)
tbls <- apply_meijendel_plot_scope(tbls,character())
tbls$plots$kavel_nummer <- normalize_kavel_nummer(tbls$plots$kavel_nummer)
stopifnot(!anyDuplicated(tbls$territoria[c("plot_id","soort_id","jaar")]))
basis <- prepare_analysis_basis(tbls,2025L)
matrix <- as.data.table(build_species_matrix(tbls,basis,2025L))
matrix <- matrix[jaar>=1984 & jaar<=2025]
stopifnot(!anyDuplicated(matrix[,.(soort_id,plot_id,jaar)]))
fwrite(matrix[,.(soort_id,soort_naam,plot_id,kavel_nummer,jaar,geteld,count_raw,observatie_status,bewijsgrond,oppervlakte_km2)],file.path(out,"vogelmatrix.csv.gz"))
fwrite(matrix[,.(n=.N),by=.(jaar,observatie_status)],file.path(out,"vogelmatrix_status.csv"))

areas <- read_sql("gebieden","SELECT g.gebied_code,v.gebied_versie_id,v.status_code,v.geldig_vanaf,v.vastgesteld_op,v.bron_id,v.geometrie_sha256,ST_AsText(v.geometrie) AS wkt FROM v_toegankelijkheidsgebied_actueel v JOIN toegankelijkheidsgebied g USING(gebied_id) ORDER BY gebied_code;")
cross <- read_sql("doorsnijdingen","SELECT a.* FROM toegankelijkheidsgebied_plot_afleiding a JOIN v_toegankelijkheidsgebied_actueel v USING(gebied_versie_id) ORDER BY a.plot_id,a.gebied_versie_id;")
plots <- st_as_sf(tbls$plots[!is.na(tbls$plots$geom_wkt),c("plot_id","kavel_nummer","geom_wkt","geom_sha256")],wkt="geom_wkt",crs=28992)
areas_sf <- st_as_sf(areas,wkt="wkt",crs=28992)
stopifnot(all(st_is_valid(plots)),all(st_is_valid(areas_sf)))
shares <- as.data.table(cross)[plot_id %in% plots$plot_id,.(m2=sum(doorsnijding_m2)),by=.(plot_id,status_code)]
shares <- dcast(shares,plot_id~status_code,value.var="m2",fill=0)
status <- c("toegankelijk","afgesloten","toegankelijk_buiten_broedseizoen","toegankelijk_met_toegangskaart")
for(n in status) if(!n %in% names(shares)) shares[,(n):=0]
geo_area <- data.table(plot_id=plots$plot_id,geom_m2=as.numeric(st_area(plots)))
shares <- merge(shares,geo_area,by="plot_id")
shares[,coverage:=rowSums(.SD)/geom_m2,.SDcols=status]
stopifnot(max(abs(shares$coverage-1))<1e-5)
for(n in status) shares[,(paste0(n,"_aandeel")):=get(n)/geom_m2]
shares[,`:=`(afgesloten_10pp=afgesloten/geom_m2/0.1,seizoen_10pp=toegankelijk_buiten_broedseizoen/geom_m2/0.1,dagkaart_10pp=toegankelijk_met_toegangskaart/geom_m2/0.1)]

# Gebruik de goedgekeurde oorspronkelijke hartlijn, met byte-identieke broncontrole.
lines <- read_sql("fietslijnen","SELECT segment_versie_id,naam,lengte_m,geometrie_sha256,ST_AsText(geometrie) AS wkt FROM v_infrastructuursegment_actueel WHERE infrastructuurtype='fietspad';")
lines_sf <- st_as_sf(lines,wkt="wkt",crs=28992)
corridor <- areas_sf[grepl("fietspad_scheveningen",areas_sf$gebied_code),]
stopifnot(nrow(corridor)==1L)
center_path <- "/Volumes/T7 Data/Home_Ton/Proefomgevingen/fietspad-scheveningen-wassenaarse-slag-2026-11-10/outputs/fietspad-toegankelijkheidsproef.gpkg"
stopifnot(digest::digest(file=center_path,algo="sha256")=="0b59cc88a80de095f9d2473e688c4f823704b8d3454605cecef5bb12d700a79b")
center <- st_read(center_path,layer="fietspad_hartlijn",quiet=TRUE)
line_union <- st_union(center)
center_length <- sum(as.numeric(st_length(center)))
unique_center_length <- as.numeric(st_length(line_union))
if(abs(center_length-9487.702)>0.01) stop("Hartlijn wijkt af van geregistreerde 9.487,702 m")
for(b in c(50,100,200)) {
  intersect <- suppressWarnings(st_intersection(plots,st_buffer(line_union,b)))
  measure <- data.table(plot_id=intersect$plot_id,m2=as.numeric(st_area(intersect)))[,.(m2=sum(m2)),by=plot_id]
  measure <- merge(geo_area,measure,by="plot_id",all.x=TRUE);measure[is.na(m2),m2:=0]
  shares <- merge(shares,measure[,.(plot_id,exposure=m2/geom_m2/0.1)],by="plot_id")
  setnames(shares,"exposure",paste0("buffer",b,"_10pp"))
}
xy <- st_coordinates(st_centroid(st_geometry(plots)))
geo <- data.table(plot_id=plots$plot_id,kavel=plots$kavel_nummer,x=xy[,1],y=xy[,2])
geo[,blok:=paste0("zuid_noord_",pmin(4L,ceiling(frank(y,ties.method="first")/.N*4)))]
shares <- merge(shares,geo,by="plot_id")
fwrite(shares,file.path(out,"kavelcontrasten.csv"))
st_write(plots,file.path(out,"kavelcontrasten.gpkg"),layer="kavels",quiet=TRUE,delete_dsn=TRUE)
st_write(areas_sf,file.path(out,"kavelcontrasten.gpkg"),layer="statusgebieden",quiet=TRUE)
st_write(center,file.path(out,"kavelcontrasten.gpkg"),layer="gereconstrueerde_hartlijn",quiet=TRUE)

land <- as.data.table(read_sql("landgebruik","SELECT * FROM plot_jaar_landgebruik WHERE jaar BETWEEN 2010 AND 2022;"))
land[,m2:=ifelse(klasse=="Bos",area_m2,0)]
forest <- land[,.(forest=sum(m2)/sum(area_m2)),by=.(plot_id,jaar)]
hab <- forest[jaar==2010,.(plot_id,bos2010_10pp=forest/0.1)]
water <- land[jaar==2010,.(water2010_10pp=sum(area_m2[grepl("water",klasse,ignore.case=TRUE)])/sum(area_m2)/0.1),by=plot_id]
hab <- merge(hab,water,by="plot_id")
fwrite(forest,file.path(out,"bosmetingen.csv"))
visits <- as.data.table(read_sql("bezoeken","SELECT plot_id,jaar,COUNT(*) AS bezoeken,SUM(deelbezoek=1) AS deelbezoeken,MIN(dagvanjaar) AS eerste_dag,MAX(dagvanjaar) AS laatste_dag,SUM(bezoekduur_min) AS duur_min,COUNT(bezoekduur_min) AS duur_bekend FROM dagbezoeken_bmp WHERE jaar BETWEEN 1984 AND 2025 GROUP BY plot_id,jaar;"))
tellers <- as.data.table(tbls$plot_jaar_teller)[jaar>=1984&jaar<=2025,.(teller_sleutel=paste(sort(unique(teller_id)),collapse=";")),by=.(plot_id,jaar)]
setorder(tellers,plot_id,jaar)
tellers[,tellerwisseling:=ifelse(jaar-shift(jaar)==1L,as.integer(teller_sleutel!=shift(teller_sleutel)),NA_integer_),by=plot_id]
fwrite(tellers,file.path(out,"tellerwisselingen.csv"))
manage <- as.data.table(read_sql("beheer","SELECT plot_id,jaar,COUNT(DISTINCT uitvoering_id) AS registraties FROM v_plot_jaar_maatregel_bronvast WHERE jaar BETWEEN 1984 AND 2025 GROUP BY plot_id,jaar;"))
fwrite(visits,file.path(out,"bezoekdekking.csv"))
dat <- merge(matrix,shares,by="plot_id")
dat <- merge(dat,hab,by="plot_id",all.x=TRUE)
dat <- merge(dat,visits,by=c("plot_id","jaar"),all.x=TRUE)
dat <- merge(dat,manage,by=c("plot_id","jaar"),all.x=TRUE)
dat <- merge(dat,tellers,by=c("plot_id","jaar"),all.x=TRUE)
dat[,`:=`(tijd_decennium=(jaar-2009)/10,beheer_geregistreerd=as.integer(!is.na(registraties)),logbezoeken=log(pmax(bezoeken,1)))]
dat[,`:=`(eerste_dag_10=eerste_dag/10,laatste_dag_10=laatste_dag/10,deelfractie=deelbezoeken/bezoeken)]
# Ontbrekende beheerregistratie is alleen 'geen geregistreerde uitvoering', geen
# bewijs dat geen beheer plaatsvond. Niet-getelde soortregels blijven NA.
dat[,bos_interpolatie:=NA_real_]
for(p in unique(dat$plot_id)) {
  h <- forest[plot_id==p][order(jaar)]
  if(nrow(h)>=2) dat[plot_id==p,bos_interpolatie:=approx(h$jaar,h$forest,xout=jaar,rule=1)$y]
}
fwrite(dat[,.(n=.N,bruikbaar=sum(geteld),positief=sum(count_raw>0,na.rm=TRUE)),by=.(soort_id,soort_naam)],file.path(out,"soortdekking.csv"))

effect_cols <- c("afgesloten_10pp","seizoen_10pp","dagkaart_10pp")
fit_rows <- list();model_rows <- list();counter<-0L
fit_one <- function(d,species,period,variant,exposure=effect_cols,controls=character()) {
  counter <<- counter+1L
  terms <- paste0("tijd_decennium:",exposure)
  formula <- as.formula(paste("count_raw ~",paste(c(terms,controls),collapse=" + "),"| plot_id + jaar"))
  needed <- unique(c("count_raw","plot_id","jaar","tijd_decennium",exposure,
    if(any(grepl("bos2010",controls))) "bos2010_10pp",
    if(any(grepl("water2010",controls))) "water2010_10pp",
    if("bos_interpolatie" %in% controls) "bos_interpolatie",
    intersect(controls,c("logbezoeken","eerste_dag_10","laatste_dag_10","deelfractie","tellerwisseling"))))
  z <- d[geteld & complete.cases(d[,..needed])]
  status <- "ok";error <- NA_character_;fit<-NULL
  model_warnings <- character()
  capture_warning <- function(w) {
    model_warnings <<- c(model_warnings,conditionMessage(w))
    invokeRestart("muffleWarning")
  }
  if(nrow(z)<20 || uniqueN(z$plot_id)<5 || sum(z$count_raw)<=0) {status<-"onvoldoende";error<-"minder dan 20 rijen, vijf kavels of uitsluitend nullen"} else {
    fit <- tryCatch(withCallingHandlers(suppressMessages(fepois(formula,data=z,vcov=~plot_id,notes=FALSE,warn=FALSE)),warning=capture_warning),error=function(e)e)
    if(inherits(fit,"error")){status<-"niet_schatbaar";error<-conditionMessage(fit);fit<-NULL}
  }
  used <- if(is.null(fit)) z[0] else z[obs(fit)]
  if(!is.null(fit)&&!isTRUE(fit$convStatus)) status <- "niet_geconvergeerd"
  model_rows[[counter]] <<- data.frame(soort_id=species,periode=period,variant=variant,status=status,fout=error,n_invoer=nrow(z),n_model=nrow(used),kavels=uniqueN(used$plot_id),jaren=uniqueN(used$jaar),kavels_uitgevallen=paste(setdiff(unique(z$plot_id),unique(used$plot_id)),collapse=";"),collineair=if(is.null(fit)) NA_character_ else paste(fit$collin.var,collapse=";"),convergentie=if(is.null(fit)) NA else isTRUE(fit$convStatus))
  if(!is.null(fit)) {
    ct <- withCallingHandlers(coeftable(fit),warning=capture_warning)
    ci <- withCallingHandlers(confint(fit),warning=capture_warning)
    r <- data.frame(soort_id=species,periode=period,variant=variant,term=rownames(ct),beta=ct[,1],se=ct[,2],p=ct[,4],rr=exp(ct[,1]),laag=exp(ci[,1]),hoog=exp(ci[,2]),n=nrow(used),kavels=uniqueN(used$plot_id))
    r$convergentie <- isTRUE(fit$convStatus)
    r$kavels_minstens_10pct <- vapply(r$term,function(term) {
      e <- sub("^tijd_decennium:","",term)
      if(!e %in% exposure) return(NA_integer_)
      uniqueN(used[get(e)>=1]$plot_id)
    },integer(1))
    r$blootgestelde_blokken <- vapply(r$term,function(term) {
      e <- sub("^tijd_decennium:","",term)
      if(!e %in% exposure) return(NA_integer_)
      uniqueN(used[get(e)>=1]$blok)
    },integer(1))
    r$waarschuwingen <- paste(unique(model_warnings),collapse=" | ")
    r$inferentie_bruikbaar <- r$convergentie&!nzchar(r$waarschuwingen)&r$kavels>=10L&is.finite(r$laag)&is.finite(r$hoog)&is.finite(r$p)&!is.na(r$kavels_minstens_10pct)&r$kavels_minstens_10pct>=5L&r$blootgestelde_blokken>=2L
    fit_rows[[length(fit_rows)+1L]] <<- r
  }
  model_rows[[counter]]$waarschuwingen <<- paste(unique(model_warnings),collapse=" | ")
  if(length(model_warnings)&&identical(model_rows[[counter]]$status,"ok")) model_rows[[counter]]$status <<- "numerieke_waarschuwing"
}
for(sid in sort(unique(dat$soort_id))) {
  d0 <- dat[soort_id==sid]
  stopifnot(nrow(d0)>0L,all(d0$soort_id==sid))
  for(start in c(1984L,2009L)) {
    period <- paste0(start,"-2025");d <- d0[jaar>=start]
    fit_one(d,sid,period,"basis")
    # Habitatvergelijking gebruikt voor basis en uitbreiding exact dezelfde rijen.
    h <- d[complete.cases(bos2010_10pp,water2010_10pp)]
    fit_one(h,sid,period,"habitat_zelfde_steekproef_basis")
    fit_one(h,sid,period,"habitat",controls=c("tijd_decennium:bos2010_10pp","tijd_decennium:water2010_10pp"))
    # Gemeenschappelijk habitatbereik van overwegend vrij en overwegend afgesloten.
    free <- unique(h[toegankelijk_aandeel>=0.5,.(plot_id,bos2010_10pp,water2010_10pp)])
    closed <- unique(h[afgesloten_aandeel>=0.5,.(plot_id,bos2010_10pp,water2010_10pp)])
    if(nrow(free)&&nrow(closed)) {
      lo<-pmax(vapply(free[,-1],min,numeric(1)),vapply(closed[,-1],min,numeric(1)))
      hi<-pmin(vapply(free[,-1],max,numeric(1)),vapply(closed[,-1],max,numeric(1)))
      overlap <- h[bos2010_10pp>=lo[1]&bos2010_10pp<=hi[1]&water2010_10pp>=lo[2]&water2010_10pp<=hi[2]]
      fit_one(overlap,sid,period,"habitat_overlap",controls=c("tijd_decennium:bos2010_10pp","tijd_decennium:water2010_10pp"))
    }
    for(b in c(50,100,200)) fit_one(d,sid,period,paste0("corridor_",b),paste0("buffer",b,"_10pp"))
    for(block in sort(unique(shares$blok))) fit_one(d[blok!=block],sid,period,paste0("weglaat_",block))
    e <- d[!is.na(bezoeken)&bezoeken>0]
    fit_one(e,sid,period,"inspanning_zelfde_steekproef_basis")
    fit_one(e,sid,period,"inspanning_beheer",controls=c("logbezoeken","beheer_geregistreerd"))
    t <- e[complete.cases(eerste_dag_10,laatste_dag_10,deelfractie,tellerwisseling)]
    fit_one(t,sid,period,"timing_teller_zelfde_steekproef_basis")
    fit_one(t,sid,period,"timing_teller",controls=c("logbezoeken","eerste_dag_10","laatste_dag_10","deelfractie","tellerwisseling","beheer_geregistreerd"))
  }
  h <- d0[jaar>=2010&jaar<=2022&!is.na(bos_interpolatie)]
  fit_one(h,sid,"2010-2022","habitatontwikkeling_zelfde_steekproef_basis")
  fit_one(h,sid,"2010-2022","habitatontwikkeling",controls="bos_interpolatie")
  if(sid %% 10==0) {cat("SOORT",sid,"MODELLEN",counter,"\n");flush.console()}
}
fwrite(rbindlist(model_rows,fill=TRUE),file.path(out,"modelstatus.csv"))
results <- rbindlist(fit_rows,fill=TRUE)
if(!nrow(results)) stop("Geen schatbare modellen; zie modelstatus.csv")
results <- merge(results,unique(dat[,.(soort_id,soort_naam)]),by="soort_id",all.x=TRUE)
results[,q_bh:=NA_real_]
results[inferentie_bruikbaar==TRUE,q_bh:=p.adjust(p,"BH"),by=.(periode,variant)]
results[,buiten_beslisgrens:=laag>1.10|hoog<1/1.10]
fwrite(results,file.path(out,"effecten.csv"));fwrite(rbindlist(model_rows,fill=TRUE),file.path(out,"modelstatus.csv"))
fwrite(results[variant=="basis",.(soorten=uniqueN(soort_id),termen=.N,bruikbaar=sum(inferentie_bruikbaar),interval_boven_een=sum(laag>1&inferentie_bruikbaar,na.rm=TRUE),interval_onder_een=sum(hoog<1&inferentie_bruikbaar,na.rm=TRUE),bh_005=sum(q_bh<0.05,na.rm=TRUE)),by=.(periode,term)],file.path(out,"samenvatting.csv"))

png(file.path(out,"kavelcontrasten.png"),width=1800,height=1800,res=180,type="quartz")
par(mfrow=c(2,2),mar=c(1,1,3,1))
map <- merge(plots,as.data.frame(shares),by="plot_id")
pal<-hcl.colors(10,"YlOrRd",rev=FALSE)
for(n in c("toegankelijk_aandeel","afgesloten_aandeel","toegankelijk_met_toegangskaart_aandeel","buffer100_10pp")) {
  value<-map[[n]];if(n=="buffer100_10pp")value<-value/10
  plot(st_geometry(map),col=pal[pmin(10,pmax(1,ceiling(value*10)))],border="grey40",main=switch(n,toegankelijk_aandeel="Vrij toegankelijk",afgesloten_aandeel="Afgesloten",toegankelijk_met_toegangskaart_aandeel="Dagkaart",buffer100_10pp="Binnen 100 m van corridor"))
  pts<-st_coordinates(st_point_on_surface(st_geometry(map)));text(pts[,1],pts[,2],map$kavel_nummer,cex=.45)
  legend("bottomleft",legend=c("0–10%","40–50%","90–100%"),fill=pal[c(1,5,10)],cex=.65,bty="n")
}
dev.off()
saveRDS(list(matrix=matrix,shares=shares,dat=dat,results=results,modelstatus=rbindlist(model_rows)),file.path(out,"analyse.rds"),compress=TRUE)
jsonlite::write_json(list(stand="2026-11-28",eindjaar=2025,scope="meijendel_natura2000",kaart_gebieden=nrow(areas),kavels=nrow(plots),vogelkavels=uniqueN(dat[geteld&count_raw>0]$plot_id),soorten=uniqueN(dat$soort_id),modelpogingen=counter,hartlijn_m=center_length,unieke_hartlijn_m=unique_center_length,beslisgrens=list(rr=1.10,betekenis="vooraf gekozen praktische gevoeligheidsgrens; geen gevalideerde ecologische norm"),sql=queries,R=R.version.string,fixest=as.character(packageVersion("fixest"))),file.path(out,"manifest.json"),pretty=TRUE,auto_unbox=TRUE)
cat("VOLTOOID",counter,"modelpogingen\n")
