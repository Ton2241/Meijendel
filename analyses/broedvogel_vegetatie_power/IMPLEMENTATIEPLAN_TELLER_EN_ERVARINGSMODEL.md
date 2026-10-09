# Teller- en ervaringsmodel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bouw en voer een reproduceerbare analyse uit die laat zien hoeveel tellerteam en geregistreerde tellerervaring veranderen aan de geschatte ontwikkeling van broedvogelterritoria.

**Architecture:** Een zuivere datalaag maakt tellerervaring, telinspanning en drie vaste analysepopulaties. Een afzonderlijke fitlaag schat op dezelfde responsrijen M0, M1 en M2 met `glmmTMB`, gevolgd door soortmodellen en GEE-controles. Eén runner maakt vanuit read-only MySQL-extracten een gemanifesteerde uitvoering; grote objecten blijven buiten Git.

**Tech Stack:** R 4.6.x, base R, `glmmTMB`, `geepack`, `broom`, `broom.mixed`, `DHARMa`, `digest`, `jsonlite`, MySQL 9.7.1 CLI, Bash.

**Spec:** `analyses/broedvogel_vegetatie_power/ONTWERP_TELLER_EN_ERVARINGSMODEL.md`

## Global Constraints

- Gebruik uitsluitend de levende lokale MySQL-database `Meijendel`, read-only.
- Gebruik standaard 52 Natura 2000-plots; sluit M66 en M91 uit.
- Sluit M62/2016 uit van ervaringshistorie en telleranalyse.
- `plot_jaar_teller` is leidend; AVIMAP-waarnemers worden niet gebruikt.
- Imputeer geen teller voor de 99 plotjaren zonder tellerregistratie.
- Gebruik letterlijke nullen, afgeleide jaarverslagnullen, ontbrekende waarden en formele afkeur volgens `R/meijendel_cache_contract.R`.
- Vergelijk M0, M1 en M2 altijd op exact dezelfde responsrijen.
- Verwijder teller, plot, tijd, bron of oppervlakte niet op grond van niet-significantie.
- Fit sequentieel op de iMac M1 met 8 GB geheugen; schrijf na iedere fit een checkpoint en ruim niet-benodigde modelobjecten uit het geheugen.
- Gebruik random seed `20261009`; bereken rij- en bestandhashes met SHA256.
- Publiceer niets naar Shiny, dashboard of VPS.

## Review Focus

- Dubbele of anders geordende teller-ID's binnen één team moeten één canonieke teamsleutel opleveren; Task 1 test volgorde en duplicaten.
- Meerdere deelnames in hetzelfde jaar mogen niet als eerdere ervaring voor elkaar tellen; Task 1 test uitsluitend `jaar < huidig jaar` en distincte jaren.
- Een team dat maar één plotjaar voorkomt mag niet ongemerkt identificeerbare tellervariantie suggereren; Task 3 test en rapporteert teamherhaling.
- Een soort met constante nullen, te weinig positieve waarden of een constante ervaringsvariabele mag de batch niet afbreken; Task 4 test expliciete uitvalstatussen.
- Geheugen- of convergentie-uitval van één model mag eerdere resultaten niet verliezen; Task 5 test checkpoints en hervatten zonder parallelle fits.

---

### Task 1: Canonieke teller- en ervaringslaag

**Files:**
- Create: `analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_teller_data.R`
- Create: `analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_data.R`

**Interfaces:**
- Consumes: `apply_meijendel_plot_scope()` uit `R/meijendel_cache_contract.R`; tabellen `plots`, `plot_analyse_scope` en `plot_jaar_teller`.
- Produces: `canonical_tellerteam_key(teller_ids) -> character(1)`; `build_teller_experience_layer(data, year_min, year_max) -> list(participations, teams, summary)`.

- [ ] **Step 1: Schrijf de falende fixturetest voor teamsleutels en ervaring**

  Maak een fixture met twee plots, drie tellers, een dubbel ingevoerde teller, een omgekeerde teamvolgorde, twee deelnames in hetzelfde jaar, M66, M91 en M62/2016. Assert:

  - `canonical_tellerteam_key(c(9, 2, 9)) == "2+9"`;
  - alleen distincte jaren kleiner dan het huidige jaar meetellen;
  - `eerdere_jaren_plot + eerdere_jaren_elders == eerdere_jaren_totaal`;
  - M66, M91 en M62/2016 ontbreken;
  - een teamrij bevat gemiddelde, minimum- en maximumwaarde van `log1p`-ervaring.

