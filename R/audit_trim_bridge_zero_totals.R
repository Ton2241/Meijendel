#!/usr/bin/env Rscript
# Reproduceerbare vergelijking; leest uitsluitend de historische broncache.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
repo <- normalizePath(args[[1L]], mustWork = TRUE)
cache_path <- normalizePath(args[[2L]], mustWork = TRUE)
out <- args[[3L]]
e <- new.env(parent = globalenv())
e$commandArgs <- function(trailingOnly = FALSE) paste0("--file=", repo, "/R/trim_soorten_en_msi_evg.R")
for (f in c("trim_soorten_en_msi_evg.R", "trim_bootstrap_core.R", "trim_bridge_core.R", "audit_trim_bridge_windows.R", "build_trim_bootstrap_bundle.R")) sys.source(file.path(repo, "R", f), envir = e)
stopifnot(digest::digest(file = cache_path, algo = "sha256") == "071e66821f706ae1c0c37b11b3295ddde84a1872b194f9a09f43e595b50252d8")
cache <- readRDS(cache_path)
stopifnot(cache$identity$sql_sha256 == "15de9245b0d0fbbd0a65990c6c0d618ff8f0298f712775210fe0b1566a917913")
tbls <- e$apply_meijendel_plot_scope(cache$data, character())
tbls$plots$kavel_nummer <- e$normalize_kavel_nummer(tbls$plots$kavel_nummer)
periods <- e$resolve_trim_periods(2025L)
basis <- e$prepare_analysis_basis(tbls, 2025L)
sm <- e$build_species_matrix(tbls, basis, 2025L)
clusters <- e$build_cluster_definition_from_basis(basis, e$derive_bridge_plot_sets)
status <- read.csv(file.path(repo, "trim/soorten/soorten_modelstatus.csv"))
indices <- read.csv(file.path(repo, "trim/soorten/soortindices_per_jaar.csv"))
old_ids <- e$select_fixed_robust_species(list(status=status, indices=indices), 1958:2025)
context <- e$build_bootstrap_context(list(species_matrix=e$restrict_species_matrix_to_bootstrap_clusters(sm,clusters)),clusters,
 list(run_seed=20260920L,periods=list(pre=periods$pre$years,post=periods$post$years),bridge_pre_years=1981:1983,primary_post_years=1986:1988,calibration_method="yearly_trim"))
