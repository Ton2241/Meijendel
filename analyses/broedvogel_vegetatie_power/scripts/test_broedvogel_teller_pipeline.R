args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
test_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_teller_pipeline.R"
repo <- normalizePath(file.path(dirname(test_path), "..", "..", ".."), mustWork = TRUE)

Sys.setenv(MEIJENDEL_REPO = repo)
source(file.path(repo, "analyses", "broedvogel_vegetatie_power", "scripts", "run_broedvogel_teller_model.R"))

tmp <- tempfile("teller-pipeline-")
dir.create(tmp)
extract_dir <- file.path(tmp, "extract")
checkpoint_dir <- file.path(tmp, "checkpoints")
dir.create(extract_dir)
dir.create(checkpoint_dir)
utils::write.table(data.frame(id = 1:2), file.path(extract_dir, "plots.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
utils::write.table(data.frame(id = 1:3), file.path(extract_dir, "territoria.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)

source_metadata <- collect_tsv_metadata(extract_dir)
stopifnot(
  identical(sort(names(source_metadata)), c("plots", "territoria")),
  source_metadata$plots$rows == 2L,
  grepl("^[0-9a-f]{64}$", source_metadata$territoria$sha256)
)

executions <- new.env(parent = emptyenv())
executions$count <- 0L
mock_step <- function(value) {
  force(value)
  function() {
    executions$count <- executions$count + 1L
    list(status = "berekend", value = value)
  }
}

first_a <- run_resumable_step("A", strrep("a", 64L), checkpoint_dir, FALSE, mock_step(1L))
first_b <- run_resumable_step("B", strrep("b", 64L), checkpoint_dir, FALSE, mock_step(2L))
stopifnot(executions$count == 2L, !first_a$resumed, !first_b$resumed)

second_a <- run_resumable_step("A", strrep("a", 64L), checkpoint_dir, TRUE, mock_step(10L))
second_b <- run_resumable_step("B", strrep("b", 64L), checkpoint_dir, TRUE, mock_step(20L))
stopifnot(executions$count == 2L, second_a$resumed, second_b$resumed)

unlink(file.path(checkpoint_dir, "B.rds"))
third_a <- run_resumable_step("A", strrep("a", 64L), checkpoint_dir, TRUE, mock_step(100L))
third_b <- run_resumable_step("B", strrep("b", 64L), checkpoint_dir, TRUE, mock_step(200L))
stopifnot(executions$count == 3L, third_a$resumed, !third_b$resumed, third_b$value$value == 200L)

output_path <- file.path(tmp, "resultaat.csv")
utils::write.csv(data.frame(x = 1), output_path, row.names = FALSE)
manifest_path <- file.path(tmp, "teller_model_manifest.json")
manifest <- write_teller_manifest(
  manifest_path,
  metadata = list(
    run_id = "test-run",
    git_commit = strrep("c", 40L),
    mysql_version = "9.7.1",
    random_seed = 20261009L
  ),
  source_files = source_metadata,
  response_hashes = c(long = strrep("d", 64L)),
  formulas = joint_teller_formulas(),
  outputs = c(resultaat = output_path)
)
read_manifest <- jsonlite::read_json(manifest_path)
stopifnot(
  identical(manifest$run_id, "test-run"),
  identical(read_manifest$git_commit, strrep("c", 40L)),
  identical(read_manifest$mysql_version, "9.7.1"),
  identical(as.integer(read_manifest$random_seed), 20261009L),
  all(c("glmmTMB", "geepack", "digest", "jsonlite") %in% names(read_manifest$package_versions)),
  identical(as.integer(read_manifest$tables$territoria$rows), 3L),
  length(read_manifest$formulas) == 3L,
  identical(read_manifest$response_row_hashes$long, strrep("d", 64L)),
  identical(read_manifest$outputs$resultaat$sha256, sha256_file(output_path))
)

unlink(tmp, recursive = TRUE)
cat("OK: tellerpijplijn manifesteert bronnen en hervat uitsluitend geldige checkpoints.\n")
