args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1]] else ".")
source(file.path(repo, "R", "trim_bootstrap_preview.R"))
p <- list(manifest = list(selection = list(plot_ids=c(1L,2L),species_ids=c(3L,4L),year_from=1958L,year_to=2025L),source_hash="bron"))
stopifnot(trim_bootstrap_preview_matches(p,c(2,1),c(4,3),1958,2025,"bron"))
stopifnot(!trim_bootstrap_preview_matches(p,1,c(4,3),1958,2025,"bron"))
stopifnot(!trim_bootstrap_preview_matches(p,c(2,1),3,1958,2025,"bron"))
stopifnot(!trim_bootstrap_preview_matches(p,c(2,1),c(4,3),1958,2026,"bron"))
stopifnot(!trim_bootstrap_preview_matches(p,c(2,1),c(4,3),1958,2025,"andere bron"))
stopifnot(is.null(load_trim_bootstrap_preview(tempdir())))
cat("OK: eigen selectie, ander eindjaar en andere bron nemen de standaardbootstrap niet over.\n")

# Optional integration using a generated local candidate, without fitting models.
if (length(args) > 1L) {
 preview_root <- normalizePath(args[[2]],mustWork=TRUE)
 setwd(file.path(repo,"shiny_meijendel"))
Sys.setenv(MEIJENDEL_BOOTSTRAP_PREVIEW='1',MEIJENDEL_BOOTSTRAP_PRESENTATION=preview_root,MEIJENDEL_REQUIRE_PREBUILT_CACHE='1')
app <- source('app.R')$value
preview <- load_trim_bootstrap_preview()
stopifnot(!is.null(preview))
shiny::testServer(server, {
 m <- preview$manifest
 analyse_rv(list(species_results=list(trends=data.frame(soort_id=1L,soort_naam='Dodaars')),bootstrap_selection=list(plot_ids=m$selection$plot_ids,species_ids=m$selection$species_ids,year_from=m$year_from,year_to=m$year_to,source_hash=m$source_hash)))
 session$setInputs(selected_species='Dodaars')
 html <- output$trim_species_bootstrap_preview
 stopifnot(grepl('iframe', html$html),grepl('species=1', html$html,fixed=TRUE))
 a <- analyse_rv();a$bootstrap_selection$plot_ids <- 1L;analyse_rv(a)
 session$flushReact()
 html <- output$trim_species_bootstrap_preview
 stopifnot(!grepl('iframe',html$html),grepl('andere bron',html$html,fixed=TRUE))
})
cat('OK: Shiny rendert opgeslagen beoordeling en blokkeert deze bij andere selectie.\n')

}
