# Integratie begrazing en toegankelijkheid — implementatieplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Geen delegatie zonder afzonderlijke aanwijzing.

**Goal:** Integreer de historische begrazings- en toegankelijkheidsregistraties in `maatregel*`, verwijder de drie oude fysieke tabellen en behoud een werkende website-, dashboard-, dump- en Shiny-keten zonder dubbeltelling.

**Architecture:** Projecten en uitvoeringen blijven in de bestaande bronvaste structuur. Twee gerichte registratietabellen bewaren jaarlijkse beheerfeiten en toegankelijkheidstoestanden die niet uit uitvoeringen zijn af te leiden. Een technische herkomstkoppeling verbindt oude records met precies één canoniek doel; compatibiliteitsviews en een gedeelde R-adapter leveren de bestaande leescontracten.

**Tech Stack:** MySQL 9.7.1, bestaande Python-migratie- en contracttestpatronen, R-cachebouwer, JavaScript-dashboard, Markdown/DOCX.

**Spec:** Het door Ton goedgekeurde voorstel in deze chat, met de correctie van 16 oktober 2026: de vijf overeenkomende begrazingsregels zijn bevestigde dubbelingen en worden niet opnieuw als feit opgeslagen. Het eerdere ontwerp `docs/superpowers/specs/2026-10-13-maatregelen-datamodel-design.md` beschrijft de bestaande structuur; de eis om de oude fysieke tabellen te behouden wordt voor deze migratie vervangen door dit besluit.

## Global Constraints

- Dit document is een plan. Het opslaan ervan geeft geen opdracht om de migratie uit te voeren.
- De levende lokale MySQL-database is de canonieke schrijfbron; dumps en productie zijn afnemers.
- Uitvoering begint met workspace-preflight, actuele schema- en inhoudscontrole en een schone taakgerichte branch vanaf de actuele maatregelenbasis. Onbekende wijzigingen blijven ongemoeid.
- Geen databasefeiten verwijderen voordat de migratie, volledige vergelijking en herstelproef in een geïsoleerde proefdatabase slagen.
- De vijf hieronder genoemde dubbelingen zijn door Ton bevestigd. Geen nieuwe bewijsuitvraag en geen tweede feitenregistratie voor die vijf combinaties.
- Geen onbekende begrazingsintensiteit, diersoort, deelgebied, dekking, uitvoeringsperiode of toegankelijkheidsdeel invullen uit aannames.
- Toegankelijkheidstoestand, uitgevoerde ingreep, fysieke infrastructuur en recreatiedruk blijven verschillende betekenissen.
- Geen automatische zware `Meijendel.sql`-export, volledige proefimport/cachebouw of VPS-publicatie. Hiervoor gelden de afzonderlijke akkoordmomenten in taak 6.
- MySQL-DDL kan impliciet committen. Gebruik expliciete migratiefasen, gecontroleerde objectwissel en geteste herstelcommando’s; beloof geen transactionele rollback van een heel DDL-traject.
- Bronstatuswijzigingen worden tijdens de uitvoering direct in Markdown én DOCX van het bronregister verwerkt. Deze planningsstap verandert geen bronstatus.
- Geen wijzigingen in vogelwaarnemingen, taxonidentiteiten, plotscope of brongeometrieën; databasebrede centrale taxonbereikbaarheid blijft een verplichte nacontrole.
- Geen externe opslag of NAS gebruiken zonder toestemming. Tijdelijke proefuitvoer en herstelbestanden lokaal buiten gevolgde repositorybestanden bewaren.

## Review Focus

1. De vijf dubbelingen mogen in geen enkele canonieke selectie dubbel terugkomen, ook niet na herhaling van de migratie.
2. Een geldige lege deeltabel moet een getypeerde lege uitvoer opleveren; ontbrekende vereiste tabellen of kolommen moeten daarentegen stoppen.
3. De snapshot van 2024 mag niet stilzwijgend een bewezen toestand in 2025/2026 worden. Onbekende perioden blijven zichtbaar en analysewaarden blijven onbekend.
4. Een enkele gedeeltelijke maatregel of gebiedskoppeling mag niet een heel plot of alle tussenliggende jaren als behandeld classificeren.
5. Een onderbroken objectwissel of een oude cache mag geen half gemigreerde afnemer opleveren; herstel en versiecontrole moeten dit aantoonbaar opvangen.

