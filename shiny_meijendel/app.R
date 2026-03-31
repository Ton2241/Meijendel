if (!requireNamespace("shiny", quietly = TRUE)) {
  stop("Package 'shiny' is niet geinstalleerd. Installeer het eerst met install.packages('shiny').")
}
if (!requireNamespace("rtrim", quietly = TRUE)) {
  stop("Package 'rtrim' is niet geinstalleerd. Installeer het eerst voordat je de app start.")
}

source("helpers.R", local = TRUE)

library(shiny)

default_sql <- normalizePath(file.path("..", "Meijendel.sql"), winslash = "/", mustWork = FALSE)

ui <- fluidPage(
  titlePanel("Meijendel TRIM verkenner"),
  tags$p(
    style = "margin-top:-10px;color:#666;",
    "Eerste Shiny-versie voor TRIM per soort en EVG-MSI op vrij gekozen kavels."
  ),
  sidebarLayout(
    sidebarPanel(
      textInput("sql_path", "Pad naar Meijendel.sql", value = default_sql),
      actionButton("load_sql", "SQL laden"),
      textOutput("load_status"),
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
      tags$hr(),
      h4("Korte uitleg"),
      tags$p("Kies eerst kavels en jaren. Klik daarna op 'Analyse uitvoeren'."),
      tags$p("De app maakt dan nieuwe TRIM-berekeningen voor precies die selectie.")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Selectie",
          h3("Huidige selectie"),
          verbatimTextOutput("selection_summary"),
          h4("Beschikbare kavels"),
          tableOutput("selected_plots_table")
        ),
        tabPanel(
          "Soorten",
          uiOutput("species_picker_ui"),
          plotOutput("species_plot", height = "420px"),
          h4("Trend per soort"),
          tableOutput("species_table")
        ),
        tabPanel(
          "Groepen",
          uiOutput("group_picker_ui"),
          plotOutput("group_plot", height = "420px"),
          h4("Trend per groep"),
          tableOutput("group_table"),
          h4("Soorten in gekozen groep"),
          tableOutput("group_species_table")
        ),
        tabPanel(
          "Controle",
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

  observeEvent(input$load_sql, {
    req(nzchar(input$sql_path))
    path <- normalizePath(input$sql_path, winslash = "/", mustWork = TRUE)
    cache_path <- file.path(tempdir(), "meijendel_tables_cache.rds")
    withProgress(message = "SQL wordt gelezen", detail = "Eerste keer kan dit ongeveer 20 seconden duren.", value = 0.1, {
      loaded <- load_meijendel_tables_cached(path, cache_path = cache_path)
      incProgress(0.8)
      tbls_rv(loaded$data)
      if (loaded$from_cache) {
        load_info_rv("SQL geladen uit cache. De kavel-lijst zou nu direct zichtbaar moeten zijn.")
        showNotification("SQL geladen uit cache.", type = "message")
      } else {
        load_info_rv("SQL vers ingelezen. Volgende keer gaat dit veel sneller door de cache.")
        showNotification("SQL geladen. Volgende keer gaat dit sneller.", type = "message")
      }
    })
  }, ignoreInit = FALSE)

  output$load_status <- renderText({
    load_info_rv()
  })

  output$plot_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(tags$p("Laad eerst Meijendel.sql"))
    }
    kavels <- sort(unique(tbls$plots$kavel_nummer))
    selectizeInput(
      "selected_plots",
      "Kavels",
      choices = kavels,
      selected = kavels,
      multiple = TRUE,
      options = list(plugins = list("remove_button"))
    )
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
    validate(need(length(input$selected_plots) > 0, "Kies minstens een kavel."))

    year_from <- as.integer(input$year_from)
    year_to <- as.integer(input$year_to)
    validate(need(year_from <= year_to, "'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'."))

    withProgress(message = "TRIM-analyse draait", value = 0.1, {
      analyse <- analyse_subset(tbls, input$selected_plots, year_from, year_to)
      incProgress(0.9)
      analyse_rv(analyse)
    })
    showNotification("Analyse gereed.", type = "message")
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

    plot(idx$jaar, idx$index_100, type = "o", pch = 16, col = "#157f3b",
         xlab = "Jaar", ylab = "TRIM-index (basisjaar = 100)",
         main = input$selected_species)
    grid()
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
    plot(msi$jaar, msi$msi, type = "o", pch = 16, col = "#1d4ed8",
         xlab = "Jaar", ylab = "MSI",
         main = paste(input$selected_group, "-", title))
    grid()
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
}

shinyApp(ui, server)
