# Onzekerheidsbeoordeling tot en met 2025: alle 156 soorten

Voorafcriteria: e7f68940. De bestaande 500 trekkingen zijn voor 32 soorten aangevuld met 1500 nieuwe, IDs 501–2000, met dezelfde bron 1958–2025, dezelfde seed en 52 gestratificeerde kavelclusters. Eerste 500 zijn onaangetast; nieuwe resultaten hebben een eigen identiteit met expliciete ouderhashes. Twee oude trekkingen reproduceerden vóór de uitbreiding de 32 soort- en indexuitkomsten. Er is één fitworker gebruikt. Geen 2026, nieuwe database-export/cache, groepsbootstrap of publicatie.

## Lange begin/eindmaat:32 uitgebreid

Van de 32 hebben **29 soorten 2000/2000 geldige niet-constante uitkomsten**. Daarvan zijn **4 numeriek stabiele kandidaten** volgens beide vooraf gekozen grensvergelijkingen; 25 houden bewegende grenzen. Bij 3 soorten is sprake van uitval; hun band wordt geweigerd. Geen formele 95%-marges vrijgegeven. De overige 124 behouden de 500 beoordeling: vijf met lange uitval en 119 zonder schatbare baseline voor deze vaste lange maat. Alle 156 blijven zichtbaar.

De maat blijft 100 ×(gemiddelde index 2021–2025/gemiddelde index 1958–1962−1), met brug 1979–1983/1986–1990. Beide modellen en een positieve brug zijn vereist. Alleen eindige niet-negatieve indices in gebruikte vensters verplicht; overige jaarproblemen apart. Nuleinde blijft−100%; nulbegin ongedefinieerd; geen nul→één of aanvulling. Dezelfde controle geldt voor alle soorten. Drie- en zevenjaarsvensters blijven afzonderlijke gevoeligheidsuitkomsten.

Bij 500,1000,1500 en 2000 zijn beide diagnostische percentielgrenzen opgeslagen. Voor het etiket stabiel moeten 1000→1500 én 1500→2000 ieder aan beide eisen voldoen: verschuiving minder dan 0,1 procentpunt én minder dan 5% van de actuele bandbreedte. Meer trekkingen geven geen garantie dat de percentielband de werkelijke 95%-dekking heeft. Een nieuwe uitval bij 2000 blijft zichtbaar; geen band uit alleen succesvolle trekkingen.

**Beide grenscontroles stabiel:** Scholekster, Wulp, Tortelduif en Tapuit. Alle vier hebben in 2021–2025 hoogstens één bronkavel met een positieve telling. Bij Wulp is dat nul; zijn positieve uitgangsindex berust op modelaanvulling. Numerieke stabiliteit neemt deze beperking niet weg.

**Nieuwe uitval:** Stormmeeuw 1.999/2.000, met ontbrekende beginindices 1958–1962 in trekking 1519; Kleine Mantelmeeuw 1.994/2.000, met vijf onschatbare modellen vanaf 1984 en één vóór 1984; Roodborsttapuit 1.999/2.000, met een volledig nulgeteld brugvenster in trekking 1750. De acht gevallen en oorspronkelijke redenen staan in [new_long_failures.csv](new_long_failures.csv). Echte nuleinden blijven geldige uitkomsten.

## De 119 zonder lange baseline: eigen perioden en jaarindices

Deze 119 soorten zijn geen uitgesloten soortgroep. 56 hebben twee bruikbare baselinemodellen, 42 één en 21 geen. Hun 238 perioderegels bevatten 154 beschikbare baselinemodellen en 149 schatbare eigen begin/eindveranderingen. 73 hebben een volledige niet-constante 500 verdeling met diagnostische periodeband. Hun 8092 kalenderposities bevatten 4614 beschikbare baseline-indexjaren en 2420 diagnostische jaarbanden. Ieder ontbrekend model, onvoldoende lang venster, uitgevallen referentiejaar en ontbrekende index blijft met eigen status zichtbaar.