context$species_matrix <- context$species_matrix[context$species_matrix$soort_id %in% old_ids, ]
selection <- e$select_formal_primary_species(context, 1958:2025)
fixed_ids <- Reduce(intersect,list(old_ids,selection$formal_species_ids,selection$complete_species_ids))
expected_ids <- c(1L,29L,36L,44L,77L,78L,80L,88L,97L,106L,107L,123L,125L,150L,155L,156L,162L,164L,165L,167L,170L,172L,173L,175L,182L,192L,193L,198L,200L,214L,223L,239L,251L)
stopifnot(length(old_ids)==35L,identical(sort(as.integer(fixed_ids)),expected_ids))
context$fixed_robust_species_ids <- fixed_ids
context$group_definitions <- e$build_bootstrap_group_definitions(e$build_group_mapping(tbls),e$build_functional_group_mapping(tbls),fixed_ids)
identity_draw <- data.frame(source_cluster_id=clusters$bootstrap_cluster_id, bootstrap_site_id=clusters$bootstrap_cluster_id, draw_position=seq_len(nrow(clusters)))
point_rows <- list(); index_rows <- list(); fit_cache <- list()
for (id in old_ids) {
 sp <- context$species_matrix[context$species_matrix$soort_id==id, ]
 pre <- e$bootstrap_model_index(e$fit_first_working_trim_model(sp[sp$jaar %in% periods$pre$years, ]))
 post <- e$bootstrap_model_index(e$fit_first_working_trim_model(sp[sp$jaar %in% periods$post$years, ]))
 fit_cache[[as.character(id)]] <- list(pre=pre,post=post)
 for (method in c("yearly_trim","window_poisson")) {
  cfg <- context; cfg$config$calibration_method <- method
  br <- e$compute_bridge_variants(sp,pre,post,identity_draw,cfg)
  br$soort_id <- id; br$calibration_method <- method
  br$estimate_pct_per_year <- vapply(br$bridge_factor,function(f)e$combined_pct_trend(pre,post,f),numeric(1))
  point_rows[[length(point_rows)+1L]] <- br
  if(id %in% fixed_ids) for(j in seq_len(nrow(br))) {
   ser <- c(pre,post*br$bridge_factor[[j]])
   index_rows[[length(index_rows)+1L]] <- data.frame(soort_id=id,jaar=as.integer(names(ser)),index_value=as.numeric(ser),bridge_variant=br$bridge_variant[[j]],coverage_variant="volledig_netwerk",calibration_method=method)
  }
 }
}
points <- do.call(rbind,point_rows)
points <- merge(points,status[c("soort_id","soort_naam")],by="soort_id",all.x=TRUE)
points$fixed_33 <- points$soort_id %in% fixed_ids
ix <- do.call(rbind,index_rows)
groups <- do.call(rbind,lapply(c("yearly_trim","window_poisson"),function(method){
 z <- e$build_bootstrap_group_results(ix[ix$calibration_method==method,],Filter(function(d)d$variant=="robuust",context$group_definitions),0L);z$calibration_method<-method;z
}))
probe_rows <- list()
for(i in 1:50) {
 draw <- e$make_stratified_cluster_draw(clusters,i,20260920L)
 for(id in fixed_ids) {
  sp <- context$species_matrix[context$species_matrix$soort_id==id,]
  for(method in c("yearly_trim","window_poisson")) {
   fn <- if(method=="yearly_trim")e$fit_bridge_calibration_trim else e$fit_bridge_calibration_window
   f <- fn(sp,draw,clusters$bootstrap_cluster_id[clusters$primary_bridge_plot],1981:1983,1986:1988)
   probe_rows[[length(probe_rows)+1L]] <- data.frame(replicate_id=i,soort_id=id,calibration_method=method,valid=isTRUE(f$ok),level_ratio=if(isTRUE(f$ok))mean(f$totals[as.character(1986:1988)])/mean(f$totals[as.character(1981:1983)]) else NA_real_,reason=if(is.null(f$reason))NA_character_ else f$reason)
  }
 }
 if(i%%10==0)cat("CALIBRATION_PROBE",i,"/50\n")
}
probe <- do.call(rbind,probe_rows)
stopifnot(nrow(probe)==50L*33L*2L,!anyDuplicated(probe[c("replicate_id","soort_id","calibration_method")]))
validity <- aggregate(valid~soort_id+calibration_method,probe,sum)
validity <- merge(validity,status[c("soort_id","soort_naam")],by="soort_id")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(n in c("points","groups","probe","validity"))write.csv(get(n),file.path(out,paste0(n,".csv")),row.names=FALSE,na="")
write.csv(status[match(sort(fixed_ids),status$soort_id),c("soort_id","soort_naam")],file.path(out,"fixed_species_33.csv"),row.names=FALSE)
# Dezelfde uitgangsmodellen/context voor de latere gecontroleerde pilot.
context$config$calibration_method <- "window_poisson"
context$species_matrix <- e$restrict_species_matrix_to_bootstrap_clusters(sm,clusters)
code_files <- c("R/audit_trim_bridge_zero_totals.R","R/trim_bridge_core.R","R/trim_bootstrap_core.R","R/build_trim_bootstrap_bundle.R")
selection_files <- c("trim/soorten/soorten_modelstatus.csv","trim/soorten/soortindices_per_jaar.csv")
file_hashes <- function(files) as.list(stats::setNames(vapply(file.path(repo,files),function(p)digest::digest(file=p,algo="sha256"),character(1)),files))
jsonlite::write_json(list(format="trim-bridge-zero-comparison-v1",source_hash=cache$identity$sql_sha256,cache_sha256=digest::digest(file=cache_path,algo="sha256"),run_seed=20260920L,replicate_ids=1:50,fixed_species_ids=expected_ids,code_sha256=file_hashes(code_files),selection_source_sha256=file_hashes(selection_files),publication_status="experimenteel_geen_bootstrapuitkomst"),file.path(out,"audit_manifest.json"),auto_unbox=TRUE,pretty=TRUE)
cat("FIXED_SPECIES",length(fixed_ids),"\n")
print(validity[validity$valid<50,],row.names=FALSE)
