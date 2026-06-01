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

future_analysis_tab <- function(title, subtitle) {
  tabPanel(
    title,
    fluidPage(
      titlePanel(title),
      tags$p(class = "app-subtitle", subtitle),
      tags$div(class = "method-label", switch(prefix,
        rda = "Verklarende community-analyse",
        pls = "Exploratieve/predictieve community-analyse",
        changepoint = "Trendbreukdetectie",
        sem = "Exploratieve SEM - niet causaal rapporteren",
        betadiversity = "Exploratieve community-vergelijking",
        occupancy = "Detectiegecorrigeerde occupancy",
        "Analyse"
      )),
      if (identical(prefix, "sem")) {
        tags$div(
          class = "method-warning",
          tags$strong("Let op: SEM-verkenning. "),
          "De modelstructuur is hard-coded. Gebruik deze output niet als causale rapportage zonder vooraf gespecificeerd hypothesemodel."
        )
      },
      if (identical(prefix, "pls")) {
        tags$div(
          class = "method-warning",
          tags$strong("Interpretatie PLS. "),
          "RMSEP beoordeelt voorspellende fout. VIP-scores geven relatief variabelengewicht binnen dit model, maar zijn geen bewijs voor causale ecologische effecten."
        )
      },
      fluidRow(
        column(
          width = 12,
          div(
            class = "soft-card",
            h3("Status"),
            tags$p("Deze analysemodule is voorbereid in de navigatie, maar de berekening is nog niet geactiveerd."),
            tags$p(
              class = "section-note",
              "De module gebruikt later dezelfde datalaag voor getelde plot-jaren, echte nullen en ontbrekende waarnemingen."
            )
          )
        )
      )
    )
  )
}

community_analysis_tab <- function(title, prefix, subtitle, button_label, note, extra_controls = NULL, plot_output_id = NULL) {
  if (is.null(plot_output_id)) {
    plot_output_id <- paste0(prefix, "_plot")
  }
  tabPanel(
    title,
    fluidPage(
      titlePanel(title),
      tags$p(class = "app-subtitle", subtitle),
      fluidRow(
        column(
          4,
          div(
            class = "soft-card",
            h3("Selectie"),
            uiOutput(paste0(prefix, "_plot_selector_ui")),
            uiOutput(paste0(prefix, "_year_selector_ui")),
            radioButtons(
              paste0(prefix, "_selection_type"),
              "Soortselectie",
              choices = c("Alle soorten" = "all", "Vogelgroep" = "group", "Rode/Oranje Lijst" = "richtlijn", "Vogelkenmerk" = "trait"),
              selected = "all",
              inline = FALSE
            ),
            uiOutput(paste0(prefix, "_selection_picker_ui")),
            extra_controls,
            actionButton(paste0("run_", prefix, "_analysis"), button_label, class = "btn-primary"),
            tags$p(class = "section-note", note)
          )
        ),
        column(
          8,
          div(
            class = "soft-card",
            h3("Modelstatus"),
            textOutput(paste0(prefix, "_analysis_status")),
            tags$div(style = "margin-top:12px;"),
            verbatimTextOutput(paste0(prefix, "_selection_summary"))
          ),
          div(
            class = "soft-card",
            h3("Uitkomsten"),
            plotOutput(plot_output_id, height = "500px"),
            div(
              class = "download-row",
              downloadButton(paste0("download_", prefix, "_primary"), "CSV hoofdresultaat"),
              downloadButton(paste0("download_", prefix, "_dataset"), "CSV dataset"),
              downloadButton(paste0("download_", prefix, "_script"), "R-script analyse")
            ),
            h4("Hoofdresultaat"),
            tableOutput(paste0(prefix, "_primary_table")),
            h4("Diagnostiek"),
            tableOutput(paste0(prefix, "_diagnostics_table")),
            h4("Gebruikte plot-jaren"),
            tableOutput(paste0(prefix, "_sample_table")),
            h4("Telinspanning/detectie"),
            tableOutput(paste0(prefix, "_detection_effort_table"))
          )
        )
      )
    )
  )
}