## Uitgangsstand en bindende ontdubbeling

Alleen-lezen vastgesteld op 16 oktober 2026; bij uitvoering opnieuw meten en afwijkingen beoordelen vóór mutatie:

- `plot_jaar_maatregel`: 144 regels, 16 plots, 1991–1999, maatregel 3/begrazing. Bron overal `HANDMATIG`; intensiteit, uitvoerder/diersoort en deelgebied leeg, dekking en opmerking NULL.
- `plot_jaar_toegankelijkheid`: 55 regels voor 55 plots in 2024: 20 vrij, 14 beperkt, 12 afgesloten, 8 deels beperkt/deels vrij en 1 deels afgesloten/deels vrij. Behoud de letterlijke statuswaarden en opmerkingen, waaronder M36: `nog controleren`.
- `plot_jaar_toegankelijkheid_deel`: 0 regels. De voorbeeld-CSV bevat twee niet-geïmporteerde deelregels; die zijn geen databasebron en worden niet alsnog ingevoerd.
- `v_plot_jaar_maatregel_bronvast`: 297 regels, expliciete jaren tussen 1967 en 2025. Geen vervanging van deze view door een ongefilterde verzameling legacyregistraties.

De vijf oude begrazingsregels verwijzen uitsluitend naar de al bestaande feiten:

| Plot | Jaar | Bestaande uitvoering_code |
|---|---:|---|
| M15 | 1991 | begrazing_helmduinen_1991 |
| M16 | 1991 | begrazing_helmduinen_1991 |
| M13 | 1997 | kikkervalleien_begrazing_1997 |
| M13s | 1997 | kikkervalleien_begrazing_1997 |
| M14 | 1997 | kikkervalleien_begrazing_1997 |

Verwachte migratie bij ongewijzigde invoer: **139 nieuwe beheerregistraties, 55 toegankelijkheidsregistraties en 199 herkomstkoppelingen**. Daarvan wijzen vijf koppelingen rechtstreeks naar bestaande uitvoering–plot–jaarfeiten. Een herkomstkoppeling is geen tweede inhoudelijk feit. De bestaande uitvoeringsjaarregels, plotkoppelingen en 297 viewregels blijven behouden. De reconstructie van het oude begrazingscontract blijft 144 regels tellen: 139 nieuwe feiten plus vijf bestaande feiten.

## Bestanden en interfaces

Wijzig bestaande bestanden waar hun verantwoordelijkheid past:

- `gis/database/maatregelen_schema.sql`: registratietabellen, herkomstrelaties en leesviews.
- `gis/scripts/test_maatregelen_schema_contract.py` en `test_maatregelen_seed_contract.py`: schema-, behoud- en seedcontracten.
- `gis/scripts/import_external_ecology_sources.py`: centrale schemaregistratie en audit van de nieuwe bronstructuur.
- `shiny_meijendel/helpers.R`: nieuwe dumpinlezing, gedeelde adapter, tijdselectie en cacheversie.
- `scripts/build_meijendel_shiny_cache.R`, `R/build_dashboard_browser_data.R`: nieuwe bronnen opnemen, bestaande publieke objectnamen behouden.
- `R/test_meijendel_cache_contract.R`, `scripts/test_build_meijendel_shiny_cache.sh`, `scripts/test_dashboard_browser_data_contract.sh`, `scripts/test_dashboard_browser_data_loader.js`: regressiecontracten.
- `bmp_meijendel_index.html`: bronjaar en onderscheid tussen historische registratie en bewezen actuele toestand tonen.
- `Ruimtelijke data/11_import_toegankelijkheid.sql`, `16_import_maatregelen.sql`, `17_import_toegankelijkheid_deel.sql`: schrijfroutes omschakelen; de oude `LOAD DATA`-routes naar views mogen niet actief blijven.
- `Ruimtelijke data/15_herstel_datamodel_maatregelen_toegankelijkheid.sql` en `gis/scripts/test_maatregelen_migratie_contract.py`: oude behoudsaannames actualiseren.
- `scripts/export_meijendel_sql.sh`, `scripts/validate_meijendel_export.sh` en bijbehorende exporttests: alleen aanpassen waar gewijzigde schema-/adaptercontracten dit vereisen.
- `MDs/handboek.md`, `Recreatie/README_recreatie_import.md`, `R/shiny_berekenlogica.md`, bronregister en tabelinventaris inclusief DOCX: definitieve betekenis en beheerroute.

