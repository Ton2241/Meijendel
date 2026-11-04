# Voorbereiding presentatie broedseizoen 2026

Deze matrix beschrijft de beoogde lokale release. De officiële levering bepaalt het eindjaar, de opgenomen soorten en kavels en de beschikbare schattingen. De analyse van 156 soorten over 1958–2025 levert voorbeelden voor de presentatie. De banden uit die analyse hebben de status diagnostisch.

De lokale aansluiting en de aantoonbare resterende blokkades staan in [de uitvoeringsnotitie van 4 november](TRIM_RELEASE_2026_AANSLUITING.md).

## Gedeelde presentatie

Gebruik voor elk resultaat dezelfde soort- of groepssleutel, selectie, periode, maat, eenheid, puntwaarde en status. Koppel onzekerheid aan dezelfde bronversie en hetzelfde run-ID. Vermeld bij groepsresultaten ook de samenstelling en variant. Leg per jaar vast of de waarde geteld, modelmatig aangevuld of onbekend is.

| Situatie | Weergave |
|---|---|
| Formeel periode-interval uit TRIM | Toon de periode en procent per jaar met het interval en de methode in de trendtabel. |
| Lange begin/eindverandering | Toon het netto percentage en de exacte begin-, eind- en brugvensters. Geef een vrijgegeven interval bij deze maat in de samenvatting. |
| Jaarindex met vrijgegeven puntgewijze band | Toon de band rond de jaarindex met referentiejaar, indexeenheid en methode. Laat gaten in de band open. |
| Beschrijvende GAM-band | Benoem deze als band rond de gladde lijn in de legenda. Gebruik een afzonderlijk label en een eigen stijl voor bootstraponzekerheid. |
| Diagnostische bootstrap | Toon in de lokale beoordeling met het geldige en geplande aantal trekkingen, status van de grenscontrole en bronsteun. |
| Onvoldoende geldige trekkingen, constante verdeling of onvoldoende dekking | Toon de schatbare puntwaarde en status met reden. Laat het interval leeg. Geef aantallen en reden per schatter in tabel en download. |
| Geen schatbare lange maat | Houd de soort zichtbaar met de concrete reden. Toon beschikbare afzonderlijke perioden en jaarindices onder hun eigen status. |
| Getelde nul, onbekend jaar en referentie-index | Toon de getelde nul als nul, een onbekend jaar als gat en de vaste referentie 100 als schaalanker zonder band. |

De huidige formele laadroute vraagt eindjaar 2026, minimaal 2.000 geplande trekkingen en een manifest met status `publiceerbaar`. De bestaande soort-, groeps- en functionele tabellen vragen een overeenkomend run-ID. Leg vóór activering per type schatter de vrijgaveregels vast. De lange begin/eindmaat en de puntgewijze jaarbanden vragen een eigen uitvoercontract. Neem de diagnostische 2025-bestanden apart op in de lokale review. Een formele groepsband vraagt een eigen groepsberekening voor de juiste samenstelling en variant.

## Website VWG_M

De routes hieronder verwijzen naar `website/vwg-m-linux-app/app/main.py`. Controleer bij CMS-pagina’s ook de opgeslagen inhoud en bijlagen. De lokale checkout toont de routes en sjablonen. De [lokale CMS- en figuurcontrole](TRIM_RELEASE_2026_CMS_CONTROLE.md) beschrijft de aangetroffen teksten en bestanden per pagina. Vergelijk ze tijdens de releaseproef met de gekozen CMS- en uploadbasis.

