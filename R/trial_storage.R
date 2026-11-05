# Project-wide physical storage gate for local exploratory output.
trial_output <- function(path) {
  helper <- path.expand('~/Documents/GitHub/VWG_Project/scripts/trial_storage.py')
  result <- suppressWarnings(system2('python3', shQuote(c(helper, path, '--tree')), stdout=TRUE, stderr=TRUE))
  if (!is.null(attr(result, 'status')) || length(result)!=1L) {
    stop(paste(result, collapse='\n'), call.=FALSE)
  }
  result[[1L]]
}