Twee nieuwe uitvoeringsbestanden zijn nodig omdat er nog geen gerichte migratie van deze registraties bestaat:

- `gis/scripts/migrate_maatregel_registraties.py`: alleen-lezen audit, proef-/live-migratie en herstelcontrole met expliciete uitvoermodi.
- `gis/scripts/test_maatregel_registraties_migratie_contract.py`: geïsoleerde integratietest voor ontdubbeling, behoud, herhaling en herstel.

Geen nieuwe losse analysebestanden of parallelle handleidingen. De technische herkomsttabel is nodig om oude recordidentiteit en bronwaarden te behouden terwijl de vijf dubbelingen geen nieuwe feitenrij krijgen.

### Taak 1: Schema en herkomstcontract

**Interfaces:** `maatregel_plot_jaar_registratie`, `maatregel_toegankelijkheid_registratie`, `maatregel_registratie_herkomst`; bestaande uitvoeringssleutels blijven stabiel.

- [x] Breid eerst de schematest uit en bevestig dat hij faalt op ontbrekende objecten.
- [x] Voeg `maatregel_plot_jaar_registratie` toe met registratie-id, plot_id, jaar, maatregel_id, bron_id, optionele uitvoering_id, intensiteit_code, uitvoerder_of_diersoort, deel_label, dekking_pct, opmerking en afzonderlijke beoordelingsstatus. Behoud de bestaande zakelijke uniciteit inclusief bron en deelkenmerken.
- [x] Voeg `maatregel_toegankelijkheid_registratie` toe met registratie-id, plot_id, jaar, bron_id, niveau `plot`/`deel`, deel_label, status_code, aandeel_pct, barriere_type, optionele geometrie en uitvoering_id, opmerking en afzonderlijke beoordelingsstatus. Een deelregel heeft een ouderregistratie waar die bestaat; een plotsamenvatting wordt niet als extra oppervlaktedeel opgeteld. Percentages uitsluitend 0–100 en onbekend blijft NULL.
- [x] Voeg `maatregel_registratie_herkomst` toe met unieke brontabel+bronsleutel, oorspronkelijke rijwaarden, rijhash, migratieversie en precies één doeltak: beheerregistratie, toegankelijkheidsregistratie of bestaande uitvoering+plot+jaar. Foreign keys en XOR-checks verhinderen ontbrekende/meervoudige doelen; de audit valideert de volledige uitvoering–plot–jaarcombinatie.
- [x] Registreer de oorspronkelijke handmatige bron als zodanig in `maatregel_bron`, met passend brontype. Ontleen geen onafhankelijke bronbevestiging aan deze administratieve migratie.
- [x] Registreer de drie nieuwe tabellen in het centrale schemacontract. Bewaar begrazingsdieren als beheereigenschap; maak daarvan geen wilde soortwaarneming of nieuw taxon.
- [x] Draai `python3 gis/scripts/test_maatregelen_schema_contract.py` en `python3 gis/scripts/test_maatregelen_seed_contract.py`; verwacht groen, herhaalbaar schema en ongewijzigde bestaande seed.

### Taak 2: Proefmigratie en herstel

