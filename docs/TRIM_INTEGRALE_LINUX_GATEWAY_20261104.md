# Integrale Linux/VPS-gateway — 4 november 2026

Status: code, isolatie en herstelroute lokaal getest en onafhankelijk beoordeeld. De technische installatie en werkelijke Linux-proef zijn nog niet uitgevoerd. Dit document wordt na die uitvoering met het concrete bewijs aangevuld. De eerdere native proef staat in `TRIM_INTEGRALE_RELEASE_HERSTELPROEF_20261104.md`.

## Afgesproken proef

Gebruik de bestaande uitvoer voor alle 156 soorten over 1958–2025. Geen nieuwe modeltrekkingen en geen officiële 2026-publicatie. Hergebruik de actieve MySQL- en Shiny-images op de VPS. Maak uitsluitend eigen proefcontainers, interne Docker-netwerknaam, PostgreSQL-kopie en loopbackdiensten. De normale website, dashboard- en Shiny-processen blijven actief. Controleer hun containeridentiteit, starttijd, restarttellingen, Caddy-configuratie en beide productiecommits vóór en na de proef.

De vorige presentatie bevat de bewaarde 500-periodebeoordeling; de kandidaat de uitbreiding van 141 perioden van 89 soorten naar 2.000 trekkingen. De andere 171 perioden behouden 500. Alle 156 soorten blijven zichtbaar, inclusief ontbrekende schattingen en beperkingen. Dit geeft geen nieuwe formele intervalvrijgave.

## Aansluiting en veiligheidsgrenzen

`deploy/integral_gateway_client.py` bouwt één pakket uit drie schone, gepushte mainbronnen. Het controleert broncommits en SHA-256 vóór overdracht. De bestaande duurzame gatewayjob wordt gebruikt: één operatie-ID, hervatbaar na een verbroken verbinding, geen tweede stille import.

De gesloten actie `meijendel-integral` accepteert alleen vaste fasen, een volledige commit en een SHA-256. De geïnstalleerde rootadapter bevriest het gecontroleerde pakket onder `/var/lib/vwgm-integral`. Archieven met links, bijzondere bestanden of ontsnappende paden worden geweigerd. Gebruikerspakketten leveren geen rootcode of uitvoercommando's. CMS-migraties vereisen de exacte bestandsnaam én hash uit de tijdens technische installatie goedgekeurde rootcatalogus. Er worden geen nieuwe PostgreSQL-rollen of productiegrants aangelegd.

De acht websiteobjecten en eventueel `vogelstand_1924` worden bij activering uit de dan actuele databaseback-up teruggenomen. De lokale fixture overschrijft deze niet. Codepakketten bevatten geen veranderlijke `app/data` of uploads. Deze krijgen expliciete runtimepaden; de proef gebruikt private kopieën en uitgeschakelde mail. De herstelset bevat beide volledige databases, appbestanden en de betrokken hostconfiguratie; inhoudsvingerafdrukken worden gecontroleerd. Timers worden pas na geslaagd herstel hervat.

De technische gatewayinstallatie omvat de rootcoördinator, Linux-adapter, migratiecatalogus en bijbehorende back-up/herstelhulpen. De back-upservice krijgt een nieuwe uitvoerroute, zonder start of herstart. Bestaande gatewayacties blijven beschikbaar. Installatie gebruikt de bestaande hashgebonden installer met exact herstel bij een installatiefout. De echte sudo-prompt hoort uitsluitend in het standaard macOS Terminal-venster.

## Bewijscriteria

1. Werkelijke start en HTTP-controle van website, dashboard en Shiny; website en dashboard leveren dezelfde bootstrapbytes. Vier soortpagina's zijn aangesloten. Shiny laadt de werkelijke R-cache en bootstrap; een losse HTTP 200 telt niet als gegevensproef.
2. Afgeschermde Caddy-proef weigert ongeautoriseerde dashboard-, SQL-, Shiny- en versiegebonden uitvoerrequests.
3. Volledige activering A naar B; daarna een opzettelijke fout na wijzigingen in beide proefdatabases en appbestanden. Automatisch volledig herstel naar B, vervolgens expliciet herstel naar A. Vergelijk inhoudsvingerafdrukken.
4. Productie-identiteit vóór/na exact gelijk. Verwijder na groen bewijs uitsluitend eigen proefcontainers, database, netwerk, diensten en proefdata. Bewaar onafhankelijk JSON-bewijs lokaal en onder de rootbewijslocatie.

## Lokaal al gecontroleerd

26 coördinator-, Linux- en clienttests; gatewayjobmocks; hashgebonden installermocks met vijftien vaste bestanden. Website: volledige suite eerder in deze wijziging 1.040 tests plus acht financechecks en de afzonderlijke twee-loginproef, zonder skips. Na de herstelwijzigingen opnieuw 85 gerichte back-up-, gateway- en presentatietests. Onafhankelijke eindreview: de drie gevonden herstelproblemen zijn verholpen; geen resterende belangrijke bevinding. Dit vervangt de nog uit te voeren Linux-proef niet.

## Wat op 2026 wacht

Officiële levering en inhoudelijke validatie; export en cache met de echte jaargrens 2026; actualisering van dashboard, figuren, soort-/periode-/jaarindexuitvoer en bootstrap; beoordeling per schatter welke marges vrijgegeven worden; concrete CMS-migraties volgens de paginamatrix. Daarna pakketcontrole en een afzonderlijk expliciet publicatieakkoord. Historische 2025-uitvoer wordt nooit hernoemd tot 2026. Alle drie afnemers gebruiken dezelfde bron, periode, selectie en payload.
