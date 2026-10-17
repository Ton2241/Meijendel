sha256_file <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  output <- system2("shasum", c("-a", "256", path), stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  hash <- if (length(output)) sub("[[:space:]].*$", "", output[[1L]]) else ""
  if ((!is.null(status) && status != 0L) || !grepl("^[0-9a-f]{64}$", hash)) {
    stop("SHA-256 kon niet worden bepaald voor ", path, ".", call. = FALSE)
  }
  hash
}

trim_output_inventory <- function(output_dir) {
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  files <- list.files(output_dir, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  files <- files[file.info(files)$isdir %in% FALSE]
  if (!length(files)) {
    return(data.frame(path = character(), bytes = numeric(), sha256 = character()))
  }
  rel <- substring(files, nchar(output_dir) + 2L)
  order_idx <- order(rel)
  files <- files[order_idx]
  rel <- rel[order_idx]
  data.frame(
    path = rel,
    bytes = unname(file.info(files)$size),
    sha256 = vapply(files, sha256_file, character(1)),
    stringsAsFactors = FALSE
  )
}

build_trim_run_manifest <- function(sql_path, output_dir, run_id, git_commit) {
  if (!nzchar(run_id)) stop("run_id mag niet leeg zijn.", call. = FALSE)
  if (!grepl("^[0-9a-f]{40}$", git_commit)) stop("git_commit is geen volledige Git-hash.", call. = FALSE)
  sql_path <- normalizePath(sql_path, winslash = "/", mustWork = TRUE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  list(
    format = "trim-bootstrap-run-manifest-v1",
    run_id = run_id,
    source = list(
      sql_path = sql_path,
      sql_bytes = unname(file.info(sql_path)$size),
      sql_sha256 = sha256_file(sql_path)
    ),
    code = list(git_commit = git_commit),
    software = list(
      r_version = as.character(getRversion()),
      rtrim_version = if (requireNamespace("rtrim", quietly = TRUE)) as.character(utils::packageVersion("rtrim")) else NA_character_
    ),
    output_dir = output_dir,
    outputs = trim_output_inventory(output_dir)
  )
}

validate_trim_run_manifest <- function(manifest, sql_path, output_dir) {
  if (!identical(manifest$format, "trim-bootstrap-run-manifest-v1")) {
    stop("Onbekend TRIM-runmanifestformaat.", call. = FALSE)
  }
  if (!identical(sha256_file(sql_path), manifest$source$sql_sha256)) {
    stop("TRIM-bronhash wijkt af van het runmanifest.", call. = FALSE)
  }
  current <- trim_output_inventory(output_dir)
  expected <- manifest$outputs
  rownames(current) <- NULL
  rownames(expected) <- NULL
  if (!identical(current, expected)) {
    stop("TRIM-uitvoer wijkt af van het runmanifest.", call. = FALSE)
  }
  TRUE
}