- [ ] **Step 2: Voer de test uit en verifieer RED**

  Run: `Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_data.R`  
  Expected: FAIL omdat de tellerfuncties nog niet bestaan.

- [ ] **Step 3: Implementeer de minimale datalaag**

  `build_teller_experience_layer()` gebruikt alle gescope-te tellerregistraties uit 1958–2025, sluit M62/2016 uit en berekent per tellerdeelname uitsluitend eerdere distincte kalenderjaren. Teamervaring is primair het gemiddelde van de individuele `log1p`-waarden; minimum en maximum blijven gevoeligheidsvelden.

- [ ] **Step 4: Voer tellerdata- en cachecontracttests uit**

  Run: `Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_data.R && Rscript R/test_meijendel_cache_contract.R`  
  Expected: beide eindigen met `OK`.

- [ ] **Step 5: Commit Task 1**

  ```bash
  git add analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_teller_data.R analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_data.R
  git commit -m "Bouw tellerervaringslaag"
  ```

### Task 2: Vaste modelpopulaties en telinspanning

**Files:**
- Create: `analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_teller_prepare.R`
- Create: `analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_prepare.R`
- Modify: `analyses/broedvogel_vegetatie_power/scripts/README.md`

**Interfaces:**
- Consumes: `build_teller_experience_layer()` uit Task 1 en de `matrix`, `basis` en `species` van `build_broedvogel_analysis_matrix()`.
- Produces: `build_bmp_effort(dagbezoeken, valid_plot_years) -> data.frame`; `build_teller_model_populations(matrix, teams, effort) -> list(long, single_teller, effort_1984_2025, eligibility, coverage)`.

- [ ] **Step 1: Schrijf falende tests voor de drie analysepopulaties**

  Assert met een kleine matrix:

  - M62/2016 en onbekende tellerteams ontbreken in `long`;
  - `single_teller` bevat uitsluitend `aantal_tellers == 1`;
  - `effort_1984_2025` bevat uitsluitend plotjaren met positieve totale bezoekduur;
  - afgekeurde en ontbrekende cellen krijgen geen responsrij;
  - bron, nulstatus, oppervlakte en teamervaring blijven herleidbaar;
  - de structurele soortcriteria exact `n >= 30`, `positief >= 10`, `plots >= 3`, `teams >= 3` en `jaren >= 3` toepassen.

- [ ] **Step 2: Voer de test uit en verifieer RED**

  Run: `Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_prepare.R`  
  Expected: FAIL omdat voorbereidingsfuncties ontbreken.

- [ ] **Step 3: Implementeer inspanning en populaties**

  `build_bmp_effort()` aggregeert per plotjaar `aantal_bezoeken`, `totale_bezoekduur_min`, eerste en laatste bezoekdag en aandeel gunstige bezoeken. `build_teller_model_populations()` maakt `row_id` als `soort_id:plot_id:jaar`, sorteert daarop vóór SHA256 en voegt modelvariabelen toe: `jaar_decennium = (jaar - 1990) / 10`, `ervaring_plot_z`, `ervaring_elders_z`, `log_oppervlakte_km2`, `plotjaar_factor`, `soort_plot_factor` en `analyse_bron_factor`. De ervarings-z-scores gebruiken gemiddelde en standaardafwijking uit de lange populatie; de één-teller- en inspanningspopulatie hergebruiken diezelfde schaal. Zet `sovon_m` als referentie voor analysebron wanneer dit niveau aanwezig is.

- [ ] **Step 4: Test invarianten en actuele stap-1-regressie**

  Run: `Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_prepare.R && Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_data.R`  
  Expected: beide eindigen met `OK`; de bestaande matrixaantallen veranderen niet.

- [ ] **Step 5: Documenteer de drie populaties en commit**

  ```bash
  git add analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_teller_prepare.R analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_prepare.R analyses/broedvogel_vegetatie_power/scripts/README.md
  git commit -m "Bereid populaties voor telleranalyse voor"
  ```

### Task 3: Gezamenlijke hiërarchische modellen M0–M2

**Files:**
- Create: `analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_teller_fit.R`
- Create: `analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R`