**Interfaces:** migratiescript met `--audit`, `--apply`, `--verify` en `--restore`, steeds met expliciete database en lokale herstelmap. `--audit`/`--verify` schrijven niet; `--apply` weigert zonder gevalideerde back-up. Geen automatische live-uitvoering.

- [x] Schrijf eerst de integratietest met de 144/55/0-fixture, de vijf bestaande doelen en extra tests voor conflicten, gedeeltelijke dekking en een tweede bron voor hetzelfde feit. Bevestig dat deze faalt.
- [x] Laat `--audit` bronschema’s, alle rijwaarden, verwijzingen, rijaantallen en de vijf doelcombinaties controleren. Onverwachte inhoudsverschillen blokkeren automatische migratie; ga niet door met verouderde aantallen.
- [x] Maak een tabelgerichte lokale back-up inclusief DDL, waarden, sleutels en relevante rechten. Maak ook een controlebasis van bestaande maatregelenobjecten en overige tabellen. Geen volledige zware exportketen.
- [x] Migreer in een geïsoleerde proefdatabase de 139 overige beheerfeiten en 55 toegankelijkheidsfeiten. Leg 199 herkomstkoppelingen vast; de vijf bevestigde dubbelingen leveren nul nieuwe beheerfeiten op.
- [x] Vergelijk elke oorspronkelijke rij via haar herkomstkoppeling met het canonieke doel; valideer behoud van lege waarden, NULL, opmerkingen, bronspelling en oude ids. Controleer ook dat alle nieuwe feiten een bron hebben en iedere herkomst precies één doel.
- [x] Herhaal `--apply`: aantallen en betekenissen blijven gelijk. Simuleer onderbreking vóór en na objectwissel, herstel en vergelijk alle oorspronkelijke tabellen en overige geraakte objecten volledig.
- [x] Voer `python3 gis/scripts/test_maatregel_registraties_migratie_contract.py` uit; verwacht 139/55/199 en vijf bestaande doelen, nul verweesde relaties, groene herhaling en herstelproef.

### Taak 3: Leescontracten, dump en caches

**Interfaces:** drie alleen-lezen views met de oude tabelnamen; R-functie `build_maatregel_compat_tables(tbls)` levert een named list met dezelfde drie namen en getypeerde kolommen. Deze adapter gebruikt canonieke feiten plus herkomstmetadata; zij telt geen bronverwijzingen als extra feiten.

- [x] Schrijf eerst tests voor reconstructie van de oude 144/55/0-regels, inclusief alle kolommen en oude ids. Test een dump zonder oude INSERT-blokken en met een geldige lege nieuwe deeltak.
- [x] Bouw de compatibiliteitsviews uit de nieuwe feiten en de vijf bestaande uitvoeringsfeiten. Laat `v_plot_jaar_maatregel_bronvast` haar bestaande selectieregels behouden. Een aanvullende gezamenlijke leesselectie mag de vijf overeenkomende feiten slechts eenmaal tonen.
- [x] Implementeer de gedeelde R-adapter en laat de cachebouwer de nieuwe basistabellen lezen. Accepteer een lege tabel uitsluitend als haar verwachte schema aanwezig is; los dit niet op door alle ontbrekende INSERT-blokken stilzwijgend als leeg te behandelen.
- [x] Behoud de bestaande objectnamen in cache en browser-JSON, verhoog de parser/cacheversie en weiger een oude cache bij een nieuwe dump. Bewaar herkomstmetadata intern; voeg geen volledige interne auditpayload aan browser-JSON toe.
- [x] Laat exportvalidatie ook de drie gereconstrueerde selecties en de canonieke ontdubbeling vergelijken. Gebruik voor deze taak kleine proefbestanden, geen volledige levende dump.
- [x] Voer de bestaande cache-/browser-/exportcontracttests uit volgens hun bestaande fixture-aanroep, plus de nieuwe integratietest. Alle moeten slagen zonder oude fysieke tabellen en zonder oude INSERT-blokken.

### Taak 4: Tijdselectie en toepassingen