| Pagina | Werk voor 2026 | Presentatie |
|---|---|---|
| `/tellingen/bmp.asp` | Ververs recente teljaren, soort- en territoriumtotalen en links naar jaartabellen en grafieken. | Vermeld het laatst gevalideerde broedseizoen en de teldekking. |
| `/tellingen/jaar.asp`, `/tellingen/jaar.csv` | Voeg het gevalideerde jaar toe aan keuze, vergelijking en download. | Onderscheid telling, getelde nul en ontbrekende telling. |
| `/tellingen/totaallijst.asp`, `/tellingen/totaallijst.csv`, `/tellingen/euringlijst.asp`, `/tellingen/euringlijst.csv` | Controleer eindjaar, totalen en aansluiting op soort-ID en EURING-code. | Toon tellingen volgens de bronstatus. |
| `/werkgroep/bmp_verslagen.asp` | Controleer jaarlabel en link zodra een officieel verslag beschikbaar is. | Benoem de status van het verslag afzonderlijk van de telgegevens. |
| `/soorten/index.asp`, `/soorten/alle-soorten.asp` | Ververs analysebereik en links naar soortdetails. Controleer welke soorten in de nieuwe levering en selectie voorkomen. | Houd soorten met gedeeltelijke of ontbrekende trend zichtbaar. |
| `/soorten/vogel.asp?id=…` | Ververs tellingen, trendgegevens, grafiek, periode en bronverwijzing. De oude grafiekroute verwijst hierheen. | Gebruik de gedeelde status en periode-indeling. Toon een vrijgegeven band bij de bijbehorende maat en vermeld waarom een band of lange maat ontbreekt. |
| `/groepen/index.asp`, `/groepen/{slug}.asp`, `/groepen/grafiek/{chart_id}.svg` | Ververs alle grafiekcodes en bijbehorende soortlijsten uit de nieuwe groepsuitvoer. Controleer ecologische en habitatgroepen, Rode en Oranje Lijst, Vogelrichtlijn en de binaire en gewogen functionele varianten. | Toon variant en samenstelling. De publieke SVG gebruikt dichtheid uit `groep_dichtheid.csv`. Controleer GAM, MSI en landelijke vergelijkingen afzonderlijk waar die worden getoond. Gebruik een formele groepsband uitsluitend met eigen groepsuitvoer. |
| `/meijendel/index.asp`, `/meijendel/beschrijving.asp`, `/meijendel/vogelonderzoek.asp`, `/meijendel/verhalen.asp` | Controleer eindjaren, tellingen, samenvattingen en verwijzingen naar analyse en verhalen. | Geef de peildatum van cijfers. Houd historische ankerjaren en gepubliceerde bronperioden herkenbaar. |
| `/meijendel/verhalen/landelijke-spiegel.asp` | Controleer lokale eindjaren, landelijke reeks en gemeenschappelijk vergelijkingsvenster. | Benoem het eindjaar per bron en onderbouw eventuele lokale afwijking. |
| `/meijendel/verhalen/riet-en-watervogels.asp`, `/meijendel/verhalen/meeuwenkolonie.asp` | Controleer figuren, eindwaarden en tekst over riet-, water- en kolonievogels. Gebruik per uitspraak de bijbehorende broedvogel- of koloniebron. | Scheid tellingen, indices en afgeleide verandering. |
| `/meijendel/verhalen/tapuit-in-meijendel.asp`, `/meijendel/verhalen/raaf-in-meijendel.asp`, `/meijendel/verhalen/grote-karekiet.asp` | Controleer per soort of nieuwe tellingen de laatste waarneming, eindwaarde of conclusie wijzigen. | Vermeld dekking en modelaanvulling waar die de conclusie dragen. |
| `/meijendel/verhalen/steeds-meer-van-hetzelfde.asp`, `/meijendel/verhalen/wisseling-van-de-wacht.asp`, `/meijendel/verhalen/paradox-open-duin.asp` | Controleer soortensamenstelling, indexfiguren, jaartallen en tekst tegen de gebruikte analysemethode. | Herbereken afgeleide conclusies bij een gewijzigd venster of een gewijzigde selectie. |
| Verhalen `broedvogels-en-begrazing`, `broedvogels-en-stikstof`, `recreatie-en-broedvogels`, `natuurherstel`, `klimaatverandering`, `predatie-in-het-duin`, `vogels-op-de-klok-van-het-weer`, `terugkeer-van-de-nacht`, `trekvogels-twee-werelden`, `konijn-en-grijs-duin`, `pq-vegetatie` en `geschiedenis-vogelwerkgroep` | Controleer in ieder verhaal cijfers, figuuronderschriften en uitspraken met een voortschrijdend lokaal broedvogeleindjaar. Koppel ieder getroffen onderdeel aan de exacte onderliggende analyse. | Behoud de bronperiode bij historische, beheer- en contextanalyses. Beoordeel gewijzigde samenhang in het licht van de beschikbare referentie en andere mogelijke verklaringen. |

## Dashboard en Shiny

| Onderdeel | Werk voor 2026 | Presentatie |
|---|---|---|
| Dashboard Trends, ruwe territoria en kavelgrafieken | Ververs tellingen, keuzes, dekking en eindjaar uit de browserdataset. | Toon gaten en nullen volgens de bron. Behoud de waarschuwing voor de methodebreuk rond 1984. |
| Dashboard Trends, TRIM-soortindex en trendkaart | Ververs jaarindices, modelstatus, trendoverzicht en bronsteun. Koppel een vrijgegeven onzekerheidsbestand aan de juiste soort, periode en maat. | Gebruik de gedeelde regels voor jaarband, lange samenvatting en uitval. |
| Dashboard MSI, robuust en volledig, inclusief landelijke vergelijking | Ververs MSI, GAM, beschikbare landelijke referentie en soortlijsten per variant. | Label bronperiodes, varianten en bandtype. Toon groepsbootstrap in de aparte trendinformatie bij een geldige groepsuitkomst. |
| Dashboard MSI, functionele groepen, Rode/Oranje Lijst, Vogelrichtlijn en habitat | Ververs per beschikbare groepscode, inclusief binair en gewogen waar van toepassing. | Vermeld samenstelling, exploratieve status en eigen bandtype per reeks. |
| Dashboard kenmerken, winter en overige vergelijkingen | Controleer de bronafhankelijkheid per paneel. Ververs alleen onderdelen die de nieuwe broedvogelgegevens daadwerkelijk gebruiken. | Geef de eigen bronperiode per analyse. |
| Shiny TRIM → Selectie en Controle | Ververs beschikbare jaren, kaveldekking, oppervlak, modelstatus en downloads. | Geef herkenbaar aan welke selectie actief is en waarom een periode of jaar ontbreekt. |
| Shiny TRIM → Soorten (`species_plot`, `species_table`, onzekerheidstabel en CSV’s) | Ververs standaarduitvoer en controleer berekening op een eigen selectie. | Toon standaardbootstrap alleen bij exact passende selectie, periode en maat. Toon voor eigen selecties de daadwerkelijk berekende resultaten en hun eigen status. |
| Shiny TRIM → Groepen en Functionele groepen | Ververs grafieken, trendtabellen, samenstelling en downloads. Controleer robuust/volledig en binair/gewogen. | Houd GAM, groepsbootstrap en soortbootstrap herkenbaar gescheiden. |
| Shiny TRIM → Rode/Oranje Lijst en Habitatgroep | Ververs MSI, trendtabellen, soortenlijsten en downloads. | Toon de eigen status van de groep. |
| Shiny LAMBDA, NMDS, GEE en GLMM | Controleer jaarbereik en herbereken de onderdelen die de broedvogelbron of standaardselectie gebruiken. | Toon onzekerheid volgens de eigen methode en selectie van ieder model. |

