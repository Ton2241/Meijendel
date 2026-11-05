#!/usr/bin/env Rscript
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3L)
repo<-normalizePath(args[1],mustWork=TRUE);run<-normalizePath(args[2],mustWork=TRUE);out<-args[3]
source(path.expand('~/Documents/GitHub/Meijendel/R/trial_storage.R'));out<-trial_output(out)
source(file.path(repo,'R/trim_bootstrap_core.R'))
cx<-readRDS(file.path(run,'input/context.rds'))
e<-read.csv(file.path(run,'assessment/raw_assessment/estimates.csv'))
bad<-e[e$width==5&e$replicate_id>0&e$status=='index_onvolledig_of_ongeldig',]
rows<-list()
for(i in seq_len(nrow(bad))){
 id<-bad$soort_id[i];n<-bad$replicate_id[i];from<-5L*((n-1L)%/%5L)+1L
 r<-readRDS(file.path(run,'batches',sprintf('batch-%06d-%06d.rds',from,from+4L)))$results[[as.character(n)]]
 t<-cx$species_targets[[as.character(id)]];ix<-r$indices[r$indices$soort_id==id&r$indices$bridge_variant=='primary_5yr',]
 missing<-setdiff(c(t$pre$years,t$post$years),ix$jaar)
 d<-apply_cluster_draw(cx$species_matrix[cx$species_matrix$soort_id==id,],r$draw)
 for(y in missing){
  ys<-if(y<1984)t$pre$years else t$post$years
  z<-d[d$jaar%in%ys&d$geteld%in%TRUE&is.finite(d$count_adjusted),]
  totals<-aggregate(count_adjusted~plot_id,z,sum);active<-totals$plot_id[totals$count_adjusted>0]
  rows[[length(rows)+1L]]<-data.frame(soort_id=id,replicate_id=n,missing_index_year=y,
   counted_source_cells=sum(z$jaar==y),positive_source_cells=sum(z$jaar==y&z$count_adjusted>0),
   retained_cells_after_zero_site_filter=sum(z$jaar==y&z$plot_id%in%active),
   inside_endpoint_windows=y%in%c(1958:1962,2021:2025),inside_bridge_windows=y%in%c(1979:1983,1986:1990))
 }
}
audit<-do.call(rbind,rows)
stopifnot(nrow(bad)==9L,nrow(audit)==12L,setequal(unique(audit$missing_index_year),c(1984,1985)),all(audit$counted_source_cells>0),all(audit$positive_source_cells==0),all(audit$retained_cells_after_zero_site_filter==0))
write.csv(audit,out,row.names=FALSE)
cat('INDEX_GAP_AUDIT:9soort-trekkinggevallen met12indexjaren(1984/1985); getelde nullen aanwezig, na nulkavelfilter geen modelcellen; buiten doel- en brugvensters\n')
