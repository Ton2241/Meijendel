# Integrale Linux/VPS-gateway — 4 november 2026

Status op 10 november 2026: de technische gateway en gecorrigeerde Linux-adapter zijn geïnstalleerd. De volledige geïsoleerde Linux-proef is geslaagd: activering, bewuste fout, automatisch herstel en expliciet terugzetten, inclusief beide databases, appbestanden, website, dashboard, Shiny en Caddy-toegangsbeveiliging. De eigen proefobjecten zijn opgeruimd; de onafhankelijke productiecontrole is groen. Geen website- of onderzoeksuitkomsten gepubliceerd. De onderstaande eerdere afbrekingen en correcties zijn historische uitvoeringsstappen.

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

## Eerste Linux-uitvoering en gericht herstel — 10 november 2026

De bundel op T7 `integrale-linux-gateway-20261110` gebruikt de bestaande 156 soorten over 1958–2025. Payload-SHA-256: `dfa9c3491e7b5080f9fabb8317a5da5bd06274b8e6a769a9ef26e901279c4556`; broncommits Meijendel `796ede5b`, VWG_M `db943c58`, VWG_Project `5cd9b7f3`. De gebruiker startte de zichtbare Terminal-opdracht. De hashgebonden gatewayinstallatie en preflight slaagden. De volledige proefinvoer doorliep MySQL en PostgreSQL; het proces bereikte de start van de basisdiensten. De Shiny-proefcontainer faalde met Docker125/OCI128: het geneste mountpoint `app_cache` ontbrak in de reeds alleen-lezen gekoppelde appmap. Dit was geen geslaagde activerings- of herstelproef.

De productiewebsite en Caddy bleven actief. Productie-MySQL en productie-Shiny bleven draaien; beide productiecommits bleven exact gelijk aan de preflight (`9da16f606a6fbc58763e83f708f03cd544b73b61` en `b54b7b741326ca9ea1e5789f3a3ded75f6a71b9b`). De foutuitvoer staat op T7 in `outputs/shiny-startdiagnose.log`; de proefobjecten zijn voor diagnose behouden.

De fix maakt uitsluitend de lege cachemountmap vooraf aan; de gecontroleerde pakketbestanden veranderen niet en de app blijft alleen-lezen gekoppeld. Een tweede feitelijk vastgestelde blokkade is de niet bereikbare loopbackpoort33317 van de interne MySQL-proefcontainer (TCP-resultaat111). De proefwebsite krijgt daarom het gecontroleerde private adres van haar eigen gelabelde container binnen het eigen interne netwerk, met een werkelijke TCP-probe vóór de dienststart. Geen extra hostpoort wordt geopend.

Beginhervatting hergebruikt de reeds geladen proefdatabases uitsluitend bij een rootbeheerde marker/eigendomsregistratie, actieve basisrelease A, geen activeringsjournal, geldige pakketbytes/bron/jaren, beide databaseprobes op A, jaargrens2025 en appbestanden op A. Anders stopt de adapter; geen stille herimport of overschrijving. De historische payload en receipt blijven ongewijzigd. Alleen de technische rootadapter komt uit de nieuwe schone actuele mainbron. De bestaande begrensde jobrunner krijgt daarna dezelfde commit/pakkethash en een nieuw operatie-ID. Dit omzeilt geen pakketcontrole: de rootadapter verifieert de ongewijzigde verzegelde bron opnieuw; het hervattingsdossier legt de nieuwe runtimebron afzonderlijk vast.

Alle nieuwe lokale hulp-/log-/controlebestanden en TMPDIR blijven onder de geregistreerde T7-proefmap. Na geslaagde hervatting volgen dezelfde volledige Linux-activerings-/herstelcriteria en controle van productie-identiteit, en uitsluitend de eigen proefobjecten worden opgeruimd. Geen formele intervalvrijgave of 2026-publicatie.

Dezelfde interne netwerkbinding geldt consequent voor Shiny: de eigen container houdt zijn private netwerkadres; dienstcontrole en de afgeschermde Caddy-proefroute gebruiken datzelfde adres op3838. Hiervoor wordt evenmin een hostpoort geopend. De productiepoort3838 blijft ongewijzigd. Deze route volgt de gedocumenteerde hosttoegang tot interne Docker-brugnetwerken: https://docs.docker.com/reference/cli/docker/network/create/#network-internal-mode---internal .

## Tweede beginhervatting: Caddy-parser — 10 november 2026

De gebruiker installeerde de eerste runtimecorrectie uit main `d8c6d385` via de zichtbare Terminal-opdracht. De geïnstalleerde rootmodules kwamen exact overeen met de vastgelegde hashes. De begincontrole hergebruikte de bestaande proefdatabases. Website, dashboard, gedeelde bootstrapbytes, vier soortpagina's en de echte R-cache/bootstrapcontrole in Shiny doorliepen hun controles. De resterende afbreking was de Caddy-proefpoort18199 (connection refused), dus nog vóór de eerste volledige basis-health en vóór activering/herstel. Productie-Caddy en website bleven actief.

De echte Caddy-parser wees regel8 af: `Unexpected next token after '{' on same line`. De generator had de nieuwe `forward_auth`-sectie op één regel gezet. De fix gebruikt dezelfde meerregelige blokvorm als de bestaande geldige secties, voert voortaan `caddy adapt` uit vóór de start van de proefdienst en geeft een parsefout leesbaar door via de gatewaylog. De gereedheidscontrole omvat nu ook Caddy; er volgt geen autorisatiecheck voordat die dienst gereed is.

