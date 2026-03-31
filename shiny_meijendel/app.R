if (!requireNamespace("shiny", quietly = TRUE)) {
  stop("Package 'shiny' is niet geinstalleerd. Installeer het eerst met install.packages('shiny').")
}
if (!requireNamespace("rtrim", quietly = TRUE)) {
  stop("Package 'rtrim' is niet geinstalleerd. Installeer het eerst voordat je de app start.")
}
if (!requireNamespace("mgcv", quietly = TRUE)) {
  stop("Package 'mgcv' is niet geinstalleerd. Installeer het eerst voordat je de app start.")
}

source("helpers.R", local = TRUE)

library(shiny)

default_sql <- normalizePath(file.path("..", "Meijendel.sql"), winslash = "/", mustWork = FALSE)

ui <- fluidPage(
  theme = bslib::bs_theme(version = 5, bootswatch = "flatly"),
  tags$head(
    tags$style(HTML("
      .app-subtitle { color:#4b5563; margin-top:-12px; margin-bottom:18px; }
      .status-box {
        background:#f8fafc; border:1px solid #dbe4ef; border-radius:12px;
        padding:12px 14px; margin:10px 0 14px 0; color:#1f2937;
      }
      .status-label { font-weight:700; display:block; margin-bottom:4px; color:#0f172a; }
      .soft-card {
        background:#ffffff; border:1px solid #dbe4ef; border-radius:14px;
        padding:14px; margin-bottom:14px;
      }
      .section-note { color:#475569; font-size:13px; margin-top:6px; }
      .download-row .btn { margin-right:8px; margin-bottom:8px; }
    "))
  ),
  titlePanel("Meijendel TRIM verkenner"),
  tags$p(class = "app-subtitle",
    "Eerste Shiny-versie voor TRIM per soort en EVG-MSI op vrij gekozen kavels."
  ),
  sidebarLayout(
    sidebarPanel(
      class = "soft-card",
      textInput("sql_path", "Pad naar Meijendel.sql", value = default_sql),
      actionButton("load_sql", "SQL laden"),
      div(class = "status-box",
          tags$span(class = "status-label", "Status SQL"),
          textOutput("load_status")),
      tags$hr(),
      uiOutput("plot_selector_ui"),
      uiOutput("year_selector_ui"),
      checkboxGroupInput(
        "analyse_keuze",
        "Wat berekenen",
        choices = c("Soorten" = "species", "Groepen" = "groups"),
        selected = c("species", "groups")
      ),
      actionButton("run_analysis", "Analyse uitvoeren", class = "btn-primary"),
      div(class = "status-box",
          tags$span(class = "status-label", "Status analyse"),
          textOutput("analysis_status")),
      tags$hr(),
      h4("Korte uitleg"),
      tags$p("Klik kavels aan om ze toe te voegen aan je selectie. Kies daarna jaren en klik op 'Analyse uitvoeren'."),
      tags$p("De app maakt dan nieuwe TRIM-berekeningen voor precies die selectie.")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Selectie",
          h3("Huidige selectie"),
          verbatimTextOutput("selection_summary"),
          h4("Geselecteerde kavels"),
          tableOutput("selected_plots_table")
        ),
        tabPanel(
          "Soorten",
          uiOutput("species_picker_ui"),
          tags$p(class = "section-note", "Groen: TRIM-index per jaar. Oranje: gladde GAM-lijn over dezelfde reeks."),
          plotOutput("species_plot", height = "420px"),
          div(class = "download-row",
              downloadButton("download_species_trends", "CSV soorttrends"),
              downloadButton("download_species_indices", "CSV soortindices")),
          h4("Trend per soort"),
          tableOutput("species_table")
        ),
        tabPanel(
          "Groepen",
          uiOutput("group_picker_ui"),
          tags$p(class = "section-note", "Blauw: MSI per jaar. Oranje: gladde GAM-lijn over dezelfde reeks."),
          plotOutput("group_plot", height = "420px"),
          div(class = "download-row",
              downloadButton("download_group_trends", "CSV groepstrends"),
              downloadButton("download_group_msi", "CSV groep-MSI")),
          h4("Trend per groep"),
          tableOutput("group_table"),
          h4("Soorten in gekozen groep"),
          tableOutput("group_species_table")
        ),
        tabPanel(
          "Controle",
          div(class = "download-row",
              downloadButton("download_basis", "CSV analysebasis"),
              downloadButton("download_status", "CSV modelstatus")),
          h4("Dekking per kavel"),
          tableOutput("coverage_table"),
          h4("Oppervlak per jaar"),
          tableOutput("area_table"),
          h4("Modelstatus soorten"),
          tableOutput("status_table")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  tbls_rv <- reactiveVal(NULL)
  analyse_rv <- reactiveVal(NULL)
  load_info_rv <- reactiveVal("Nog geen SQL geladen.")
  analysis_info_rv <- reactiveVal("Nog geen analyse uitgevoerd.")

  observeEvent(input$load_sql, {
    req(nzchar(input$sql_path))
    load_info_rv("SQL wordt geladen...")
    tryCatch({
      path <- normalizePath(input$sql_path, winslash = "/", mustWork = TRUE)
      cache_path <- file.path(tempdir(), "meijendel_tables_cache.rds")
      withProgress(message = "SQL wordt gelezen", detail = "Eerste keer kan dit ongeveer 20 seconden duren.", value = 0.1, {
        loaded <- load_meijendel_tables_cached(path, cache_path = cache_path)
        incProgress(0.8)
        tbls_rv(loaded$data)
        if (loaded$from_cache) {
          load_info_rv("SQL geladen uit cache. De kavel-lijst is direct beschikbaar.")
          showNotification("SQL geladen uit cache.", type = "message", duration = 4)
        } else {
          load_info_rv("SQL vers ingelezen. Volgende keer gaat dit veel sneller door de cache.")
          showNotification("SQL geladen. Volgende keer gaat dit sneller.", type = "message", duration = 4)
        }
      })
    }, error = function(e) {
      load_info_rv(paste("Fout bij SQL laden:", conditionMessage(e)))
      showNotification(paste("Fout bij SQL laden:", conditionMessage(e)), type = "error", duration = NULL)
    })
  }, ignoreInit = FALSE)

  output$load_status <- renderText({
    load_info_rv()
  })

  output$analysis_status <- renderText({
    analysis_info_rv()
  })

  output$plot_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(tags$p("Laad eerst Meijendel.sql"))
    }
    kavels <- sort(unique(tbls$plots$kavel_nummer))
    tagList(
      tags$p(class = "section-note", "Klik kavels aan om ze toe te voegen. Gebruik de knoppen hieronder om snel alles of niets te kiezen."),
      fluidRow(
        column(6, actionButton("select_all_plots", "Alle kavels", width = "100%")),
        column(6, actionButton("clear_all_plots", "Geen kavels", width = "100%"))
      ),
      selectizeInput(
        "selected_plots",
        "Kavels",
        choices = kavels,
        selected = character(0),
        multiple = TRUE,
        options = list(plugins = list("remove_button"))
      )
    )
  })

  observeEvent(input$select_all_plots, {
    tbls <- tbls_rv()
    req(tbls)
    kavels <- sort(unique(tbls$plots$kavel_nummer))
    updateSelectizeInput(session, "selected_plots", selected = kavels)
  })

  observeEvent(input$clear_all_plots, {
    updateSelectizeInput(session, "selected_plots", selected = character(0))
  })

  output$year_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(NULL)
    }
    years <- sort(unique(tbls$plot_jaar_oppervlak$jaar))
    tagList(
      selectInput("year_from", "Van jaar", choices = years, selected = min(years)),
      selectInput("year_to", "Tot jaar", choices = years, selected = max(years))
    )
  })

  observeEvent(input$run_analysis, {
    tbls <- tbls_rv()
    req(tbls, input$selected_plots, input$year_from, input$year_to)
    if (length(input$selected_plots) == 0) {
      analysis_info_rv("Kies eerst minstens één kavel.")
      showNotification("Kies eerst minstens één kavel.", type = "error", duration = 5)
      return()
    }

    year_from <- as.integer(input$year_from)
    year_to <- as.integer(input$year_to)
    if (year_from > year_to) {
      analysis_info_rv("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.")
      showNotification("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.", type = "error", duration = 5)
      return()
    }

    analysis_info_rv("Analyse draait...")
    tryCatch({
      withProgress(message = "TRIM-analyse draait", detail = "Per soort wordt een model geschat; dit kan even duren.", value = 0.1, {
        analyse <- analyse_subset(tbls, input$selected_plots, year_from, year_to)
        incProgress(0.9)
        analyse_rv(analyse)
      })
      analysis_info_rv("Analyse gereed.")
      showNotification("Analyse gereed.", type = "message", duration = 4)
    }, error = function(e) {
      analysis_info_rv(paste("Fout bij analyse:", conditionMessage(e)))
      showNotification(paste("Fout bij analyse:", conditionMessage(e)), type = "error", duration = NULL)
    })
  })

  output$selection_summary <- renderText({
    analyse <- analyse_rv()
    if (is.null(analyse)) {
      return("Nog geen analyse uitgevoerd.")
    }
    basis <- analyse$basis
    status <- analyse$species_results$status
    paste(
      "Kavels:", length(unique(basis$kavel_nummer)),
      "\nJaren:", min(basis$jaar), "-", max(basis$jaar),
      "\nPlot-jaar cellen:", nrow(basis),
      "\nSoorten met territoria:", sum(analyse$selection$in_selectie),
      "\nSoorten met bruikbaar TRIM-model:", sum(status$analyse_categorie == "trim_bruikbaar"),
      "\nTe zeldzame soorten:", sum(status$analyse_categorie == "te_zeldzaam")
    )
  })

  output$selected_plots_table <- renderTable({
    tbls <- tbls_rv()
    req(tbls, input$selected_plots)
    validate(need(length(input$selected_plots) > 0, "Er zijn nog geen kavels geselecteerd."))
    tbls$plots[tbls$plots$kavel_nummer %in% input$selected_plots, c("plot_id", "kavel_nummer", "plot_naam")]
  }, striped = TRUE)

  output$species_picker_ui <- renderUI({
    analyse <- analyse_rv()
    if (is.null(analyse)) {
      return(tags$p("Voer eerst een analyse uit."))
    }
    soorten <- sort(unique(analyse$species_results$indices$soort_naam))
    selectInput("selected_species", "Soort", choices = soorten, selected = soorten[1])
  })

  output$species_plot <- renderPlot({
    analyse <- analyse_rv()
    req(analyse, input$selected_species)
    idx <- analyse$species_results$indices
    idx <- idx[idx$soort_naam == input$selected_species, ]
    validate(need(nrow(idx) > 0, "Geen indexgegevens voor deze soort."))

    gam_curve <- fit_gam_curve(idx, "index_100")
    y_max <- max(idx$index_100, if (!is.null(gam_curve)) gam_curve$upper else NA_real_, na.rm = TRUE)
    y_min <- min(idx$index_100, if (!is.null(gam_curve)) gam_curve$lower else NA_real_, na.rm = TRUE)

    plot(idx$jaar, idx$index_100, type = "o", pch = 16, lwd = 2, col = "#157f3b",
         xlab = "Jaar", ylab = "TRIM-index (basisjaar = 100)",
         ylim = c(y_min, y_max),
         main = input$selected_species)
    if (!is.null(gam_curve)) {
      lines(gam_curve$jaar, gam_curve$fit, col = "#f59e0b", lwd = 3)
    }
    grid()
    legend("topleft", legend = c("TRIM-index", "GAM"), col = c("#157f3b", "#f59e0b"),
           lwd = c(2, 3), pch = c(16, NA), bty = "n")
  })

  output$species_table <- renderTable({
    analyse <- analyse_rv()
    req(analyse)
    analyse$species_results$trends[, c(
      "soort_naam", "analyse_categorie", "trend_pct_per_jaar",
      "trend_uitleg", "n_jaren_index", "model"
    )]
  }, striped = TRUE)

  output$group_picker_ui <- renderUI({
    analyse <- analyse_rv()
    if (is.null(analyse)) {
      return(tags$p("Voer eerst een analyse uit."))
    }
    groepen <- unique(analyse$group_results$trends[, c("groep_100", "groep_titel")])
    choices <- setNames(groepen$groep_100, paste0(groepen$groep_100, " - ", groepen$groep_titel))
    selectInput("selected_group", "Ecologische groep", choices = choices, selected = groepen$groep_100[1])
  })

  output$group_plot <- renderPlot({
    analyse <- analyse_rv()
    req(analyse, input$selected_group)
    msi <- analyse$group_results$msi
    msi <- msi[msi$groep_100 == as.integer(input$selected_group), ]
    validate(need(nrow(msi) > 0, "Geen MSI-gegevens voor deze groep."))

    title <- unique(msi$groep_titel)[1]
    gam_curve <- fit_gam_curve(msi, "msi")
    y_max <- max(msi$msi, if (!is.null(gam_curve)) gam_curve$upper else NA_real_, na.rm = TRUE)
    y_min <- min(msi$msi, if (!is.null(gam_curve)) gam_curve$lower else NA_real_, na.rm = TRUE)

    plot(msi$jaar, msi$msi, type = "o", pch = 16, lwd = 2, col = "#1d4ed8",
         xlab = "Jaar", ylab = "MSI",
         ylim = c(y_min, y_max),
         main = paste(input$selected_group, "-", title))
    if (!is.null(gam_curve)) {
      lines(gam_curve$jaar, gam_curve$fit, col = "#f59e0b", lwd = 3)
    }
    grid()
    legend("topleft", legend = c("MSI", "GAM"), col = c("#1d4ed8", "#f59e0b"),
           lwd = c(2, 3), pch = c(16, NA), bty = "n")
  })

  output$group_table <- renderTable({
    analyse <- analyse_rv()
    req(analyse)
    analyse$group_results$trends
  }, striped = TRUE)

  output$group_species_table <- renderTable({
    analyse <- analyse_rv()
    req(analyse, input$selected_group)
    analyse$group_results$composition[
      analyse$group_results$composition$groep_100 == as.integer(input$selected_group),
      c("soort_naam", "engelse_naam", "euring_code")
    ]
  }, striped = TRUE)

  output$coverage_table <- renderTable({
    analyse <- analyse_rv()
    req(analyse)
    basis <- analyse$basis
    cov <- aggregate(geteld ~ kavel_nummer, data = basis, FUN = function(x) sum(x, na.rm = TRUE))
    names(cov)[2] <- "aantal_getelde_jaren"
    cov$totaal_jaren <- length(unique(basis$jaar))
    cov$niet_geteld <- cov$totaal_jaren - cov$aantal_getelde_jaren
    cov[order(cov$kavel_nummer), ]
  }, striped = TRUE)

  output$area_table <- renderTable({
    analyse <- analyse_rv()
    req(analyse)
    basis <- analyse$basis
    out <- aggregate(oppervlakte_km2 ~ jaar, data = basis[basis$geteld, ], FUN = sum, na.rm = TRUE)
    names(out)[2] <- "geteld_oppervlak_km2"
    out
  }, striped = TRUE)

  output$status_table <- renderTable({
    analyse <- analyse_rv()
    req(analyse)
    analyse$species_results$status[, c(
      "soort_naam", "analyse_categorie", "n_positieve_jaren",
      "n_getelde_cellen", "model_gelukt", "fout"
    )]
  }, striped = TRUE)

  output$download_species_trends <- downloadHandler(
    filename = function() {
      sprintf("meijendel_soorttrends_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$species_results$trends, file, row.names = FALSE)
    }
  )

  output$download_species_indices <- downloadHandler(
    filename = function() {
      sprintf("meijendel_soortindices_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$species_results$indices, file, row.names = FALSE)
    }
  )

  output$download_group_trends <- downloadHandler(
    filename = function() {
      sprintf("meijendel_groepstrends_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$group_results$trends, file, row.names = FALSE)
    }
  )

  output$download_group_msi <- downloadHandler(
    filename = function() {
      sprintf("meijendel_groep_msi_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$group_results$msi, file, row.names = FALSE)
    }
  )

  output$download_basis <- downloadHandler(
    filename = function() {
      sprintf("meijendel_analysebasis_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$basis, file, row.names = FALSE)
    }
  )

  output$download_status <- downloadHandler(
    filename = function() {
      sprintf("meijendel_modelstatus_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$species_results$status, file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)
