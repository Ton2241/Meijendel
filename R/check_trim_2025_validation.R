#!/usr/bin/env Rscript
source('R/run_trim_2025_validation.R')
p<-list(species_matrix=data.frame(x=1:3),clusters=data.frame(x=1:2),species_targets=list(a=1),bridge_variants=list(a=2),config=list(run_seed=20260920L,planned_replicates=50L,analysis_end_year=2025L,run_id='old'))
x<-validation_2025_context(p,'new');stopifnot(x$config$planned_replicates==500L,x$config$run_id=='new',x$config$analysis_end_year==2025L)
stopifnot(identical(x[names(x)!='config'],p[names(p)!='config']),identical(x$config$run_seed,p$config$run_seed),p$config$planned_replicates==50L)
cat('500context: alleen planidentiteit verandert; bron/soorten/seed/jaarselectie behouden: OK\n')
