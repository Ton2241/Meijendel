# Integrale lokale release- en herstelproef — 4 november 2026

Deze proef gebruikt uitsluitend de bestaande Meijendel-uitvoer over 1958–2025. De bootstrapinventaris bevat alle 156 soorten en 52 kavels. Er zijn geen nieuwe bootstrapmodellen geschat. Niets is op de VPS gelezen, geïnstalleerd of gepubliceerd.

## Afrondcriteria en wijzigingen

1. De presentatieroute leest beginjaar, eindjaar, bronhash en component-run uit gecontroleerde metadata. De vijfjaarsvensters volgen het gekozen eindjaar. Een verzoek voor 2026 met alleen gegevens tot en met 2025 wordt afgewezen; er volgt geen stille terugval naar 2025. De historische brugvensters blijven methodisch dezelfde vensters. De bestaande generatie- en deployscripts vragen nu een expliciet eindjaar of een release-manifest met dat eindjaar.
2. Website, dashboard en Shiny kunnen dezelfde diagnostische bootstrap automatisch tonen via één expliciet release-manifest, zonder de tijdelijke previewparameter. Zij controleren bron, jaargrenzen, inhoudshash en status. Een lokale proef blijft tot loopback beperkt. De productiemodus vraagt bovendien gevalideerde officiële gegevens. Een gewijzigde selectie krijgt geen opgeslagen band van een andere selectie. Een onbekende soort krijgt geen cijfers van de eerste soort.
3. `deploy/integral_release.py` bouwt en controleert een compleet onveranderlijk pakket en coördineert activering en herstel. Alle drie diensten stoppen vóór de gezamenlijke databaseback-up. Na beide databasewijzigingen wordt één versieaanwijzing omgezet. Alle diensten moeten daarna slagen. Bij een fout worden beide databases en de vorige versie hersteld. Mislukt ook herstel, dan blijven de diensten gestopt en krijgt het journal status `recovery_failed` met beide fouten.

Het pakket bevat websitecode, CMS-migraties en media, dashboardcode en gegevens/figuren, dezelfde bootstrap-HTML, Shiny-code en R-hulpfuncties, de volledige SQL-bron en de bijbehorende cache/manifests. Iedere inhoudelijke pakketfile heeft een SHA-256-controle. Symlinks en paden buiten het pakket zijn verboden. Er zijn geen wachtwoorden of CMS-databaseback-ups in het pakket.

## Werkelijke lokale omgeving

De native adapter `scripts/rehearse_integral_release.py` gebruikt een afzonderlijke MySQL-instance zonder netwerkpoort, met een eigen socket/datadir onder de proefmap, en een afzonderlijke PostgreSQL-database `vwg_release_20261104_2025`. De volledige bewaarde SQL-bron van 4.272.158.039 bytes is geïmporteerd. Zij bevat 157.580 territoriumregels tot en met 2025; na de vastgelegde kavelafbakening gebruikt Shiny 151.583 regels over 1958–2025. Dit zijn verschillende selecties, geen gegevensverlies.

De CMS-kopie komt uit de bestaande lokale websitekandidaat. De twee websitekoppeltabellen en zes websiteviews komen uit de reeds eerder met toestemming gelezen momentopname. Er zijn geen nieuwe VPS-lezingen gedaan. Voor de proef worden herkenbare testwaarden toegevoegd aan beide uitsluitend lokale proefdatabases. De gewone gebruikersdatabases blijven buiten de adapter.

De dashboardserver draait op loopbackpoort 18196, de echte website op 18197 en de echte Shiny-app op 18198. Dashboardbestanden krijgen versiegebonden URL’s. Website-iframes dragen de release-ID; een iframeverzoek voor een andere actieve release wordt geweigerd. Shiny neemt de gecontroleerde HTML binnen de eigen sessie op. Website- en dashboard-HTML moeten bytegelijk zijn aan de gedeelde payload. Ook de daadwerkelijk verpakte Shiny-hulpfuncties laden de cache en bootstrap tijdens de controle; alleen HTTP 200 op de Shiny-startpagina telt niet als gegevensproef.

