# Voorafcriteria: afzonderlijke perioden en jaarindices tot en met 2025

4 november 2026. Ton heeft uitbreiding tot 2.000 goedgekeurd, met hergebruik, rapportage per soort en behoud van alle 156 soorten. Geen VPS-publicatie, 2026-invoer, databasewijziging, export/cachebouw of groepsbootstrap.

## Bevroren bron en selectie

Dezelfde Meijendel-ontwikkelbron 1958–2025, 52 kavelclusters (17 historisch, 35 later), seed 20261102, oorspronkelijke modeljaren, engine en modelzoekvolgorde. De bron is `outputs/trim-2025-validation-500-20261103/input`. Eerste 500 zelfstandige periode-/jaaruitkomsten uit `outputs/trim-2025-species-2000-20261103/assessment/period_annual_draws.rds` blijven exact behouden, inclusief ontbrekende waarden en uitval. De oorspronkelijke archieven worden niet overschreven.

Voor uitbreiding geselecteerd: iedere soort-periode met minstens één volledige niet-constante diagnostische periode- of jaarverdeling bij 500. In de vastgelegde beoordeling zijn dat 141 perioden van 89 soorten. Per geselecteerde periode worden de eigen periodeverandering en alle bijbehorende jaarindices beoordeeld met 2.000. Overige 171 perioden behouden hun 500-beoordeling en concrete blokkade; 67 soorten hebben geen uitbreidbare periode. Dit is een rekenkeuze, geen ecologische uitsluiting. Het verslag behoudt 156 soorten, 312 perioden en 10.608 kalenderposities.

## Hergebruik en nieuwe berekening

Gebruik trekkingsnummers 501–2000 met dezelfde gezamenlijke trekking van complete kavelgeschiedenissen als in de eerdere 32-soortenuitbreiding. Hergebruik daarvan iedere beschikbare geselecteerde periode-uitkomst. Terugschalen van positief gebrugde postindices mag; waar een eerder geslaagd postmodel door ontbrekende brug geen opgeslagen eigen indices heeft, alleen datzelfde model herstellen en modelconfiguratie en opgeslagen periodehelling laten reproduceren. Voor overige geselecteerde perioden uitsluitend de ontbrekende zelfstandige periodefit berekenen, zonder brugfit of groepsberekening. Bewaar alle uitval. De eerste 500 worden niet opnieuw berekend voor de eindverdeling.

Vóór productie: hashes en engine controleren; twee oude trekkingen met de directe onafhankelijke fitroute reproduceren tegen de bewaarde herstelde uitkomsten. Draw, modelstatus, modelconfiguratie en eindige indices (tolerantie 1e-10) moeten overeenkomen; nul- en ontbrekendpatroon exact gelijk. Eén fitworker, batches van vijf met checkpoints en herstartbewaking. Nieuwe uitvoer krijgt eigen identiteit en ouderhashes. Een mislukte berekening is geen reden om een trekking te vervangen.

## Maten, nullen en banden

Periodeverandering blijft nettoverandering van gemiddelde eerste vijf naar laatste vijf bevroren modeljaren, minimaal tien opeenvolgende jaren zonder overlap. Nuleinde is geldig -100%; nulbegin ongedefinieerd. Geen verschoven vensters of nulvervanging. Jaarindices houden per periode het oorspronkelijke eerste positieve baseline-referentiejaar = 100. Nul of ontbrekend referentiejaar in een trekking maakt de relatieve reeks ongedefinieerd; andere echte nullen blijven nul. Ontbrekende indices blijven gaten.

Diagnostische percentielband type 7 uitsluitend bij een schatbare baseline en 2.000/2.000 geldige, niet-constante waarden voor die uitkomst. Geen band uit alleen succesvolle trekkingen. Referentie 100 en constante verdelingen krijgen geen schijnband. Jaarbanden blijven puntgewijs, geen gelijktijdige band voor de hele reeks.

Controlepunten 500, 1000, 1500, 2000. Numeriek stabiel uitsluitend wanneer beide grenzen bij zowel 1000→1500 als 1500→2000 minder dan 0,1 procentpunt (periode) of indexpunt (jaar) én minder dan 5% van de actuele bandbreedte verschuiven. Criteria niet achteraf versoepelen. Onrust en nieuwe uitval blijven per uitkomst zichtbaar. Niet automatisch verder naar 5.000.

Geen formele 95%-vrijgave: CI-kolommen blijven leeg. Meer trekken bewijst geen intervaldekking, representativiteit of oplossing van methodebreuk. De lange begin/eindmaat en jaarlijkse beschrijvende percentages sinds 1958/1990 blijven ongewijzigd; hun marges worden niet uit deze periodebanden afgeleid.

## Afronding

Resultaten en beperkingen per 156 soorten; beide perioden en alle jaarposities met eigen beoordeelde/geldige aantallen, uitval, band- en stabiliteitsstatus, referentie en bronsteun. Controleer hergebruik en hashes, alle eerste 500 waarden en de nieuwe 1500 draw-ID's, tellingen en redenverdelingen. Leg nieuwe uitval en veranderingen ten opzichte van 500 vast. Werk runbook, besluiten, projectstatus en bronregister MD/DOCX bij; render en controleer Word. Eindcontrole door onafhankelijke reviewer. Commit/push taakbranch; geen merge of VPS-publicatie.