De gecorrigeerde configuratie is via stdin door de daadwerkelijke Caddy-parser op de VPS geaccepteerd (exit0); daarbij zijn geen VPS-bestanden gewijzigd en geen diensten gestart of herstart. De enige parserwaarschuwing betreft formattering, geen configuratiefout. Bewijs staat op T7 in `outputs/caddy-fix/parser-proof.json` en `parser-after.log`. Alle35 betrokken Pythonchecks, JavaScript-/gatewaycontracten en onafhankelijke review zijn groen. Installatie van deze tweede fix en volledige activerings-/herstelproef volgen nog. De eerdere foutlogs en oorspronkelijke payload/receipt blijven behouden.

## Eindresultaat: volledige Linux-proef geslaagd

De laatste begrensde gatewayoperatie `eb2cc17ec6031a8389f4bd68c7e668a4` is volledig groen. De oorspronkelijke beginimport is aantoonbaar hergebruikt. De onveranderde payload gebruikt de gecontroleerde inventaris van 156 soorten, 312 perioderegels en 10.608 jaarposities over 1958–2025, inclusief de vastgelegde ontbrekende schattingen en uitval. Dit soortenaantal komt uit `LOKALE_CONTROLE.json`; bronhash en pakkethash koppelen die lokale controle exact aan het Linux-bewijs. Er zijn geen modellen opnieuw geschat of marges formeel vrijgegeven.

- Activering A naar B: `active`, alle drie diensten, werkelijke Shiny-cache/bootstrap en Caddy-auth groen. Website en dashboard leveren dezelfde B-bootstrapbytes.
- Opzettelijke fout na echte wijzigingen in beide proefdatabases en appbestanden: `restored` naar B met de bedoelde foutmelding; alle diensten en gegevenscontroles opnieuw groen.
- Expliciet terugzetten naar A: `rolled_back`; beide databases en veranderlijke appbestanden zijn gelijk aan de back-ups; alle diensten en de oorspronkelijke A-bootstrap opnieuw groen. De aparte A- en B-HTML-hashes zijn behouden in het bewijs.
- Productie-identiteit vóór/na exact gelijk: beide container-ID's/images, starttijden en restarttellingen, Caddy-configuratiehash en beide productiecommitbestanden. De werkelijke website- en gegevensrelease is niet omgezet.

Bewijs op T7: `outputs/runtime-resume-caddy/linux-proof.json`, `status.json`, `cleanup.log`, `production-smoke.log`, `vps-final-inventory.log`, `own-database-cleanup.log` en `backup-status.log`. De aparte onafhankelijke bewijsreview bevestigt alle booleans, fasen en de beperkte scope van deze conclusie. Root-runtimebron: Meijendel `f1e87a48a9e8b5269edf36a3919d90e79181a7d2`; broncommits en werkelijke modulehashes staan afzonderlijk in `installed-runtime.json`. De oudere foutlogs en gehashte helpersnapshot blijven behouden.

Cleanupoperatie `20e63f0e4c9b47df29a0aba97467d42b` is groen: eigen containers, netwerk, PostgreSQL-kopie, diensten, datamappen, proefback-ups, verzegelde serverkopie en inboxarchief zijn verwijderd. Onafhankelijke cataloguscontrole telt nul exemplaren van de eigen PostgreSQL-proefdatabase. De VPS toont alleen de twee productiecontainers en twee bestaande images, nul gatewayjobs, een vrij productieslot en circa41GiB vrije ruimte. Bestaande Dockerbuildcache en door de installer gemaakte herstelsets zijn behouden; er is geen prune uitgevoerd. Het T7-bronpakket en alle controle-/herstelbewijzen blijven bewaard.

De volledige bestaande rooktest voor www.vwg-m.nl, app.vwg-m.nl en vwg-m.nl is groen, inclusief Caddy/MySQL-isolatie en de gedeployde productieconfiguratie. De normale back-uptimer is actief; de laatst beschikbare reguliere back-up van10november01:30 slaagde, inclusief het tijdelijke MySQL-proefherstel. Die back-up dateert van vóór deze technische installatie. Een extra volledige hostback-up is niet gestart; opname van de nieuwe technische modules volgt via de bijgewerkte normale back-upketen. Voor de onveranderde exacte image-ID's is het bestaande geregistreerde scanbewijs hergebruikt.

### Beperkingen en resterende 2026-poorten

Dit bewijst de volledige gezamenlijke activerings- en herstelcoördinatie op echte Linux-databases en diensten binnen de afgeschermde proefomgeving. Het is geen daadwerkelijke omschakeling van de publieke productie-units en geen nieuwe kale-VPS-herstelproef. Het historische bronbestand van4.272.158.039bytes en de gecontroleerde parser13-cache dienen uitsluitend deze herkenbare1958–2025-proef. De productieroute weigert die historische proefcache.

Nog nodig voor een inhoudelijke2026-release: officiële bronvalidatie, actuele gecontroleerde SQL-export en productiecache, opnieuw samengestelde index-/periode-/trend-/groep-/bootstrapproducten met de echte2026-jaargrens en dan geldende selectie, beoordeling en vrijgave per schatter, CMS-teksten/figuren uit de paginamatrix en expliciet publicatieakkoord. Gebruik daarvoor een nieuwe bundel uit schone actuele mainversies. De afgeronde proef- en hervattingsopdrachten niet opnieuw uitvoeren.
