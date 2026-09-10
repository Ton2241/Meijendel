NDFF_LOCAL_DATABASE <- "Meijendel_ndff_secure"
NDFF_LOCAL_LOGIN_PATH <- "meijendel_ndff_shiny"

ndff_local_allowed_views <- function() {
  c(
    "v_ndff_lokale_overzicht",
    "v_ndff_lokale_plot_jaar_taxon",
    "v_ndff_lokale_protocolstatus"
  )
}

ndff_local_safe_columns <- function() {
  c(
    "soortgroep", "verspreidingscontext_status", "trend_status", "pq_status",
    "positieve_waarnemingen", "plotversie_id", "plot_id", "jaar",
    "ndff_soort_id", "wetenschappelijke_naam", "nederlandse_naam",
    "protocol_auditklasse", "protocol"
  )
}

ndff_mysql_connection_args <- function(
  host = Sys.getenv("NDFF_MYSQL_HOST", unset = "127.0.0.1"),
  port = Sys.getenv("NDFF_MYSQL_PORT", unset = "3306")
) {
  c("--protocol=tcp", sprintf("--host=%s", host), sprintf("--port=%s", port))
}

ndff_local_enabled <- function(
  flag = Sys.getenv("NDFF_SECURE_LOCAL", unset = "0"),
  runtime = Sys.getenv("MEIJENDEL_RUNTIME", unset = "local"),
  working_directory = getwd()
) {
  enabled <- identical(flag, "1")
  if (!enabled) {
    return(FALSE)
  }
  production_context <- identical(tolower(runtime), "production") ||
    startsWith(normalizePath(working_directory, mustWork = FALSE), "/srv/shiny-server")
  if (production_context) {
    stop("NDFF_SECURE_LOCAL mag niet in de productie- of VPS-runtime worden geactiveerd.")
  }
  TRUE
}

ndff_query_safe_view <- function(
  view,
  mysql_client = Sys.getenv("MEIJENDEL_MYSQL_CLIENT", unset = "/usr/local/mysql/bin/mysql"),
  login_path = Sys.getenv("NDFF_MYSQL_LOGIN_PATH", unset = NDFF_LOCAL_LOGIN_PATH)
) {
  if (!view %in% ndff_local_allowed_views()) {
    stop("Niet-toegestane NDFF-view.")
  }
  if (!file.exists(mysql_client)) {
    stop("Lokale MySQL-client niet gevonden.")
  }
  query <- sprintf("SELECT * FROM `%s`", view)
  output <- system2(
    mysql_client,
    c(
      sprintf("--login-path=%s", login_path),
      ndff_mysql_connection_args(),
      "--batch",
      "--raw",
      "--default-character-set=utf8mb4",
      NDFF_LOCAL_DATABASE,
      "--execute",
      shQuote(query)
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status")
  if (!is.null(status) && status != 0L) {
    stop("De lokale beveiligde NDFF-view kon niet worden gelezen.")
  }
  if (!length(output)) {
    return(data.frame())
  }
  result <- utils::read.delim(
    text = paste(output, collapse = "\n"),
    sep = "\t",
    quote = "",
    check.names = FALSE,
    stringsAsFactors = FALSE,
    na.strings = "NULL"
  )
  unexpected <- setdiff(names(result), ndff_local_safe_columns())
  if (length(unexpected)) {
    stop("De NDFF-view bevat niet-toegestane kolommen.")
  }
  result
}

ndff_local_tab <- function() {
  shiny::tabPanel(
    "NDFF lokaal",
    shiny::fluidPage(
      shiny::titlePanel("NDFF — lokale beveiligde contextlaag"),
      shiny::tags$div(
        class = "method-warning",
        shiny::tags$strong("Interpretatiebeperking. "),
        "Dit zijn positieve, geaggregeerde aanwezigheidssignalen. Zij bewijzen geen afwezigheid, abundantie of populatietrend. Provinciale PQ-data in de life-database blijven de gezaghebbende PQ-bron; NDFF-PQ is uitgesloten."
      ),
      shiny::actionButton("ndff_local_refresh", "Veilige NDFF-overzichten laden", class = "btn-primary"),
      shiny::verbatimTextOutput("ndff_local_status"),
      shiny::h3("Overzicht per soortgroep en kwaliteitsstatus"),
      shiny::tableOutput("ndff_local_overview"),
      shiny::h3("Protocolstatus"),
      shiny::tableOutput("ndff_local_protocols"),
      shiny::h3("Positieve context per SOVON-plot, jaar en taxon"),
      shiny::tableOutput("ndff_local_plot_year_taxon"),
      shiny::tags$p(
        class = "section-note",
        "Geen ruwe download, exacte locatie, dagdatum of NDFF-identiteit wordt via deze module aangeboden."
      )
    )
  )
}

ndff_local_server <- function(input, output, session) {
  overview <- shiny::reactiveVal(data.frame())
  protocols <- shiny::reactiveVal(data.frame())
  plot_year_taxon <- shiny::reactiveVal(data.frame())
  status <- shiny::reactiveVal("Nog niet geladen.")

  shiny::observeEvent(input$ndff_local_refresh, {
    status("Beveiligde lokale views worden geladen...")
    tryCatch({
      overview(ndff_query_safe_view("v_ndff_lokale_overzicht"))
      protocols(ndff_query_safe_view("v_ndff_lokale_protocolstatus"))
      plot_year_taxon(ndff_query_safe_view("v_ndff_lokale_plot_jaar_taxon"))
      status("Geladen uit uitsluitend geaggregeerde lokale views.")
    }, error = function(condition) {
      status(sprintf("Laden mislukt: %s", conditionMessage(condition)))
    })
  }, ignoreInit = TRUE)

  output$ndff_local_status <- shiny::renderText(status())
  output$ndff_local_overview <- shiny::renderTable(overview(), striped = TRUE, bordered = TRUE)
  output$ndff_local_protocols <- shiny::renderTable(protocols(), striped = TRUE, bordered = TRUE)
  output$ndff_local_plot_year_taxon <- shiny::renderTable(plot_year_taxon(), striped = TRUE, bordered = TRUE)
}