**Interfaces:**
- Consumes: `populations$long` uit Task 2.
- Produces: `joint_teller_formulas(include_effort = FALSE, effort_variable = NULL) -> named list`; `fit_glmmtmb_safely(formula, data, model_id, checkpoint_dir) -> list(status, fit_path, warnings, diagnostics)`; `fit_joint_teller_models(data, analysis_id, checkpoint_dir, experience_variant = "mean", effort_variable = NULL) -> list(models, comparison, species_trends, diagnostics)`.

- [ ] **Step 1: Schrijf falende tests voor formules en gelijke rijen**

  Assert:

  - M0, M1 en M2 gebruiken dezelfde `row_id`-set;
  - alle modellen gebruiken `nbinom2(link="log")` en de oppervlakte-offset;
  - M1 voegt alleen tellerteam toe aan M0;
  - M2 voegt de twee ervaringsvariabelen en soortafwijkingen toe aan M1;
  - `plotjaar_factor` staat al in M0 zodat een eenmalig hoog of laag plotjaar niet automatisch tellerteam wordt;
  - teamherhaling en het aandeel eenmalige teams verschijnen in diagnostiek;
  - een opgegeven inspanningsvariabele staat in M0, M1 en M2 en verandert de onderlinge rijselectie niet.

- [ ] **Step 2: Voer de test uit en verifieer RED**

  Run: `Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R`  
  Expected: FAIL omdat fitfuncties ontbreken.

- [ ] **Step 3: Implementeer vaste modelstructuur**

  Gebruik als startstructuur:

  - M0: tijd, analysebron, offset, een random intercept en tijdhelling per soort, soort×plot, jaar en plotjaar;
  - M1: M0 plus tellerteam;
  - M2: M1 plus ervaring in de plot, ervaring elders en ongecorreleerde soortafwijkingen voor beide ervaringseffecten.

  Gebruik `glmmTMBControl(iter.max=1000, eval.max=1000)`. Schrijf iedere geslaagde fit onmiddellijk als RDS-checkpoint, bewaar waarschuwingen, `pdHess`, random-effectvarianties en gebruikte rijhash, verwijder het fitobject daarna uit het geheugen en voer `gc()` uit.

  Dezelfde functie moet de lange populatie, de één-tellerpopulatie en de
  inspanningspopulatie kunnen fitten. Voor de inspanningspopulatie is totale
  bezoekduur de primaire covariaat en aantal bezoeken de gevoeligheidsvariant;
  gebruik in beide gevallen de binnen die populatie gestandaardiseerde
  `log1p`-waarde als gewone covariaat, niet als offset.
  Voor alle-teammodellen is gemiddelde teamervaring primair; minimum en maximum
  zijn afzonderlijk gelabelde gevoeligheidsvarianten.

- [ ] **Step 4: Voeg een kleine echte `glmmTMB`-integratietest toe**

  Genereer een deterministische synthetische telset met herhaalde soorten, plots, jaren en teams. Assert dat M0–M2 fitten of expliciet `modeluitval` teruggeven, dat een geforceerde fout de batch niet stopt en dat eerder geschreven checkpoints blijven bestaan.

- [ ] **Step 5: Voer de fit- en eerdere tests uit**

  Run: `Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R && Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_prepare.R`  
  Expected: beide eindigen met `OK`, zonder onverwachte waarschuwing.

- [ ] **Step 6: Commit Task 3**

  ```bash
  git add analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_teller_fit.R analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R
  git commit -m "Voeg hiërarchische tellermodellen toe"
  ```

### Task 4: Soortmodellen en GEE-controle

**Files:**
- Modify: `analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_teller_fit.R`
- Modify: `analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R`

**Interfaces:**
- Consumes: `populations$long`, `populations$single_teller`, `populations$effort_1984_2025`, `populations$eligibility` en checkpointfuncties uit Task 3.
- Produces: `fit_species_teller_models(data, eligibility, analysis_id, checkpoint_dir, effort_variable = NULL) -> data.frame`; `fit_species_gee_checks(data, eligibility, analysis_id) -> data.frame`; `summarise_teller_sensitivity(joint, species, gee) -> list(summary, species_comparison, diagnostics)`.

- [ ] **Step 1: Breid eerst de test uit met soort- en GEE-uitval**

  Maak drie synthetische soorten: één voldoende soort, één constante-nulsoort en één soort met constante ervaring. Assert dat de eerste een resultaatrij krijgt en de andere twee een benoemde status met reden. Assert dat GLMM en GEE dezelfde soortselectie en responsrijhash gebruiken.

