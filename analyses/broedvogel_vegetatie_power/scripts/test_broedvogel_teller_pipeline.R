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

first_a <- run_resumable_step("A", strrep("a", 64L), strrep("1", 64L), checkpoint_dir, FALSE, mock_step(1L))
first_b <- run_resumable_step("B", strrep("b", 64L), strrep("2", 64L), checkpoint_dir, FALSE, mock_step(2L))
stopifnot(executions$count == 2L, !first_a$resumed, !first_b$resumed)

second_a <- run_resumable_step("A", strrep("a", 64L), strrep("1", 64L), checkpoint_dir, TRUE, mock_step(10L))
second_b <- run_resumable_step("B", strrep("b", 64L), strrep("2", 64L), checkpoint_dir, TRUE, mock_step(20L))
stopifnot(executions$count == 2L, second_a$resumed, second_b$resumed)

changed_contract <- run_resumable_step("A", strrep("a", 64L), strrep("3", 64L), checkpoint_dir, TRUE, mock_step(30L))
stopifnot(executions$count == 3L, !changed_contract$resumed, changed_contract$value$value == 30L)

unlink(file.path(checkpoint_dir, "B.rds"))
third_a <- run_resumable_step("A", strrep("a", 64L), strrep("3", 64L), checkpoint_dir, TRUE, mock_step(100L))
third_b <- run_resumable_step("B", strrep("b", 64L), strrep("2", 64L), checkpoint_dir, TRUE, mock_step(200L))
stopifnot(executions$count == 4L, third_a$resumed, !third_b$resumed, third_b$value$value == 200L)

contract_a <- analysis_contract_hash(
  metadata = list(git_commit = strrep("c", 40L)),
  analysis_id = "lang_mean",
  row_hash = strrep("d", 64L),
  formulas = joint_teller_formulas(),
  extra = list(family = "nbinom2", experience_variant = "mean")
)
contract_b <- analysis_contract_hash(
  metadata = list(git_commit = strrep("e", 40L)),
  analysis_id = "lang_mean",
  row_hash = strrep("d", 64L),
  formulas = joint_teller_formulas(),
  extra = list(family = "nbinom2", experience_variant = "mean")
)
stopifnot(grepl("^[0-9a-f]{64}$", contract_a), !identical(contract_a, contract_b))

all_formulas <- teller_formula_manifest()
stopifnot(
  length(all_formulas) == 32L,
  all(c(
    "joint_lang_mean_M0", "joint_inspanning_duur_M2",
    "species_lang_M0", "species_inspanning_bezoeken_M2",
    "gee_lang_M0", "gee_lang_M2"
  ) %in% names(all_formulas))
)

joint_fixture <- stats::setNames(lapply(
  c("lang_mean", "lang_min", "lang_max", "een_teller_mean", "inspanning_duur", "inspanning_bezoeken"),
  function(id) list(comparison = data.frame(
    model = c("M0", "M1", "M2"),
    status = rep("geslaagd", 3L),
    row_hash = rep(paste0("hash_", id), 3L),
    stringsAsFactors = FALSE
  ))
), c("lang_mean", "lang_min", "lang_max", "een_teller_mean", "inspanning_duur", "inspanning_bezoeken"))
species_fixture <- list(
  lang = data.frame(soort_id = 1:2, status = c("geslaagd", "modeluitval"), row_hash = c("s1", "s2")),
  een_teller = data.frame(soort_id = 1L, status = "geslaagd", row_hash = "s1"),
  inspanning_duur = data.frame(soort_id = 1L, status = "geslaagd", row_hash = "s1"),
  inspanning_bezoeken = data.frame(soort_id = 1L, status = "geslaagd", row_hash = "s1")
)
gee_fixture <- data.frame(
  soort_id = 1:2, status = c("geslaagd", "modeluitval"), row_hash = c("s1", "s2"),
  trend_m0_pct_jaar = c(1, NA), trend_m2_pct_jaar = c(1, NA),
  ervaring_plot_beta = c(0.1, NA), ervaring_elders_beta = c(0.2, NA),
  trend_m0_se = c(0.1, NA), trend_m2_se = c(0.1, NA),
  ervaring_plot_se = c(0.1, NA), ervaring_elders_se = c(0.1, NA),
  gee_error_m0 = c(0L, NA_integer_), gee_error_m2 = c(0L, NA_integer_)
)
expected_contract <- list(
  joint_hashes = stats::setNames(paste0("hash_", names(joint_fixture)), names(joint_fixture)),
  species_ids = list(lang = 1:2, een_teller = 1L, inspanning_duur = 1L, inspanning_bezoeken = 1L)
)
stopifnot(isTRUE(validate_teller_pipeline_results(joint_fixture, species_fixture, gee_fixture, expected_contract)))
broken_joint <- joint_fixture
broken_joint$lang_mean$comparison$status[[2L]] <- "modeluitval"
broken_error <- tryCatch(
  { validate_teller_pipeline_results(broken_joint, species_fixture, gee_fixture, expected_contract); "" },
  error = conditionMessage
)
stopifnot(grepl("gezamenlijk model", broken_error, fixed = TRUE))

coverage_fixture <- data.frame(
  metric = c(
    "natura2000_plots", "telleranalyse_plotjaren", "plotjaren_met_teller",
    "plotjaren_zonder_teller", "een_teller_plotjaren", "twee_teller_plotjaren",
    "drie_teller_plotjaren", "gezamenlijke_modelsoorten", "structureel_geschikte_soorten"
  ),
  value = c(52, 2106, 2007, 99, 1804, 201, 2, 156, 121)
)
stopifnot(isTRUE(validate_teller_coverage_contract(coverage_fixture)))
broken_coverage <- coverage_fixture
broken_coverage$value[broken_coverage$metric == "plotjaren_zonder_teller"] <- 100
coverage_error <- tryCatch(
  { validate_teller_coverage_contract(broken_coverage); "" },
  error = conditionMessage
)
stopifnot(grepl("plotjaren_zonder_teller", coverage_error, fixed = TRUE))

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
  formulas = all_formulas,
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
  length(read_manifest$formulas) == 32L,
  identical(read_manifest$response_row_hashes$long, strrep("d", 64L)),
  identical(read_manifest$outputs$resultaat$sha256, sha256_file(output_path))
)

unlink(tmp, recursive = TRUE)
cat("OK: tellerpijplijn manifesteert bronnen en hervat uitsluitend geldige checkpoints.\n")