**Interfaces:** beheer toont expliciete jaarfeiten; toegankelijkheid levert een bewezen status voor het gekozen jaar of `onbekend`, naast een afzonderlijke laatste historische registratie met bronjaar. Een later onderbouwde periode vereist expliciete begin-/eindgrenzen en bron; een open einddatum is geen automatische toestemming voor onbeperkt doortrekken.

- [x] Leg falende regressies vast: 2023 heeft geen toegankelijkheidswaarde uit 2024; 2024 behoudt alle 55 oorspronkelijke statussen; 2025/2026 krijgen zonder aanvullend bewijs geen bewezen status uit 2024. Een historische status mag wel met bronjaar apart worden getoond.
- [x] Pas `getSelectedToegankelijkheid`, `getMaatregelblok` en de plottab aan: geen stilzwijgende voortzetting van beheer uit 1999 en geen toegankelijkheidssnapshot als actuele zekerheid. Laat historische informatie zichtbaar beschikbaar; verwijder geen bestaande kaart, tekst, filter of grafiek.
- [x] Pas `add_toegankelijkheid_covariate` aan op dezelfde bewezen jaarselectie. Behoud de vijf huidige statuslabels, `onbekend` en herkenbare kwaliteitsopmerkingen. Meld eventueel veranderde modelpopulatie en modeluitkomsten als gevolg van deze goedgekeurde inhoudelijke correctie; dit is geen technische pariteitseis.
- [x] Test gepland/niet-uitgevoerd beheer, meerdere maatregelen in hetzelfde jaar, een deelmaatregel zonder dekkingspercentage en overlappende bronnen. Onopgeloste conflicten worden zichtbaar of blokkeren de analyse; geen willekeurige eerste rij.
- [x] Controleer lokaal de website-kavelpagina, dashboardlink en Shiny-link. In de onderzochte websitecode ontbreekt een directe verwijzing naar de oude tabellen; houd bestaande websiteviews en rechten intact. Bij noodzakelijke VWG_M-wijziging ook daar de toepasselijke instructies en handleidingen volgen.
- [x] Voer `node scripts/test_dashboard_browser_data_loader.js` en de relevante bestaande R-/browsercontracttests uit. Verifieer plottab en Shiny met kleine fixtures, ook voor onbekende jaren en M36 in 2024.

### Taak 5: Schrijfroutes, documentatie en lokale omschakeling

**Interfaces:** alleen de nieuwe registratiestructuur is schrijfbron; compatibiliteitsviews zijn uitsluitend leesbaar. De migratie verwijdert fysieke tabellen, niet de drie leescontracten.

- [x] Zet de drie bestaande import-SQL-routes om naar de nieuwe registraties en centrale bronverwijzingen. Gebruik geen nieuwe `LOAD DATA` naar compatibiliteitsviews en importeer voorbeeld-CSV’s niet als actuele bron.
- [x] Actualiseer oude migratie-/behoudstests en voorkom dat historische scripts de verwijderde fysieke tabellen opnieuw introduceren.
- [x] Voer na uitvoeringsopdracht de lokale back-up, proefmigratie en herstelproef opnieuw uit met de actuele invoer. Zet pas daarna lokaal de gegevens en leesobjecten om, met gecontroleerde herstelstappen en zonder gelijktijdige schrijver.
- [x] Controleer oude leescontracten 144/55/0, nieuwe feiten 139/55, de vijf bestaande doelen en ongewijzigde oorspronkelijke uitvoeringen. Bevestig dat geen onopgeloste inkomende afhankelijkheden of verweesde sleutels overblijven; controleer rechten en databasebrede centrale taxonbereikbaarheid; vergelijk overige gegevens met de begincontrolebasis.
- [x] Werk onmiddellijk bronregister, tabelinventaris en handboek bij; vermeld de 144 oorspronkelijke begrazingsregistraties uit 1991–1999, vijf ontdubbelingen en de 55 toegankelijkheidssnapshots uit 2024. Actualiseer bij bronregister en inventaris ook DOCX, render met de bestaande lokale route en controleer visueel.
- [x] Maak een gerichte diff-/regressiecontrole; commit en push de samenhangende wijziging. Integreer de afgeronde taak gecontroleerd in main. Meld afzonderlijk: lokale database omgezet, Git-status, afnemerketen getest op fixtures, productie nog niet gepubliceerd.

