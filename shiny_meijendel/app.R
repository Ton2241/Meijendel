if (!requireNamespace("shiny", quietly = TRUE)) {
  stop("Package 'shiny' is niet geinstalleerd. Installeer het eerst met install.packages('shiny').")
}
if (!requireNamespace("rtrim", quietly = TRUE)) {
  stop("Package 'rtrim' is niet geinstalleerd. Installeer het eerst voordat je de app start.")
}
if (!requireNamespace("mgcv", quietly = TRUE)) {
  stop("Package 'mgcv' is niet geinstalleerd. Installeer het eerst voordat je de app start.")
}
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("Package 'bslib' is niet geinstalleerd. Installeer het eerst voordat je de app start.")
}

source("helpers.R", local = TRUE)

library(shiny)

default_sql_candidates <- c("../Meijendel.sql", "Meijendel.sql")
default_sql <- default_sql_candidates[file.exists(default_sql_candidates)][1]
if (is.na(default_sql)) {
  default_sql <- "Meijendel.sql"
}
default_sql <- normalizePath(default_sql, winslash = "/", mustWork = FALSE)


ui <- navbarPage(
  title = "Statistische Analyses Vogelterritoriadata",
  theme = bslib::bs_theme(version = 5, bootswatch = "flatly"),
  header = tags$head(
    tags$style(HTML("
      .app-subtitle { color:#4b5563; margin-top:-12px; margin-bottom:18px; }
      .navbar .navbar-nav,
      .navbar-nav {
        float: none !important;
        display: flex !important;
        flex-direction: row !important;
        flex-wrap: wrap !important;
        align-items: center !important;
        gap: 18px !important;
      }
      .navbar .navbar-nav > li,
      .navbar-nav > li {
        float: none !important;
        width: auto !important;
        margin-right: 0 !important;
        display: block !important;
      }
      .navbar .navbar-nav > li > a,
      .navbar-nav > li > a {
        display: inline-block !important;
        white-space: nowrap;
      }
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
      .load-timer {
        display:inline-block; margin-left:10px; color:#475569; font-size:14px;
      }
    "))
    ,
    tags$script(HTML("
      (function() {
        var timerId = null;
        var startTime = null;

        function formatElapsed(seconds) {
          var mins = Math.floor(seconds / 60);
          var secs = seconds % 60;
          return mins + ':' + String(secs).padStart(2, '0');
        }

        function timerEl() {
          return document.getElementById('sql_load_timer');
        }

        function setTimerText(text) {
          var el = timerEl();
          if (el) el.textContent = text;
        }

        function startTimer() {
          if (timerId) window.clearInterval(timerId);
          startTime = Date.now();
          setTimerText('laden: 0:00');
          timerId = window.setInterval(function() {
            var elapsed = Math.floor((Date.now() - startTime) / 1000);
            setTimerText('laden: ' + formatElapsed(elapsed));
          }, 1000);
        }

        function stopTimer() {
          if (timerId) window.clearInterval(timerId);
          timerId = null;
          var elapsed = startTime ? Math.floor((Date.now() - startTime) / 1000) : 0;
          setTimerText(elapsed > 0 ? 'geladen in ' + formatElapsed(elapsed) : '');
        }

        document.addEventListener('click', function(event) {
          if (event.target && event.target.id === 'load_sql') startTimer();
        });

        new MutationObserver(function() {
          var status = document.getElementById('load_status');
          if (!status || !timerId) return;
          var text = status.textContent || '';
          if (text.indexOf('SQL geladen') >= 0 || text.indexOf('Fout bij SQL laden') >= 0) {
            stopTimer();
          }
        }).observe(document.body, { childList: true, subtree: true, characterData: true });

        function autoLoadSql() {
          if (window.__meijendelSqlAutoLoadDone) return;
          window.__meijendelSqlAutoLoadDone = true;
          window.setTimeout(function() {
            var button = document.getElementById('load_sql');
            if (button) button.click();
          }, 800);
        }

        document.addEventListener('DOMContentLoaded', function() {
          window.setTimeout(autoLoadSql, 1500);
        });
        document.addEventListener('shiny:connected', autoLoadSql);
      })();
    "))
  ),
  tabPanel(
    "Startpagina",
    fluidPage(
      titlePanel("Statistische Analyses Vogelterritoriadata"),
      tags$p(
        class = "app-subtitle",
        "Vogelterritoriadata 1958-heden, ruimtelijke data, beheeringrepen, recreatie en weer."
      ),
      fluidRow(
        column(
          width = 6,
          div(
            class = "soft-card",
            h3("SQL-bron laden"),
            textInput("sql_path", "Pad naar Meijendel.sql", value = default_sql),
            actionButton("load_sql", "SQL laden"),
            tags$span(id = "sql_load_timer", class = "load-timer"),
            div(class = "status-box",
                tags$span(class = "status-label", "Status SQL"),
                textOutput("load_status"))
          )
        ),
        column(
          width = 6,
          div(
            class = "soft-card",
            h3("Korte uitleg"),
            tags$p("Op deze startpagina laad je eerst de SQL-bron voor de analyses."),
            tags$p("Ga daarna naar TRIM, LAMBDA of G.E.E. om de gewenste analyses uit te voeren. Kies daar of je de analyses voor vogelsoorten en/of vogelgroepen wil doen en selecteer de kavels en jaren."),
            tags$p(
              class = "section-note",
              "Meer informatie over TRIM, LAMBDA, G.E.E., GAM-grafieken en de beschrijving van de onderscheiden vogelgroepen vind je in de tekstblokken hieronder."
            )
          )
        )
      ),
      fluidRow(
        column(
          width = 12,
          div(
            class = "soft-card",
            tags$ol(
              tags$li("TRIM"),
              tags$li("LAMBDA"),
              tags$li("G.E.E."),
              tags$li("GAM"),
              tags$li("Vogelgroepen")
            ),
            h4("TRIM"),
            tags$p("TRIM (TRends and Indices for Monitoring data) is een door het Centraal Bureau voor de Statistiek ontwikkeld statistisch model voor analyse van telreeksen met ontbrekende waarnemingen. Het zet tellingen om in indexcijfers (basisjaar = 100) en schat ontbrekende waarden op basis van trends in andere meetpunten. De methode corrigeert voor scheve bemonstering en levert robuuste trend- en trendklasse-schattingen. Statistisch is TRIM gebaseerd op loglineaire Poisson-regressie met correctie voor overdispersie en autocorrelatie. Het wordt binnen het Netwerk Ecologische Monitoring gebruikt voor trendanalyse van soorten. Een deel van de territoria data is niet volgens de gestandaardiseerde landelijke SOVON-methode geinterpreteerd. Dit geldt o.a. voor de periode 1958-1983 in Meijendel. In de TRIM analyses wordt, bij gebruik van data voor 1984, gewerkt met brugjaren om de TRIM data vergelijkbaar te maken. Het betreft de jaren 1981-1982-1983 en de jaren 1984-1985-1986."),
            h4("LAMBDA"),
            tags$p("De LAMBDA-methode beschrijft populatieverandering via de groeifactor λ, gedefinieerd als de verhouding tussen aantallen in opeenvolgende jaren (λ = Nₜ₊₁ / Nₜ). Een waarde λ > 1 duidt op groei, λ < 1 op afname en λ = 1 op stabiliteit. Door λ per jaar te berekenen ontstaat een tijdreeks van relatieve veranderingen, die eenvoudig te middelen of cumuleren is. De methode vereist consistente tellingen en is gevoelig voor nulwaarden en waarnemingsfouten. Om die reden zijn sporadisch verschijnende soorten niet meegenomen in de berekening van de MSI van de vogelgroepen. In de praktijk wordt vaak gewerkt met log-transformaties van λ om trends statistisch stabieler te analyseren. LAMBDA gebruikt drie T0-perioden: 1959-1972 (T0=1959), 1973-1983 (T0=1973) en 1984-heden (T0=1984)."),
            h4("G.E.E."),
            tags$p("G.E.E. (Generalized Estimating Equations) is een methode voor de analyse van gecorreleerde gegevens. De methode is relatief robuust bij misspecificatie en levert consistente schattingen, ook bij onregelmatige tellingen en ontbrekende waarnemingen. Binnen de app is G.E.E. bedoeld voor verklarende analyse, niet voor trendbeschrijving. Het vormt een derde analysetype naast TRIM en LAMBDA, gericht op het schatten van effecten van covariaten zoals beheer, recreatie, weer en habitat bij herhaalde plotmetingen. In de app kun je kiezen tussen vier verschillende correlatiestructuren (Ar1, exchangeable, unstructured en independence). Voor Meijendel is de praktische aanpak om te starten met Ar1 en daarna vergelijken met exchangeable. Als de resultaten nauwelijks veranderen dan zijn de uitkomsten robuust. Dat kan je dan eventueel nog controleren met independence. Bij de autoregressive 1 variant (Ar1) neemt G.E.E. aan dat de correlatie afneemt met de tijd, wat ecologisch zeer logisch is. Successie verloopt geleidelijk, beheer werkt door en populaties hebben traagheid, dus nabije jaren lijken meer op elkaar dan verre jaren. Bij de exchangeable-variant neemt G.E.E. aan dat alle jaren binnen een plot dezelfde correlatie hebben. Een plot heeft een “algemene kwaliteit”, tijdsafstand maakt niet uit. In de unstructured-variant schat G.E.E. schat elke correlatie afzonderlijk. Je gebruikt het als je alle mogelijke factoren wilt testen, dus ook de factoren die mogelijk geen invloed hebben. In de Independence-variant neemt GEE aan dat alle jaren binnen een plot onafhankelijk zijn. Dat is voor Meijendel ecologisch onrealistisch en te simpel."),
            h4("GAM"),
            tags$p("In deze app wordt gebruik gemaakt van GAM. GAM (Generalized Additive Model) is een flexibele statistische methode die relaties modelleert zonder een vaste functionele vorm op te leggen. Het model beschrijft de responsvariabele als som van gladde (niet-lineaire) functies van verklarende variabelen. Hiermee kunnen complexe, niet-lineaire trends in tijdreeksen van ecologische data worden geschat en grafisch weergegeven."),
            h4("Vogelgroepen"),
            tags$p("De ", tags$strong("ecologische vogelgroepen"), " van Piet Sierdsema zijn een indeling van vogelsoorten op basis van hun habitatvoorkeur en ecologische functie. Soorten worden gegroepeerd in: 100 - Watervogels, 200 - Rietvogels, 300 - Vogels van pionierbegroeiingen, 400 - Vogels van open heide, 500 - Weidevogels, 600 - Struweelvogels, 700 - Bosrandvogels, 800 - Bosvogels, 900 - Vogels van bebouwing/overige."),
            tags$p("De ", tags$strong("Rode Lijst"), " van Nederlandse broedvogels bevat soorten die bedreigd worden of kwetsbaar zijn. De laatste actualisatie van de Rode Lijst van de Nederlandse broedvogels werd in 2017 vastgesteld door het Ministerie van Landbouw, Natuur en Voedselkwaliteit. De rode lijst wordt verdeeld in vijf categorieën: RL: Verdwenen, RL: Ernstig bedreigd, RL: Bedreigd, RL: Kwetsbaar en RL: Gevoelig."),
            tags$p("De Rode Lijst wordt eens in de 10 jaar geactualiseerd. Om tussentijds zicht op veranderingen te houden is de ", tags$strong("Oranje Lijst"), " ontwikkeld. Daarop staan 22 soorten die nog niet aan de criteria van de Rode Lijst voldoen maar waarvan wordt aangenomen dat ze dat in de nabije toekomst zullen gaan doen.")
          )
        )
      )
    )
  ),
  tabPanel(
    "TRIM",
    fluidPage(
      titlePanel("TRIM-verkenner"),
      tags$p(class = "app-subtitle", "Trends en Indices voor Monitoringdata (cbs.nl)"),
      sidebarLayout(
        sidebarPanel(
          class = "soft-card",
          uiOutput("plot_selector_ui"),
          uiOutput("year_selector_ui"),
          checkboxGroupInput(
            "analyse_keuze",
            "Wat berekenen",
            choices = c("Soorten" = "species", "Vogelgroepen" = "groups", "Rode/Oranje Lijst" = "richtlijnen"),
            selected = c("species", "groups", "richtlijnen")
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
              tags$p(class = "section-note", "Groen: TRIM-index per jaar. Oranje: gladde GAM-lijn. Lichtoranje band: variatiezone rond de GAM-lijn."),
              tags$p(class = "section-note", "Download hier de TRIM-uitkomsten per soort: trendoverzicht en indexreeks."),
              plotOutput("species_plot", height = "420px"),
              div(class = "download-row",
                  downloadButton("download_species_trends", "CSV TRIM-trends"),
                  downloadButton("download_species_indices", "CSV TRIM-indices")),
              h4("Trend per soort"),
              tableOutput("species_table")
            ),
            tabPanel(
              "Groepen",
              uiOutput("group_picker_ui"),
              tags$p(class = "section-note", "Blauw: MSI per jaar. Oranje: gladde GAM-lijn. Lichtoranje band: variatiezone rond de GAM-lijn."),
              tags$p(class = "section-note", "Download hier de groepsuitkomsten: trendoverzicht en MSI per jaar."),
              plotOutput("group_plot", height = "420px"),
              div(class = "download-row",
                  downloadButton("download_group_trends", "CSV groepstrends"),
                  downloadButton("download_group_msi", "CSV MSI per groep")),
              h4("Trend per groep"),
              tableOutput("group_table"),
              h4("Soorten in gekozen groep"),
              tableOutput("group_species_table")
            ),
            tabPanel(
              "Rode/Oranje Lijst",
              uiOutput("richtlijn_picker_ui"),
              tags$p(class = "section-note", "Blauw: MSI per jaar. Oranje: gladde GAM-lijn. Lichtoranje band: variatiezone rond de GAM-lijn."),
              tags$p(class = "section-note", "Download hier de uitkomsten per Rode/Oranje Lijst-categorie: trendoverzicht en MSI per jaar."),
              plotOutput("richtlijn_plot", height = "420px"),
              div(class = "download-row",
                  downloadButton("download_richtlijn_trends", "CSV richtlijntrends"),
                  downloadButton("download_richtlijn_msi", "CSV MSI per richtlijn")),
              h4("Trend per categorie"),
              tableOutput("richtlijn_table"),
              h4("Soorten in gekozen categorie"),
              tableOutput("richtlijn_species_table")
            ),
            tabPanel(
              "Controle",
              tags$p(class = "section-note", "Gebruik deze tab om te controleren of de selectie logisch is opgebouwd: dekking per kavel, oppervlak per jaar en modelstatus van soorten."),
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
  ),
  tabPanel(
    "LAMBDA",
    fluidPage(
      titlePanel("LAMBDA"),
      tags$p(class = "app-subtitle", "Jaar-op-jaar verandering op basis van T0-reeksen."),
      fluidRow(
        column(
          width = 12,
          div(
            class = "soft-card",
            h3("Uitgangspunt in Meijendel"),
            tags$p("De T0-aanpak kijkt niet primair naar absolute niveaus vóór en na 1984, maar naar de verandering van jaar op jaar."),
            tags$p("Daarmee vergelijk je vooral de dynamiek van de tijdreeksen en minder de methodegevoelige niveauverschillen."),
            tags$ul(
              tags$li("pre-1984 en post-1984 blijven methodisch gescheiden"),
              tags$li("per reeks wordt eerst genormaliseerd op T0"),
              tags$li("daarna wordt de jaar-op-jaar verandering berekend")
            )
          )
        )
      ),
      sidebarLayout(
        sidebarPanel(
          class = "soft-card",
          uiOutput("lambda_plot_selector_ui"),
          uiOutput("lambda_year_selector_ui"),
          checkboxGroupInput(
              "lambda_analyse_keuze",
              "Wat berekenen",
              choices = c("Vogelsoorten" = "species", "Vogelgroepen" = "groups", "Rode/Oranje Lijst" = "richtlijnen"),
            selected = c("species", "groups", "richtlijnen")
          ),
          actionButton("run_lambda_analysis", "LAMBDA berekenen", class = "btn-primary"),
          div(
            class = "status-box",
            tags$span(class = "status-label", "Status LAMBDA"),
            textOutput("lambda_analysis_status")
          ),
          tags$hr(),
          h4("Korte uitleg"),
          tags$p("1958 wordt genegeerd. LAMBDA gebruikt drie T0-perioden: 1959-1972, 1973-1983 en 1984-heden."),
          tags$p("De methodebreuken tussen deelreeksen worden hier niet gebrugd. De analyse toont dynamiek per deelreeks op basis van T0 en jaar-op-jaar verandering.")
        ),
        mainPanel(
          tabsetPanel(
            tabPanel(
              "Selectie",
              h3("Huidige selectie"),
              verbatimTextOutput("lambda_selection_summary"),
              h4("Geselecteerde kavels"),
              tableOutput("lambda_selected_plots_table")
            ),
            tabPanel(
              "Soorten",
              uiOutput("lambda_species_picker_ui"),
              tags$p(class = "section-note", "Grafiek toont de jaar-op-jaar verandering per deelreeks als percentage."),
              uiOutput("lambda_species_note_ui"),
              plotOutput("lambda_species_plot", height = "420px"),
              div(
                class = "download-row",
                downloadButton("download_lambda_species_years", "CSV LAMBDA soortjaren"),
                downloadButton("download_lambda_species_summary", "CSV LAMBDA soorten")
              ),
              h4("Soortoverzicht"),
              tableOutput("lambda_species_table")
            ),
            tabPanel(
              "Groepen",
              uiOutput("lambda_group_picker_ui"),
              tags$p(class = "section-note", "Grafiek toont de jaar-op-jaar verandering per vogelgroep als percentage, gebaseerd op soorten die voldoen aan de strengere T0-MSI-selectie."),
              plotOutput("lambda_group_plot", height = "420px"),
              div(
                class = "download-row",
                downloadButton("download_lambda_group_years", "CSV LAMBDA groepjaren"),
                downloadButton("download_lambda_group_summary", "CSV LAMBDA groepen")
              ),
              h4("Groepsoverzicht"),
              tableOutput("lambda_group_table"),
              h4("Soorten in gekozen groep"),
              tableOutput("lambda_group_species_table")
            ),
            tabPanel(
              "Rode/Oranje Lijst",
              uiOutput("lambda_richtlijn_picker_ui"),
              tags$p(class = "section-note", "Grafiek toont de jaar-op-jaar verandering per Rode/Oranje Lijst-categorie als percentage, gebaseerd op soorten die voldoen aan de strengere T0-MSI-selectie."),
              plotOutput("lambda_richtlijn_plot", height = "420px"),
              div(
                class = "download-row",
                downloadButton("download_lambda_richtlijn_years", "CSV LAMBDA richtlijnjaren"),
                downloadButton("download_lambda_richtlijn_summary", "CSV LAMBDA richtlijnen")
              ),
              h4("Categorieoverzicht"),
              tableOutput("lambda_richtlijn_table"),
              h4("Soorten in gekozen categorie"),
              tableOutput("lambda_richtlijn_species_table")
            ),
            tabPanel(
              "Controle",
              tags$p(class = "section-note", "Gebruik deze tab om te controleren welke soorten geschikt zijn voor T0-soortanalyse en welke streng genoeg zijn voor T0-MSI."),
              h4("Dekking per kavel"),
              tableOutput("lambda_coverage_table"),
              h4("LAMBDA-status soorten"),
              tableOutput("lambda_status_table")
            )
          )
        )
      )
    )
  ),
  tabPanel(
    "G.E.E.",
    fluidPage(
      titlePanel("G.E.E."),
      tags$p(class = "app-subtitle", "Verklarende analyse van covariaten op herhaalde plotmetingen."),
      fluidRow(
        column(
          4,
          div(
            class = "soft-card",
            h3("Selectie"),
            uiOutput("gee_plot_selector_ui"),
            uiOutput("gee_year_selector_ui"),
            radioButtons(
              "gee_mode",
              "G.E.E.-modus",
              choices = c("Reguliere analyse" = "regular", "Kenmerkenanalyse" = "traits"),
              selected = "regular",
              inline = FALSE
            ),
            conditionalPanel(
              "input.gee_mode == 'regular'",
              radioButtons(
                "gee_target_type",
                "Analyse-niveau",
                choices = c("Soort" = "species", "Vogelgroep" = "group", "Rode/Oranje Lijst" = "richtlijn"),
                selected = "species",
                inline = TRUE
              ),
              uiOutput("gee_target_picker_ui")
            ),
            uiOutput("gee_trait_controls_ui"),
            selectInput(
              "gee_corstr",
              "Correlatiestructuur",
              choices = c(
                "Ar1" = "ar1",
                "exchangeable" = "exchangeable",
                "independence" = "independence",
                "unstructured" = "unstructured"
              ),
              selected = "ar1"
            ),
            conditionalPanel(
              "input.gee_mode == 'regular'",
              checkboxGroupInput(
                "gee_covariates",
                "Vaste Covariaten",
                choices = setNames(
                  gee_covariate_specs()$code,
                  gee_covariate_specs()$label
                ),
                selected = c("stikstof_mean", "toegankelijkheid_status")
              ),
              uiOutput("gee_ahn_covariate_ui"),
              uiOutput("gee_infra_covariate_ui"),
              uiOutput("gee_habitat_covariate_ui")
            ),
            actionButton("run_gee_analysis", "Voer G.E.E.-analyse uit", class = "btn-primary")
          )
        ),
        column(
          8,
          div(
            class = "soft-card",
            h3("Modelstatus"),
            textOutput("gee_analysis_status"),
            tags$div(style = "margin-top:12px;"),
            verbatimTextOutput("gee_selection_summary")
          ),
          div(
            class = "soft-card",
            h3("Effectschattingen"),
            tags$p(class = "section-note", "De grafiek toont Incident Rate Ratios (IRR) met 95%-betrouwbaarheidsinterval. Jaar wordt hier als controlevariabele behandeld, niet als aparte trendmodule."),
            plotOutput("gee_coef_plot", height = "420px"),
            div(
              class = "download-row",
              downloadButton("download_gee_coefficients", "CSV G.E.E. coefs"),
              downloadButton("download_gee_dataset", "CSV G.E.E. dataset")
            ),
            h4("Coefficienten"),
            tableOutput("gee_coef_table"),
            h4("Gebruikte kavels"),
            tableOutput("gee_plot_usage_table"),
            h4("Gebruikte plot-jaren"),
            tableOutput("gee_dataset_table")
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  tbls_rv <- reactiveVal(NULL)
  analyse_rv <- reactiveVal(NULL)
  lambda_analyse_rv <- reactiveVal(NULL)
  gee_analyse_rv <- reactiveVal(NULL)
  load_info_rv <- reactiveVal("Nog geen SQL geladen.")
  analysis_info_rv <- reactiveVal("Nog geen analyse uitgevoerd.")
  lambda_analysis_info_rv <- reactiveVal("Nog geen LAMBDA-analyse uitgevoerd.")
  gee_analysis_info_rv <- reactiveVal("Nog geen G.E.E.-analyse uitgevoerd.")

  draw_lambda_period_lines <- function(idx) {
    specs <- lambda_period_specs()
    used_labels <- character()
    used_cols <- character()
    for (i in seq_len(nrow(specs))) {
      part <- idx[idx$periode == specs$periode[[i]], , drop = FALSE]
      if (nrow(part)) {
        lines(part$jaar, part$lambda_pct, type = "o", pch = 16, lwd = 2, col = specs$kleur[[i]])
        used_labels <- c(used_labels, specs$periode[[i]])
        used_cols <- c(used_cols, specs$kleur[[i]])
      }
    }
    list(labels = c(used_labels, "0% = stabiel"), cols = c(used_cols, "#64748b"))
  }

  observeEvent(input$load_sql, {
    req(nzchar(input$sql_path))
    load_info_rv("SQL wordt geladen...")
    tryCatch({
      path <- normalizePath(input$sql_path, winslash = "/", mustWork = TRUE)
      cache_path <- file.path(tempdir(), "meijendel_tables_cache.rds")
      withProgress(message = "SQL wordt gelezen.", detail = "Dit kan even duren afhankelijk van het werkgeheugen van de server.", value = 0.1, {
        loaded <- load_meijendel_tables_cached(path, cache_path = cache_path)
        incProgress(0.8)
        tbls_rv(loaded$data)
        if (loaded$from_cache) {
          load_info_rv(sprintf("SQL geladen uit cache: %s", path))
          showNotification("SQL geladen uit cache.", type = "message", duration = 4)
        } else {
          load_info_rv(sprintf("SQL vers ingelezen: %s", path))
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

  output$lambda_analysis_status <- renderText({
    lambda_analysis_info_rv()
  })

  output$gee_analysis_status <- renderText({
    gee_analysis_info_rv()
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

  output$lambda_plot_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(tags$p("Laad eerst Meijendel.sql"))
    }
    kavels <- sort(unique(tbls$plots$kavel_nummer))
    tagList(
      tags$p(class = "section-note", "Klik kavels aan om ze toe te voegen. Gebruik de knoppen hieronder om snel alles of niets te kiezen."),
      fluidRow(
        column(6, actionButton("lambda_select_all_plots", "Alle kavels", width = "100%")),
        column(6, actionButton("lambda_clear_all_plots", "Geen kavels", width = "100%"))
      ),
      selectizeInput(
        "lambda_selected_plots",
        "Kavels",
        choices = kavels,
        selected = character(0),
        multiple = TRUE,
        options = list(plugins = list("remove_button"))
      )
    )
  })

  observeEvent(input$lambda_select_all_plots, {
    tbls <- tbls_rv()
    req(tbls)
    kavels <- sort(unique(tbls$plots$kavel_nummer))
    updateSelectizeInput(session, "lambda_selected_plots", selected = kavels)
  })

  observeEvent(input$lambda_clear_all_plots, {
    updateSelectizeInput(session, "lambda_selected_plots", selected = character(0))
  })

  output$lambda_year_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(NULL)
    }
    years <- sort(unique(tbls$plot_jaar_oppervlak$jaar))
    years <- years[years != 1958L]
    tagList(
      selectInput("lambda_year_from", "Van jaar", choices = years, selected = min(years)),
      selectInput("lambda_year_to", "Tot jaar", choices = years, selected = max(years))
    )
  })

  output$gee_plot_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(tags$p("Laad eerst Meijendel.sql"))
    }
    kavels <- sort(unique(tbls$plots$kavel_nummer))
    selectizeInput(
      "gee_selected_plots",
      "Kavel(s)",
      choices = kavels,
      selected = character(0),
      multiple = TRUE,
      options = list(plugins = list("remove_button"))
    )
  })

  output$gee_year_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(NULL)
    }
    years <- sort(unique(tbls$plot_jaar_oppervlak$jaar))
    tagList(
      selectInput("gee_year_from", "Van jaar", choices = years, selected = max(min(years), 1984)),
      selectInput("gee_year_to", "Tot jaar", choices = years, selected = max(years))
    )
  })

  output$gee_target_picker_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(NULL)
    }
    if (identical(input$gee_target_type, "group")) {
      groepen <- build_group_mapping(tbls)
      groepen <- unique(groepen[, c("groep_100", "groep_titel")])
      groepen <- groepen[order(groepen$groep_100), , drop = FALSE]
      choices <- setNames(groepen$groep_100, paste0(groepen$groep_100, " - ", groepen$groep_titel))
      return(selectizeInput("gee_group", "Vogelgroep", choices = choices, selected = groepen$groep_100[[1]], multiple = FALSE))
    }
    if (identical(input$gee_target_type, "richtlijn")) {
      richtlijnen <- build_richtlijn_mapping(tbls)
      richtlijnen <- unique(richtlijnen[, c("richtlijn_id", "richtlijn_titel", "richtlijn_volgorde")])
      richtlijnen <- richtlijnen[order(richtlijnen$richtlijn_volgorde), , drop = FALSE]
      choices <- setNames(richtlijnen$richtlijn_id, richtlijnen$richtlijn_titel)
      return(selectizeInput("gee_richtlijn", "Rode/Oranje Lijst", choices = choices, selected = richtlijnen$richtlijn_id[[1]], multiple = FALSE))
    }
    soorten <- sort(tbls$soorten$soort_naam)
    selectizeInput("gee_species", "Soort", choices = soorten, selected = "Nachtegaal", multiple = FALSE)
  })

  output$gee_trait_controls_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls) || !identical(input$gee_mode, "traits")) {
      return(NULL)
    }
    catalog <- build_soort_kenmerken_catalog(tbls)
    validate(need(nrow(catalog) > 0, "Geen soortkenmerken beschikbaar in deze SQL."))
    hoofdcats <- unique(catalog[, c("hoofdcategorie_id", "hoofdcategorie_label")])
    hoofdcats <- hoofdcats[order(hoofdcats$hoofdcategorie_id), , drop = FALSE]
    group_mapping <- build_group_mapping(tbls)
    groepen <- unique(group_mapping[, c("groep_100", "groep_titel")])
    groepen <- groepen[order(groepen$groep_100), , drop = FALSE]
    richtlijnen <- build_richtlijn_mapping(tbls)
    richtlijnen <- unique(richtlijnen[, c("richtlijn_id", "richtlijn_titel", "richtlijn_volgorde")])
    richtlijnen <- richtlijnen[order(richtlijnen$richtlijn_volgorde), , drop = FALSE]
    tagList(
      tags$hr(),
      h4("Kenmerkenanalyse"),
      radioButtons(
        "gee_trait_scope",
        "Soortselectie",
        choices = c("Alle soorten" = "all", "Vogelgroep" = "group", "Rode/Oranje Lijst" = "richtlijn"),
        selected = "all"
      ),
      conditionalPanel(
        "input.gee_trait_scope == 'group'",
        selectizeInput("gee_trait_group", "Vogelgroep", choices = setNames(groepen$groep_100, groepen$groep_titel), selected = groepen$groep_100[[1]], multiple = FALSE)
      ),
      conditionalPanel(
        "input.gee_trait_scope == 'richtlijn'",
        selectizeInput("gee_trait_richtlijn", "Rode/Oranje Lijst", choices = setNames(richtlijnen$richtlijn_id, richtlijnen$richtlijn_titel), selected = richtlijnen$richtlijn_id[[1]], multiple = FALSE)
      ),
      selectInput(
        "gee_trait_hoofdcategorie",
        "Hoofdcategorie kenmerken",
        choices = setNames(hoofdcats$hoofdcategorie_id, hoofdcats$hoofdcategorie_label),
        selected = hoofdcats$hoofdcategorie_id[[1]]
      ),
      checkboxGroupInput(
        "gee_trait_code_types",
        "Diepgang",
        choices = c("Hoofdkenmerken" = "main", "Subkenmerken" = "sub", "Detailkenmerken" = "detail"),
        selected = c("main")
      ),
      numericInput("gee_trait_min_species", "Minimum soorten met en zonder kenmerk", value = 5, min = 3, max = 25, step = 1),
      tags$p(class = "section-note", "De screening toetst per kenmerk de interactie jaar x kenmerk: het verschil in ontwikkeling tussen soorten met en zonder dat kenmerk.")
    )
  })

  output$gee_ahn_covariate_ui <- renderUI({
    specs <- gee_ahn_covariate_specs()
    selectizeInput(
      "gee_ahn_covariates",
      "AHN",
      choices = setNames(specs$code, specs$label),
      selected = c("ahn_mean"),
      multiple = TRUE,
      options = list(plugins = list("remove_button"))
    )
  })

  output$gee_infra_covariate_ui <- renderUI({
    specs <- gee_infra_covariate_specs()
    selectizeInput(
      "gee_infra_covariates",
      "Infra & recreatie",
      choices = setNames(specs$code, specs$label),
      selected = c("afstand_pad_m"),
      multiple = TRUE,
      options = list(plugins = list("remove_button"))
    )
  })

  output$gee_habitat_covariate_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(NULL)
    }
    specs <- gee_habitat_covariate_specs(tbls)
    if (!nrow(specs)) {
      return(tags$p(class = "section-note", "Geen habitattypen beschikbaar. Laad de SQL opnieuw zodat de vernieuwde cache wordt opgebouwd."))
    }
    selectizeInput(
      "gee_habitat_covariates",
      "Habitattypen",
      choices = setNames(specs$code, specs$label),
      selected = character(0),
      multiple = TRUE,
      options = list(plugins = list("remove_button"))
    )
  })

  observeEvent(input$gee_mode, {
    if (identical(input$gee_mode, "traits")) {
      updateSelectInput(session, "gee_corstr", selected = "independence")
    } else if (identical(input$gee_mode, "regular")) {
      updateSelectInput(session, "gee_corstr", selected = "ar1")
    }
  }, ignoreInit = TRUE)

  observeEvent(input$run_analysis, {
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      analysis_info_rv("Laad eerst Meijendel.sql.")
      showNotification("Laad eerst Meijendel.sql.", type = "error", duration = 5)
      return()
    }
    if (is.null(input$year_from) || is.null(input$year_to)) {
      analysis_info_rv("Wacht tot de jarenselectie geladen is.")
      showNotification("Wacht tot de jarenselectie geladen is.", type = "error", duration = 5)
      return()
    }
    selected_plots <- if (is.null(input$selected_plots)) character(0) else input$selected_plots
    if (length(selected_plots) == 0) {
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
        analyse <- analyse_subset(tbls, selected_plots, year_from, year_to)
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

  observeEvent(input$run_lambda_analysis, {
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      lambda_analysis_info_rv("Laad eerst Meijendel.sql.")
      showNotification("Laad eerst Meijendel.sql.", type = "error", duration = 5)
      return()
    }
    if (is.null(input$lambda_year_from) || is.null(input$lambda_year_to)) {
      lambda_analysis_info_rv("Wacht tot de jarenselectie geladen is.")
      showNotification("Wacht tot de jarenselectie geladen is.", type = "error", duration = 5)
      return()
    }
    selected_plots <- if (is.null(input$lambda_selected_plots)) character(0) else input$lambda_selected_plots
    if (length(selected_plots) == 0) {
      lambda_analysis_info_rv("Kies eerst minstens één kavel.")
      showNotification("Kies eerst minstens één kavel.", type = "error", duration = 5)
      return()
    }
    if (length(input$lambda_analyse_keuze) == 0) {
      lambda_analysis_info_rv("Kies eerst of je vogelsoorten, vogelgroepen en/of Rode/Oranje Lijst wilt analyseren.")
      showNotification("Kies eerst wat je wilt berekenen.", type = "error", duration = 5)
      return()
    }

    year_from <- as.integer(input$lambda_year_from)
    year_to <- as.integer(input$lambda_year_to)
    if (year_from > year_to) {
      lambda_analysis_info_rv("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.")
      showNotification("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.", type = "error", duration = 5)
      return()
    }

    lambda_analysis_info_rv("LAMBDA-analyse draait...")
    tryCatch({
      withProgress(message = "LAMBDA-analyse draait", detail = "T0-reeksen en jaar-op-jaar veranderingen worden opgebouwd.", value = 0.1, {
        analyse <- analyse_lambda_subset(tbls, selected_plots, year_from, year_to)
        if (nrow(analyse$species_results$yearly) == 0) {
          stop("Geen bruikbare LAMBDA-data in deze selectie. Controleer jaren en kavels.")
        }
        incProgress(0.9)
        lambda_analyse_rv(analyse)
      })
      lambda_analysis_info_rv("LAMBDA-analyse gereed.")
      showNotification("LAMBDA-analyse gereed.", type = "message", duration = 4)
    }, error = function(e) {
      lambda_analysis_info_rv(paste("Fout bij LAMBDA-analyse:", conditionMessage(e)))
      showNotification(paste("Fout bij LAMBDA-analyse:", conditionMessage(e)), type = "error", duration = NULL)
    })
  })

  observeEvent(input$run_gee_analysis, {
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      gee_analysis_info_rv("Laad eerst Meijendel.sql.")
      showNotification("Laad eerst Meijendel.sql.", type = "error", duration = 5)
      return()
    }
    gee_mode <- if (is.null(input$gee_mode)) "regular" else input$gee_mode
    if (is.null(input$gee_year_from) || is.null(input$gee_year_to)) {
      gee_analysis_info_rv("Wacht tot de selectievelden geladen zijn.")
      showNotification("Wacht tot de selectievelden geladen zijn.", type = "error", duration = 5)
      return()
    }
    selected_plots <- if (is.null(input$gee_selected_plots)) character(0) else input$gee_selected_plots
    if (length(selected_plots) == 0) {
      gee_analysis_info_rv("Kies eerst minstens één kavel.")
      showNotification("Kies eerst minstens één kavel.", type = "error", duration = 5)
      return()
    }
    year_from <- as.integer(input$gee_year_from)
    year_to <- as.integer(input$gee_year_to)
    if (year_from > year_to) {
      gee_analysis_info_rv("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.")
      showNotification("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.", type = "error", duration = 5)
      return()
    }

    if (identical(gee_mode, "traits")) {
      if (is.null(input$gee_trait_scope) || is.null(input$gee_trait_hoofdcategorie) || is.null(input$gee_trait_code_types) || !length(input$gee_trait_code_types)) {
        gee_analysis_info_rv("Kies eerst een kenmerkenselectie.")
        showNotification("Kies eerst een kenmerkenselectie.", type = "error", duration = 5)
        return()
      }
      scope_value <- NULL
      if (identical(input$gee_trait_scope, "group")) {
        scope_value <- input$gee_trait_group
        if (is.null(scope_value) || !nzchar(scope_value)) {
          gee_analysis_info_rv("Kies eerst een vogelgroep.")
          showNotification("Kies eerst een vogelgroep.", type = "error", duration = 5)
          return()
        }
      } else if (identical(input$gee_trait_scope, "richtlijn")) {
        scope_value <- input$gee_trait_richtlijn
        if (is.null(scope_value) || !nzchar(scope_value)) {
          gee_analysis_info_rv("Kies eerst een Rode/Oranje Lijst-categorie.")
          showNotification("Kies eerst een Rode/Oranje Lijst-categorie.", type = "error", duration = 5)
          return()
        }
      }
      gee_analysis_info_rv("G.E.E.-kenmerkenanalyse draait...")
      tryCatch({
        withProgress(message = "G.E.E.-kenmerkenanalyse draait", detail = "Soortkenmerken worden een voor een getoetst.", value = 0.1, {
          analyse <- run_gee_trait_screening(
            tbls = tbls,
            selected_kavels = selected_plots,
            year_from = year_from,
            year_to = year_to,
            scope_type = input$gee_trait_scope,
            scope_value = scope_value,
            hoofdcategorie_id = input$gee_trait_hoofdcategorie,
            code_types = input$gee_trait_code_types,
            min_species_per_level = as.integer(input$gee_trait_min_species),
            gee_corstr = input$gee_corstr
          )
          incProgress(0.9)
          gee_analyse_rv(analyse)
        })
        gee_analysis_info_rv("G.E.E.-kenmerkenanalyse gereed.")
        showNotification("G.E.E.-kenmerkenanalyse gereed.", type = "message", duration = 4)
      }, error = function(e) {
        gee_analysis_info_rv(paste("Fout bij G.E.E.-kenmerkenanalyse:", conditionMessage(e)))
        showNotification(paste("Fout bij G.E.E.-kenmerkenanalyse:", conditionMessage(e)), type = "error", duration = NULL)
      })
      return()
    }

    if (is.null(input$gee_target_type)) {
      gee_analysis_info_rv("Wacht tot het analyse-niveau geladen is.")
      showNotification("Wacht tot het analyse-niveau geladen is.", type = "error", duration = 5)
      return()
    }
    if (identical(input$gee_target_type, "species")) {
      if (is.null(input$gee_species) || !nzchar(input$gee_species)) {
        gee_analysis_info_rv("Kies eerst een soort.")
        showNotification("Kies eerst een soort.", type = "error", duration = 5)
        return()
      }
      target_value <- input$gee_species
    } else if (identical(input$gee_target_type, "group")) {
      if (is.null(input$gee_group) || !nzchar(input$gee_group)) {
        gee_analysis_info_rv("Kies eerst een vogelgroep.")
        showNotification("Kies eerst een vogelgroep.", type = "error", duration = 5)
        return()
      }
      target_value <- input$gee_group
    } else {
      if (is.null(input$gee_richtlijn) || !nzchar(input$gee_richtlijn)) {
        gee_analysis_info_rv("Kies eerst een Rode/Oranje Lijst-categorie.")
        showNotification("Kies eerst een Rode/Oranje Lijst-categorie.", type = "error", duration = 5)
        return()
      }
      target_value <- input$gee_richtlijn
    }
    totaal_covariaten <- c(input$gee_covariates, input$gee_ahn_covariates, input$gee_infra_covariates, input$gee_habitat_covariates)
    if (length(totaal_covariaten) == 0) {
      gee_analysis_info_rv("Kies eerst minstens één covariaat.")
      showNotification("Kies eerst minstens één covariaat.", type = "error", duration = 5)
      return()
    }
    gee_analysis_info_rv("G.E.E.-analyse draait...")
    tryCatch({
      withProgress(message = "G.E.E.-analyse draait", detail = "Covariaten worden gekoppeld en het model wordt geschat.", value = 0.1, {
        analyse <- run_gee_subset(
          tbls = tbls,
          selected_kavels = selected_plots,
          year_from = year_from,
          year_to = year_to,
          target_type = input$gee_target_type,
          target_value = target_value,
          covariates = input$gee_covariates,
          ahn_covariates = input$gee_ahn_covariates,
          infra_covariates = input$gee_infra_covariates,
          habitat_covariates = input$gee_habitat_covariates,
          gee_corstr = input$gee_corstr
        )
        incProgress(0.9)
        gee_analyse_rv(analyse)
      })
      gee_analysis_info_rv("G.E.E.-analyse gereed.")
      showNotification("G.E.E.-analyse gereed.", type = "message", duration = 4)
    }, error = function(e) {
      gee_analysis_info_rv(paste("Fout bij G.E.E.-analyse:", conditionMessage(e)))
      showNotification(paste("Fout bij G.E.E.-analyse:", conditionMessage(e)), type = "error", duration = NULL)
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

  output$lambda_selection_summary <- renderText({
    analyse <- lambda_analyse_rv()
    if (is.null(analyse)) {
      return("Nog geen LAMBDA-analyse uitgevoerd.")
    }
    basis <- analyse$basis
    status <- analyse$species_results$summary
    paste(
      "Kavels:", length(unique(basis$kavel_nummer)),
      "\nJaren:", min(basis$jaar[basis$jaar != 1958], na.rm = TRUE), "-", max(basis$jaar, na.rm = TRUE),
      "\nPlot-jaar cellen:", nrow(basis[basis$jaar != 1958, ]),
      "\nSoorten met territoria:", sum(analyse$selection$in_selectie),
      "\nGeschikt voor T0-soortanalyse:", sum(status$analyse_categorie != "ongeschikt_voor_T0"),
      "\nGeschikt voor T0-MSI:", sum(status$analyse_categorie == "geschikt_voor_T0_MSI"),
      "\nOngeschikt voor T0:", sum(status$analyse_categorie == "ongeschikt_voor_T0")
    )
  })

  output$gee_selection_summary <- renderText({
    analyse <- gee_analyse_rv()
    tbls <- tbls_rv()
    if (is.null(analyse)) {
      return("Nog geen G.E.E.-analyse uitgevoerd.")
    }
    cov_labels <- c(
      setNames(gee_covariate_specs()$label, gee_covariate_specs()$code),
      setNames(gee_ahn_covariate_specs()$label, gee_ahn_covariate_specs()$code),
      setNames(gee_infra_covariate_specs()$label, gee_infra_covariate_specs()$code)
    )
    if (!is.null(tbls)) {
      hab_specs <- gee_habitat_covariate_specs(tbls)
      cov_labels <- c(cov_labels, setNames(hab_specs$label, hab_specs$code))
    }
    sam <- analyse$summary[1, , drop = FALSE]
    if (identical(analyse$analysis_type, "trait_screening")) {
      return(paste(
        "Analyse-niveau:", sam$analyse_niveau,
        "\nSoortselectie:", sam$doel_label,
        "\nPlots:", sam$n_plots,
        "\nPlot-jaren:", sam$n_plot_jaren,
        "\nSoort-plot-jaren:", sam$n_soort_plot_jaren,
        "\nSoorten:", sam$n_soorten,
        "\nJaren:", sam$eerste_jaar, "-", sam$laatste_jaar,
        "\nCorrelatiestructuur:", sam$gee_corstr,
        "\nGetoetste kenmerken:", sam$n_kenmerken_getoetst,
        "\nModel:", sam$covariaten
      ))
    }
    cov_names <- trimws(strsplit(sam$covariaten, ",", fixed = TRUE)[[1]])
    cov_names <- ifelse(cov_names %in% names(cov_labels), unname(cov_labels[cov_names]), cov_names)
    dropped_names <- character()
    if (!is.na(sam$covariaten_vervallen) && nzchar(sam$covariaten_vervallen)) {
      dropped_raw <- trimws(strsplit(sam$covariaten_vervallen, ",", fixed = TRUE)[[1]])
      dropped_names <- ifelse(dropped_raw %in% names(cov_labels), unname(cov_labels[dropped_raw]), dropped_raw)
    }
    paste(
      "Analyse-niveau:", sam$analyse_niveau,
      "\nDoel:", sam$doel_label,
      "\nPlots:", sam$n_plots,
      "\nPlot-jaren:", sam$n_plot_jaren,
      "\nJaren:", sam$eerste_jaar, "-", sam$laatste_jaar,
      "\nCorrelatiestructuur:", sam$gee_corstr,
      "\nCovariaten:", paste(cov_names, collapse = ", "),
      if (length(dropped_names)) paste0("\nVervallen covariaten:", " ", paste(dropped_names, collapse = ", ")) else ""
    )
  })

  output$selected_plots_table <- renderTable({
    tbls <- tbls_rv()
    req(tbls, input$selected_plots)
    validate(need(length(input$selected_plots) > 0, "Er zijn nog geen kavels geselecteerd."))
    tbls$plots[tbls$plots$kavel_nummer %in% input$selected_plots, c("plot_id", "kavel_nummer", "plot_naam")]
  }, striped = TRUE)

  output$lambda_selected_plots_table <- renderTable({
    tbls <- tbls_rv()
    req(tbls, input$lambda_selected_plots)
    validate(need(length(input$lambda_selected_plots) > 0, "Er zijn nog geen kavels geselecteerd."))
    tbls$plots[tbls$plots$kavel_nummer %in% input$lambda_selected_plots, c("plot_id", "kavel_nummer", "plot_naam")]
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
      polygon(
        c(gam_curve$jaar, rev(gam_curve$jaar)),
        c(gam_curve$lower, rev(gam_curve$upper)),
        col = grDevices::adjustcolor("#f59e0b", alpha.f = 0.20),
        border = NA
      )
      lines(gam_curve$jaar, gam_curve$fit, col = "#f59e0b", lwd = 3)
    }
    grid()
    legend("topleft",
           legend = c("TRIM-index", "GAM", "Variatiezone"),
           col = c("#157f3b", "#f59e0b", grDevices::adjustcolor("#f59e0b", alpha.f = 0.20)),
           lwd = c(2, 3, 8), pch = c(16, NA, NA), bty = "n")
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
    selectInput("selected_group", "Vogelgroepen", choices = choices, selected = groepen$groep_100[1])
  })

  output$richtlijn_picker_ui <- renderUI({
    analyse <- analyse_rv()
    if (is.null(analyse)) {
      return(tags$p("Voer eerst een analyse uit."))
    }
    richtlijnen <- unique(analyse$richtlijn_results$trends[, c("richtlijn_id", "richtlijn_titel", "richtlijn_volgorde")])
    richtlijnen <- richtlijnen[order(richtlijnen$richtlijn_volgorde), , drop = FALSE]
    validate(need(nrow(richtlijnen) > 0, "Geen Rode/Oranje Lijst-categorieën beschikbaar in deze selectie."))
    choices <- setNames(richtlijnen$richtlijn_id, richtlijnen$richtlijn_titel)
    selectInput("selected_richtlijn", "Rode/Oranje Lijst", choices = choices, selected = richtlijnen$richtlijn_id[1])
  })

  output$lambda_species_picker_ui <- renderUI({
    analyse <- lambda_analyse_rv()
    if (is.null(analyse)) {
      return(tags$p("Voer eerst een LAMBDA-analyse uit."))
    }
    if (!("species" %in% input$lambda_analyse_keuze)) {
      return(tags$p("Soortniveau is nu niet geselecteerd."))
    }
    soorten <- sort(unique(analyse$species_results$summary$soort_naam))
    validate(need(length(soorten) > 0, "Geen soorten beschikbaar in deze selectie."))
    selectInput("lambda_selected_species", "Soort", choices = soorten, selected = soorten[1])
  })

  output$lambda_species_plot <- renderPlot({
    analyse <- lambda_analyse_rv()
    req(analyse, input$lambda_selected_species)
    validate(need("species" %in% input$lambda_analyse_keuze, "Soortniveau is niet geselecteerd."))
    idx <- analyse$species_results$yearly
    idx <- idx[idx$soort_naam == input$lambda_selected_species & is.finite(idx$lambda), , drop = FALSE]
    validate(need(nrow(idx) > 0, "Geen jaar-op-jaar veranderingen voor deze soort."))
    idx$lambda_pct <- (idx$lambda - 1) * 100

    y_max <- max(idx$lambda_pct, 0, na.rm = TRUE)
    y_min <- min(idx$lambda_pct, 0, na.rm = TRUE)
    plot(idx$jaar, idx$lambda_pct, type = "n",
         xlab = "Jaar", ylab = "Jaar-op-jaar verandering (%)",
         ylim = c(y_min, y_max),
         main = input$lambda_selected_species)
    legend_info <- draw_lambda_period_lines(idx)
    abline(h = 0, lty = 2, col = "#64748b")
    grid()
    legend("topleft",
           legend = legend_info$labels,
           col = legend_info$cols,
           lwd = c(rep(2, length(legend_info$labels) - 1L), 1),
           pch = c(rep(16, length(legend_info$labels) - 1L), NA),
           bty = "n")
  })

  output$lambda_species_note_ui <- renderUI({
    analyse <- lambda_analyse_rv()
    req(analyse, input$lambda_selected_species)
    validate(need("species" %in% input$lambda_analyse_keuze, "Soortniveau is niet geselecteerd."))

    info <- analyse$species_results$summary
    info <- info[info$soort_naam == input$lambda_selected_species, , drop = FALSE]
    if (!nrow(info) || info$analyse_categorie[[1]] != "ongeschikt_voor_T0") {
      return(NULL)
    }

    redenen <- character()
    if (!isTRUE(info$periode_1959_1972_aanwezig[[1]])) {
      redenen <- c(redenen, "geen positieve aanwezigheid in 1959-1972")
    }
    if (!isTRUE(info$periode_1973_1983_aanwezig[[1]])) {
      redenen <- c(redenen, "geen positieve aanwezigheid in 1973-1983")
    }
    if (!isTRUE(info$periode_1984_heden_aanwezig[[1]])) {
      redenen <- c(redenen, "geen positieve aanwezigheid in 1984-heden")
    }
    if (is.finite(info$nul_aandeel[[1]]) && info$nul_aandeel[[1]] > 0.50) {
      redenen <- c(redenen, sprintf("nul-aandeel %.1f%%", 100 * info$nul_aandeel[[1]]))
    }
    if (is.finite(info$geldige_jaarparen[[1]]) && info$geldige_jaarparen[[1]] < 8L) {
      redenen <- c(redenen, sprintf("te weinig geldige jaarparen (%s)", info$geldige_jaarparen[[1]]))
    }
    if (is.finite(info$positieve_jaren[[1]]) && info$positieve_jaren[[1]] < 5L) {
      redenen <- c(redenen, sprintf("te weinig positieve jaren (%s)", info$positieve_jaren[[1]]))
    }

    div(
      class = "status-box",
      tags$span(class = "status-label", "Toelichting"),
      tags$span(
        sprintf(
          "Deze soort is ongeschikt voor T0-selectie (%s), maar de beschikbare deelreeks met geldige jaar-op-jaar verandering wordt wel getoond.",
          paste(redenen, collapse = ", ")
        )
      )
    )
  })

  output$lambda_species_table <- renderTable({
    analyse <- lambda_analyse_rv()
    req(analyse)
    validate(need("species" %in% input$lambda_analyse_keuze, "Soortniveau is niet geselecteerd."))
    analyse$species_results$summary[, c(
      "soort_naam", "analyse_categorie", "geldige_jaren", "geldige_jaarparen",
      "positieve_jaren", "nul_aandeel", "gemiddeld_lambda", "gemiddelde_verandering_pct"
    )]
  }, striped = TRUE)

  output$lambda_group_picker_ui <- renderUI({
    analyse <- lambda_analyse_rv()
    if (is.null(analyse)) {
      return(tags$p("Voer eerst een LAMBDA-analyse uit."))
    }
    if (!("groups" %in% input$lambda_analyse_keuze)) {
      return(tags$p("Groepsniveau is nu niet geselecteerd."))
    }
    groepen <- unique(analyse$group_results$summary[, c("groep_100", "groep_titel")])
    validate(need(nrow(groepen) > 0, "Geen groepen beschikbaar in deze selectie."))
    choices <- setNames(groepen$groep_100, paste0(groepen$groep_100, " - ", groepen$groep_titel))
    selectInput("lambda_selected_group", "Vogelgroepen", choices = choices, selected = groepen$groep_100[1])
  })

  output$lambda_group_plot <- renderPlot({
    analyse <- lambda_analyse_rv()
    req(analyse, input$lambda_selected_group)
    validate(need("groups" %in% input$lambda_analyse_keuze, "Groepsniveau is niet geselecteerd."))
    idx <- analyse$group_results$index
    idx <- idx[idx$groep_100 == as.integer(input$lambda_selected_group) & is.finite(idx$lambda), , drop = FALSE]
    validate(need(nrow(idx) > 0, "Geen jaar-op-jaar veranderingen voor deze groep."))
    idx$lambda_pct <- (idx$lambda - 1) * 100

    title <- unique(idx$groep_titel)[1]
    y_max <- max(idx$lambda_pct, 0, na.rm = TRUE)
    y_min <- min(idx$lambda_pct, 0, na.rm = TRUE)
    plot(idx$jaar, idx$lambda_pct, type = "n",
         xlab = "Jaar", ylab = "Jaar-op-jaar verandering (%)",
         ylim = c(y_min, y_max),
         main = paste(input$lambda_selected_group, "-", title))
    legend_info <- draw_lambda_period_lines(idx)
    abline(h = 0, lty = 2, col = "#64748b")
    grid()
    legend("topleft",
           legend = legend_info$labels,
           col = legend_info$cols,
           lwd = c(rep(2, length(legend_info$labels) - 1L), 1),
           pch = c(rep(16, length(legend_info$labels) - 1L), NA),
           bty = "n")
  })

  output$lambda_group_table <- renderTable({
    analyse <- lambda_analyse_rv()
    req(analyse)
    validate(need("groups" %in% input$lambda_analyse_keuze, "Groepsniveau is niet geselecteerd."))
    analyse$group_results$summary
  }, striped = TRUE)

  output$lambda_group_species_table <- renderTable({
    analyse <- lambda_analyse_rv()
    req(analyse, input$lambda_selected_group)
    validate(need("groups" %in% input$lambda_analyse_keuze, "Groepsniveau is niet geselecteerd."))
    analyse$group_results$composition[
      analyse$group_results$composition$groep_100 == as.integer(input$lambda_selected_group),
      c("soort_naam", "engelse_naam", "euring_code")
    ]
  }, striped = TRUE)

  output$lambda_richtlijn_picker_ui <- renderUI({
    analyse <- lambda_analyse_rv()
    if (is.null(analyse)) {
      return(tags$p("Voer eerst een LAMBDA-analyse uit."))
    }
    if (!("richtlijnen" %in% input$lambda_analyse_keuze)) {
      return(tags$p("Rode/Oranje Lijst is nu niet geselecteerd."))
    }
    richtlijnen <- unique(analyse$richtlijn_results$summary[, c("richtlijn_id", "richtlijn_titel", "richtlijn_volgorde")])
    richtlijnen <- richtlijnen[order(richtlijnen$richtlijn_volgorde), , drop = FALSE]
    validate(need(nrow(richtlijnen) > 0, "Geen Rode/Oranje Lijst-categorieën beschikbaar in deze selectie."))
    choices <- setNames(richtlijnen$richtlijn_id, richtlijnen$richtlijn_titel)
    selectInput("lambda_selected_richtlijn", "Rode/Oranje Lijst", choices = choices, selected = richtlijnen$richtlijn_id[1])
  })

  output$lambda_richtlijn_plot <- renderPlot({
    analyse <- lambda_analyse_rv()
    req(analyse, input$lambda_selected_richtlijn)
    validate(need("richtlijnen" %in% input$lambda_analyse_keuze, "Rode/Oranje Lijst is niet geselecteerd."))
    idx <- analyse$richtlijn_results$index
    idx <- idx[idx$richtlijn_id == as.integer(input$lambda_selected_richtlijn) & is.finite(idx$lambda), , drop = FALSE]
    validate(need(nrow(idx) > 0, "Geen jaar-op-jaar veranderingen voor deze categorie."))
    idx$lambda_pct <- (idx$lambda - 1) * 100

    title <- unique(idx$richtlijn_titel)[1]
    y_max <- max(idx$lambda_pct, 0, na.rm = TRUE)
    y_min <- min(idx$lambda_pct, 0, na.rm = TRUE)
    plot(idx$jaar, idx$lambda_pct, type = "n",
         xlab = "Jaar", ylab = "Jaar-op-jaar verandering (%)",
         ylim = c(y_min, y_max),
         main = title)
    legend_info <- draw_lambda_period_lines(idx)
    abline(h = 0, lty = 2, col = "#64748b")
    grid()
    legend("topleft",
           legend = legend_info$labels,
           col = legend_info$cols,
           lwd = c(rep(2, length(legend_info$labels) - 1L), 1),
           pch = c(rep(16, length(legend_info$labels) - 1L), NA),
           bty = "n")
  })

  output$lambda_richtlijn_table <- renderTable({
    analyse <- lambda_analyse_rv()
    req(analyse)
    validate(need("richtlijnen" %in% input$lambda_analyse_keuze, "Rode/Oranje Lijst is niet geselecteerd."))
    analyse$richtlijn_results$summary[, c(
      "richtlijn_titel", "eerste_jaar", "laatste_jaar", "n_indexjaren",
      "geldige_jaarparen", "gemiddeld_lambda", "gemiddelde_verandering_pct"
    )]
  }, striped = TRUE)

  output$lambda_richtlijn_species_table <- renderTable({
    analyse <- lambda_analyse_rv()
    req(analyse, input$lambda_selected_richtlijn)
    validate(need("richtlijnen" %in% input$lambda_analyse_keuze, "Rode/Oranje Lijst is niet geselecteerd."))
    analyse$richtlijn_results$composition[
      analyse$richtlijn_results$composition$richtlijn_id == as.integer(input$lambda_selected_richtlijn),
      c("soort_naam", "engelse_naam", "euring_code")
    ]
  }, striped = TRUE)

  output$lambda_coverage_table <- renderTable({
    analyse <- lambda_analyse_rv()
    req(analyse)
    basis <- analyse$basis
    basis <- basis[basis$jaar != 1958L, , drop = FALSE]
    cov <- aggregate(geteld ~ kavel_nummer, data = basis, FUN = function(x) sum(x, na.rm = TRUE))
    names(cov)[2] <- "aantal_getelde_jaren"
    cov$totaal_jaren <- length(unique(basis$jaar))
    cov$niet_geteld <- cov$totaal_jaren - cov$aantal_getelde_jaren
    cov[order(cov$kavel_nummer), ]
  }, striped = TRUE)

  output$lambda_status_table <- renderTable({
    analyse <- lambda_analyse_rv()
    req(analyse)
    analyse$species_results$summary[, c(
      "soort_naam", "analyse_categorie", "geldige_jaren",
      "geldige_jaarparen", "positieve_jaren", "nul_aandeel",
      "periode_1959_1972_aanwezig", "periode_1973_1983_aanwezig",
      "periode_1984_heden_aanwezig"
    )]
  }, striped = TRUE)

  output$gee_coef_plot <- renderPlot({
    analyse <- gee_analyse_rv()
    tbls <- tbls_rv()
    req(analyse)
    coefs <- analyse$coefficients
    validate(need(nrow(coefs) > 0, "Geen coëfficiënten beschikbaar."))
    if (identical(analyse$analysis_type, "trait_screening")) {
      coefs <- coefs[order(coefs$p.value), , drop = FALSE]
      coefs <- head(coefs, 20)
      coefs <- coefs[order(coefs$irr_jaar_interactie), , drop = FALSE]
      y <- seq_len(nrow(coefs))
      xlim <- range(c(coefs$irr_low, coefs$irr_high, 1), na.rm = TRUE)
      labels <- paste0(coefs$code, " - ", coefs$kenmerk)
      old_par <- graphics::par(no.readonly = TRUE)
      on.exit(graphics::par(old_par), add = TRUE)
      graphics::par(mar = c(5.1, 22, 4.1, 2.1), xpd = NA)
      plot(coefs$irr_jaar_interactie, y,
           xlim = xlim,
           yaxt = "n",
           pch = 16,
           col = "#0f766e",
           xlab = "IRR voor jaar x kenmerk",
           ylab = "",
           main = "G.E.E.-kenmerken: verschil in jaar-op-jaar ontwikkeling")
      segments(coefs$irr_low, y, coefs$irr_high, y, col = "#94a3b8", lwd = 2)
      abline(v = 1, lty = 2, col = "#64748b")
      axis(2, at = y, labels = labels, las = 1, cex.axis = 0.8)
      grid()
      return(invisible())
    }
    term_labels <- c(
      year_c = "Jaar",
      ahn_mean = "AHN gemiddelde hoogte",
      ahn_sd = "AHN standaard deviatie",
      stikstof_mean = "Stikstof gemiddelde depositie",
      afstand_pad_m = "Afstand tot pad",
      padlengte_m_per_ha = "Padlengte per hectare",
      afstand_parkeerplaats_m = "Afstand tot parkeerplaats",
      afstand_hoofdtoegang_m = "Afstand tot hoofdtoegang",
      toegankelijkheid_statusbeperkt = "Toegankelijkheid: beperkt",
      toegankelijkheid_statusafgesloten = "Toegankelijkheid: afgesloten",
      `toegankelijkheid_statusdeels beperkt, deels vrij` = "Toegankelijkheid: deels beperkt/deels vrij",
      `toegankelijkheid_statusdeels afgesloten, deels vrij` = "Toegankelijkheid: deels afgesloten/deels vrij",
      toegankelijkheid_statusonbekend = "Toegankelijkheid: onbekend"
    )
    if (!is.null(tbls)) {
      hab_specs <- gee_habitat_covariate_specs(tbls)
      term_labels <- c(term_labels, setNames(paste0("Habitat: ", hab_specs$label), hab_specs$code))
    }
    coefs$term_label <- ifelse(coefs$term %in% names(term_labels), unname(term_labels[coefs$term]), coefs$term)
    coefs <- coefs[order(coefs$irr), , drop = FALSE]
    y <- seq_len(nrow(coefs))
    xlim <- range(c(coefs$irr_low, coefs$irr_high, 1), na.rm = TRUE)
    old_par <- graphics::par(no.readonly = TRUE)
    on.exit(graphics::par(old_par), add = TRUE)
    graphics::par(mar = c(5.1, 20, 4.1, 2.1), xpd = NA)
    plot(coefs$irr, y,
         xlim = xlim,
         yaxt = "n",
         pch = 16,
         col = "#1d4ed8",
         xlab = "Incident Rate Ratio (IRR)",
         ylab = "",
         main = paste("G.E.E.-effecten voor", analyse$summary$doel_label[[1]]))
    segments(coefs$irr_low, y, coefs$irr_high, y, col = "#94a3b8", lwd = 2)
    abline(v = 1, lty = 2, col = "#64748b")
    axis(2, at = y, labels = coefs$term_label, las = 1, cex.axis = 0.9)
    grid()
  })

  output$gee_coef_table <- renderTable({
    analyse <- gee_analyse_rv()
    req(analyse)
    if (identical(analyse$analysis_type, "trait_screening")) {
      out <- analyse$coefficients[, c(
        "code", "kenmerk", "hoofdcategorie", "code_type",
        "n_soorten_met_kenmerk", "n_soorten_zonder_kenmerk",
        "pct_verschil_trend_per_jaar", "p.value", "p_adj_bh",
        "irr_jaar_interactie", "irr_low", "irr_high"
      )]
      return(head(out, 50))
    }
    analyse$coefficients[, c("term", "estimate", "std.error", "statistic", "p.value", "irr", "irr_low", "irr_high")]
  }, striped = TRUE)

  output$gee_plot_usage_table <- renderTable({
    analyse <- gee_analyse_rv()
    req(analyse)
    if (identical(analyse$analysis_type, "trait_screening")) {
      out <- aggregate(
        count ~ plot_id + kavel_nummer,
        data = analyse$model_data,
        FUN = function(x) sum(x, na.rm = TRUE)
      )
      names(out)[3] <- "totaal_territoria"
      nrows <- aggregate(
        jaar ~ plot_id + kavel_nummer,
        data = unique(analyse$model_data[, c("plot_id", "kavel_nummer", "jaar")]),
        FUN = length
      )
      names(nrows)[3] <- "n_plot_jaren"
      out <- merge(out, nrows, by = c("plot_id", "kavel_nummer"), all.x = TRUE)
      out <- out[order(out$kavel_nummer, out$plot_id), c("plot_id", "kavel_nummer", "n_plot_jaren", "totaal_territoria")]
      rownames(out) <- NULL
      return(out)
    }
    out <- aggregate(
      count ~ plot_id + kavel_nummer,
      data = analyse$model_data,
      FUN = function(x) sum(x, na.rm = TRUE)
    )
    names(out)[3] <- "totaal_territoria"
    nrows <- aggregate(
      jaar ~ plot_id + kavel_nummer,
      data = analyse$model_data,
      FUN = length
    )
    names(nrows)[3] <- "n_plot_jaren"
    years <- aggregate(
      jaar ~ plot_id + kavel_nummer,
      data = analyse$model_data,
      FUN = function(x) sprintf("%s-%s", min(x, na.rm = TRUE), max(x, na.rm = TRUE))
    )
    names(years)[3] <- "jaarbereik"
    out <- merge(out, nrows, by = c("plot_id", "kavel_nummer"), all.x = TRUE)
    out <- merge(out, years, by = c("plot_id", "kavel_nummer"), all.x = TRUE)
    out <- out[order(out$kavel_nummer, out$plot_id), c("plot_id", "kavel_nummer", "jaarbereik", "n_plot_jaren", "totaal_territoria")]
    rownames(out) <- NULL
    out
  }, striped = TRUE)

  output$gee_dataset_table <- renderTable({
      analyse <- gee_analyse_rv()
      req(analyse)
      if (identical(analyse$analysis_type, "trait_screening")) {
        out <- analyse$model_data[, c("plot_id", "kavel_nummer", "jaar", "soort_id", "soort_naam", "count")]
        out <- out[order(out$jaar, out$kavel_nummer, out$plot_id, out$soort_naam), , drop = FALSE]
        rownames(out) <- NULL
        return(head(out, 200))
      }
      out <- analyse$model_data[, c(
      "plot_id", "kavel_nummer", "jaar", "count", "ahn_mean", "ahn_sd", "stikstof_mean",
      "afstand_pad_m", "padlengte_m_per_ha", "afstand_parkeerplaats_m",
      "afstand_hoofdtoegang_m", "toegankelijkheid_status"
    )]
      out <- out[order(out$jaar, out$kavel_nummer, out$plot_id), , drop = FALSE]
      rownames(out) <- NULL
      out
  }, striped = TRUE)

  output$download_gee_coefficients <- downloadHandler(
    filename = function() {
      analyse <- gee_analyse_rv()
      req(analyse)
      sprintf("meijendel_shiny_gee_coef_%s.csv", analyse$summary$doel_slug[[1]])
    },
    content = function(file) {
      analyse <- gee_analyse_rv()
      utils::write.csv(analyse$coefficients, file, row.names = FALSE)
    }
  )

  output$download_gee_dataset <- downloadHandler(
    filename = function() {
      analyse <- gee_analyse_rv()
      req(analyse)
      sprintf("meijendel_shiny_gee_dataset_%s.csv", analyse$summary$doel_slug[[1]])
    },
    content = function(file) {
      analyse <- gee_analyse_rv()
      utils::write.csv(analyse$model_data, file, row.names = FALSE)
    }
  )

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
      polygon(
        c(gam_curve$jaar, rev(gam_curve$jaar)),
        c(gam_curve$lower, rev(gam_curve$upper)),
        col = grDevices::adjustcolor("#f59e0b", alpha.f = 0.20),
        border = NA
      )
      lines(gam_curve$jaar, gam_curve$fit, col = "#f59e0b", lwd = 3)
    }
    grid()
    legend("topleft",
           legend = c("MSI", "GAM", "Variatiezone"),
           col = c("#1d4ed8", "#f59e0b", grDevices::adjustcolor("#f59e0b", alpha.f = 0.20)),
           lwd = c(2, 3, 8), pch = c(16, NA, NA), bty = "n")
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

  output$richtlijn_plot <- renderPlot({
    analyse <- analyse_rv()
    req(analyse, input$selected_richtlijn)
    msi <- analyse$richtlijn_results$msi
    msi <- msi[msi$richtlijn_id == as.integer(input$selected_richtlijn), ]
    validate(need(nrow(msi) > 0, "Geen MSI-gegevens voor deze categorie."))

    title <- unique(msi$richtlijn_titel)[1]
    gam_curve <- fit_gam_curve(msi, "msi")
    y_max <- max(msi$msi, if (!is.null(gam_curve)) gam_curve$upper else NA_real_, na.rm = TRUE)
    y_min <- min(msi$msi, if (!is.null(gam_curve)) gam_curve$lower else NA_real_, na.rm = TRUE)

    plot(msi$jaar, msi$msi, type = "o", pch = 16, lwd = 2, col = "#1d4ed8",
         xlab = "Jaar", ylab = "MSI",
         ylim = c(y_min, y_max),
         main = title)
    if (!is.null(gam_curve)) {
      polygon(
        c(gam_curve$jaar, rev(gam_curve$jaar)),
        c(gam_curve$lower, rev(gam_curve$upper)),
        col = grDevices::adjustcolor("#f59e0b", alpha.f = 0.20),
        border = NA
      )
      lines(gam_curve$jaar, gam_curve$fit, col = "#f59e0b", lwd = 3)
    }
    grid()
    legend("topleft",
           legend = c("MSI", "GAM", "Variatiezone"),
           col = c("#1d4ed8", "#f59e0b", grDevices::adjustcolor("#f59e0b", alpha.f = 0.20)),
           lwd = c(2, 3, 8), pch = c(16, NA, NA), bty = "n")
  })

  output$richtlijn_table <- renderTable({
    analyse <- analyse_rv()
    req(analyse)
    analyse$richtlijn_results$trends[, c(
      "richtlijn_titel", "eerste_jaar", "laatste_jaar", "gemiddeld_n_soorten",
      "trend_pct_per_jaar", "trend_p", "trend_r2", "trend_uitleg"
    )]
  }, striped = TRUE)

  output$richtlijn_species_table <- renderTable({
    analyse <- analyse_rv()
    req(analyse, input$selected_richtlijn)
    analyse$richtlijn_results$composition[
      analyse$richtlijn_results$composition$richtlijn_id == as.integer(input$selected_richtlijn),
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
      sprintf("meijendel_shiny_soorttrends_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$species_results$trends, file, row.names = FALSE)
    }
  )

  output$download_species_indices <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_soortindices_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$species_results$indices, file, row.names = FALSE)
    }
  )

  output$download_group_trends <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_groepstrends_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$group_results$trends, file, row.names = FALSE)
    }
  )

  output$download_group_msi <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_groep_msi_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$group_results$msi, file, row.names = FALSE)
    }
  )

  output$download_richtlijn_trends <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_richtlijntrends_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$richtlijn_results$trends, file, row.names = FALSE)
    }
  )

  output$download_richtlijn_msi <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_richtlijn_msi_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$richtlijn_results$msi, file, row.names = FALSE)
    }
  )

  output$download_basis <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_analysebasis_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$basis, file, row.names = FALSE)
    }
  )

  output$download_status <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_modelstatus_%s_%s.csv", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      utils::write.csv(analyse$species_results$status, file, row.names = FALSE)
    }
  )

  output$download_lambda_species_years <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_lambda_soortjaren_%s_%s.csv", input$lambda_year_from, input$lambda_year_to)
    },
    content = function(file) {
      analyse <- lambda_analyse_rv()
      req(analyse)
      utils::write.csv(analyse$species_results$yearly, file, row.names = FALSE)
    }
  )

  output$download_lambda_species_summary <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_lambda_soorten_%s_%s.csv", input$lambda_year_from, input$lambda_year_to)
    },
    content = function(file) {
      analyse <- lambda_analyse_rv()
      req(analyse)
      utils::write.csv(analyse$species_results$summary, file, row.names = FALSE)
    }
  )

  output$download_lambda_group_years <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_lambda_groepjaren_%s_%s.csv", input$lambda_year_from, input$lambda_year_to)
    },
    content = function(file) {
      analyse <- lambda_analyse_rv()
      req(analyse)
      utils::write.csv(analyse$group_results$index, file, row.names = FALSE)
    }
  )

  output$download_lambda_group_summary <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_lambda_groepen_%s_%s.csv", input$lambda_year_from, input$lambda_year_to)
    },
    content = function(file) {
      analyse <- lambda_analyse_rv()
      req(analyse)
      utils::write.csv(analyse$group_results$summary, file, row.names = FALSE)
    }
  )

  output$download_lambda_richtlijn_years <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_lambda_richtlijnjaren_%s_%s.csv", input$lambda_year_from, input$lambda_year_to)
    },
    content = function(file) {
      analyse <- lambda_analyse_rv()
      req(analyse)
      utils::write.csv(analyse$richtlijn_results$index, file, row.names = FALSE)
    }
  )

  output$download_lambda_richtlijn_summary <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_lambda_richtlijnen_%s_%s.csv", input$lambda_year_from, input$lambda_year_to)
    },
    content = function(file) {
      analyse <- lambda_analyse_rv()
      req(analyse)
      utils::write.csv(analyse$richtlijn_results$summary, file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)