De bewaarde parser13-cache is uitsluitend in deze herkenbare historische proef toegestaan, met controle van SQL- en cachehash. Zij wordt niet als parser15 voorgesteld. Normale productievalidatie blijft ongewijzigd. Bulkimports in de wegwerp-MySQL-instance mogen tijdelijk zonder redo-opbouw werken; de adapter schakelt redo vóór de dienstcontrole weer in. Dit is een functionele herstelproef, geen stroomuitval- of schijfcrashproef.

## Uitvoering en bewijs

De vorige kandidaat bevat de bestaande periodebeoordeling met 500 trekkingen; de volgende kandidaat bevat de uitbreiding van 141 perioden van 89 soorten naar 2.000 trekkingen. De andere 171 perioden behouden hun bestaande beoordeling met 500 trekkingen. Beide bevatten alle 156 soorten en dezelfde bestaande lange-maatuitvoer. De wetenschappelijke beperkingen staan in `trim/bootstrap/periods_2025_2000_20261104/README.md` en `PER_SOORT.md`; deze technische proef maakt geen diagnostische band tot een formeel 95%-interval.

De native proef controleert succesvolle volledige activering, een opzettelijke fout na de drie dienstcontroles, automatisch herstel en expliciet terugzetten naar de vorige release. Voor de bewuste fout worden echte proefwaarden in beide databases gewijzigd. Beide presentatieversies delen exact dezelfde wetenschappelijke SQL-bron; die bron hoeft voor deze deelwijzigingsfout niet opnieuw te worden geïmporteerd. Zo blijven versiegebonden CMS-migraties onveranderd. De gezamenlijke herstelroute zet vervolgens wel de volledige databases uit de gecontroleerde back-ups terug. Back-upbestanden worden vóór herstel op SHA-256 gecontroleerd. Na herstel worden alle MySQL-tabelchecksums en alle PostgreSQL-tabelaantallen/inhoudshashes met de back-up vergeleken. SQL-routines, events, triggers en views worden meegekopieerd. De twee concrete testwaarden moeten telkens bij de actieve versie horen.

Uitvoer en besloten back-ups blijven buiten Git onder `Meijendel/outputs/integrale-release-proef-20261104`. Publiceer de private map en CMS-back-ups nooit. Een compacte, niet-persoonsgebonden samenvatting staat in `rehearsal-proof.json` zodra de volledige oefening slaagt. Het actuele `journal.json` toont de fase en eventuele fout; een gestarte oefening is geen geslaagde oefening.

Status van de volledige praktijkproef: **GESLAAGD**. Basis `2025-A3` → volledige activering `2025-B3` → bewuste fout met gewijzigde waarden in beide databases → automatisch herstel `2025-B3` → expliciet volledig terugzetten `2025-A3`. Beide herstelde database-inhouden zijn gelijk aan hun eigen back-upfingerprints; de drie diensten en beide proefwaarden zijn na iedere herstelactie gecontroleerd. Redo staat na de import weer aan. De oorspronkelijke bron telt nog steeds 157.580 territoriumregels tot en met 2025; alleen de geïsoleerde instance is gebruikt.

Bewijsbestand `rehearsal-proof.json`, SHA-256 `057294a1bca7c59212941d112cc1e31b4808a32d5245191a23bea5f08edbcd70`. De gedeelde HTML-hash van kandidaat B3 is `e38bc54650e3b18ea24bd593c89b0cc955f0e2a1d05de481bac109513842adba`; A3 heeft een andere hash en is aantoonbaar als vorige presentatie teruggezet. De gewone lokale kandidaat/bewaarkopie blijft de nieuwste B-uitvoer bevatten en is bytegelijk aan die payload.

De browser heeft de versiegebonden B3-dashboardroute zonder previewparameter geopend en bij Dodaars het automatische gedeelde blok getoond. Een afzonderlijke browsercontrole bevestigt dat een onbekend soort-ID alleen een ontbrekende-uitkomstmelding toont. Shiny heeft zowel de werkelijk verpakte cache/bootstrap geladen als de bestaande modelvrije render-/afwijkende-selectieproef doorstaan. De laatste fixture geeft vier `min/max`-waarschuwingen voor haar bewust lege mock-jaarvector; zij betreft niet de werkelijk geladen 151.583 territoriumregels. De onafhankelijke eindreview is akkoord na herstel van stop-, start- en herstel-foutpaden.