## Lokale vrijgaveproef

1. Valideer de officiële levering en leg herkomst, import, dekking en aantallen vast volgens het draaiboek. Maak daarna de overeengekomen verse dump en cache.
2. Stel vóór de bootstrap vast welke schatters en vensters worden gebruikt. Valideer de nieuwe run getrapt en beoordeel uitval, stabiliteit, bronsteun en dekking. Leg de beslissing per schatter en variant vast.
3. Genereer dashboarddataset, Shiny-cache, TRIM-tabellen en websitegrafieken uit dezelfde vastgelegde bronversie. Maak voor iedere getroffen CMS-pagina een reviewbare tekst- en figuurwijziging.
4. Draai `R/check_dashboard_website_parity.R`, `R/check_shiny_dashboard_parity.R`, de bestaande onzekerheids- en releasecontractcontroles en een lokale routeproef voor website, dashboard en Shiny. Vergelijk per gedeelde grafiek waarden, eindjaar, schaal, labels, legenda en type band. Controleer ook downloads.
5. Neem in de lokale schermproef een volledige reeks, een soort met bruguitval, een soort met alleen een afzonderlijke periode, een getelde nul en een onbekend jaar op. Controleer dat een eigen Shiny-selectie de standaardband niet overneemt.
6. Leg in de releasebeschrijving bronversie, beide codecommits, gewijzigde pagina’s, grafieken, bestanden en openstaande uitzonderingen vast. Leg die concrete release daarna ter goedkeuring voor.

Hoofdroutes en controles zijn afgeleid uit `VWG_M/website/vwg-m-linux-app/app/main.py`, `bmp_meijendel_index.html`, `shiny_meijendel/app.R`, `R/trim_uncertainty_presentation.R` en `deploy/update_en_deploy_meijendel.sh`. Zie ook [het 2026-draaiboek](TRIM_BOOTSTRAP_2026_RUNBOOK.md).


## Doorlopende integrale voorbereiding — afspraak 4 november 2026

Na iedere wijziging worden bronproducten, consumenten, onzekerheids-/uitvalweergave, documentatie en controles in dezelfde taak in de lokale releaseketen verwerkt. Eén gecontroleerde actualisering omvat website, dashboard en Shiny. De actuele zelfstandige periode-/jaarindexuitvoer wordt daarom via `--period-source` in hetzelfde gedeelde bootstrapblok opgenomen; het kandidaatmanifest bindt alle drie consumenten via `--website-root` aan hun codehashes. De broncontext van de lange en zelfstandige maat moet overeenkomen. Beoordeelde en geldige aantallen blijven schattergebonden.

Vóór de uiteindelijke publicatie moet één releasekandidaat database/bronexport, jaargrens, soort-/kavelselectie, drie bootstrap-CSV’s, modelstatussen, jaarindices, groepsproducten, websitefiguren, CMS/migraties/media, dashboard en Shiny onder passende bronidentiteiten en checksums bijeenbrengen. De bovenstaande paginamatrix en de CMS-controle blijven onderdeel van die eindcontrole. Een 2025-artefact is geen gevalideerd 2026-product. Ontbrekende officiële data, onbesliste intervalvrijgave of een afwijkende bron-/jaaridentiteit blokkeren de betreffende publicatie; soorten en uitval verdwijnen daarbij niet uit beeld. Publicatie blijft afzonderlijk te autoriseren.


De actieve gedeelde presentatie en de native release-/herstelcoördinator zijn toegevoegd. Zie [de proefnotitie van 4 november](TRIM_INTEGRALE_RELEASE_HERSTELPROEF_20261104.md) voor de exacte teststand en de afzonderlijke technische Linux/gatewayrestpost. De paginamatrix hierboven blijft de inhoudelijke controlelijst voor de officiële 2026-uitkomsten. Een lokaal groen pakket is geen reeds uitvoerbare of goedgekeurde VPS-publicatie.
