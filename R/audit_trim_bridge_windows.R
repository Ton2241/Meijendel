count_window_coverage <- function(basis, years, label) {
  counted <- unique(basis[basis$geteld %in% TRUE & basis$jaar %in% years, c("plot_id", "jaar"), drop = FALSE])
  data.frame(
    window = label,
    first_year = min(years),
    last_year = max(years),
    unique_plots = length(unique(counted$plot_id)),
    plot_years = nrow(counted),
    plots_all_years = sum(table(counted$plot_id) == length(unique(years))),
    stringsAsFactors = FALSE
  )
}

derive_bridge_plot_sets <- function(basis, pre_years, post_years) {
  required <- c("plot_id", "jaar", "geteld")
  missing <- setdiff(required, names(basis))
  if (length(missing)) stop("Analysebasis mist: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  pre_years <- sort(unique(as.integer(pre_years)))
  post_years <- sort(unique(as.integer(post_years)))
  if (!length(pre_years) || !length(post_years) || length(intersect(pre_years, post_years))) {
    stop("Brugvensters moeten gevuld en niet-overlappend zijn.", call. = FALSE)
  }
  counted <- unique(basis[basis$geteld %in% TRUE, c("plot_id", "jaar"), drop = FALSE])
  pre <- counted[counted$jaar %in% pre_years, , drop = FALSE]
  post <- counted[counted$jaar %in% post_years, , drop = FALSE]
  pre_any <- sort(unique(pre$plot_id))
  post_any <- sort(unique(post$plot_id))
  all_years <- c(pre_years, post_years)
  in_all <- table(counted$plot_id[counted$jaar %in% all_years])
  common_all <- sort(as.integer(names(in_all)[in_all == length(all_years)]))
  list(
    pre_any_year = pre_any,
    post_any_year = post_any,
    common_any_year = sort(intersect(pre_any, post_any)),
    common_all_years = common_all
  )
}

audit_trim_bridge_windows <- function(tbls, basis, windows) {
  if (!all(c("pre", "primary") %in% names(windows))) {
    stop("Brugvensters moeten 'pre' en 'primary' bevatten.", call. = FALSE)
  }
  pre_years <- sort(unique(as.integer(windows$pre)))
  post_years <- sort(unique(as.integer(windows$primary)))
  if (any(post_years %in% c(1984L, 1985L))) {
    stop("Overgangsjaren 1984 en 1985 mogen de primaire brug niet kalibreren.", call. = FALSE)
  }
  sets <- derive_bridge_plot_sets(basis, pre_years, post_years)
  counted <- unique(basis[basis$geteld %in% TRUE, c("plot_id", "jaar"), drop = FALSE])
  annual <- aggregate(plot_id ~ jaar, data = counted, FUN = function(x) length(unique(x)))
  names(annual)[2L] <- "unique_plots"
  list(
    annual = annual[order(annual$jaar), , drop = FALSE],
    windows = rbind(
      count_window_coverage(basis, pre_years, "pre"),
      count_window_coverage(basis, post_years, "primary")
    ),
    overlap = data.frame(
      any_year = length(sets$common_any_year),
      all_six_years = length(sets$common_all_years),
      stringsAsFactors = FALSE
    ),
    plot_sets = sets,
    primary_post_years = post_years
  )
}
