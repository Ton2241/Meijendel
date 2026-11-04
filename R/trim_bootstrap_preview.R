# Shared HTML preview, kept separate from formal uncertainty loading.
load_trim_bootstrap_preview <- function(root = Sys.getenv("MEIJENDEL_BOOTSTRAP_PRESENTATION", unset = "")) {
  active_release <- identical(Sys.getenv("MEIJENDEL_BOOTSTRAP_RELEASE"), "1")
  if (!active_release && (!identical(Sys.getenv("MEIJENDEL_BOOTSTRAP_PREVIEW"), "1") || !nzchar(root))) return(NULL)
  tryCatch({
    release <- NULL
    if (active_release) {
      control <- normalizePath(Sys.getenv("MEIJENDEL_RELEASE_MANIFEST"),mustWork=TRUE)
      release <- jsonlite::read_json(control,simplifyVector=TRUE)
      if (!identical(release$schema,"meijendel-integral-release-v1") || !isTRUE(release$presentation_approved)) return(NULL)
      if (identical(release$mode,"local_rehearsal")) {
        if (!identical(Sys.getenv("MEIJENDEL_BIND_HOST"),"127.0.0.1")) return(NULL)
      } else if (!identical(release$mode,"production") || !isTRUE(release$official_data_validated)) return(NULL)
      relative <- release$bootstrap$root
      if (grepl("^/|(^|/)\\.\\.(/|$)",relative)) return(NULL)
      root <- normalizePath(file.path(dirname(control),relative),mustWork=TRUE)
      if (!startsWith(paste0(root,"/"),paste0(dirname(control),"/"))) return(NULL)
    }
    manifest <- jsonlite::read_json(file.path(root, "manifest.json"), simplifyVector = TRUE)
    path <- file.path(root, "bootstrap.html")
    if (!identical(manifest$schema, "trim-bootstrap-presentation-v1") ||
        !identical(manifest$publication_status, "diagnostisch") ||
        !identical(digest::digest(file = path, algo = "sha256"), manifest$html_sha256)) return(NULL)
    if (!is.null(release) && (!identical(manifest$source_hash,release$source_hash) ||
      manifest$year_from!=release$year_from || manifest$year_to!=release$year_to ||
      !identical(manifest$html_sha256,release$bootstrap$html_sha256) ||
      !identical(digest::digest(file=file.path(root,"manifest.json"),algo="sha256"),release$bootstrap$manifest_sha256))) return(NULL)
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