Van de 149 schatbare periodeveranderingen missen er 76 een volledige verdeling en krijgen daarom geen band. Van de 73 periodebanden haalt één beide stabiliteitscontroles; van de 2.420 jaarbanden halen 62 soort-jaarbanden beide controles. Ook deze stabiele banden blijven diagnostisch.

Dezelfde onafhankelijke 500-beoordeling staat ook voor de 32 uitgebreide soorten en de vijf met lange uitval, zodat alle 156 vergelijkbaar zijn vastgelegd:312 perioden en 10608 soort-jaarposities. Dit zijn eigen onzekerheidsbeoordelingen; de periode- en jaarbanden hebben 500 trekkingen, de lange maat van 32 heeft 2000.

Periodeverandering: gemiddelde eerste vijf tegenover laatste vijf jaren van de eigen bevroren baseline-modelperiode. Minimaal tien opeenvolgende jaren, geen overlap of schuivende vensters. Deze jaren staan per soort vermeld en verschillen tussen soorten. De maat is netto over die periode; zij vervangt niet de bestaande formele jaarlijkse overall-trend. Nulvriendelijk betekent dat een nuleinde−100% kan zijn, niet dat een ongedefinieerd nulbegin toch een getal krijgt. Modelperioden met eerder geblokkeerde overall-uitkomsten blijven geblokkeerd voor die jaarlijkse overall-inferentie.

Jaarindex: per periode hetzelfde eerste positieve baseline-referentiejaar=100 voor alle 500 trekkingen. Een nul of ontbrekende index in dat referentiejaar maakt de relatieve reeks in die trekking ongedefinieerd; er wordt niet naar een ander jaar verschoven. Nul in andere jaren blijft nul. Het referentiejaar is per definitie 100 en krijgt geen schijnmarge. Ook constante nulverdelingen krijgen geen inferentiële band. De brongetelde en positief getelde kavels staan per jaar naast de index. Uitval is per jaar uitgesplitst naar een ontbrekend bruikbaar model, een onbruikbaar vast referentiejaar en een ontbrekende of ongeldige eigen jaarindex; deze aantallen tellen met de geldige uitkomsten op tot 500.

Voor periode- en jaarbanden gelden dezelfde volledige-verdelingseis en percentielmethode type 7. Stabiliteit wordt apart bij 250→375 en 375→500 getoetst, in procentpunten voor periodeverandering en indexpunten voor jaarindex, telkens met relatieve 5%-eis. Jaarbanden zijn puntgewijs; er is geen gelijktijdige 95%-band voor de hele reeks. Alle nieuwe formeleCI-kolommen blijven leeg.

De bestaande jaarlijkse overall-uitvoer per periode staat in [soorten_trendoverzicht.csv](../../soorten/soorten_trendoverzicht.csv). Die bestaande uitkomsten en nulblokkades zijn ongewijzigd. De kolom `n_model_failure` telt trekkingen zonder bruikbaar model, ook wanneer een onschatbaar baselinemodel volgens de bevroren selectie niet opnieuw is aangezet.

## Herstel van zelfstandige periode-uitvoer

De 500 oorspronkelijke batches bewaarden postindices na brugvermenigvuldiging. Een ontbrekende brug vernietigde daarmee de zelfstandig beschikbare postindex in de uitvoer, terwijl het postmodel wel kon slagen. Waar een brugvariant positief is, zijn de indices teruggeschaald. Alleen waar beide bruggen ontbreken, zijn dezelfde succesvolle postperiodemodellen met dezelfde trekkingen, modeljaren en engine hersteld: **22670 periodeherstellingen**, met **85677 afzonderlijke modelpogingen**. Modelconfiguratie en bestaande periodehelling reproduceerden; bij een afwijking zou de uitvoering stoppen. Dit zijn geen nieuwe onafhankelijke trekkingen en geen nieuwe modelregel. Beschikbare preperioden en terug te schalen postperioden zijn hergebruikt. Het originele 500 archief blijft intact.

## Grenzen van gebruik

