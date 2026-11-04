# Shared HTML preview, kept separate from formal uncertainty loading.
load_trim_bootstrap_preview <- function(root = Sys.getenv("MEIJENDEL_BOOTSTRAP_PRESENTATION", unset = "")) {
  if (!identical(Sys.getenv("MEIJENDEL_BOOTSTRAP_PREVIEW"), "1") || !nzchar(root)) return(NULL)
  tryCatch({
    manifest <- jsonlite::read_json(file.path(root, "manifest.json"), simplifyVector = TRUE)
    path <- file.path(root, "bootstrap.html")
    if (!identical(manifest$schema, "trim-bootstrap-presentation-v1") ||
        !identical(manifest$publication_status, "diagnostisch") ||
        !identical(digest::digest(file = path, algo = "sha256"), manifest$html_sha256)) return(NULL)
    list(manifest = manifest, path = path)
  }, error = function(e) NULL)
}

trim_bootstrap_preview_matches <- function(preview, plot_ids, species_ids, year_from, year_to, source_hash) {
  if (is.null(preview)) return(FALSE)
  m <- preview$manifest
  equal_ids <- function(x,y) identical(sort(unique(as.integer(x))), sort(unique(as.integer(y))))
  isTRUE(equal_ids(plot_ids, m$selection$plot_ids) && equal_ids(species_ids, m$selection$species_ids) &&
    as.integer(year_from) == m$selection$year_from && as.integer(year_to) == m$selection$year_to &&
    identical(source_hash, m$source_hash))
}