- [ ] **Step 2: Voer de uitgebreide test uit en verifieer RED**

  Run: `Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R`  
  Expected: FAIL omdat soort- en GEE-functies ontbreken.

- [ ] **Step 3: Implementeer sequentiële soortmodellen**

  Fit voor iedere structureel geschikte soort M0–M2 met `nbinom2`. Alleen bij gedocumenteerde NB-uitval is een gelabelde Poisson-fit toegestaan. Leg trend, standaardfout, interval, trendverschil M2–M0, teamvariantie en voorspelde telverhoudingen bij 0 versus 1, 3 en 5 eerdere jaren vast. Voer dezelfde soortlus uit voor de lange en één-tellerpopulatie; voor de inspanningspopulatie uitsluitend wanneer de soort daar opnieuw aan de structurele criteria voldoet. Publiceer geen teller-ID-effecten.

- [ ] **Step 4: Implementeer GEE-controle**

  Gebruik per soort een Poisson-GEE met robuuste sandwichstandaardfouten, plot als cluster en `exchangeable` als primaire correlatiestructuur. Vergelijk zonder en met ervaring op dezelfde rijen. Een alternatieve correlatiestructuur wordt alleen bij vooraf benoemde instabiliteit gebruikt en blijft zichtbaar in de uitvoer.

- [ ] **Step 5: Implementeer samenvatting zonder significantieselectie**

  Rapporteer aantallen geslaagde en mislukte modellen, verdeling van trendverschuiving, intervalverandering, teamvariantie en richtingsovereenkomst tussen GLMM en GEE. Behoud alle 121 kandidaat-soorten in de tabel, ook bij uitval.

- [ ] **Step 6: Voer alle fit-tests uit en commit**

  Run: `Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R`  
  Expected: eindigt met `OK` en bevat voor ieder testmodel een expliciete status.

  ```bash
  git add analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_teller_fit.R analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R
  git commit -m "Voeg soortmodellen en GEE-controle toe"
  ```

### Task 5: Reproduceerbare runner, manifest en hervatten

**Files:**
- Create: `analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_teller_model.R`
- Create: `analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_teller_model.sh`
- Create: `analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_teller_pipeline.R`
- Modify: `analyses/broedvogel_vegetatie_power/resultaten/.gitignore`
- Modify: `analyses/broedvogel_vegetatie_power/scripts/README.md`

**Interfaces:**
- Consumes: alle Task 1–4-functies en read-only TSV-extracten van de negen benodigde tabellen, inclusief `dagbezoeken_bmp`.
- Produces: één runmap met matrix, populaties, checkpoints, samenvattingen en `teller_model_manifest.json`; stabiele compacte bestanden onder `resultaten/`.

- [ ] **Step 1: Schrijf falende pijplijntest**

  Gebruik fixture-TSV's en een klein synthetisch model. Assert dat het manifest run-ID, Git-commit, MySQL-versie, pakketversies, tabellen, rijtellingen, formules, random seed, bronhashes, responsrijhashes en outputhashes bevat. Assert dat `--resume` een bestaand groen checkpoint overslaat en een ontbrekend checkpoint vervolgt.

- [ ] **Step 2: Voer de pijplijntest uit en verifieer RED**

  Run: `Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_teller_pipeline.R`  
  Expected: FAIL omdat runner en manifest nog ontbreken.

- [ ] **Step 3: Implementeer R-orchestratie en Bash-extractie**

  De Bash-runner voert `scripts/check_local_workspace.sh` uit, maakt een tijdelijke map met `mktemp -d`, exporteert read-only de bestaande acht matrixtabellen plus de benodigde kolommen uit `dagbezoeken_bmp`, start R sequentieel en verwijdert alleen zijn eigen tijdelijke extractmap. De R-runner ondersteunt een runmap hervatten en overschrijft nooit een andere run.

  De orchestrator voert de gezamenlijke modellen uit voor: lange reeks met
  gemiddelde, minimum- en maximum-teamervaring; alleen één-teller-plotjaren;
  en 1984–2025 met respectievelijk totale bezoekduur en aantal bezoeken. Daarna
  volgen de vooraf toegelaten soortmodellen en de GEE-controle. Iedere variant
  krijgt een eigen `analysis_id`, rijhash en checkpointstatus.

