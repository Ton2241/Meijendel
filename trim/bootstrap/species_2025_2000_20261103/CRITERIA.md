# Voorafcriteria: 2.000 lange uitkomsten en afzonderlijke perioden/jaarindices

3 november 2026. Opdracht van Ton: bestaande 500 voor de 32 complete soorten uitbreiden tot 2.000 tot en met 2025; voor de 119 zonder lange baseline afzonderlijke perioden en jaarindices met eigen onzekerheidsbeoordeling; alle 156 zichtbaar. Geen 2026, database/export/cache of publicatie.

## Bron, hergebruik en selectie

Dezelfde bewaarde ontwikkelbron 1958–2025, 156 soorten, 52 kavelclusters (17 historisch/35 later), seed20261102. De 32 zijn exact gate=kandidaat_2000_validatie in endpoint_2025_500_window_check_20261103/per_species.csv. De vijf met lange uitval en de 119 zonder lange baseline blijven zichtbaar. De 500 oorspronkelijke RDS-uitkomsten worden niet gewijzigd of opnieuw berekend voor de lange maat. Nieuwe trekken zijn uitsluitend501–2000 voor de32; iedere trekking bemonstert alle52clusters zoals eerder. Filtering van soorten verandert de clusters, seed en bevroren modeljaren niet. Voor de uitbreiding worden twee oude trekkingen gereproduceerd als verificatie; dit zijn geen nieuwe onafhankelijke trekkingen.

Hergebruik krijgt expliciete oudermanifest-/batchhashes; nieuwe batches krijgen een aparte identiteit. Eerste500 en nieuwe1500 worden pas na herkomstcontrole gecombineerd, niet onder een vervalst gemeenschappelijk batchmanifest. Engine/modelvoorschrift ongewijzigd; één rekenworker, batches5 met checkpoint/herstart.

## Lange begin/eindmaat voor32

Maat, nulbeleid en relevante-jaarcontrole blijven ongewijzigd: gemiddeld1958–1962 tegenover2021–2025, brug1979–1983/1986–1990. Beide modellen en positieve brug vereist. Ontbrekende/ongeldige benodigde index geen uitkomst; andere jaarproblemen apart. Echte nuleinden blijven−100%; nulbegin ongedefinieerd.

Per soort alleen een diagnostische percentielband type7 bij eindige baseline,2000/2000 geldige uitkomsten en niet-constante verdeling. Geen filtering van mislukte trekkingen. Bandgrenzen worden beoordeeld bij500,1000,1500,2000; laatste én voorgaande overgang moeten elk voor beide grenzen <0,1 procentpunt en <5% van de actuele bandbreedte verschuiven. Voor vrijgave als numeriek stabiele kandidaat zijn1500→2000 én1000→1500 vereist. Uitval/degeneratie blokkeert een band, onrust blokkeert het etiket stabiel. Geen automatische95%-dekking of p-waarde; formeleCI-kolommen blijven leeg, ook bij stabiele kandidaten.

## Afzonderlijke perioden en jaarindices

Voor alle156 wordt dezelfde eigen beoordeling gemaakt met bestaande500draws, zodat vooral de119 zonder lange baseline toch hun bruikbare informatie behouden. Pre1958–1983 en post1984–2025 blijven onafhankelijk van elkaar en van de brug. Geen baselinefit beschikbaar: periode met concrete reden zichtbaar; geen geforceerd model. Bevroren baseline-modeljaren per soort blijven gelijk.

De oorspronkelijke postindices zijn bruggeschaald opgeslagen. Bij positieve brug worden ze teruggeschaald; zo nodig wordt de andere bewaarde brugvariant gebruikt. Wanneer het postmodel wel slaagde maar beide bruggen ontbreken, wordt alleen dat postmodel met exact dezelfde draw en bevroren modeljaren opnieuw uitgevoerd om de ontbrekende ongebrrugde index te herstellen. Modelstatus/configuratie en bestaande periodeschatting moeten reproduceren; anders stoppen. Geen nieuwe bron, modelzoekregel of onafhankelijke trekking. Deze noodzakelijke herstelmodelfits worden geteld en gehasht; niet voorgesteld als volledig fitvrij hergebruik.

Periode-uitkomst: nettoverandering tussen gemiddelde eerste5 en laatste5 kalenderjaren van de bevroren eigen modelperiode, minimaal10 opeenvolgende jaren en geen overlappende vensters. Dit is een beschrijvende begin/eindverandering, geen vervanging van de bestaande formele jaarlijkseoverall-trend en niet de lange1958–2025maat. Eigen begin/eindjaren staan per soort vermeld; korte of onsamenhangende perioden krijgen geen samenvatting. Dezelfde nul- en uitvalregels gelden, zonder brugvereiste.

Jaarindex: iedere kalenderjaarpositie1958–2025 blijft zichtbaar. Binnen iedere beschikbare periode vaste normalisatie aan het eerste positieve baseline-indexjaar: dat jaar=100. Ieder bootstrapjaar wordt aan datzelfde jaar genormaliseerd. Een ontbrekend/nul referentiejaar maakt die relatieve reeks in die trekking ongedefinieerd; niet verschuiven naar een ander jaar. Buiten de bevroren modeljaren geen index. Echte nulwaarden in overige jaren behouden. Referentiejaar=100 is een definitie en krijgt geen schijnmarge. Constante nul-/andere verdelingen krijgen statusconstant_geen_band; geen bewijs van geografische zekerheid.

Periode- en jaarbanden: diagnostische percentielen type7 uitsluitend bij beschikbare baseline,500/500 eindige geldige waarden en niet-constante verdeling. Alle500 meetellen; geen succesvolle-deelverdeling. Jaarbanden zijn puntgewijs, geen gelijktijdige95%-band. Stabiliteit bij250,375,500 met dezelfde absolute0,1 en relatieve5%-regel, in procentpunten voor periodeverandering en indexpunten voor jaarindex. Onrust zichtbaar; de500beoordeling is geen uitbreiding van deze soorten naar2000. FormeleCI-kolommen leeg; geen jaarlijksep-waarden. Eerdere overall-uitkomsten met nuljaartotalen blijven geblokkeerd; geen nul→één.

## Afronding

Per156 soorten: lange status/met1500extra voor32 of bestaande500 voor124, beide periode-uitkomsten en indexjaaroverzicht, eigen aantallen, redenvelden, diagnostische bandstatus/stabiliteit en bronsteun. Alle10608soort-jaarposities en312perioden zichtbaar, inclusief niet beschikbare. Beperkte kavels, modelaanvulling, vensterkeuze, model-/brugaannamen en onbekende dekking expliciet. Geen groepsbootstrap. Nieuwe resultaten naast historie; protected bronCSV-hashes behouden. BronregisterMD/Word, besluiten/status/taken/runbook actualiseren; gerichte tests en onafhankelijke eindreview inclusief alleWordpagina’s. Commit/push taakbranch; geen merge/deploy.