ui <- navbarPage(
  title = "Analyses in R: A Language and Environment for Statistical Computing",
  theme = bslib::bs_theme(version = 5, bootswatch = "flatly"),
  header = tags$head(
    tags$style(HTML("
      .navbar {
        align-items: flex-start !important;
      }
      .navbar .container-fluid {
        display: flex !important;
        flex-direction: column !important;
        align-items: flex-start !important;
      }
      .navbar-brand {
        display: block !important;
        margin: 0 0 6px 0 !important;
        padding-bottom: 0 !important;
      }
      .navbar-collapse {
        width: 100% !important;
      }
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
      .method-label {
        display:inline-block; padding:4px 9px; margin:0 0 10px 0;
        border-radius:6px; background:#e0f2fe; color:#075985;
        font-size:12px; font-weight:700; letter-spacing:0;
      }
      .method-warning {
        border-left:4px solid #d97706; background:#fffbeb; color:#78350f;
        padding:9px 11px; margin:8px 0 12px 0; border-radius:6px;
      }
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
            tags$p("Ga daarna naar TRIM, LAMBDA of een van de correlatie analyse methodes om de gewenste analyses uit te voeren. Kies daar of je de analyses voor vogelsoorten, vogelgroepen of vogelkenmerken wil doen en selecteer de kavels en jaren. Meer informatie over TRIM, LAMBDA, de correlatie analyse methodes, GAM-grafieken en de beschrijving van de onderscheiden vogelgroepen vind je in de tekstblokken hieronder.")
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
              tags$li("GEE"),
              tags$li("GLMM"),
              tags$li("NMDS"),
              tags$li("RDA"),
              tags$li("PLS"),
              tags$li("Changepoint"),
              tags$li("SEM"),
              tags$li("Beta-Diversity"),
              tags$li("Occupancy"),
              tags$li("GAM"),
              tags$li("Vogelgroepen")
            ),
            h4("1. TRIM"),
            tags$p("TRIM (TRends and Indices for Monitoring data) is een door het Centraal Bureau voor de Statistiek ontwikkeld statistisch model voor analyse van telreeksen met ontbrekende waarnemingen. Het zet tellingen om in indexcijfers, waarbij index 100 hier het eerste analysejaar vanaf het eerste positieve jaar betekent. De app kiest het eerste werkende model volgens een vaste voorkeurshierarchie; dit is geen AIC-modelselectie. De trendlabels zijn eigen trendduidingen op basis van de TRIM-index, geen officiële TRIM-classificaties. Een deel van de territoria data is niet volgens de gestandaardiseerde landelijke SOVON-methode geinterpreteerd. Dit geldt o.a. voor de periode 1958-1983 in Meijendel. In de TRIM analyses wordt, bij gebruik van data voor 1984, gewerkt met brugjaren om de TRIM data vergelijkbaar te maken. Het betreft de jaren 1981-1982-1983 en de jaren 1984-1985-1986."),
            h4("2. LAMBDA"),
            tags$p("De LAMBDA-methode beschrijft populatieverandering via de groeifactor λ, gedefinieerd als de verhouding tussen aantallen in opeenvolgende jaren (λ = Nₜ₊₁ / Nₜ). Een waarde λ > 1 duidt op groei, λ < 1 op afname en λ = 1 op stabiliteit. Door λ per jaar te berekenen ontstaat een tijdreeks van relatieve veranderingen, die eenvoudig te middelen of cumuleren is. De methode vereist consistente tellingen en is gevoelig voor nulwaarden en waarnemingsfouten. Om die reden zijn sporadisch verschijnende soorten niet meegenomen in de berekening van de MSI van de vogelgroepen. In de praktijk wordt vaak gewerkt met log-transformaties van λ om trends statistisch stabieler te analyseren. LAMBDA gebruikt drie T0-perioden: 1959-1972 (T0=1959), 1973-1983 (T0=1973) en 1984-heden (T0=1984)."),
            h4("3. GEE — Generalized Estimating Equations"),
            tags$p("Analyseert relaties tussen vogelgegevens en omgevingsfactoren bij herhaalde metingen per plot en jaar. Geschikt voor verklarende analyses van effecten van beheer, recreatie, weer, habitat of stikstof op soorten en soortgroepen. Robuust bij onregelmatige tellingen en ontbrekende waarnemingen. Werkt met verschillende correlatiestructuren. Voor Meijendel is Ar1 meestal ecologisch het meest plausibel, omdat opeenvolgende jaren sterker op elkaar lijken dan jaren die verder uit elkaar liggen."),
            h4("4. GLMM — Generalized Linear Mixed Models"),
            tags$p("Geschikt voor analyse van veranderingen in aantallen of territoria per soort in de Meijendel-database. Kan vaste effecten modelleren zoals stikstof, recreatie, vegetatie of beheermaatregelen. Neemt tegelijk random effecten mee voor plot, jaar of teller, waardoor herhaalde metingen correct worden behandeld. Werkt goed bij niet-normale data zoals tellingen met veel nullen of scheve verdelingen. Geschikt voor soortspecifieke trendanalyse en toetsing van causale hypothesen."),
            h4("5. NMDS — Non-metric Multidimensional Scaling"),
            tags$p("Ordent vogelgemeenschappen op basis van overeenkomst in soortensamenstelling tussen plots en jaren. Laat zien welke plots ecologisch op elkaar lijken of juist uiteenlopen door beheer of habitatverandering. Gebruikt rangordes van verschillen en is daardoor robuust voor ecologische datasets met veel zeldzame soorten. Kan verschuivingen zichtbaar maken van open duin naar struweel- of bosgemeenschappen. Vooral nuttig als exploratieve analyse van gemeenschapsstructuur."),
            h4("6. RDA — Redundancy Analysis"),
            tags$p("Analyseert welke omgevingsfactoren veranderingen in vogelgemeenschappen verklaren. Koppelt soortenpatronen direct aan variabelen zoals begrazing, waterbeheer of recreatiedruk. Geschikt wanneer lineaire relaties vermoed worden tussen milieuvariabelen en soortenrespons. Geeft zowel soort- als plotniveau-informatie in één geïntegreerde analyse. Kan helpen bepalen welke factoren het sterkst samenhangen met biodiversiteitsverandering."),
            h4("7. PLS — Partial Least Squares Regression"),
            tags$p("Analyseert samenhang tussen vogelgemeenschappen en omgevingsvariabelen wanneer verklarende variabelen onderling kunnen samenhangen. PLS reduceert de omgevingsvariabelen tot componenten die zo goed mogelijk de variatie in soortensamenstelling verklaren. Binnen de app gebruikt PLS dezelfde community-matrix als NMDS en RDA, op basis van territoria per km2."),
            h4("8. Changepoint-analyse"),
            tags$p("Zoekt naar jaren waarin abrupte veranderingen optreden in trends of soortaantallen. Kan omslagpunten detecteren zoals de terugkeer van de vos of veranderingen in infiltratiebeheer. Geschikt voor lange tijdreeksen zoals de historische Meijendel-data sinds 1958. Helpt onderscheid maken tussen geleidelijke trends en plotselinge systeemveranderingen. Nuttig voor koppeling van ecologische veranderingen aan concrete beheer- of landschapsingrepen."),
            h4("9. SEM — Structural Equation Modelling"),
            tags$p("Modelleert complexe causale relaties tussen meerdere factoren tegelijk. Kan indirecte effecten zichtbaar maken, bijvoorbeeld: stikstof → vegetatiestructuur → vogelsoorten. Geschikt voor integratie van beheer, habitat, recreatie en predatie binnen één model. Laat onderscheid zien tussen directe en indirecte invloeden op biodiversiteit. Voor Meijendel vooral waardevol als synthese-instrument voor meerdere datasets en hypothesen."),
            h4("10. Beta-Diversity analyse"),
            tags$p("Meet verschillen in soortensamenstelling tussen plots, habitats of jaren. Kan laten zien of Meijendel ecologisch homogener of juist diverser wordt. Maakt onderscheid tussen soortenverlies en vervanging van soorten door andere soorten. Geschikt voor analyse van verstruweling, successie en habitatfragmentatie. Relevant voor beoordeling van landschappelijke variatie en ecologische veerkracht."),
            h4("11. Occupancy modelling"),
            tags$p("Schat de kans dat een soort werkelijk aanwezig is, ook wanneer zij niet altijd wordt waargenomen. Corrigeert voor detectieproblemen bij zeldzame of moeilijk waarneembare soorten. Geschikt voor BMP-data waarin afwezigheid soms onzeker is door variërende telinspanning. Kan trends in verspreiding analyseren zonder volledig afhankelijk te zijn van territoriumtellingen. Bijzonder bruikbaar voor Rode Lijst-soorten en soorten met lage detectiekans."),
            h4("12. GAM"),
            tags$p("In deze app wordt gebruik gemaakt van GAM. GAM (Generalized Additive Model) is een flexibele statistische methode die relaties modelleert zonder een vaste functionele vorm op te leggen. Het model beschrijft de responsvariabele als som van gladde (niet-lineaire) functies van verklarende variabelen. Hiermee kunnen complexe, niet-lineaire trends in tijdreeksen van ecologische data worden geschat en grafisch weergegeven."),
            h4("13. Vogelgroepen"),
            tags$p("De ", tags$strong("ecologische vogelgroepen"), " van Piet Sierdsema zijn een indeling van vogelsoorten op basis van hun habitatvoorkeur en ecologische functie. Soorten worden gegroepeerd in: 100 - Watervogels, 200 - Rietvogels, 300 - Vogels van pionierbegroeiingen, 400 - Vogels van open heide, 500 - Weidevogels, 600 - Struweelvogels, 700 - Bosrandvogels, 800 - Bosvogels, 900 - Vogels van bebouwing/overige."),
            tags$p("De ", tags$strong("Rode Lijst"), " van Nederlandse broedvogels bevat soorten die bedreigd worden of kwetsbaar zijn. De laatste actualisatie van de Rode Lijst van de Nederlandse broedvogels werd in 2017 vastgesteld door het Ministerie van Landbouw, Natuur en Voedselkwaliteit. De rode lijst wordt verdeeld in vijf categorieën: RL: Verdwenen, RL: Ernstig bedreigd, RL: Bedreigd, RL: Kwetsbaar en RL: Gevoelig."),
            tags$p("De Rode Lijst wordt eens in de 10 jaar geactualiseerd. Om tussentijds zicht op veranderingen te houden is de ", tags$strong("Oranje Lijst"), " ontwikkeld. Daarop staan 22 soorten die nog niet aan de criteria van de Rode Lijst voldoen maar waarvan wordt aangenomen dat ze dat in de nabije toekomst zullen gaan doen.")
          )
        )
      )
    )
  ),
  navbarMenu(
    "Trends",
    tabPanel(
    "TRIM",
    fluidPage(
      titlePanel("TRIM-verkenner"),
      tags$p(class = "app-subtitle", "Trends en Indices voor Monitoringdata (cbs.nl)"),
      tags$div(class = "method-label", "Trendindex - beschrijvend, geen verklarend model"),
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
          div(class = "download-row",
              downloadButton("download_trim_script", "R-script analyse")),
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
              uiOutput("trim_species_model_warning_ui"),
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
      tags$div(class = "method-label", "Jaar-op-jaar trendmaat - beschrijvend"),
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
          div(class = "download-row",
              downloadButton("download_lambda_script", "R-script analyse")),
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
  ),
  navbarMenu(
    "Analyses",
    tabPanel(
    "GEE",
    fluidPage(
      titlePanel("GEE"),
      tags$p(class = "app-subtitle", "Verklarende analyse van covariaten op herhaalde plotmetingen."),
      tags$div(class = "method-label", "Verklarend populatiegemiddeld telmodel"),
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
              "GEE-modus",
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
            actionButton("run_gee_analysis", "Voer GEE-analyse uit", class = "btn-primary"),
            conditionalPanel(
              "input.gee_mode == 'regular'",
              tags$div(style = "margin-top:8px;"),
              actionButton("run_gee_screening", "Screening GEE")
            )
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
              downloadButton("download_gee_coefficients", "CSV GEE coefs"),
              downloadButton("download_gee_dataset", "CSV GEE dataset"),
              downloadButton("download_gee_script", "R-script analyse")
            ),
            h4("Coefficienten"),
            tableOutput("gee_coef_table"),
            h4("Overdispersie-diagnose"),
            tableOutput("gee_overdispersion_table"),
            h4("Telinspanning/detectie"),
            tableOutput("gee_detection_effort_table"),
            h4("VIF multicollineariteit"),
            tableOutput("gee_vif_table"),
            h4("Gebruikte kavels"),
            tableOutput("gee_plot_usage_table"),
            h4("Gebruikte plot-jaren"),
            tableOutput("gee_dataset_table")
          )
        )
      )
    )
  ),
    tabPanel(
    "GLMM",
    fluidPage(
      titlePanel("GLMM"),
      tags$p(class = "app-subtitle", "Verklarende analyse met random intercept voor plot."),
      tags$div(class = "method-label", "Verklarend mixed telmodel"),
      fluidRow(
        column(
          4,
          div(
            class = "soft-card",
            h3("Selectie"),
            uiOutput("glmm_plot_selector_ui"),
            uiOutput("glmm_year_selector_ui"),
            radioButtons(
              "glmm_mode",
              "GLMM-modus",
              choices = c("Reguliere analyse" = "regular", "Kenmerkenanalyse" = "traits"),
              selected = "regular",
              inline = FALSE
            ),
            conditionalPanel(
              "input.glmm_mode == 'regular'",
              radioButtons(
                "glmm_target_type",
                "Analyse-niveau",
                choices = c("Soort" = "species", "Vogelgroep" = "group", "Rode/Oranje Lijst" = "richtlijn"),
                selected = "species",
                inline = TRUE
              ),
              uiOutput("glmm_target_picker_ui")
            ),
            uiOutput("glmm_trait_controls_ui"),
            selectInput(
              "glmm_family",
              "Verdeling",
              choices = c("Poisson" = "poisson", "Negative binomial" = "nbinom2"),
              selected = "nbinom2"
            ),
            conditionalPanel(
              "input.glmm_mode == 'regular'",
              selectInput(
                "glmm_random_effects",
                "Random effects",
                choices = c(
                  "Plot-intercept (1 | plot)" = "plot_intercept",
                  "Plot + jaar-intercept (1 | plot) + (1 | jaar)" = "plot_year_intercept",
                  "Jaar-slope per plot (year | plot)" = "year_slope_plot"
                ),
                selected = "plot_intercept"
              )
            ),
            conditionalPanel(
              "input.glmm_mode == 'regular'",
              checkboxGroupInput(
                "glmm_covariates",
                "Vaste Covariaten",
                choices = setNames(
                  gee_covariate_specs()$code,
                  gee_covariate_specs()$label
                ),
                selected = c("stikstof_mean", "toegankelijkheid_status")
              ),
              uiOutput("glmm_ahn_covariate_ui"),
              uiOutput("glmm_infra_covariate_ui"),
              uiOutput("glmm_habitat_covariate_ui")
            ),
            actionButton("run_glmm_analysis", "Voer GLMM-analyse uit", class = "btn-primary"),
            tags$p(class = "section-note", "GLMM gebruikt in reguliere analyse vaste covariaten plus random intercept voor plot. In kenmerkenanalyse wordt per vogelkenmerk de interactie jaar x kenmerk getoetst met random intercepts voor plot en soort.")
          )
        ),
        column(
          8,
          div(
            class = "soft-card",
            h3("Modelstatus"),
            textOutput("glmm_analysis_status"),
            tags$div(style = "margin-top:12px;"),
            verbatimTextOutput("glmm_selection_summary")
          ),
          div(
            class = "soft-card",
            h3("Effectschattingen"),
            tags$p(class = "section-note", "De grafiek toont Incident Rate Ratios (IRR) met 95%-betrouwbaarheidsinterval."),
            plotOutput("glmm_coef_plot", height = "420px"),
            div(
              class = "download-row",
              downloadButton("download_glmm_coefficients", "CSV GLMM coefs"),
              downloadButton("download_glmm_dataset", "CSV GLMM dataset"),
              downloadButton("download_glmm_script", "R-script analyse")
            ),
            h4("Coefficienten"),
            tableOutput("glmm_coef_table"),
            h4("Overdispersie-diagnose"),
            tableOutput("glmm_overdispersion_table"),
            h4("GLMM-diagnostiek"),
            tableOutput("glmm_diagnostics_table"),
            h4("Random-effect variantie"),
            plotOutput("glmm_random_effects_plot", height = "260px"),
            h4("Telinspanning/detectie"),
            tableOutput("glmm_detection_effort_table"),
            h4("Gebruikte kavels"),
            tableOutput("glmm_plot_usage_table"),
            h4("Gebruikte plot-jaren"),
            tableOutput("glmm_dataset_table")
          )
        )
      )
    )
  ),
  community_analysis_tab(
    "Occupancy", "occupancy",
    "Analyse van territoriumbezetting; later uitbreidbaar naar detectie/niet-detectie.",
    "Voer occupancy-analyse uit",
    "Occupancy gebruikt unmarked en dagbezoeken als herhaalde detectiemomenten. Alleen selecties met voldoende dagbezoeken kunnen detectiegecorrigeerd worden.",
    extra_controls = tagList(
      selectInput("occupancy_min_visits", "Minimaal aantal bezoeken per plot-jaar", choices = c("2" = 2, "3" = 3, "4" = 4), selected = 2),
      checkboxGroupInput(
        "occupancy_detection_covariates",
        "Detectiecovariaten",
        choices = c("Dag in seizoen" = "dagvanjaar", "Bezoekduur" = "bezoekduur_min", "Gunstig bezoek" = "gunstig"),
        selected = c("dagvanjaar", "bezoekduur_min", "gunstig")
      ),
      checkboxGroupInput(
        "occupancy_site_covariates",
        "Sitecovariaten",
        choices = c("Jaar" = "year_c", "Stikstof" = "stikstof_mean", "AHN hoogte" = "ahn_mean", "Afstand tot pad" = "afstand_pad_m"),
        selected = "year_c"
      )
    )
  ),
    tabPanel(
    "NMDS",
    fluidPage(
      titlePanel("NMDS"),
      tags$p(class = "app-subtitle", "Exploratieve ordinatie van soortensamenstelling op basis van getelde plot-jaren."),
      tags$div(class = "method-label", "Exploratieve ordinatie - geen causaliteit"),
      fluidRow(
        column(
          4,
          div(
            class = "soft-card",
            h3("Selectie"),
            uiOutput("nmds_plot_selector_ui"),
            uiOutput("nmds_year_selector_ui"),
            radioButtons(
              "nmds_selection_type",
              "Soortselectie",
              choices = c("Alle soorten" = "all", "Vogelgroep" = "group", "Rode/Oranje Lijst" = "richtlijn", "Vogelkenmerk" = "trait"),
              selected = "all",
              inline = FALSE
            ),
            uiOutput("nmds_selection_picker_ui"),
            selectInput(
              "nmds_transform",
              "Transformatie",
              choices = c("Hellinger" = "hellinger", "Presence/absence" = "presence_absence", "Log1p" = "log1p", "Ruw" = "raw"),
              selected = "hellinger"
            ),
            selectInput(
              "nmds_distance",
              "Afstandsmaat",
              choices = c("Bray-Curtis" = "bray", "Jaccard" = "jaccard", "Euclidean" = "euclidean"),
              selected = "bray"
            ),
            selectInput("nmds_dimensions", "Dimensies", choices = c("2D" = 2, "3D" = 3), selected = 2),
            checkboxInput("nmds_show_trajectories", "Tijdstrajecten per kavel tonen", value = TRUE),
            actionButton("run_nmds_analysis", "Voer NMDS-analyse uit", class = "btn-primary"),
            tags$p(class = "section-note", "NMDS gebruikt getelde plot-jaren. Echte nullen blijven 0; niet-getelde plot-jaren blijven buiten de community-matrix.")
          )
        ),
        column(
          8,
          div(
            class = "soft-card",
            h3("Modelstatus"),
            textOutput("nmds_analysis_status"),
            tags$div(style = "margin-top:12px;"),
            verbatimTextOutput("nmds_selection_summary")
          ),
          div(
            class = "soft-card",
            h3("Ordinatie"),
            tags$p(class = "section-note", "Punten zijn plot-jaren. De kleur geeft het jaar weer; labels tonen de kavel."),
            plotOutput("nmds_plot", height = "500px"),
            div(
              class = "download-row",
              downloadButton("download_nmds_sites", "CSV NMDS site-scores"),
              downloadButton("download_nmds_species", "CSV NMDS soort-scores"),
              downloadButton("download_nmds_matrix", "CSV NMDS matrix"),
              downloadButton("download_nmds_script", "R-script analyse")
            ),
            h4("Site-scores"),
            tableOutput("nmds_site_table"),
            h4("Soort-scores"),
            tableOutput("nmds_species_table"),
            h4("Envfit"),
            tableOutput("nmds_envfit_table"),
            h4("Shepard-diagram"),
            plotOutput("nmds_shepard_plot", height = "360px"),
            h4("Gebruikte plot-jaren"),
            tableOutput("nmds_sample_table"),
            h4("Telinspanning/detectie"),
            tableOutput("nmds_detection_effort_table")
          )
        )
      )
    )
  ),
  community_analysis_tab(
    "RDA", "rda",
    "Verklarende ordinatie van soortensamenstelling met omgevingsvariabelen.",
    "Voer RDA-analyse uit",
    "RDA gebruikt getelde plot-jaren en koppelt de community-matrix in territoria per km2 aan jaar, stikstof, AHN-hoogte en afstand tot pad.",
    extra_controls = tagList(
      selectInput("rda_transform", "Transformatie", choices = c("Hellinger" = "hellinger", "Presence/absence" = "presence_absence", "Log1p" = "log1p", "Ruw" = "raw"), selected = "hellinger"),
      selectInput("rda_condition", "Partial RDA", choices = c("Geen conditionering" = "none", "Conditioneer voor jaar" = "year"), selected = "none")
    )
  ),
  community_analysis_tab(
    "PLS", "pls",
    "Partial Least Squares regressie van soortensamenstelling op omgevingsvariabelen.",
    "Voer PLS-analyse uit",
    "PLS gebruikt getelde plot-jaren en koppelt de community-matrix in territoria per km2 aan jaar, stikstof, AHN-hoogte en afstand tot pad.",
    extra_controls = tagList(
      selectInput("pls_transform", "Transformatie", choices = c("Hellinger" = "hellinger", "Presence/absence" = "presence_absence", "Log1p" = "log1p", "Ruw" = "raw"), selected = "hellinger"),
      selectInput("pls_components", "Componenten", choices = c("1" = 1, "2" = 2, "3" = 3, "4" = 4), selected = 2)
    )
  ),
  community_analysis_tab(
    "Changepoint", "changepoint",
    "Detectie van omslagpunten in ecologische tijdreeksen.",
    "Voer changepoint-analyse uit",
    "Changepoint gebruikt jaarlijkse tellingen, TRIM-indexen of MSI als invoer. Niet-getelde jaren worden niet als nul ingevuld; controleer altijd de plotdekking en penaltygevoeligheid.",
    extra_controls = tagList(
      selectInput(
        "changepoint_source",
        "Invoerbron",
        choices = c(
          "Jaarlijkse tellingen" = "community",
          "TRIM-indexen" = "trim_index",
          "MSI" = "msi"
        ),
        selected = "community"
      ),
      selectInput("changepoint_metric", "Reeks", choices = c("Totaal territoria per km2" = "totaal_territoria_per_km2", "Soortenrijkdom" = "soortenrijkdom"), selected = "totaal_territoria_per_km2"),
      selectInput("changepoint_method", "Methode", choices = c("Niveauverandering enkele knip" = "level", "Trendbreuk enkele knip" = "trend", "Meerdere niveau-omslagpunten PELT" = "multi"), selected = "level"),
      selectInput("changepoint_penalty", "Penalty PELT", choices = c("MBIC", "BIC", "SIC", "AIC"), selected = "MBIC")
    )
  ),
  community_analysis_tab(
    "SEM", "sem",
    "SEM-verkenning voor directe en indirecte relaties tussen variabelen.",
    "Voer SEM-verkenning uit",
    "SEM gebruikt nu alleen het verkennende model. Hypothese-templates zijn voorbereid, maar worden pas actief zodra begrazing- en struweeldata beschikbaar zijn.",
    extra_controls = tagList(
      tags$label(`for` = "sem_template_disabled", "SEM-modeltemplate"),
      tags$select(
        id = "sem_template_disabled",
        class = "form-select",
        disabled = "disabled",
        tags$option("Verkennende SEM (actief)"),
        tags$option("Begrazing -> Struweel -> doelsoort (vereist begrazing- en struweeldata)"),
        tags$option("Begrazing -> doelsoort (vereist begrazingsdata)"),
        tags$option("Direct + indirect model (vereist begrazing- en struweeldata)")
      ),
      tags$div(
        class = "method-warning",
        tags$strong("Voorbereid, nog niet actief. "),
        "Voor hypothesegedreven SEM zijn minimaal begrazing per plot-jaar, struweel/vegetatiestructuur per plot-jaar en een doelsoortrespons nodig."
      ),
      tags$p(
        class = "section-note",
        "Geplande output: directe effecten, indirecte effecten, totaal effect, gestandaardiseerde effecten, fitmaten, modelvergelijking en een padendiagram."
      )
    )
  ),
  community_analysis_tab(
    "Beta-Diversity", "betadiversity",
    "Analyse van verschillen in soortensamenstelling tussen plots, jaren of perioden.",
    "Voer beta-diversity analyse uit",
    "Beta-diversity gebruikt Sorensen presence/absence op getelde plot-jaren. Echte nullen gelden als afwezigheid; niet-getelde plot-jaren blijven buiten de analyse.",
    extra_controls = tagList(
      tags$p(class = "section-note", "Methode: betapart::beta.pair met index.family = 'sorensen'.")
    )
  )
  )
)