- [ ] **Step 4: Schrijf compacte gevolgde resultaten**

  Kopieer na een volledig groene uitvoering uitsluitend:

  - `teller_model_laatste_dekking.csv`;
  - `teller_model_laatste_samenvatting.csv`;
  - `teller_model_laatste_soorten.csv`;
  - `teller_model_laatste_diagnostiek.csv`;
  - `teller_model_laatste_manifest.json`.

  Volledige matrices, RDS-modellen en detailuitvoer blijven onder `resultaten/runs/`.

- [ ] **Step 5: Voer de volledige lokale testsuite voor deze keten uit**

  Run: `Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_data.R && Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_data.R && Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_prepare.R && Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R && Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_teller_pipeline.R && Rscript R/test_meijendel_cache_contract.R && bash -n analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_teller_model.sh`  
  Expected: alle R-tests eindigen met `OK`; Bash-syntaxis is geldig.

- [ ] **Step 6: Commit Task 5 vóór de formele uitvoering**

  ```bash
  git add analyses/broedvogel_vegetatie_power/scripts analyses/broedvogel_vegetatie_power/resultaten/.gitignore
  git commit -m "Maak telleranalyse reproduceerbaar uitvoerbaar"
  ```

### Task 6: Formele uitvoering, beoordeling en vastlegging

**Files:**
- Modify: `analyses/broedvogel_vegetatie_power/ANALYSE_HOOFDLIJNEN_EN_UITKOMSTEN.md`
- Modify: `analyses/broedvogel_vegetatie_power/BESLUITEN.md` alleen als de uitvoering een nieuw methodisch besluit vereist
- Modify: `analyses/broedvogel_vegetatie_power/resultaten/README.md`
- Create: de vijf compacte `teller_model_laatste_*`-bestanden uit Task 5

**Interfaces:**
- Consumes: formele runner uit Task 5 op een schone codecommit.
- Produces: gecontroleerde actuele resultaten en een leesbare conclusie zonder power- of causaliteitsclaim.

- [ ] **Step 1: Voer de formele analyse uit**

  Run: `analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_teller_model.sh`  
  Expected: een volledige run met expliciete status voor ieder gezamenlijk model, iedere kandidaat-soort en iedere GEE-controle; geen parallelle fits.

- [ ] **Step 2: Controleer data- en modelcontracten**

  Verifieer minimaal 52 plots vóór M62-filtering, 2.106 telleranalyse-plotjaren, 2.007 met teller, 99 zonder teller, 1.804 één-teller-plotjaren, 201 twee-teller-plotjaren, 2 drie-teller-plotjaren, 156 soorten in het gezamenlijke model en 121 kandidaten voor afzonderlijke soortmodellen. Stop bij afwijking en verklaar die uit de actuele bron voordat resultaten worden geïnterpreteerd.

- [ ] **Step 3: Controleer statistische bruikbaarheid**

  Lees alle convergentie-, Hessian-, singulariteits-, dispersie- en GEE-waarschuwingen. Controleer of M0–M2 per vergelijking dezelfde rijhash hebben. Beschrijf uitval als uitkomst; herhaal modellen niet met achteraf gekozen variabelen om een gewenste conclusie te verkrijgen.

- [ ] **Step 4: Actualiseer het hoofddocument met feitelijke uitkomsten**

  Noteer voor de concrete gegevensverzameling en periode: hoeveel modellen slaagden, hoe groot de geschatte teamspreiding was, hoeveel soorttrends materieel veranderden, wat de ervaringseffecten waren, of de één-teller- en inspanningsanalyses hetzelfde beeld gaven en waar GEE afweek. Noem dit tellersensitiviteit, niet power of bewijs van gemiste vogels.

- [ ] **Step 5: Voer eindverificatie uit**

  Run: de volledige testopdracht uit Task 5, gevolgd door `git diff --check` en `/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh`.  
  Expected: tests groen; alleen bedoelde resultaat- en documentatiebestanden gewijzigd; preflight blokkeert uitsluitend zolang de nieuwe commits nog niet zijn gepusht.

- [ ] **Step 6: Commit en push resultaten**

  ```bash
  git add analyses/broedvogel_vegetatie_power
  git commit -m "Leg uitkomsten telleranalyse vast"
  git push
  ```

  Voer daarna de workspace-preflight opnieuw uit. Expected: alle werkbomen schoon en iedere actieve branch gelijk aan haar upstream. Geen VPS-publicatie.
