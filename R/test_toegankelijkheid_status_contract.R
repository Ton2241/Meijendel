source("shiny_meijendel/helpers.R")

input <- data.frame(plot_id = 35L, jaar = 2026L)
source_data <- data.frame(
  plot_id = 35L,
  status_code = "toegankelijk_buiten_broedseizoen",
  aandeel_pct = 100,
  geldig_vanaf = as.Date("1955-01-01"),
  geldig_tot = as.Date(NA)
)

result <- add_toegankelijkheid_covariates(input, source_data)
stopifnot(
  identical(as.character(result$toegankelijkheid_status), "toegankelijk_buiten_broedseizoen"),
  identical(result$toegankelijkheid_aandeel_buiten_broedseizoen, 100),
  identical(result$toegankelijkheid_aandeel_onbekend, 0)
)

cat("OK: toegankelijkheid-statuscontract\n")