server <- function(input, output, session) {
  tbls_rv <- reactiveVal(NULL)
  analyse_rv <- reactiveVal(NULL)
  lambda_analyse_rv <- reactiveVal(NULL)
  gee_analyse_rv <- reactiveVal(NULL)
  glmm_analyse_rv <- reactiveVal(NULL)
  nmds_analyse_rv <- reactiveVal(NULL)
  rda_analyse_rv <- reactiveVal(NULL)
  pls_analyse_rv <- reactiveVal(NULL)
  changepoint_analyse_rv <- reactiveVal(NULL)
  sem_analyse_rv <- reactiveVal(NULL)
  betadiversity_analyse_rv <- reactiveVal(NULL)
  occupancy_analyse_rv <- reactiveVal(NULL)
  load_info_rv <- reactiveVal("Nog geen SQL geladen.")
  analysis_info_rv <- reactiveVal("Nog geen analyse uitgevoerd.")
  lambda_analysis_info_rv <- reactiveVal("Nog geen LAMBDA-analyse uitgevoerd.")
  gee_analysis_info_rv <- reactiveVal("Nog geen GEE-analyse uitgevoerd.")
  glmm_analysis_info_rv <- reactiveVal("Nog geen GLMM-analyse uitgevoerd.")
  nmds_analysis_info_rv <- reactiveVal("Nog geen NMDS-analyse uitgevoerd.")
  rda_analysis_info_rv <- reactiveVal("Nog geen RDA-analyse uitgevoerd.")
  pls_analysis_info_rv <- reactiveVal("Nog geen PLS-analyse uitgevoerd.")
  changepoint_analysis_info_rv <- reactiveVal("Nog geen changepoint-analyse uitgevoerd.")
  sem_analysis_info_rv <- reactiveVal("Nog geen SEM-verkenning uitgevoerd.")
  betadiversity_analysis_info_rv <- reactiveVal("Nog geen beta-diversity analyse uitgevoerd.")
  occupancy_analysis_info_rv <- reactiveVal("Nog geen occupancy-analyse uitgevoerd.")
  community_rvs <- list(
    rda = rda_analyse_rv,
    pls = pls_analyse_rv,
    changepoint = changepoint_analyse_rv,
    sem = sem_analyse_rv,
    betadiversity = betadiversity_analyse_rv,
    occupancy = occupancy_analyse_rv
  )
  community_infos <- list(
    rda = rda_analysis_info_rv,
    pls = pls_analysis_info_rv,
    changepoint = changepoint_analysis_info_rv,
    sem = sem_analysis_info_rv,
    betadiversity = betadiversity_analysis_info_rv,
    occupancy = occupancy_analysis_info_rv
  )

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

  output$glmm_analysis_status <- renderText({
    glmm_analysis_info_rv()
  })

  output$nmds_analysis_status <- renderText({
    nmds_analysis_info_rv()
  })

  output$rda_analysis_status <- renderText({
    rda_analysis_info_rv()
  })

  output$pls_analysis_status <- renderText({
    pls_analysis_info_rv()
  })

  output$changepoint_analysis_status <- renderText({
    changepoint_analysis_info_rv()
  })

  output$sem_analysis_status <- renderText({
    sem_analysis_info_rv()
  })

  output$betadiversity_analysis_status <- renderText({
    betadiversity_analysis_info_rv()
  })

  output$occupancy_analysis_status <- renderText({
    occupancy_analysis_info_rv()
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

  output$glmm_plot_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(tags$p("Laad eerst Meijendel.sql"))
    }
    kavels <- sort(unique(tbls$plots$kavel_nummer))
    selectizeInput(
      "glmm_selected_plots",
      "Kavel(s)",
      choices = kavels,
      selected = character(0),
      multiple = TRUE,
      options = list(plugins = list("remove_button"))
    )
  })

  output$glmm_year_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(NULL)
    }
    years <- sort(unique(tbls$plot_jaar_oppervlak$jaar))
    tagList(
      selectInput("glmm_year_from", "Van jaar", choices = years, selected = max(min(years), 1984)),
      selectInput("glmm_year_to", "Tot jaar", choices = years, selected = max(years))
    )
  })

  output$glmm_target_picker_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(NULL)
    }
    if (identical(input$glmm_target_type, "group")) {
      groepen <- build_group_mapping(tbls)
      groepen <- unique(groepen[, c("groep_100", "groep_titel")])
      groepen <- groepen[order(groepen$groep_100), , drop = FALSE]
      choices <- setNames(groepen$groep_100, paste0(groepen$groep_100, " - ", groepen$groep_titel))
      return(selectizeInput("glmm_group", "Vogelgroep", choices = choices, selected = groepen$groep_100[[1]], multiple = FALSE))
    }
    if (identical(input$glmm_target_type, "richtlijn")) {
      richtlijnen <- build_richtlijn_mapping(tbls)
      richtlijnen <- unique(richtlijnen[, c("richtlijn_id", "richtlijn_titel", "richtlijn_volgorde")])
      richtlijnen <- richtlijnen[order(richtlijnen$richtlijn_volgorde), , drop = FALSE]
      choices <- setNames(richtlijnen$richtlijn_id, richtlijnen$richtlijn_titel)
      return(selectizeInput("glmm_richtlijn", "Rode/Oranje Lijst", choices = choices, selected = richtlijnen$richtlijn_id[[1]], multiple = FALSE))
    }
    soorten <- sort(tbls$soorten$soort_naam)
    selectizeInput("glmm_species", "Soort", choices = soorten, selected = "Nachtegaal", multiple = FALSE)
  })

  output$glmm_trait_controls_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls) || !identical(input$glmm_mode, "traits")) {
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
        "glmm_trait_scope",
        "Soortselectie",
        choices = c("Alle soorten" = "all", "Vogelgroep" = "group", "Rode/Oranje Lijst" = "richtlijn"),
        selected = "all"
      ),
      conditionalPanel(
        "input.glmm_trait_scope == 'group'",
        selectizeInput("glmm_trait_group", "Vogelgroep", choices = setNames(groepen$groep_100, groepen$groep_titel), selected = groepen$groep_100[[1]], multiple = FALSE)
      ),
      conditionalPanel(
        "input.glmm_trait_scope == 'richtlijn'",
        selectizeInput("glmm_trait_richtlijn", "Rode/Oranje Lijst", choices = setNames(richtlijnen$richtlijn_id, richtlijnen$richtlijn_titel), selected = richtlijnen$richtlijn_id[[1]], multiple = FALSE)
      ),
      selectInput(
        "glmm_trait_hoofdcategorie",
        "Hoofdcategorie kenmerken",
        choices = setNames(hoofdcats$hoofdcategorie_id, hoofdcats$hoofdcategorie_label),
        selected = hoofdcats$hoofdcategorie_id[[1]]
      ),
      checkboxGroupInput(
        "glmm_trait_code_types",
        "Diepgang",
        choices = c("Hoofdkenmerken" = "main", "Subkenmerken" = "sub", "Detailkenmerken" = "detail"),
        selected = c("main")
      ),
      numericInput("glmm_trait_min_species", "Minimum soorten met en zonder kenmerk", value = 5, min = 3, max = 25, step = 1),
      tags$p(class = "section-note", "De screening toetst per kenmerk de interactie jaar x kenmerk met random intercepts voor plot en soort.")
    )
  })

  output$glmm_ahn_covariate_ui <- renderUI({
    specs <- gee_ahn_covariate_specs()
    selectizeInput(
      "glmm_ahn_covariates",
      "AHN",
      choices = setNames(specs$code, specs$label),
      selected = c("ahn_mean"),
      multiple = TRUE,
      options = list(plugins = list("remove_button"))
    )
  })

  output$glmm_infra_covariate_ui <- renderUI({
    specs <- gee_infra_covariate_specs()
    selectizeInput(
      "glmm_infra_covariates",
      "Infra & recreatie",
      choices = setNames(specs$code, specs$label),
      selected = c("afstand_pad_m"),
      multiple = TRUE,
      options = list(plugins = list("remove_button"))
    )
  })

  output$glmm_habitat_covariate_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(NULL)
    }
    specs <- gee_habitat_covariate_specs(tbls)
    if (!nrow(specs)) {
      return(tags$p(class = "section-note", "Geen habitattypen beschikbaar. Laad de SQL opnieuw zodat de vernieuwde cache wordt opgebouwd."))
    }
    selectizeInput(
      "glmm_habitat_covariates",
      "Habitattypen",
      choices = setNames(specs$code, specs$label),
      selected = character(0),
      multiple = TRUE,
      options = list(plugins = list("remove_button"))
    )
  })

  output$nmds_plot_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(tags$p("Laad eerst Meijendel.sql"))
    }
    kavels <- sort(unique(tbls$plots$kavel_nummer))
    selectizeInput(
      "nmds_selected_plots",
      "Kavel(s)",
      choices = kavels,
      selected = character(0),
      multiple = TRUE,
      options = list(plugins = list("remove_button"))
    )
  })

  output$nmds_year_selector_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(NULL)
    }
    years <- sort(unique(tbls$plot_jaar_oppervlak$jaar))
    tagList(
      selectInput("nmds_year_from", "Van jaar", choices = years, selected = max(min(years), 1984)),
      selectInput("nmds_year_to", "Tot jaar", choices = years, selected = max(years))
    )
  })

  output$nmds_selection_picker_ui <- renderUI({
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      return(NULL)
    }
    if (identical(input$nmds_selection_type, "group")) {
      groepen <- build_group_mapping(tbls)
      groepen <- unique(groepen[, c("groep_100", "groep_titel")])
      groepen <- groepen[order(groepen$groep_100), , drop = FALSE]
      choices <- setNames(groepen$groep_100, paste0(groepen$groep_100, " - ", groepen$groep_titel))
      return(selectizeInput("nmds_group", "Vogelgroep", choices = choices, selected = groepen$groep_100[[1]], multiple = FALSE))
    }
    if (identical(input$nmds_selection_type, "richtlijn")) {
      richtlijnen <- build_richtlijn_mapping(tbls)
      richtlijnen <- unique(richtlijnen[, c("richtlijn_id", "richtlijn_titel", "richtlijn_volgorde")])
      richtlijnen <- richtlijnen[order(richtlijnen$richtlijn_volgorde), , drop = FALSE]
      choices <- setNames(richtlijnen$richtlijn_id, richtlijnen$richtlijn_titel)
      return(selectizeInput("nmds_richtlijn", "Rode/Oranje Lijst", choices = choices, selected = richtlijnen$richtlijn_id[[1]], multiple = FALSE))
    }
    if (identical(input$nmds_selection_type, "trait")) {
      catalog <- build_soort_kenmerken_catalog(tbls)
      validate(need(nrow(catalog) > 0, "Geen soortkenmerken beschikbaar in deze SQL."))
      hoofdcats <- unique(catalog[, c("hoofdcategorie_id", "hoofdcategorie_label")])
      hoofdcats <- hoofdcats[order(hoofdcats$hoofdcategorie_id), , drop = FALSE]
      selected_hc <- input$nmds_trait_hoofdcategorie
      if (is.null(selected_hc) || !selected_hc %in% as.character(hoofdcats$hoofdcategorie_id)) {
        selected_hc <- hoofdcats$hoofdcategorie_id[[1]]
      }
      filtered <- catalog[catalog$hoofdcategorie_id == as.integer(selected_hc), , drop = FALSE]
      filtered <- filtered[order(filtered$code_type, filtered$kenmerk_label), , drop = FALSE]
      tagList(
        selectInput(
          "nmds_trait_hoofdcategorie",
          "Hoofdcategorie kenmerken",
          choices = setNames(hoofdcats$hoofdcategorie_id, hoofdcats$hoofdcategorie_label),
          selected = selected_hc
        ),
        selectizeInput(
          "nmds_trait_code",
          "Vogelkenmerk",
          choices = setNames(filtered$code, paste0(filtered$code, " - ", filtered$kenmerk_label)),
          selected = filtered$code[[1]],
          multiple = FALSE
        )
      )
    }
    tags$p(class = "section-note", "Alle soorten met territoria binnen de geselecteerde kavels en jaren worden meegenomen.")
  })

  for (community_prefix in c("rda", "pls", "changepoint", "sem", "betadiversity", "occupancy")) {
    local({
      prefix <- community_prefix
      output[[paste0(prefix, "_plot_selector_ui")]] <- renderUI({
        tbls <- tbls_rv()
        if (is.null(tbls)) {
          return(tags$p("Laad eerst Meijendel.sql"))
        }
        kavels <- sort(unique(tbls$plots$kavel_nummer))
        selectizeInput(
          paste0(prefix, "_selected_plots"),
          "Kavel(s)",
          choices = kavels,
          selected = character(0),
          multiple = TRUE,
          options = list(plugins = list("remove_button"))
        )
      })

      output[[paste0(prefix, "_year_selector_ui")]] <- renderUI({
        tbls <- tbls_rv()
        if (is.null(tbls)) {
          return(NULL)
        }
        years <- sort(unique(tbls$plot_jaar_oppervlak$jaar))
        tagList(
          selectInput(paste0(prefix, "_year_from"), "Van jaar", choices = years, selected = max(min(years), 1984)),
          selectInput(paste0(prefix, "_year_to"), "Tot jaar", choices = years, selected = max(years))
        )
      })

      output[[paste0(prefix, "_selection_picker_ui")]] <- renderUI({
        tbls <- tbls_rv()
        if (is.null(tbls)) {
          return(NULL)
        }
        selection_type <- input[[paste0(prefix, "_selection_type")]]
        if (identical(selection_type, "group")) {
          groepen <- build_group_mapping(tbls)
          groepen <- unique(groepen[, c("groep_100", "groep_titel")])
          groepen <- groepen[order(groepen$groep_100), , drop = FALSE]
          choices <- setNames(groepen$groep_100, paste0(groepen$groep_100, " - ", groepen$groep_titel))
          return(selectizeInput(paste0(prefix, "_group"), "Vogelgroep", choices = choices, selected = groepen$groep_100[[1]], multiple = FALSE))
        }
        if (identical(selection_type, "richtlijn")) {
          richtlijnen <- build_richtlijn_mapping(tbls)
          richtlijnen <- unique(richtlijnen[, c("richtlijn_id", "richtlijn_titel", "richtlijn_volgorde")])
          richtlijnen <- richtlijnen[order(richtlijnen$richtlijn_volgorde), , drop = FALSE]
          choices <- setNames(richtlijnen$richtlijn_id, richtlijnen$richtlijn_titel)
          return(selectizeInput(paste0(prefix, "_richtlijn"), "Rode/Oranje Lijst", choices = choices, selected = richtlijnen$richtlijn_id[[1]], multiple = FALSE))
        }
        if (identical(selection_type, "trait")) {
          catalog <- build_soort_kenmerken_catalog(tbls)
          validate(need(nrow(catalog) > 0, "Geen soortkenmerken beschikbaar in deze SQL."))
          hoofdcats <- unique(catalog[, c("hoofdcategorie_id", "hoofdcategorie_label")])
          hoofdcats <- hoofdcats[order(hoofdcats$hoofdcategorie_id), , drop = FALSE]
          selected_hc <- input[[paste0(prefix, "_trait_hoofdcategorie")]]
          if (is.null(selected_hc) || !selected_hc %in% as.character(hoofdcats$hoofdcategorie_id)) {
            selected_hc <- hoofdcats$hoofdcategorie_id[[1]]
          }
          filtered <- catalog[catalog$hoofdcategorie_id == as.integer(selected_hc), , drop = FALSE]
          filtered <- filtered[order(filtered$code_type, filtered$kenmerk_label), , drop = FALSE]
          return(tagList(
            selectInput(
              paste0(prefix, "_trait_hoofdcategorie"),
              "Hoofdcategorie kenmerken",
              choices = setNames(hoofdcats$hoofdcategorie_id, hoofdcats$hoofdcategorie_label),
              selected = selected_hc
            ),
            selectizeInput(
              paste0(prefix, "_trait_code"),
              "Vogelkenmerk",
              choices = setNames(filtered$code, paste0(filtered$code, " - ", filtered$kenmerk_label)),
              selected = filtered$code[[1]],
              multiple = FALSE
            )
          ))
        }
        tags$p(class = "section-note", "Alle soorten met territoria binnen de geselecteerde kavels en jaren worden meegenomen.")
      })
    })
  }

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
        analyse <- attach_analysis_export_script(
          analyse,
          "TRIM",
          "analyse_subset",
          list(tbls = r_code("tbls"), selected_kavels = selected_plots, year_from = year_from, year_to = year_to)
        )
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
        analyse <- attach_analysis_export_script(
          analyse,
          "LAMBDA",
          "analyse_lambda_subset",
          list(tbls = r_code("tbls"), selected_kavels = selected_plots, year_from = year_from, year_to = year_to)
        )
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
      gee_analysis_info_rv("GEE-kenmerkenanalyse draait...")
      tryCatch({
        withProgress(message = "GEE-kenmerkenanalyse draait", detail = "Soortkenmerken worden een voor een getoetst.", value = 0.1, {
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
          analyse <- attach_analysis_export_script(
            analyse,
            "GEE kenmerkenanalyse",
            "run_gee_trait_screening",
            list(
              tbls = r_code("tbls"),
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
          )
          species_ids <- select_species_for_nmds(tbls, input$gee_trait_scope, scope_value)
          analyse <- add_detection_effort_to_analysis(analyse, tbls, selected_plots, year_from, year_to, species_ids = species_ids)
          incProgress(0.9)
          gee_analyse_rv(analyse)
        })
        gee_analysis_info_rv("GEE-kenmerkenanalyse gereed.")
        showNotification("GEE-kenmerkenanalyse gereed.", type = "message", duration = 4)
      }, error = function(e) {
        gee_analysis_info_rv(paste("Fout bij GEE-kenmerkenanalyse:", conditionMessage(e)))
        showNotification(paste("Fout bij GEE-kenmerkenanalyse:", conditionMessage(e)), type = "error", duration = NULL)
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
    gee_analysis_info_rv("GEE-analyse draait...")
    tryCatch({
      withProgress(message = "GEE-analyse draait", detail = "Covariaten worden gekoppeld en het model wordt geschat.", value = 0.1, {
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
        analyse <- attach_analysis_export_script(
          analyse,
          "GEE",
          "run_gee_subset",
          list(
            tbls = r_code("tbls"),
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
          )
        species_ids <- select_species_for_target(tbls, input$gee_target_type, target_value)
        analyse <- add_detection_effort_to_analysis(analyse, tbls, selected_plots, year_from, year_to, species_ids = species_ids)
        incProgress(0.9)
        gee_analyse_rv(analyse)
      })
      gee_analysis_info_rv("GEE-analyse gereed.")
      showNotification("GEE-analyse gereed.", type = "message", duration = 4)
    }, error = function(e) {
      gee_analysis_info_rv(paste("Fout bij GEE-analyse:", conditionMessage(e)))
      showNotification(paste("Fout bij GEE-analyse:", conditionMessage(e)), type = "error", duration = NULL)
    })
  })

  observeEvent(input$run_gee_screening, {
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      gee_analysis_info_rv("Laad eerst Meijendel.sql.")
      showNotification("Laad eerst Meijendel.sql.", type = "error", duration = 5)
      return()
    }
    if (!identical(input$gee_mode, "regular")) {
      gee_analysis_info_rv("Screening GEE is beschikbaar in de reguliere GEE-modus.")
      showNotification("Screening GEE is beschikbaar in de reguliere GEE-modus.", type = "error", duration = 5)
      return()
    }
    if (!identical(input$gee_target_type, "species")) {
      gee_analysis_info_rv("Screening GEE draait per soort. Kies analyse-niveau 'Soort'.")
      showNotification("Screening GEE draait per soort. Kies analyse-niveau 'Soort'.", type = "error", duration = 5)
      return()
    }
    selected_plots <- if (is.null(input$gee_selected_plots)) character(0) else input$gee_selected_plots
    if (!length(selected_plots)) {
      gee_analysis_info_rv("Kies eerst minstens één kavel.")
      showNotification("Kies eerst minstens één kavel.", type = "error", duration = 5)
      return()
    }
    if (is.null(input$gee_species) || !nzchar(input$gee_species)) {
      gee_analysis_info_rv("Kies eerst een soort.")
      showNotification("Kies eerst een soort.", type = "error", duration = 5)
      return()
    }
    year_from <- as.integer(input$gee_year_from)
    year_to <- as.integer(input$gee_year_to)
    if (!is.finite(year_from) || !is.finite(year_to) || year_from > year_to) {
      gee_analysis_info_rv("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.")
      showNotification("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.", type = "error", duration = 5)
      return()
    }
    gee_analysis_info_rv("Screening GEE draait...")
    tryCatch({
      withProgress(message = "Screening GEE draait", detail = "Alle beschikbare variabelen worden enkelvoudig getoetst.", value = 0.1, {
        analyse <- run_gee_screening_subset(
          tbls = tbls,
          selected_kavels = selected_plots,
          year_from = year_from,
          year_to = year_to,
          species_name = input$gee_species,
          gee_corstr = input$gee_corstr
        )
        analyse <- attach_analysis_export_script(
          analyse,
          "GEE screening",
          "run_gee_screening_subset",
          list(
            tbls = r_code("tbls"),
            selected_kavels = selected_plots,
            year_from = year_from,
            year_to = year_to,
            species_name = input$gee_species,
            gee_corstr = input$gee_corstr
          )
          )
        species_ids <- select_species_for_target(tbls, "species", input$gee_species)
        analyse <- add_detection_effort_to_analysis(analyse, tbls, selected_plots, year_from, year_to, species_ids = species_ids)
        incProgress(0.9)
        gee_analyse_rv(analyse)
      })
      gee_analysis_info_rv("Screening GEE gereed.")
      showNotification("Screening GEE gereed.", type = "message", duration = 4)
    }, error = function(e) {
      gee_analysis_info_rv(paste("Fout bij Screening GEE:", conditionMessage(e)))
      showNotification(paste("Fout bij Screening GEE:", conditionMessage(e)), type = "error", duration = NULL)
    })
  })

  observeEvent(input$run_glmm_analysis, {
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      glmm_analysis_info_rv("Laad eerst Meijendel.sql.")
      showNotification("Laad eerst Meijendel.sql.", type = "error", duration = 5)
      return()
    }
    glmm_mode <- if (is.null(input$glmm_mode)) "regular" else input$glmm_mode
    if (is.null(input$glmm_year_from) || is.null(input$glmm_year_to)) {
      glmm_analysis_info_rv("Wacht tot de selectievelden geladen zijn.")
      showNotification("Wacht tot de selectievelden geladen zijn.", type = "error", duration = 5)
      return()
    }
    selected_plots <- if (is.null(input$glmm_selected_plots)) character(0) else input$glmm_selected_plots
    if (length(selected_plots) == 0) {
      glmm_analysis_info_rv("Kies eerst minstens één kavel.")
      showNotification("Kies eerst minstens één kavel.", type = "error", duration = 5)
      return()
    }
    year_from <- as.integer(input$glmm_year_from)
    year_to <- as.integer(input$glmm_year_to)
    if (year_from > year_to) {
      glmm_analysis_info_rv("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.")
      showNotification("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.", type = "error", duration = 5)
      return()
    }

    if (identical(glmm_mode, "traits")) {
      if (is.null(input$glmm_trait_scope) || is.null(input$glmm_trait_hoofdcategorie) || is.null(input$glmm_trait_code_types) || !length(input$glmm_trait_code_types)) {
        glmm_analysis_info_rv("Kies eerst een kenmerkenselectie.")
        showNotification("Kies eerst een kenmerkenselectie.", type = "error", duration = 5)
        return()
      }
      scope_value <- NULL
      if (identical(input$glmm_trait_scope, "group")) {
        scope_value <- input$glmm_trait_group
        if (is.null(scope_value) || !nzchar(scope_value)) {
          glmm_analysis_info_rv("Kies eerst een vogelgroep.")
          showNotification("Kies eerst een vogelgroep.", type = "error", duration = 5)
          return()
        }
      } else if (identical(input$glmm_trait_scope, "richtlijn")) {
        scope_value <- input$glmm_trait_richtlijn
        if (is.null(scope_value) || !nzchar(scope_value)) {
          glmm_analysis_info_rv("Kies eerst een Rode/Oranje Lijst-categorie.")
          showNotification("Kies eerst een Rode/Oranje Lijst-categorie.", type = "error", duration = 5)
          return()
        }
      }
      glmm_analysis_info_rv("GLMM-kenmerkenanalyse draait...")
      tryCatch({
        withProgress(message = "GLMM-kenmerkenanalyse draait", detail = "Soortkenmerken worden een voor een getoetst.", value = 0.1, {
          analyse <- run_glmm_trait_screening(
            tbls = tbls,
            selected_kavels = selected_plots,
            year_from = year_from,
            year_to = year_to,
            scope_type = input$glmm_trait_scope,
            scope_value = scope_value,
            hoofdcategorie_id = input$glmm_trait_hoofdcategorie,
            code_types = input$glmm_trait_code_types,
            min_species_per_level = as.integer(input$glmm_trait_min_species),
            glmm_family = input$glmm_family
          )
          analyse <- attach_analysis_export_script(
            analyse,
            "GLMM kenmerkenanalyse",
            "run_glmm_trait_screening",
            list(
              tbls = r_code("tbls"),
              selected_kavels = selected_plots,
              year_from = year_from,
              year_to = year_to,
              scope_type = input$glmm_trait_scope,
              scope_value = scope_value,
              hoofdcategorie_id = input$glmm_trait_hoofdcategorie,
              code_types = input$glmm_trait_code_types,
              min_species_per_level = as.integer(input$glmm_trait_min_species),
              glmm_family = input$glmm_family
            )
          )
          species_ids <- select_species_for_nmds(tbls, input$glmm_trait_scope, scope_value)
          analyse <- add_detection_effort_to_analysis(analyse, tbls, selected_plots, year_from, year_to, species_ids = species_ids)
          incProgress(0.9)
          glmm_analyse_rv(analyse)
        })
        glmm_analysis_info_rv("GLMM-kenmerkenanalyse gereed.")
        showNotification("GLMM-kenmerkenanalyse gereed.", type = "message", duration = 4)
      }, error = function(e) {
        glmm_analysis_info_rv(paste("Fout bij GLMM-kenmerkenanalyse:", conditionMessage(e)))
        showNotification(paste("Fout bij GLMM-kenmerkenanalyse:", conditionMessage(e)), type = "error", duration = NULL)
      })
      return()
    }

    if (is.null(input$glmm_target_type)) {
      glmm_analysis_info_rv("Wacht tot het analyse-niveau geladen is.")
      showNotification("Wacht tot het analyse-niveau geladen is.", type = "error", duration = 5)
      return()
    }
    if (identical(input$glmm_target_type, "species")) {
      if (is.null(input$glmm_species) || !nzchar(input$glmm_species)) {
        glmm_analysis_info_rv("Kies eerst een soort.")
        showNotification("Kies eerst een soort.", type = "error", duration = 5)
        return()
      }
      target_value <- input$glmm_species
    } else if (identical(input$glmm_target_type, "group")) {
      if (is.null(input$glmm_group) || !nzchar(input$glmm_group)) {
        glmm_analysis_info_rv("Kies eerst een vogelgroep.")
        showNotification("Kies eerst een vogelgroep.", type = "error", duration = 5)
        return()
      }
      target_value <- input$glmm_group
    } else {
      if (is.null(input$glmm_richtlijn) || !nzchar(input$glmm_richtlijn)) {
        glmm_analysis_info_rv("Kies eerst een Rode/Oranje Lijst-categorie.")
        showNotification("Kies eerst een Rode/Oranje Lijst-categorie.", type = "error", duration = 5)
        return()
      }
      target_value <- input$glmm_richtlijn
    }
    totaal_covariaten <- c(input$glmm_covariates, input$glmm_ahn_covariates, input$glmm_infra_covariates, input$glmm_habitat_covariates)
    if (length(totaal_covariaten) == 0) {
      glmm_analysis_info_rv("Kies eerst minstens één covariaat.")
      showNotification("Kies eerst minstens één covariaat.", type = "error", duration = 5)
      return()
    }

    glmm_analysis_info_rv("GLMM-analyse draait...")
    tryCatch({
      withProgress(message = "GLMM-analyse draait", detail = "Covariaten worden gekoppeld en het mixed model wordt geschat.", value = 0.1, {
        analyse <- run_glmm_subset(
          tbls = tbls,
          selected_kavels = selected_plots,
          year_from = year_from,
          year_to = year_to,
          target_type = input$glmm_target_type,
          target_value = target_value,
          covariates = input$glmm_covariates,
          ahn_covariates = input$glmm_ahn_covariates,
          infra_covariates = input$glmm_infra_covariates,
          habitat_covariates = input$glmm_habitat_covariates,
          glmm_family = input$glmm_family,
          random_effects = input$glmm_random_effects
        )
        analyse <- attach_analysis_export_script(
          analyse,
          "GLMM",
          "run_glmm_subset",
          list(
            tbls = r_code("tbls"),
            selected_kavels = selected_plots,
            year_from = year_from,
            year_to = year_to,
            target_type = input$glmm_target_type,
            target_value = target_value,
            covariates = input$glmm_covariates,
            ahn_covariates = input$glmm_ahn_covariates,
            infra_covariates = input$glmm_infra_covariates,
            habitat_covariates = input$glmm_habitat_covariates,
            glmm_family = input$glmm_family,
            random_effects = input$glmm_random_effects
          )
        )
        species_ids <- select_species_for_target(tbls, input$glmm_target_type, target_value)
        analyse <- add_detection_effort_to_analysis(analyse, tbls, selected_plots, year_from, year_to, species_ids = species_ids)
        incProgress(0.9)
        glmm_analyse_rv(analyse)
      })
      glmm_analysis_info_rv("GLMM-analyse gereed.")
      showNotification("GLMM-analyse gereed.", type = "message", duration = 4)
    }, error = function(e) {
      glmm_analysis_info_rv(paste("Fout bij GLMM-analyse:", conditionMessage(e)))
      showNotification(paste("Fout bij GLMM-analyse:", conditionMessage(e)), type = "error", duration = NULL)
    })
  })

  observeEvent(input$run_nmds_analysis, {
    tbls <- tbls_rv()
    if (is.null(tbls)) {
      nmds_analysis_info_rv("Laad eerst Meijendel.sql.")
      showNotification("Laad eerst Meijendel.sql.", type = "error", duration = 5)
      return()
    }
    if (is.null(input$nmds_year_from) || is.null(input$nmds_year_to)) {
      nmds_analysis_info_rv("Wacht tot de selectievelden geladen zijn.")
      showNotification("Wacht tot de selectievelden geladen zijn.", type = "error", duration = 5)
      return()
    }
    selected_plots <- if (is.null(input$nmds_selected_plots)) character(0) else input$nmds_selected_plots
    if (length(selected_plots) == 0) {
      nmds_analysis_info_rv("Kies eerst minstens één kavel.")
      showNotification("Kies eerst minstens één kavel.", type = "error", duration = 5)
      return()
    }
    year_from <- as.integer(input$nmds_year_from)
    year_to <- as.integer(input$nmds_year_to)
    if (year_from > year_to) {
      nmds_analysis_info_rv("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.")
      showNotification("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.", type = "error", duration = 5)
      return()
    }

    selection_value <- NULL
    if (identical(input$nmds_selection_type, "group")) {
      selection_value <- input$nmds_group
      if (is.null(selection_value) || !nzchar(selection_value)) {
        nmds_analysis_info_rv("Kies eerst een vogelgroep.")
        showNotification("Kies eerst een vogelgroep.", type = "error", duration = 5)
        return()
      }
    } else if (identical(input$nmds_selection_type, "richtlijn")) {
      selection_value <- input$nmds_richtlijn
      if (is.null(selection_value) || !nzchar(selection_value)) {
        nmds_analysis_info_rv("Kies eerst een Rode/Oranje Lijst-categorie.")
        showNotification("Kies eerst een Rode/Oranje Lijst-categorie.", type = "error", duration = 5)
        return()
      }
    } else if (identical(input$nmds_selection_type, "trait")) {
      selection_value <- input$nmds_trait_code
      if (is.null(selection_value) || !nzchar(selection_value)) {
        nmds_analysis_info_rv("Kies eerst een vogelkenmerk.")
        showNotification("Kies eerst een vogelkenmerk.", type = "error", duration = 5)
        return()
      }
    }

    nmds_analysis_info_rv("NMDS-analyse draait...")
    tryCatch({
      withProgress(message = "NMDS-analyse draait", detail = "Community-matrix wordt opgebouwd en geordineerd.", value = 0.1, {
        analyse <- run_nmds_subset(
          tbls = tbls,
          selected_kavels = selected_plots,
          year_from = year_from,
          year_to = year_to,
          selection_type = input$nmds_selection_type,
          selection_value = selection_value,
          transform = input$nmds_transform,
          distance = input$nmds_distance,
          dimensions = as.integer(input$nmds_dimensions)
        )
        analyse <- attach_analysis_export_script(
          analyse,
          "NMDS",
          "run_nmds_subset",
          list(
            tbls = r_code("tbls"),
            selected_kavels = selected_plots,
            year_from = year_from,
            year_to = year_to,
            selection_type = input$nmds_selection_type,
            selection_value = selection_value,
            transform = input$nmds_transform,
            distance = input$nmds_distance,
            dimensions = as.integer(input$nmds_dimensions)
          )
          )
        species_ids <- select_species_for_nmds(tbls, input$nmds_selection_type, selection_value)
        analyse <- add_detection_effort_to_analysis(analyse, tbls, selected_plots, year_from, year_to, species_ids = species_ids)
        incProgress(0.9)
        nmds_analyse_rv(analyse)
      })
      nmds_analysis_info_rv("NMDS-analyse gereed.")
      showNotification("NMDS-analyse gereed.", type = "message", duration = 4)
    }, error = function(e) {
      nmds_analysis_info_rv(paste("Fout bij NMDS-analyse:", conditionMessage(e)))
      showNotification(paste("Fout bij NMDS-analyse:", conditionMessage(e)), type = "error", duration = NULL)
    })
  })

  for (community_prefix in c("rda", "pls", "changepoint", "sem", "betadiversity", "occupancy")) {
    local({
      prefix <- community_prefix
      observeEvent(input[[paste0("run_", prefix, "_analysis")]], {
        tbls <- tbls_rv()
        info_rv <- community_infos[[prefix]]
        result_rv <- community_rvs[[prefix]]
        method_label <- switch(prefix, rda = "RDA", pls = "PLS", changepoint = "changepoint", sem = "SEM", betadiversity = "beta-diversity", occupancy = "occupancy")
        if (is.null(tbls)) {
          info_rv("Laad eerst Meijendel.sql.")
          showNotification("Laad eerst Meijendel.sql.", type = "error", duration = 5)
          return()
        }
        if (is.null(input[[paste0(prefix, "_year_from")]]) || is.null(input[[paste0(prefix, "_year_to")]])) {
          info_rv("Wacht tot de selectievelden geladen zijn.")
          showNotification("Wacht tot de selectievelden geladen zijn.", type = "error", duration = 5)
          return()
        }
        selected_plots <- if (is.null(input[[paste0(prefix, "_selected_plots")]])) character(0) else input[[paste0(prefix, "_selected_plots")]]
        if (length(selected_plots) == 0) {
          info_rv("Kies eerst minstens één kavel.")
          showNotification("Kies eerst minstens één kavel.", type = "error", duration = 5)
          return()
        }
        year_from <- as.integer(input[[paste0(prefix, "_year_from")]])
        year_to <- as.integer(input[[paste0(prefix, "_year_to")]])
        if (year_from > year_to) {
          info_rv("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.")
          showNotification("'Van jaar' moet kleiner of gelijk zijn aan 'Tot jaar'.", type = "error", duration = 5)
          return()
        }
        selection_type <- input[[paste0(prefix, "_selection_type")]]
        selection_value <- NULL
        if (identical(selection_type, "group")) {
          selection_value <- input[[paste0(prefix, "_group")]]
          if (is.null(selection_value) || !nzchar(selection_value)) {
            info_rv("Kies eerst een vogelgroep.")
            showNotification("Kies eerst een vogelgroep.", type = "error", duration = 5)
            return()
          }
        } else if (identical(selection_type, "richtlijn")) {
          selection_value <- input[[paste0(prefix, "_richtlijn")]]
          if (is.null(selection_value) || !nzchar(selection_value)) {
            info_rv("Kies eerst een Rode/Oranje Lijst-categorie.")
            showNotification("Kies eerst een Rode/Oranje Lijst-categorie.", type = "error", duration = 5)
            return()
          }
        } else if (identical(selection_type, "trait")) {
          selection_value <- input[[paste0(prefix, "_trait_code")]]
          if (is.null(selection_value) || !nzchar(selection_value)) {
            info_rv("Kies eerst een vogelkenmerk.")
            showNotification("Kies eerst een vogelkenmerk.", type = "error", duration = 5)
            return()
          }
        }

        info_rv(paste(method_label, "draait..."))
        tryCatch({
          withProgress(message = paste(method_label, "draait"), detail = "Community-matrix en uitkomsten worden opgebouwd.", value = 0.1, {
            analyse <- switch(
              prefix,
              rda = run_rda_subset(
                tbls, selected_plots, year_from, year_to,
                selection_type = selection_type,
                selection_value = selection_value,
                transform = input$rda_transform,
                condition = input$rda_condition
              ),
              pls = run_pls_subset(
                tbls, selected_plots, year_from, year_to,
                selection_type = selection_type,
                selection_value = selection_value,
                transform = input$pls_transform,
                ncomp = as.integer(input$pls_components)
              ),
              changepoint = run_changepoint_subset(
                tbls, selected_plots, year_from, year_to,
                selection_type = selection_type,
                selection_value = selection_value,
                source = input$changepoint_source,
                metric = input$changepoint_metric,
                method = input$changepoint_method,
                penalty = input$changepoint_penalty
              ),
              sem = run_sem_subset(
                tbls, selected_plots, year_from, year_to,
                selection_type = selection_type,
                selection_value = selection_value
              ),
              betadiversity = run_betadiversity_subset(
                tbls, selected_plots, year_from, year_to,
                selection_type = selection_type,
                selection_value = selection_value
              ),
              occupancy = run_occupancy_subset(
                tbls, selected_plots, year_from, year_to,
                selection_type = selection_type,
                selection_value = selection_value,
                min_visits = as.integer(input$occupancy_min_visits),
                detection_covariates = input$occupancy_detection_covariates,
                site_covariates = input$occupancy_site_covariates
              )
            )
            export_args <- list(
              tbls = r_code("tbls"),
              selected_kavels = selected_plots,
              year_from = year_from,
              year_to = year_to,
              selection_type = selection_type,
              selection_value = selection_value
            )
            export_function <- switch(
              prefix,
              rda = "run_rda_subset",
              pls = "run_pls_subset",
              changepoint = "run_changepoint_subset",
              sem = "run_sem_subset",
              betadiversity = "run_betadiversity_subset",
              occupancy = "run_occupancy_subset"
            )
            if (identical(prefix, "rda")) {
              export_args$transform <- input$rda_transform
              export_args$condition <- input$rda_condition
            } else if (identical(prefix, "pls")) {
              export_args$transform <- input$pls_transform
              export_args$ncomp <- as.integer(input$pls_components)
            } else if (identical(prefix, "changepoint")) {
              export_args$source <- input$changepoint_source
              export_args$metric <- input$changepoint_metric
              export_args$method <- input$changepoint_method
              export_args$penalty <- input$changepoint_penalty
            } else if (identical(prefix, "occupancy")) {
              export_args$min_visits <- as.integer(input$occupancy_min_visits)
              export_args$detection_covariates <- input$occupancy_detection_covariates
              export_args$site_covariates <- input$occupancy_site_covariates
            }
            if (!identical(prefix, "occupancy")) {
              species_ids <- select_species_for_nmds(tbls, selection_type, selection_value)
              analyse <- add_detection_effort_to_analysis(analyse, tbls, selected_plots, year_from, year_to, species_ids = species_ids)
            }
            analyse <- attach_analysis_export_script(
              analyse,
              method_label,
              export_function,
              export_args
            )
            incProgress(0.9)
            result_rv(analyse)
          })
          info_rv(paste(method_label, "gereed."))
          showNotification(paste(method_label, "gereed."), type = "message", duration = 4)
        }, error = function(e) {
          info_rv(paste("Fout bij", method_label, ":", conditionMessage(e)))
          showNotification(paste("Fout bij", method_label, ":", conditionMessage(e)), type = "error", duration = NULL)
        })
      }, ignoreInit = TRUE)
    })
  }

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
      return("Nog geen GEE-analyse uitgevoerd.")
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
    if (identical(analyse$analysis_type, "gee_screening")) {
      return(paste(
        "Analyse-niveau:", sam$analyse_niveau,
        "\nSoort:", sam$doel_label,
        "\nPlots:", sam$n_plots,
        "\nPlot-jaren:", sam$n_plot_jaren,
        "\nJaren:", sam$eerste_jaar, "-", sam$laatste_jaar,
        "\nCorrelatiestructuur:", sam$gee_corstr,
        "\nGetoetste variabelen:", sam$n_variabelen_getoetst,
        "\nModel per variabele:", "count ~ variabele + offset(log_area)"
      ))
    }
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
    vif_txt <- ""
    if (!is.null(analyse$vif) && nrow(analyse$vif) && any(is.finite(analyse$vif$vif))) {
      max_vif <- max(analyse$vif$vif[is.finite(analyse$vif$vif)], na.rm = TRUE)
      vif_txt <- paste0("\nMax. VIF:", " ", signif(max_vif, 4))
    }
    paste(
      "Analyse-niveau:", sam$analyse_niveau,
      "\nDoel:", sam$doel_label,
      "\nPlots:", sam$n_plots,
      "\nPlot-jaren:", sam$n_plot_jaren,
      "\nJaren:", sam$eerste_jaar, "-", sam$laatste_jaar,
      "\nCorrelatiestructuur:", sam$gee_corstr,
      "\nCovariaten:", paste(cov_names, collapse = ", "),
      vif_txt,
      if ("effect_eenheden" %in% names(sam) && !is.na(sam$effect_eenheden) && nzchar(sam$effect_eenheden)) paste0("\nIRR-eenheden: ", sam$effect_eenheden) else "",
      if (length(dropped_names)) paste0("\nVervallen covariaten:", " ", paste(dropped_names, collapse = ", ")) else ""
    )
  })

  output$glmm_selection_summary <- renderText({
    analyse <- glmm_analyse_rv()
    tbls <- tbls_rv()
    if (is.null(analyse)) {
      return("Nog geen GLMM-analyse uitgevoerd.")
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
        "\nVerdeling:", sam$glmm_family,
        "\nRandom effects:", sam$random_effects,
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
      "\nVerdeling:", sam$glmm_family,
      "\nRandom effects:", sam$random_effects,
      "\nAIC:", round(sam$aic, 2),
      "\nCovariaten:", paste(cov_names, collapse = ", "),
      if (length(dropped_names)) paste0("\nVervallen covariaten:", " ", paste(dropped_names, collapse = ", ")) else ""
    )
  })

  output$nmds_selection_summary <- renderText({
    analyse <- nmds_analyse_rv()
    if (is.null(analyse)) {
      return("Nog geen NMDS-analyse uitgevoerd.")
    }
    sam <- analyse$summary[1, , drop = FALSE]
    paste(
      "Analyse-niveau:", sam$analyse_niveau,
      "\nDoel:", sam$doel_label,
      "\nPlots:", sam$n_plots,
      "\nPlot-jaren:", sam$n_plot_jaren,
      "\nSoorten:", sam$n_soorten,
      "\nJaren:", sam$eerste_jaar, "-", sam$laatste_jaar,
      "\nTransformatie:", sam$transform,
      "\nAfstandsmaat:", sam$distance,
      "\nDimensies:", sam$dimensions,
      "\nStress:", round(sam$stress, 4)
    )
  })

  for (community_prefix in c("rda", "pls", "changepoint", "sem", "betadiversity", "occupancy")) {
    local({
      prefix <- community_prefix
      output[[paste0(prefix, "_selection_summary")]] <- renderText({
        analyse <- community_rvs[[prefix]]()
        if (is.null(analyse)) {
          return(switch(prefix,
            rda = "Nog geen RDA-analyse uitgevoerd.",
            pls = "Nog geen PLS-analyse uitgevoerd.",
            changepoint = "Nog geen changepoint-analyse uitgevoerd.",
            sem = "Nog geen SEM-verkenning uitgevoerd.",
            betadiversity = "Nog geen beta-diversity analyse uitgevoerd.",
            occupancy = "Nog geen occupancy-analyse uitgevoerd."
          ))
        }
        sam <- analyse$summary[1, , drop = FALSE]
        extra <- switch(prefix,
          rda = paste("\nVerklaarde variatie:", round(sam$verklaarde_variatie, 4), "\nTransformatie:", sam$transform),
          pls = paste("\nY-variatie verklaard:", round(sam$verklaarde_y_variatie, 4), "\nX-variatie verklaard:", round(sam$verklaarde_x_variatie, 2), "%\nTransformatie:", sam$transform, "\nComponenten:", sam$ncomp),
          changepoint = paste("\nReeks:", sam$metric, "\nKnipjaar:", sam$knip_jaar, "\nVerschil:", round(sam$verschil, 3)),
          sem = paste("\nModeltype:", sam$modeltype, "\nComplete plot-jaren:", sam$n_complete_plot_jaren),
          betadiversity = paste("\nTransformatie:", sam$transform, "\nAfstandsmaat:", sam$distance, "\nGemiddelde beta:", round(sam$gemiddelde_beta, 4)),
          occupancy = paste("\nModeltype:", sam$modeltype, "\nGemiddelde occupancy:", round(sam$gemiddelde_occupancy, 4))
        )
        paste(
          "Analyse-niveau:", sam$analyse_niveau,
          "\nDoel:", sam$doel_label,
          "\nPlots:", sam$n_plots,
          "\nPlot-jaren:", sam$n_plot_jaren,
          "\nSoorten:", sam$n_soorten,
          "\nJaren:", sam$eerste_jaar, "-", sam$laatste_jaar,
          extra
        )
      })
    })
  }

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

  output$trim_species_model_warning_ui <- renderUI({
    analyse <- analyse_rv()
    req(analyse, input$selected_species)
    status <- analyse$species_results$status
    status <- status[status$soort_naam == input$selected_species, , drop = FALSE]
    if (!nrow(status) || identical(status$model_fallback_reden[[1]], "voorkeursmodel_gekozen")) {
      return(NULL)
    }
    tags$div(
      class = "method-warning",
      tags$strong("TRIM-model fallback gebruikt. "),
      sprintf(
        "Gekozen model: %s. Reden: %s. Interpreteer de index voor deze soort extra voorzichtig.",
        status$model[[1]],
        status$model_fallback_reden[[1]]
      )
    )
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
         xlab = "Jaar", ylab = "TRIM-index (100 = eerste analysejaar vanaf eerste positieve jaar)",
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
      "soort_naam", "analyse_categorie", "basisjaar", "trend_pct_per_jaar",
      "trend_uitleg", "trendduiding_type", "n_jaren_index", "model",
      "model_fallback_reden", "model_fallback_gebruikt"
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

    div(
      class = "status-box",
      tags$span(class = "status-label", "Toelichting"),
      tags$span(
        sprintf(
          "Deze soort is ongeschikt voor T0-selectie (%s), maar de beschikbare deelreeks met geldige jaar-op-jaar verandering wordt wel getoond.",
          info$status_reden[[1]]
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
      "positieve_jaren", "nul_aandeel", "status_reden", "gemiddeld_lambda", "gemiddelde_verandering_pct"
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
           main = "GEE-kenmerken: verschil in jaar-op-jaar ontwikkeling")
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
    if ("effect_eenheid" %in% names(coefs)) {
      coefs$term_label <- paste0(coefs$term_label, " (", coefs$effect_eenheid, ")")
    }
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
         xlab = "Incident Rate Ratio (IRR) per getoonde effecteenheid",
         ylab = "",
         main = paste("GEE-effecten voor", analyse$summary$doel_label[[1]]))
    segments(coefs$irr_low, y, coefs$irr_high, y, col = "#94a3b8", lwd = 2)
    abline(v = 1, lty = 2, col = "#64748b")
    axis(2, at = y, labels = coefs$term_label, las = 1, cex.axis = 0.9)
    grid()
  })

  output$gee_coef_table <- renderTable({
    analyse <- gee_analyse_rv()
    tbls <- tbls_rv()
    req(analyse)
    if (identical(analyse$analysis_type, "gee_screening")) {
      coefs <- analyse$coefficients
      labels <- ifelse(!is.na(coefs$variabele_label) & nzchar(coefs$variabele_label), coefs$variabele_label, coefs$term)
      if (any(duplicated(coefs$variabele_code))) {
        labels <- ifelse(coefs$term == coefs$variabele_code, labels, paste0(labels, " - ", coefs$term))
      }
      out <- data.frame(
        variabele = paste0(labels, " (", coefs$effect_eenheid, ")"),
        IRR = signif(coefs$irr, 4),
        p = signif(coefs$p.value, 3),
        check.names = FALSE
      )
      return(out)
    }
    if (identical(analyse$analysis_type, "trait_screening")) {
      coefs <- analyse$coefficients
      out <- data.frame(
        variabele = paste0(coefs$code, " - ", coefs$kenmerk),
        hoofdcategorie = coefs$hoofdcategorie,
        code_type = coefs$code_type,
        n_soorten_met_kenmerk = coefs$n_soorten_met_kenmerk,
        n_soorten_zonder_kenmerk = coefs$n_soorten_zonder_kenmerk,
        IRR = signif(coefs$irr_jaar_interactie, 4),
        `95%-BI` = paste0(signif(coefs$irr_low, 4), " - ", signif(coefs$irr_high, 4)),
        p = signif(coefs$p.value, 3),
        p_BH = signif(coefs$p_adj_bh, 3),
        pct_verschil_trend_per_jaar = signif(coefs$pct_verschil_trend_per_jaar, 4),
        check.names = FALSE
      )
      return(head(out, 50))
    }
    coefs <- analyse$coefficients
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
    variabele <- ifelse(coefs$term %in% names(term_labels), unname(term_labels[coefs$term]), coefs$term)
    data.frame(
      variabele = variabele,
      effecteenheid = if ("effect_eenheid" %in% names(coefs)) coefs$effect_eenheid else "",
      IRR = signif(coefs$irr, 4),
      `95%-BI` = paste0(signif(coefs$irr_low, 4), " - ", signif(coefs$irr_high, 4)),
      p = signif(coefs$p.value, 3),
      term = coefs$term,
      check.names = FALSE
    )
  }, striped = TRUE)

  output$gee_overdispersion_table <- renderTable({
    analyse <- gee_analyse_rv()
    req(analyse)
    sam <- analyse$summary[1, , drop = FALSE]
    validate(need(all(c("gemiddelde", "variantie", "variantie_gemiddelde", "overdispersie") %in% names(sam)), "Geen overdispersie-diagnose beschikbaar."))
    data.frame(
      Maat = c("Gemiddelde", "Variantie", "Variantie/gemiddelde", "Interpretatie", "Advies"),
      Waarde = c(
        format(round(sam$gemiddelde, 3), decimal.mark = ",", trim = TRUE),
        format(round(sam$variantie, 3), decimal.mark = ",", trim = TRUE),
        format(round(sam$variantie_gemiddelde, 3), decimal.mark = ",", trim = TRUE),
        sam$overdispersie,
        if ("overdispersie_advies" %in% names(sam)) sam$overdispersie_advies else ""
      ),
      check.names = FALSE
    )
  }, striped = TRUE)

  output$gee_detection_effort_table <- renderTable({
    analyse <- gee_analyse_rv()
    req(analyse)
    if (is.null(analyse$detection_effort) || !nrow(analyse$detection_effort)) {
      return(data.frame(Maat = "Melding", Waarde = "Geen telinspanning/detectie-diagnose beschikbaar.", check.names = FALSE))
    }
    analyse$detection_effort
  }, striped = TRUE)

  output$gee_vif_table <- renderTable({
    analyse <- gee_analyse_rv()
    tbls <- tbls_rv()
    req(analyse)
    if (identical(analyse$analysis_type, "trait_screening") || is.null(analyse$vif) || !nrow(analyse$vif)) {
      return(data.frame(melding = "VIF is alleen beschikbaar voor reguliere multivariate GEE."))
    }
    vif <- analyse$vif
    term_labels <- c(
      year_c = "Jaar",
      ahn_mean = "AHN gemiddelde hoogte",
      ahn_sd = "AHN standaard deviatie",
      stikstof_mean = "Stikstof gemiddelde depositie",
      afstand_pad_m = "Afstand tot pad",
      padlengte_m_per_ha = "Padlengte per hectare",
      afstand_parkeerplaats_m = "Afstand tot parkeerplaats",
      afstand_hoofdtoegang_m = "Afstand tot hoofdtoegang",
      toegankelijkheid_status = "Toegankelijkheidsstatus"
    )
    if (!is.null(tbls)) {
      hab_specs <- gee_habitat_covariate_specs(tbls)
      term_labels <- c(term_labels, setNames(paste0("Habitat: ", hab_specs$label), hab_specs$code))
    }
    variabele <- ifelse(vif$term %in% names(term_labels), unname(term_labels[vif$term]), vif$term)
    data.frame(
      variabele = variabele,
      modelkolom = vif$modelkolom,
      VIF = signif(vif$vif, 4),
      beoordeling = vif$beoordeling,
      check.names = FALSE
    )
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
        cols <- intersect(c(
          "plot_id", "kavel_nummer", "jaar", "soort_id", "soort_naam",
          "count", "territoria_per_km2", "observatie_status", "echte_nul"
        ), names(analyse$model_data))
        out <- analyse$model_data[, cols, drop = FALSE]
        out <- out[order(out$jaar, out$kavel_nummer, out$plot_id, out$soort_naam), , drop = FALSE]
        rownames(out) <- NULL
        return(head(out, 200))
      }
      cols <- intersect(c(
      "plot_id", "kavel_nummer", "jaar", "count", "territoria_per_km2", "observatie_status", "echte_nul",
      "ahn_mean", "ahn_sd", "stikstof_mean",
      "afstand_pad_m", "padlengte_m_per_ha", "afstand_parkeerplaats_m",
      "afstand_hoofdtoegang_m", "toegankelijkheid_status"
    ), names(analyse$model_data))
      out <- analyse$model_data[, cols, drop = FALSE]
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

  output$download_gee_script <- downloadHandler(
    filename = function() {
      analyse <- gee_analyse_rv()
      req(analyse)
      sprintf("meijendel_shiny_gee_script_%s.R", analyse$summary$doel_slug[[1]])
    },
    content = function(file) {
      analyse <- gee_analyse_rv()
      req(analyse)
      write_analysis_export_script(analyse, file)
    }
  )

  output$glmm_coef_plot <- renderPlot({
    analyse <- glmm_analyse_rv()
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
           col = "#7c3aed",
           xlab = "IRR voor jaar x kenmerk",
           ylab = "",
           main = "GLMM-kenmerken: verschil in jaar-op-jaar ontwikkeling")
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
         col = "#7c3aed",
         xlab = "Incident Rate Ratio (IRR)",
         ylab = "",
         main = paste("GLMM-effecten voor", analyse$summary$doel_label[[1]]))
    segments(coefs$irr_low, y, coefs$irr_high, y, col = "#94a3b8", lwd = 2)
    abline(v = 1, lty = 2, col = "#64748b")
    axis(2, at = y, labels = coefs$term_label, las = 1, cex.axis = 0.9)
    grid()
  })

  output$glmm_coef_table <- renderTable({
    analyse <- glmm_analyse_rv()
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

  output$glmm_overdispersion_table <- renderTable({
    analyse <- glmm_analyse_rv()
    req(analyse)
    sam <- analyse$summary[1, , drop = FALSE]
    validate(need(all(c("gemiddelde", "variantie", "variantie_gemiddelde", "overdispersie") %in% names(sam)), "Geen overdispersie-diagnose beschikbaar."))
    data.frame(
      Maat = c("Gemiddelde", "Variantie", "Variantie/gemiddelde", "Interpretatie", "Advies"),
      Waarde = c(
        format(round(sam$gemiddelde, 3), decimal.mark = ",", trim = TRUE),
        format(round(sam$variantie, 3), decimal.mark = ",", trim = TRUE),
        format(round(sam$variantie_gemiddelde, 3), decimal.mark = ",", trim = TRUE),
        sam$overdispersie,
        if ("overdispersie_advies" %in% names(sam)) sam$overdispersie_advies else ""
      ),
      check.names = FALSE
    )
  }, striped = TRUE)

  output$glmm_diagnostics_table <- renderTable({
    analyse <- glmm_analyse_rv()
    req(analyse)
    if (is.null(analyse$diagnostics) || !nrow(analyse$diagnostics)) {
      return(data.frame(Maat = "Melding", Waarde = "Geen GLMM-diagnostiek beschikbaar.", check.names = FALSE))
    }
    out <- analyse$diagnostics
    if ("Waarde" %in% names(out)) {
      out$Waarde <- ifelse(is.finite(suppressWarnings(as.numeric(out$Waarde))), round(as.numeric(out$Waarde), 4), out$Waarde)
    }
    out
  }, striped = TRUE)

  output$glmm_random_effects_plot <- renderPlot({
    analyse <- glmm_analyse_rv()
    req(analyse)
    vc <- analyse$random_effects
    validate(need(!is.null(vc) && nrow(vc) > 0 && "variance" %in% names(vc), "Geen random-effect varianties beschikbaar."))
    if ("var2" %in% names(vc)) {
      vc <- vc[is.na(vc$var2) | !nzchar(as.character(vc$var2)), , drop = FALSE]
    }
    vc$variance <- suppressWarnings(as.numeric(vc$variance))
    vc <- vc[is.finite(vc$variance), , drop = FALSE]
    validate(need(nrow(vc) > 0, "Geen random-effect varianties beschikbaar."))
    vc$label <- paste(vc$grp, vc$var1, sep = ": ")
    vc <- vc[order(vc$variance), , drop = FALSE]
    old_par <- graphics::par(no.readonly = TRUE)
    on.exit(graphics::par(old_par), add = TRUE)
    graphics::par(mar = c(5.1, 12, 3.1, 2.1))
    barplot(vc$variance, names.arg = vc$label, horiz = TRUE, las = 1, col = "#7c3aed", xlab = "Variantie", main = "Random-effect variantie")
    grid()
  })

  output$glmm_detection_effort_table <- renderTable({
    analyse <- glmm_analyse_rv()
    req(analyse)
    if (is.null(analyse$detection_effort) || !nrow(analyse$detection_effort)) {
      return(data.frame(Maat = "Melding", Waarde = "Geen telinspanning/detectie-diagnose beschikbaar.", check.names = FALSE))
    }
    analyse$detection_effort
  }, striped = TRUE)

  output$glmm_plot_usage_table <- renderTable({
    analyse <- glmm_analyse_rv()
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

  output$glmm_dataset_table <- renderTable({
    analyse <- glmm_analyse_rv()
    req(analyse)
    if (identical(analyse$analysis_type, "trait_screening")) {
      cols <- intersect(c(
        "plot_id", "kavel_nummer", "jaar", "soort_id", "soort_naam",
        "count", "territoria_per_km2", "observatie_status", "echte_nul"
      ), names(analyse$model_data))
      out <- analyse$model_data[, cols, drop = FALSE]
      out <- out[order(out$jaar, out$kavel_nummer, out$plot_id, out$soort_naam), , drop = FALSE]
      rownames(out) <- NULL
      return(head(out, 200))
    }
    base_cols <- c(
      "plot_id", "kavel_nummer", "jaar", "count", "territoria_per_km2", "observatie_status", "echte_nul",
      "ahn_mean", "ahn_sd", "stikstof_mean",
      "afstand_pad_m", "padlengte_m_per_ha", "afstand_parkeerplaats_m",
      "afstand_hoofdtoegang_m", "toegankelijkheid_status"
    )
    cols <- intersect(base_cols, names(analyse$model_data))
    out <- analyse$model_data[, cols, drop = FALSE]
    out <- out[order(out$jaar, out$kavel_nummer, out$plot_id), , drop = FALSE]
    rownames(out) <- NULL
    out
  }, striped = TRUE)

  output$download_glmm_coefficients <- downloadHandler(
    filename = function() {
      analyse <- glmm_analyse_rv()
      req(analyse)
      sprintf("meijendel_shiny_glmm_coef_%s.csv", analyse$summary$doel_slug[[1]])
    },
    content = function(file) {
      analyse <- glmm_analyse_rv()
      utils::write.csv(analyse$coefficients, file, row.names = FALSE)
    }
  )

  output$download_glmm_dataset <- downloadHandler(
    filename = function() {
      analyse <- glmm_analyse_rv()
      req(analyse)
      sprintf("meijendel_shiny_glmm_dataset_%s.csv", analyse$summary$doel_slug[[1]])
    },
    content = function(file) {
      analyse <- glmm_analyse_rv()
      utils::write.csv(analyse$model_data, file, row.names = FALSE)
    }
  )

  output$download_glmm_script <- downloadHandler(
    filename = function() {
      analyse <- glmm_analyse_rv()
      req(analyse)
      sprintf("meijendel_shiny_glmm_script_%s.R", analyse$summary$doel_slug[[1]])
    },
    content = function(file) {
      analyse <- glmm_analyse_rv()
      req(analyse)
      write_analysis_export_script(analyse, file)
    }
  )

  output$nmds_plot <- renderPlot({
    analyse <- nmds_analyse_rv()
    req(analyse)
    sites <- analyse$site_scores
    validate(need(all(c("NMDS1", "NMDS2") %in% names(sites)), "Geen 2D NMDS-scores beschikbaar."))
    year_vals <- sites$jaar
    pal <- grDevices::colorRampPalette(c("#2563eb", "#059669", "#d97706"))(max(3L, length(unique(year_vals))))
    year_levels <- sort(unique(year_vals))
    point_cols <- pal[match(year_vals, year_levels)]
    old_par <- graphics::par(no.readonly = TRUE)
    on.exit(graphics::par(old_par), add = TRUE)
    graphics::par(mar = c(5.1, 5.1, 4.1, 2.1))
    plot(
      sites$NMDS1,
      sites$NMDS2,
      pch = 16,
      col = point_cols,
      xlab = "NMDS1",
      ylab = "NMDS2",
      main = paste("NMDS:", analyse$summary$doel_label[[1]], sprintf("(stress %.3f)", analyse$summary$stress[[1]]))
    )
    if (isTRUE(input$nmds_show_trajectories)) {
      trajectory_sites <- sites[order(sites$plot_id, sites$jaar), , drop = FALSE]
      for (plot_id in unique(trajectory_sites$plot_id)) {
        plot_sites <- trajectory_sites[trajectory_sites$plot_id == plot_id, , drop = FALSE]
        if (nrow(plot_sites) < 2L) {
          next
        }
        lines(plot_sites$NMDS1, plot_sites$NMDS2, col = grDevices::adjustcolor("#475569", alpha.f = 0.45), lwd = 1.1)
        graphics::arrows(
          head(plot_sites$NMDS1, -1L),
          head(plot_sites$NMDS2, -1L),
          tail(plot_sites$NMDS1, -1L),
          tail(plot_sites$NMDS2, -1L),
          length = 0.06,
          angle = 20,
          col = grDevices::adjustcolor("#475569", alpha.f = 0.45),
          lwd = 1.1
        )
      }
    }
    text(sites$NMDS1, sites$NMDS2, labels = sites$kavel_nummer, pos = 3, cex = 0.7, col = "#334155")
    grid()
    legend_idx <- unique(round(seq(1, length(year_levels), length.out = min(6L, length(year_levels)))))
    legend("topright", legend = year_levels[legend_idx], col = pal[legend_idx], pch = 16, title = "Jaar", bty = "n")
  })

  output$nmds_site_table <- renderTable({
    analyse <- nmds_analyse_rv()
    req(analyse)
    cols <- intersect(c("plot_id", "kavel_nummer", "jaar", "NMDS1", "NMDS2", "NMDS3"), names(analyse$site_scores))
    out <- analyse$site_scores[, cols, drop = FALSE]
    head(out, 100)
  }, striped = TRUE)

  output$nmds_species_table <- renderTable({
    analyse <- nmds_analyse_rv()
    req(analyse)
    cols <- intersect(c("soort_id", "soort_naam", "engelse_naam", "euring_code", "NMDS1", "NMDS2", "NMDS3"), names(analyse$species_scores))
    out <- analyse$species_scores[, cols, drop = FALSE]
    out <- out[order(out$soort_naam), , drop = FALSE]
    head(out, 100)
  }, striped = TRUE)

  output$nmds_envfit_table <- renderTable({
    analyse <- nmds_analyse_rv()
    req(analyse)
    if (is.null(analyse$envfit) || !nrow(analyse$envfit)) {
      return(data.frame(Maat = "Melding", Waarde = "Geen envfit-diagnostiek beschikbaar.", check.names = FALSE))
    }
    analyse$envfit
  }, striped = TRUE)

  output$nmds_shepard_plot <- renderPlot({
    analyse <- nmds_analyse_rv()
    req(analyse)
    validate(need(requireNamespace("vegan", quietly = TRUE), "Package vegan is niet beschikbaar."))
    vegan::stressplot(analyse$fit, main = "Shepard-diagram NMDS")
  })

  output$nmds_sample_table <- renderTable({
    analyse <- nmds_analyse_rv()
    req(analyse)
    analyse$sample_totals[, c("plot_id", "kavel_nummer", "jaar", "soortenrijkdom", "totaal_territoria_per_km2")]
  }, striped = TRUE)

  output$nmds_detection_effort_table <- renderTable({
    analyse <- nmds_analyse_rv()
    req(analyse)
    if (is.null(analyse$detection_effort) || !nrow(analyse$detection_effort)) {
      return(data.frame(Maat = "Melding", Waarde = "Geen telinspanning/detectie-diagnose beschikbaar.", check.names = FALSE))
    }
    analyse$detection_effort
  }, striped = TRUE)

  output$download_nmds_sites <- downloadHandler(
    filename = function() {
      analyse <- nmds_analyse_rv()
      req(analyse)
      sprintf("meijendel_shiny_nmds_sites_%s.csv", analyse$summary$doel_slug[[1]])
    },
    content = function(file) {
      analyse <- nmds_analyse_rv()
      utils::write.csv(analyse$site_scores, file, row.names = FALSE)
    }
  )

  output$download_nmds_species <- downloadHandler(
    filename = function() {
      analyse <- nmds_analyse_rv()
      req(analyse)
      sprintf("meijendel_shiny_nmds_species_%s.csv", analyse$summary$doel_slug[[1]])
    },
    content = function(file) {
      analyse <- nmds_analyse_rv()
      utils::write.csv(analyse$species_scores, file, row.names = FALSE)
    }
  )

  output$download_nmds_matrix <- downloadHandler(
    filename = function() {
      analyse <- nmds_analyse_rv()
      req(analyse)
      sprintf("meijendel_shiny_nmds_matrix_%s.csv", analyse$summary$doel_slug[[1]])
    },
    content = function(file) {
      analyse <- nmds_analyse_rv()
      mat <- as.data.frame(analyse$community_matrix, stringsAsFactors = FALSE)
      mat$sample_id <- rownames(analyse$community_matrix)
      mat <- mat[, c("sample_id", setdiff(names(mat), "sample_id")), drop = FALSE]
      utils::write.csv(mat, file, row.names = FALSE)
    }
  )

  output$download_nmds_script <- downloadHandler(
    filename = function() {
      analyse <- nmds_analyse_rv()
      req(analyse)
      sprintf("meijendel_shiny_nmds_script_%s.R", analyse$summary$doel_slug[[1]])
    },
    content = function(file) {
      analyse <- nmds_analyse_rv()
      req(analyse)
      write_analysis_export_script(analyse, file)
    }
  )

  output$rda_plot <- renderPlot({
    analyse <- rda_analyse_rv()
    req(analyse)
    sites <- analyse$site_scores
    validate(need(all(c("RDA1", "RDA2") %in% names(sites)), "Geen RDA-scores beschikbaar."))
    cols <- grDevices::colorRampPalette(c("#2563eb", "#059669", "#d97706"))(max(3L, length(unique(sites$jaar))))
    year_levels <- sort(unique(sites$jaar))
    point_cols <- cols[match(sites$jaar, year_levels)]
    plot(sites$RDA1, sites$RDA2, pch = 16, col = point_cols, xlab = "RDA1", ylab = "RDA2", main = paste("RDA:", analyse$summary$doel_label[[1]]))
    text(sites$RDA1, sites$RDA2, labels = sites$kavel_nummer, pos = 3, cex = 0.7, col = "#334155")
    if (nrow(analyse$constraints)) {
      arrows(0, 0, analyse$constraints$RDA1, analyse$constraints$RDA2, length = 0.08, col = "#dc2626")
      text(analyse$constraints$RDA1, analyse$constraints$RDA2, labels = analyse$constraints$variabele, col = "#dc2626", pos = 4)
    }
    grid()
  })

  output$pls_plot <- renderPlot({
    analyse <- pls_analyse_rv()
    req(analyse)
    sites <- analyse$site_scores
    validate(need(all(c("PLS1", "PLS2") %in% names(sites)), "Geen PLS-scores beschikbaar."))
    cols <- grDevices::colorRampPalette(c("#2563eb", "#059669", "#d97706"))(max(3L, length(unique(sites$jaar))))
    year_levels <- sort(unique(sites$jaar))
    point_cols <- cols[match(sites$jaar, year_levels)]
    plot(sites$PLS1, sites$PLS2, pch = 16, col = point_cols, xlab = "PLS1", ylab = "PLS2", main = paste("PLS:", analyse$summary$doel_label[[1]]))
    text(sites$PLS1, sites$PLS2, labels = sites$kavel_nummer, pos = 3, cex = 0.7, col = "#334155")
    loads <- analyse$variable_loadings
    if (nrow(loads)) {
      scale_factor <- 0.8 * max(abs(c(sites$PLS1, sites$PLS2)), na.rm = TRUE) / max(abs(c(loads$PLS1, loads$PLS2)), na.rm = TRUE)
      if (is.finite(scale_factor) && scale_factor > 0) {
        arrows(0, 0, loads$PLS1 * scale_factor, loads$PLS2 * scale_factor, length = 0.08, col = "#dc2626")
        text(loads$PLS1 * scale_factor, loads$PLS2 * scale_factor, labels = loads$variabele, col = "#dc2626", pos = 4)
      }
    }
    grid()
  })

  output$changepoint_plot <- renderPlot({
    analyse <- changepoint_analyse_rv()
    req(analyse)
    annual <- analyse$annual
    old_par <- graphics::par(no.readonly = TRUE)
    on.exit(graphics::par(old_par), add = TRUE)
    graphics::par(mar = c(5.1, 4.1, 4.1, 4.1))
    plot(annual$jaar, annual$waarde, type = "o", pch = 16, col = "#2563eb", xlab = "Jaar", ylab = analyse$summary$metric[[1]], main = paste("Changepoint:", analyse$summary$doel_label[[1]]))
    knipjaren <- suppressWarnings(as.integer(trimws(strsplit(analyse$summary$knip_jaar[[1]], ",", fixed = TRUE)[[1]])))
    knipjaren <- knipjaren[is.finite(knipjaren)]
    if (length(knipjaren)) {
      abline(v = knipjaren, col = "#dc2626", lwd = 2, lty = 2)
    }
    if ("fit" %in% names(annual)) {
      lines(annual$jaar, annual$fit, col = "#d97706", lwd = 2)
    }
    if ("n_plot_jaren" %in% names(annual)) {
      graphics::par(new = TRUE)
      plot(annual$jaar, annual$n_plot_jaren, type = "h", axes = FALSE, xlab = "", ylab = "", col = grDevices::adjustcolor("#64748b", alpha.f = 0.35), lwd = 3)
      axis(4, col = "#64748b", col.axis = "#64748b")
      mtext("n plot-jaren", side = 4, line = 2.5, col = "#64748b")
    }
    grid()
  })

  output$sem_plot <- renderPlot({
    analyse <- sem_analyse_rv()
    req(analyse)
    paths <- analyse$paths
    paths$label <- paste(paths$predictor, "->", paths$response)
    paths <- paths[order(abs(paths$estimate)), , drop = FALSE]
    cols <- ifelse(paths$estimate >= 0, "#059669", "#dc2626")
    old_par <- graphics::par(no.readonly = TRUE)
    on.exit(graphics::par(old_par), add = TRUE)
    graphics::par(mar = c(5.1, 16, 4.1, 2.1))
    barplot(paths$estimate, names.arg = paths$label, horiz = TRUE, las = 1, col = cols, main = "SEM-verkenning: padcoefficienten", xlab = "Estimate")
    abline(v = 0, col = "#64748b")
  })

  output$betadiversity_plot <- renderPlot({
    analyse <- betadiversity_analyse_rv()
    req(analyse)
    annual <- analyse$annual
    annual <- annual[is.finite(annual$beta_sorensen), , drop = FALSE]
    validate(need(nrow(annual) > 0, "Geen jaarlijkse beta-diversity beschikbaar."))
    plot(annual$jaar, annual$beta_sorensen, type = "o", pch = 16, col = "#7c3aed", xlab = "Jaar", ylab = "Beta-diversity (Sorensen)", main = paste("Beta-Diversity:", analyse$summary$doel_label[[1]]))
    lines(annual$jaar, annual$beta_turnover, type = "o", pch = 17, col = "#059669")
    lines(annual$jaar, annual$beta_nestedness, type = "o", pch = 15, col = "#d97706")
    grid()
    legend("topleft", legend = c("Sorensen totaal", "Turnover", "Nestedness"), col = c("#7c3aed", "#059669", "#d97706"), pch = c(16, 17, 15), lwd = 2, bty = "n")
  })

  output$occupancy_plot <- renderPlot({
    analyse <- occupancy_analyse_rv()
    req(analyse)
    annual <- analyse$annual
    plot(annual$jaar, annual$naieve_detectie_occupancy, type = "o", pch = 16, col = "#0f766e", xlab = "Jaar", ylab = "Naieve detectie-occupancy", ylim = c(0, 1), main = paste("Occupancy:", analyse$summary$doel_label[[1]]))
    grid()
  })

  for (community_prefix in c("rda", "pls", "changepoint", "sem", "betadiversity", "occupancy")) {
    local({
      prefix <- community_prefix
      output[[paste0(prefix, "_primary_table")]] <- renderTable({
        analyse <- community_rvs[[prefix]]()
        req(analyse)
        out <- switch(prefix,
          rda = analyse$constraints,
          pls = analyse$vip_scores,
          changepoint = head(analyse$candidates, 20),
          sem = analyse$paths,
          betadiversity = analyse$annual,
          occupancy = analyse$coefficients
        )
        rownames(out) <- NULL
        out
      }, striped = TRUE)

      output[[paste0(prefix, "_diagnostics_table")]] <- renderTable({
        analyse <- community_rvs[[prefix]]()
        req(analyse)
        out <- switch(prefix,
          rda = analyse$diagnostics,
          pls = {
            rmsep <- analyse$rmsep
            rmsep$onderdeel <- "RMSEP componentselectie"
            comp <- analyse$component_interpretation
            comp$onderdeel <- "Componentinterpretatie"
            rbind_fill_base(rmsep, comp)
          },
          changepoint = analyse$diagnostics,
          sem = analyse$diagnostics,
          betadiversity = analyse$diagnostics,
          occupancy = analyse$diagnostics
        )
        if (is.null(out) || !nrow(out)) {
          out <- data.frame(Maat = "Melding", Waarde = "Geen diagnostiek beschikbaar.", check.names = FALSE)
        }
        rownames(out) <- NULL
        out
      }, striped = TRUE)

      output[[paste0(prefix, "_sample_table")]] <- renderTable({
        analyse <- community_rvs[[prefix]]()
        req(analyse)
        out <- switch(prefix,
          rda = analyse$meta[, intersect(c("plot_id", "kavel_nummer", "jaar", "soortenrijkdom", "totaal_territoria_per_km2", "stikstof_mean", "ahn_mean", "afstand_pad_m"), names(analyse$meta)), drop = FALSE],
          pls = analyse$meta[, intersect(c("plot_id", "kavel_nummer", "jaar", "soortenrijkdom", "totaal_territoria_per_km2", "stikstof_mean", "ahn_mean", "afstand_pad_m"), names(analyse$meta)), drop = FALSE],
          changepoint = analyse$annual,
          sem = analyse$model_data[, intersect(c("plot_id", "kavel_nummer", "jaar", "soortenrijkdom", "totaal_territoria_per_km2", "stikstof_mean", "ahn_mean", "afstand_pad_m"), names(analyse$model_data)), drop = FALSE],
          betadiversity = analyse$meta[, intersect(c("plot_id", "kavel_nummer", "jaar", "soortenrijkdom", "totaal_territoria_per_km2"), names(analyse$meta)), drop = FALSE],
          occupancy = analyse$annual
        )
        head(out, 200)
      }, striped = TRUE)

      output[[paste0(prefix, "_detection_effort_table")]] <- renderTable({
        analyse <- community_rvs[[prefix]]()
        req(analyse)
        if (is.null(analyse$detection_effort) || !nrow(analyse$detection_effort)) {
          return(data.frame(Maat = "Melding", Waarde = "Geen telinspanning/detectie-diagnose beschikbaar.", check.names = FALSE))
        }
        analyse$detection_effort
      }, striped = TRUE)

      output[[paste0("download_", prefix, "_primary")]] <- downloadHandler(
        filename = function() {
          analyse <- community_rvs[[prefix]]()
          req(analyse)
          sprintf("meijendel_shiny_%s_primary_%s.csv", prefix, analyse$summary$doel_slug[[1]])
        },
        content = function(file) {
          analyse <- community_rvs[[prefix]]()
          out <- switch(prefix,
            rda = analyse$constraints,
            pls = analyse$vip_scores,
            changepoint = analyse$candidates,
            sem = analyse$paths,
            betadiversity = analyse$annual,
            occupancy = analyse$coefficients
          )
          utils::write.csv(out, file, row.names = FALSE)
        }
      )

      output[[paste0("download_", prefix, "_dataset")]] <- downloadHandler(
        filename = function() {
          analyse <- community_rvs[[prefix]]()
          req(analyse)
          sprintf("meijendel_shiny_%s_dataset_%s.csv", prefix, analyse$summary$doel_slug[[1]])
        },
        content = function(file) {
          analyse <- community_rvs[[prefix]]()
          utils::write.csv(analyse$dataset, file, row.names = FALSE)
        }
      )

      output[[paste0("download_", prefix, "_script")]] <- downloadHandler(
        filename = function() {
          analyse <- community_rvs[[prefix]]()
          req(analyse)
          sprintf("meijendel_shiny_%s_script_%s.R", prefix, analyse$summary$doel_slug[[1]])
        },
        content = function(file) {
          analyse <- community_rvs[[prefix]]()
          req(analyse)
          write_analysis_export_script(analyse, file)
        }
      )
    })
  }

  output$group_plot <- renderPlot({
    analyse <- analyse_rv()
    req(analyse, input$selected_group)
    msi <- analyse$group_results$msi
    msi <- msi[msi$groep_100 == as.integer(input$selected_group), ]
    validate(need(nrow(msi) > 0, "Geen MSI-gegevens voor deze groep."))

    title <- unique(msi$groep_titel)[1]
    variants <- unique(msi$msi_variant)
    cols <- c(volledig = "#1d4ed8", robuust = "#15803d")
    pchs <- c(volledig = 16, robuust = 17)
    y_max <- max(msi$msi, na.rm = TRUE)
    y_min <- min(msi$msi, na.rm = TRUE)

    plot(NA, NA,
         xlab = "Jaar", ylab = "MSI",
         xlim = range(msi$jaar, na.rm = TRUE),
         ylim = c(y_min, y_max),
         main = paste(input$selected_group, "-", title))
    for (variant in variants) {
      part <- msi[msi$msi_variant == variant, ]
      part <- part[order(part$jaar), ]
      col <- if (variant %in% names(cols)) cols[[variant]] else "#1d4ed8"
      pch <- if (variant %in% names(pchs)) pchs[[variant]] else 16
      lines(part$jaar, part$msi, type = "o", pch = pch, lwd = 2, col = col)
    }
    grid()
    legend("topleft",
           legend = c("Volledige MSI", "Robuuste MSI"),
           col = c(cols[["volledig"]], cols[["robuust"]]),
           lwd = 2, pch = c(pchs[["volledig"]], pchs[["robuust"]]), bty = "n")
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
    variants <- unique(msi$msi_variant)
    cols <- c(volledig = "#1d4ed8", robuust = "#15803d")
    pchs <- c(volledig = 16, robuust = 17)
    y_max <- max(msi$msi, na.rm = TRUE)
    y_min <- min(msi$msi, na.rm = TRUE)

    plot(NA, NA,
         xlab = "Jaar", ylab = "MSI",
         xlim = range(msi$jaar, na.rm = TRUE),
         ylim = c(y_min, y_max),
         main = title)
    for (variant in variants) {
      part <- msi[msi$msi_variant == variant, ]
      part <- part[order(part$jaar), ]
      col <- if (variant %in% names(cols)) cols[[variant]] else "#1d4ed8"
      pch <- if (variant %in% names(pchs)) pchs[[variant]] else 16
      lines(part$jaar, part$msi, type = "o", pch = pch, lwd = 2, col = col)
    }
    grid()
    legend("topleft",
           legend = c("Volledige MSI", "Robuuste MSI"),
           col = c(cols[["volledig"]], cols[["robuust"]]),
           lwd = 2, pch = c(pchs[["volledig"]], pchs[["robuust"]]), bty = "n")
  })

  output$richtlijn_table <- renderTable({
    analyse <- analyse_rv()
    req(analyse)
    analyse$richtlijn_results$trends[, c(
      "richtlijn_titel", "msi_variant", "eerste_jaar", "laatste_jaar", "gemiddeld_n_soorten",
      "min_n_soorten", "max_n_soorten", "samenstelling_waarschuwing",
      "trend_pct_per_jaar", "trend_p", "trend_r2", "trend_uitleg", "trendduiding_type"
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

  output$download_trim_script <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_trim_script_%s_%s.R", input$year_from, input$year_to)
    },
    content = function(file) {
      analyse <- analyse_rv()
      req(analyse)
      write_analysis_export_script(analyse, file)
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

  output$download_lambda_script <- downloadHandler(
    filename = function() {
      sprintf("meijendel_shiny_lambda_script_%s_%s.R", input$lambda_year_from, input$lambda_year_to)
    },
    content = function(file) {
      analyse <- lambda_analyse_rv()
      req(analyse)
      write_analysis_export_script(analyse, file)
    }
  )
}

shinyApp(ui, server)