Gerichte controles: tien Python-presentatiechecks; twaalf coördinator-/proceschecks en twee CLI-eindjaarchecks; JavaScript-contracten voor selectie, nulwaarden en actieve release; R-check voor releasebron/jaargrens en historische-cacheguard; expliciete afwijzing van ontbrekend eindjaar 2026 zonder modelberekening. Website: 1.038 tests geslaagd; de acht aanvankelijk overgeslagen financechecks zijn daarna via de eigen geïsoleerde runner geslaagd. Ook de afzonderlijke twee-loginproef slaagt zonder mail en zonder achterblijvende testdatabase.

## Herhalen op deze reeds ingerichte lokale proefomgeving

```sh
python3 deploy/integral_release.py build --recipe /absoluut/recipe.json --target /absoluut/proef/releases/nieuwe-versie
python3 deploy/integral_release.py verify /absoluut/proef/releases/nieuwe-versie
python3 scripts/rehearse_integral_release.py exercise --root /absoluut/proef --website-root /absoluut/VWG_M-worktree --candidate /absoluut/proef/releases/nieuwe-versie
```

`exercise` vraagt een bestaande andere basisrelease en een draaiende geïsoleerde MySQL-instance. Het is geen installatieprogramma voor de VPS. `activate`, `rollback`, `check` en `stop` zijn ook afzonderlijk beschikbaar. `exercise-recovery` vervolgt alleen een aantoonbaar geslaagde, vastgelegde activering; zij herhaalt de gegevensimport niet. De PostgreSQL-naam moet met `vwg_release_` beginnen en de MySQL-datadir moet exact de private proefdatadir zijn. Bewaar de herstelbronnen tot retentie afzonderlijk is beoordeeld.

## Wat nog op officiële 2026-gegevens wacht

- Ontvangst en inhoudelijke validatie van de officiële 2026-levering, inclusief onderscheid nul versus ontbrekend en de vastgelegde kavel-/soortselectie.
- Een nieuwe gecontroleerde SQL-export, actuele productiecache, dashboardgegevens, jaarindices, perioden, trends, groepsfiguren en bootstrapuitvoer met de werkelijke gegevensgrens 2026. Bestaande trekkingen worden waar methodisch geldig hergebruikt; 2025-uitvoer wordt nooit hernoemd tot 2026.
- Beoordeling per soort/per schatter van uitval en numerieke stabiliteit, en een afzonderlijk besluit welke betrouwbaarheidsmarges formeel mogen worden getoond. Alle soorten blijven zichtbaar, ook zonder schatbare marge.
- De concrete CMS-teksten, jaartallen, percentages en figuren uit de bestaande paginamatrix bijwerken met de officiële uitkomsten; daarna dezelfde bron/jaar-/selectiecontrole in alle drie presentaties.

## Grens van de lokale proef en toekomstige VPS-gang

Native macOS is geen test van de Linux-Dockerimages, Caddy, systemd of de gesloten VPS-gateway. De bestaande productieprocedure blijft leidend: beide repositorywijzigingen eerst op schone actuele `main`, ancestry- en commitcontrole, één globale productielock, één expliciet publicatieakkoord en gezamenlijke nacontrole. Er is in deze taak geen nieuwe productiehostadapter geïnstalleerd of beproefd. De lokale adapter mag niet rechtstreeks als VPS-deployscript worden gebruikt.

Voor een daadwerkelijke eenmalige VPS-actualisering moet de bestaande gesloten gateway de gezamenlijke coördinator met de echte Linux-service- en databasehandelingen verbinden. Daarbij worden de op dat moment geldende twee koppeltabellen en zes views uit de productieback-up behouden; de lokale momentopname mag ze niet overschrijven. CMS-inhoud wordt met beoordeelde versiegebonden migraties bijgewerkt; een lokale volledige CMS-kopie mag nooit de productieledenadministratie vervangen. Het herstel gebruikt de complete back-up van vóór de gezamenlijke wijziging. Caddy-authenticatie en bestaande absolute upload-/secretpaden blijven behouden. De installatie, container-/HTTP-proef en die gatewaykoppeling zijn een afzonderlijke technische productiestap vóór vrijgave; zij hangen niet inhoudelijk van nieuwe 2026-tellingen af.

Daarom betekent een groene lokale proef: de gedeelde uitvoer, actieve lezers en herstelcoördinatie zijn lokaal bewezen. Zij betekent nog niet dat één productieopdracht op de VPS al uitvoerbaar of goedgekeurd is.
