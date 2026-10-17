resolve_trim_periods <- function(end_year = 2025L) {
  if (length(end_year) != 1L || is.na(end_year) || !is.finite(end_year) || end_year != as.integer(end_year)) {
    stop("TRIM-eindjaar moet één geheel kalenderjaar zijn.", call. = FALSE)
  }
  end_year <- as.integer(end_year)
  if (end_year < 1984L) stop("TRIM-eindjaar moet 1984 of later zijn.", call. = FALSE)
  period <- function(from, to) {
    list(from = as.integer(from), to = as.integer(to), years = seq.int(from, to), label = paste0(from, "-", to))
  }
  list(
    end_year = end_year,
    pre = period(1958L, 1983L),
    post = period(1984L, end_year),
    combined = period(1958L, end_year),
    bridge = list(pre = 1981:1983, primary_post = 1986:1988)
  )
}