De uitkomst beschrijft de bestaande modelgecorrigeerde telnetwerkroute. Zij bewijst geen gelijk bemonsterde geografische populatie. Schaarse positieve kavels, modelaanvulling, modelkeuze en de niet volledig te scheiden methode-/tijdverschillen in de brug blijven van belang. Venstergevoeligheid zit niet automatisch in één bootstrapband. Volledig berekenbaar of numeriek stabiel betekent daarom geen bewezen 95%-dekking of ecologische zekerheid. Een ontbrekend jaar wordt nooit een nul en een constante bootstrapverdeling bewijst geen afwezigheid in heel Meijendel.

## Bestanden en herkomst

- PER_SOORT.md en species_overview.csv: alle 156 soorten, lange maat plus eigen perioden/jaarindices en beperkingen.
- long_per_species.csv:156 lange statussen; long_primary_estimates.csv:bron en alle relevante trekkingen; long_window_sensitivity.csv:468 vensterregels; long_checkpoints.csv:128 primaire grenscontroles.
- periods.csv:312 perioden; annual_indices.csv:10608 kalenderposities met eigen onzekerheidsbeoordeling, referentiejaar en bronsteun.
- species_without_long_baseline.csv, periods_without_long_baseline.csv en annual_without_long_baseline.csv: expliciet 119 soorten,238 perioden en 8092 jaarposities.
- long_manifest.json en period_manifest.json: hashes, aantallen, hergebruik, nieuwe trekkingen, herstel en batchfouten. Criteria blijven in CRITERIA.md.

Nieuwe batchtijd voor 1500 trekkingen: 9103.93 seconden; herstel 500 periode-uitvoer: 1340.05 seconden. De twee verificatietrekkingen en rapportage vallen buiten die batchtijden. Geheugengetal is R-gc, geen volledigeRSS; systeemswap is niet alleen aanR toe te schrijven. Nieuwe batchfouten:0; herstelfouten:0.

Ruwe batches, alle 378468 lange vensterregels en de volledige periode-/jaarindexdrawmatrix blijven buitenGit in de canonieke map outputs/trim-2025-species-2000-20261103. Reproductie met R/run_trim_2025_2000.R, R/run_trim_period_recovery.R, R/assess_trim_2025_2000.R en R/assess_trim_period_uncertainty.R; rapport met scripts/build_trim_2025_uncertainty_report.py. Alle scripts krijgen REPO,PARENT,ROOT en waar van toepassing OUT; voorbeelden staan in het uitvoeringsplan. Geen automatisme om meer trekkingen of publicatie te starten.

**Afsluitcontrole:** de uitbreiding schreef alle 300 batches vóór de voltooiingsmarker. Daarna las R door een tijdens de run aangepast aanroepbestand een restregel (`sole()`), met procesexit 1. De oorspronkelijke EOF-offset verklaart de melding. Alle 300 batchchecksums, de identiteit, precies 501–2000,32 soorten per trekking en nul batchfouten zijn onafhankelijk van de procesexit gecontroleerd. Geen trekking opnieuw gedraaid. Zie extension_completion_check.json.

## Afrondcontrole

De gerichte R-controles zijn groen. De onafhankelijke eindreview bevestigt de 300 nieuwe en 100 herstelbatches, 78.156 ongewijzigde oorspronkelijke primaire regels, acht nieuwe uitvallen, alle gepubliceerde periode-/jaarbanden en hun stabiliteitsvlaggen. De bestanden bevatten alle 156 soorten, 312 perioden en 10.608 jaarposities. De vier beschermde bronbestanden hebben hun SHA-256 behouden. Zie result_verification.json voor de afzonderlijke bestandscontrole. Geen inhoudelijke of redactionele reviewbevindingen.

Het bronregister is in Markdown en Word bijgewerkt. Alle 62 gerenderde Wordpagina’s zijn afzonderlijk op volledige resolutie gecontroleerd; geen clipping, overlap of blanco pagina’s. De nieuwe alinea op pagina 9–10 is exact gelijk aan Markdown. Dekkingsvalidatie en geografische representativiteit zijn hiermee niet bewezen.