### Taak 6: Afgeleide keten en eventuele publicatie — afzonderlijke akkoordmomenten

- [ ] Vraag na lokale databasewijziging expliciet of de zware export/proefimport/cachebouw nodig is. Een uitvoeringsopdracht voor lokale migratie is daarvoor geen automatische toestemming.
- [ ] Bouw na dat akkoord via `scripts/export_meijendel_sql.sh` de gevalideerde dump, proefimport, cache en browserdata. Eis live-/dumpovereenkomst, groene contracttests en geslaagde volledige dashboard-/Shiny-inhoudscontrole.
- [ ] Publiceer uitsluitend na afzonderlijk VPS-akkoord, vanaf schone main gelijk aan origin/main, via het bestaande deployscript en met ancestrycontrole, deploy-lock, volledig manifest en herstelmogelijkheid. Laat de bestaande productie tot die release de bestaande consistente gegevens/code/cache gebruiken.
- [ ] Controleer na publicatie website-kavelpagina’s, alle behouden dashboardonderdelen, de vijf ontdubbelingen, historische jaarselecties, Shiny-start/cacheversie en toegankelijkheidscovariaat. Registreer productiecommit pas bij volledig groene nacontrole.
- [ ] Actualiseer vervolgens het gezamenlijke release-manifest met beide geregistreerde productiecommits, valideer en integreer dit in VWG_Project/main. Voer de afsluitende workspace-preflight en volledige synchronisatiecontrole uit.

## Gereedcriteria

De lokale migratie is gereed wanneer de drie oude fysieke tabellen weg zijn, de oorspronkelijke 199 records volledig herleidbaar zijn, de vijf dubbelingen éénmaal als feit bestaan, de 139 overige beheerregistraties en 55 toegankelijkheidsregistraties behouden zijn, de lees-/schrijf-/cachecontracten groen zijn en documentatie gelijk en actueel is. Productie is pas bijgewerkt na de afzonderlijk goedgekeurde en geverifieerde publicatiefase. Rapporteer deze twee eindpunten afzonderlijk.

## Uitvoeringsstand 16 oktober 2026

Taken 1–5 lokaal uitgevoerd. De actuele bronvaste basis was 307 regels en is ongewijzigd behouden; de gezamenlijke view bevat 446 regels. Vijf bevestigde dubbelingen wijzen naar bestaande feiten. Volledige reconstructie van 144 begrazingsregels (1991–1999) en 55 toegankelijkheidsregels (2024), herstelproef, SQL/R-pariteit, overige-tabelchecksums en 128 centrale taxonroutes zijn groen. Alle betrokken Markdown-/Worddocumentatie is bijgewerkt. Reviewbevindingen over bronidentiteit bij correctie, native ids, te ruime ontdubbeling en tussentoestanden zijn opgelost en getest.

Taak 6: de afzonderlijke vraag over zware export/proefimport/cachebouw is gesteld; zonder antwoord geen uitvoering. VPS-publicatie is niet goedgekeurd en niet uitgevoerd. Proefbestanden en herstelbewijs staan in `/Users/ton/Documents/Meijendel-herstel/2026-10-16-beheer-toegankelijkheid`.


## Vervolgbesluit van Ton op 16 oktober 2026

De drie compatibiliteitsviews eveneens verwijderen en de afnemers rechtstreeks aansluiten. Uitgevoerd op een afzonderlijke taakbranch: R/cache/browserobjecten hernoemd, import- en exportcontroles rechtstreeks op maatregel*, behoud van 144 beheerfeiten en 55 toegankelijkheidsregistraties, expliciete jaarselectie en vijf ontdubbelingen. Historische reconstructie en herstelbewijs blijven mogelijk zonder de views. Geen zware export of VPS-publicatie.
