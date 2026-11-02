#!/usr/bin/env Rscript
# Afzonderlijke ontwikkelpilot: alle soorten, geen groepsselectie of publicatie.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==3L)
repo <- normalizePath(args[[1L]],mustWork=TRUE)
cache_path <- normalizePath(args[[2L]],mustWork=TRUE)
out <- args[[3L]]
e <- new.env(parent=globalenv())
e$commandArgs <- function(trailingOnly=FALSE) paste0('--file=',repo,'/R/trim_soorten_en_msi_evg.R')
.libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()))
for (f in c('trim_soorten_en_msi_evg.R','trim_trend_contract.R','trim_bootstrap_core.R','trim_bridge_core.R','audit_trim_bridge_windows.R','build_trim_bootstrap_bundle.R')) sys.source(file.path(repo,'R',f),envir=e)
stopifnot(digest::digest(file=cache_path,algo='sha256')=='071e66821f706ae1c0c37b11b3295ddde84a1872b194f9a09f43e595b50252d8')
cache <- readRDS(cache_path)
stopifnot(cache$identity$sql_sha256=='15de9245b0d0fbbd0a65990c6c0d618ff8f0298f712775210fe0b1566a917913')
t <- e$apply_meijendel_plot_scope(cache$data,character())
t$plots$kavel_nummer <- e$normalize_kavel_nummer(t$plots$kavel_nummer)
b <- e$prepare_analysis_basis(t,2025L)
sm <- e$build_species_matrix(t,b,2025L)
cl <- e$build_cluster_definition_from_basis(b,e$derive_bridge_plot_sets)
sm <- e$restrict_species_matrix_to_bootstrap_clusters(sm,cl)
periods <- e$resolve_trim_periods(2025L)
config <- list(run_seed=20261102L,periods=list(pre=periods$pre$years,post=periods$post$years),
 bridge_pre_years=1979:1983,primary_post_years=1986:1990,calibration_method='window_poisson',
 coverage_variants='volledig_netwerk',primary_variant='primary_5yr',
 bridge_variants=list(primary_5yr=list(pre_years=1979:1983,post_years=1986:1990),reference_3yr=list(pre_years=1981:1983,post_years=1986:1988)),
 analysis_end_year=2025L,planned_replicates=50L,run_id='species-pilot-2025-50-20261102',freeze_species_model_years=TRUE)
context <- e$build_bootstrap_context(list(species_matrix=sm),cl,config)
context$group_definitions <- list()
context$species_targets <- list()
draw <- data.frame(source_cluster_id=cl$bootstrap_cluster_id,bootstrap_site_id=cl$bootstrap_cluster_id,draw_position=seq_len(nrow(cl)))
rows <- list()
for (id in sort(unique(sm$soort_id))) {
 sp <- context$species_matrix[context$species_matrix$soort_id==id,]
 fits <- lapply(config$periods,function(years)e$fit_first_working_trim_model(sp[sp$jaar %in% years,]))
 context$species_targets[[as.character(id)]] <- lapply(fits,function(f)list(ok=isTRUE(f$ok),years=f$year_map$jaar,reason=f$reason))
 pre <- e$bootstrap_model_index(fits$pre); post <- e$bootstrap_model_index(fits$post)
 br <- e$compute_bridge_variants(sp,pre,post,draw,context)
 for (i in seq_len(nrow(br))) {
  f <- br$bridge_factor[[i]]
  estimate <- e$combined_pct_trend(pre,post,f,required_years=c(fits$pre$year_map$jaar,fits$post$year_map$jaar))
  rows[[length(rows)+1L]] <- data.frame(soort_id=id,soort_naam=t$soorten$soort_naam[match(id,t$soorten$id)],
   pre_ok=isTRUE(fits$pre$ok),post_ok=isTRUE(fits$post$ok),pre_reason=e$`%||%`(fits$pre$reason,NA_character_),post_reason=e$`%||%`(fits$post$reason,NA_character_),
   pre_model=e$`%||%`(fits$pre$config,NA_character_),post_model=e$`%||%`(fits$post$config,NA_character_),
   pre_model_years=paste(fits$pre$year_map$jaar,collapse=';'),post_model_years=paste(fits$post$year_map$jaar,collapse=';'),
   pre_estimate_pct_per_year=e$combined_pct_trend(pre,numeric(),1,required_years=fits$pre$year_map$jaar),
   post_estimate_pct_per_year=e$combined_pct_trend(post,numeric(),1,required_years=fits$post$year_map$jaar),
   br[i,],estimate_pct_per_year=estimate,stringsAsFactors=FALSE)
 }
 cat('BASELINE',id,'\n')
}
context$config$species_targets_sha256 <- digest::digest(context$species_targets,algo='sha256')
identity <- list(run_id=config$run_id,source_hash=cache$identity$sql_sha256,config_hash=digest::digest(context$config,algo='sha256'),
 code_commit=system2('git',c('-C',repo,'rev-parse','HEAD'),stdout=TRUE)[[1L]],software_id=paste0('R-',getRversion(),'_rtrim-',utils::packageVersion('rtrim')))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(do.call(rbind,rows),file.path(out,'baseline.csv'),row.names=FALSE,na='')
e$write_trim_bootstrap_bundle(context,identity,file.path(out,'input'),metadata=list(analysis_end_year=2025L,planned_replicates=50L,
 publication_status='ontwikkelpilot_geen_formele_intervallen',species_count=length(unique(sm$soort_id)),cluster_count=nrow(cl),
 cache_sha256=digest::digest(file=cache_path,algo='sha256'),engine_sha256=as.list(e$trim_bootstrap_engine_hashes(repo))))
cat('SPECIES_PILOT_BUNDLE_READY\n')
