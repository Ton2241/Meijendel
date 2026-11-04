# Lokale aansluiting bootstrap

4 november 2026. Uitvoering van de goedgekeurde presentatiematrix.

## Keuze en afrondcriteria

Eén gegenereerd, zelfstandig HTML-blok voor website, dashboard en Shiny. De code en gegevens blijven in Meijendel. VWG_M serveert uitsluitend het aangewezen bestand. Zo blijven de indexwaarden, schaal, kleur, legenda, tabellen en downloads identiek. De eigen periode-indices komen in afzonderlijke grafieken omdat ieder model zijn eigen referentiejaar heeft. Zij worden niet over de gebrugde index of de dichtheid getekend.

De bestaande 156 soorten, 312 perioden en 10.608 jaarposities over 1958–2025 blijven zichtbaar. Netto begin/eindverandering en jaarlijkse formele TRIM-trend krijgen afzonderlijke labels. Iedere rij behoudt aantallen, status, reden, vensters, bronsteun en stabiliteit. Geen diagnostische band bij uitval, constante verdeling of referentie 100. Onbekende jaren blijven gaten, nulindices blijven nul. Downloads bevatten alle oorspronkelijke velden.

Een expliciete lokale preview-instelling activeert de diagnostische kandidaat. De website accepteert deze uitsluitend vanaf loopback. Een eigen Shiny-selectie neemt het blok niet over. De productieactivering van formele 2026-intervallen blijft geblokkeerd totdat de schattergebonden vrijgave is vastgesteld en getoetst. Dit werk verricht geen nieuwe bootstrapberekeningen.

## Uitvoeringsplan

1. Schrijf een contracttest voor de volledige bestaande uitvoer, uitval, referentie, constante verdeling en ontbrekende waarden. Laat deze falen vóór implementatie.
2. Bouw de gedeelde presentatie en bronmanifest met SHA-256 van de drie invoerbestanden en de modelselectie. Verifieer aantallen en rij-identiteiten vóór generatie.
3. Koppel het blok aan soortdetails, dashboard en Shiny. Toets ontbrekend bestand, lokale preview en selectieblokkade.
4. Maak een afzonderlijke lokale CMS-kopie. Pas bestaande migraties 167 en 174 toe en controleer effectieve tekst, afbeeldingen en figuren. Behoud historische analysevensters.
5. Controleer gerichte contracten en routes, bekijk de gedeelde grafieken en leg bevindingen en resterend werk vast.

Geen nieuwe ecologische identiteit of bronstructuur. De oorspronkelijke `soort_id` met broncontext blijft sleutel, soortnaam uitsluitend label. Dit is presentatie van bestaande modeluitvoer. Bronregister en brondata veranderen niet.

## Uitgevoerd en gecontroleerd

De generator `scripts/build_trim_bootstrap_presentation.py` leest de drie beoordeelde CSV’s. Hij controleert unieke soort-, periode- en jaarposities, de volledige inventaris en de voorwaarden voor iedere diagnostische band. Het bronmanifest koppelt de presentatie aan bestandscontrolesommen, oudermanifest, modelcontext, bronhash, cachehash en de oorspronkelijke 52 kavels. `R/export_trim_bootstrap_selection.R` leest hiervoor de opgeslagen modelcontext met hashcontrole. Er worden geen modellen geschat.

De lokale uitvoer staat onder `outputs/bootstrap-presentatie-2026/`, met `bootstrap.html` en `manifest.json`. Een bewaarkopie van de gegenereerde kandidaat staat in `/Users/ton/Documents/GitHub/Meijendel/outputs/bootstrap-presentatie-2026/`.

De code weigert formele CI-waarden in deze diagnostische route. Het bestand wordt op de website bytegelijk geserveerd. Dashboard en Shiny gebruiken hetzelfde HTML-blok. Shiny voegt uitsluitend het soortnummer aan de beginselectie toe. Een gewijzigde bronhash, kavelpopulatie, soortpopulatie of jaargrens blokkeert het blok. De bestaande formele laadroute is aangescherpt zodat alleen rijen met expliciet `publiceerbaar` een formeel interval krijgen.

De schermproef omvatte Dodaars, Stormmeeuw, Tapuit en Bijeneter. Dodaars toont beide perioden. Stormmeeuw toont 1.999/2.000 en geen lange band. Tapuit toont de waarschuwing over bronsteun. De afgeronde ondergrens wordt bij een waarde boven −100% als `> −100%` weergegeven. Bijeneter blijft zichtbaar met beide onbeschikbare perioden. Geen JavaScriptfouten tijdens deze proef. Downloads behouden alle oorspronkelijke velden. De browserdownload voor Dodaars is gecontroleerd op 68 jaren over 1958–2025 en lege formele CI-kolommen. De grafiek splitst op ontbrekende jaren en ontbrekende banden en tekent nulindices op nul.

Controles op 4 november 2026

- Drie Pythoncontracttests voor inventaris, bandvoorwaarden en ontbrekende waarden geslaagd.
- JavaScriptcontroles voor gaten, nul, referentie, uitval, CSV en dashboardkoppeling geslaagd.
- R-selectiecontrole en Shiny `testServer` met passende en afwijkende selectie geslaagd. De beperkte testfixture zonder telbasis veroorzaakt waarschuwingen bij de bestaande jaarkeuzeberekening. Er zijn geen nieuwe modelfits uitgevoerd.
- Bestaande onzekerheids-, dashboardpresentatie- en releasecontracten geslaagd.
- Dashboard/website-CSV-pariteit geslaagd met 33 grafiekcodes, 2.244 dichtheidsregels, 2.977 GAM-regels en 1.105 soortregels. De 32 codes die de website gebruikt zijn een deelverzameling hiervan.
- VWG_M volledige testuitvoer geslaagd met 1.035 tests en acht financiële integratietests, nul skips. De twee-loginintegratie slaagde zonder verzonden mail en met teruggedraaide testgegevens.

## CMS-kandidaat en concrete beperkingen

VWG_M gebruikt branch `codex/bootstrap-presentatie-2026`, gebaseerd op `7bc1562`. De lokale PostgreSQL-kandidaat `vwg_bootstrap_2026_candidate` is een kopie van `vwg_linux_port_test`. Daarin zijn de bestaande migraties 167 en 174 toegepast. De effectieve begrazingstekst verwijst naar de aanwezige habitatfoto en bevat de juiste beeldverantwoording. Paradox open duin bevat de bestaande Meervleermuispassage en bijbehorende correcties. Beide routes antwoorden lokaal met HTTP 200. De historische analysevensters zijn behouden.

De gekopieerde database miste de tabel `app.species_external_observations`. Voor de soortpagina-proef is migratie 156 uitsluitend op de kandidaatkopie toegepast. De oorspronkelijke testdatabase is niet gewijzigd. Dit maakt de kandidaat geen volledige actuele kopie van productie. CMS en uploads van de gekozen releasebasis blijven bij de eindproef te vergelijken.

Bebouwing en Overige situaties gebruiken dezelfde broncategorie `Vogels van bebouwing/overige`, code 900. De lokale kandidaat vermeldt dat bij beide pagina’s. De routes antwoorden met HTTP 200. Er zijn geen afzonderlijke reeksen verzonnen.

Drie archieffoto’s in het meeuwenverhaal ontbreken ook na controle van genegeerde lokale bestanden. Het betreft albums 7, 10 en 19 met respectievelijk `Nest Gr. kl. mantelmeeuw.jpg`, `Mantelmeeuw.jpg` en `05_Vos_kavel_7.jpg`. De lokale routes naar die bestanden blijven 404. De actuele uploadkopie van de uiteindelijke releasebasis is daarvoor nog nodig. Het bestaande verhaal en de bijschriften blijven behouden.

De standaard Python-MySQL-connector kan met de beschikbare lokale configuratie niet aanmelden. De bestaande beveiligde MySQL-loginroute werkt wel. De lokale leesproef gebruikt daarom een tijdelijke adapter met uitsluitend leestransacties. Daarmee geeft het meeuwenverhaal HTTP 200 en een dynamische SVG. Dit bewijst de gewone Python-connector niet.

De volledige soortdetailroute blijft bovendien geblokkeerd doordat `Meijendel.website_species_mapping` in de actuele lokale analytische database ontbreekt. De bestaande websitequery vraagt deze tabel. De bootstrapkoppeling zelf is met een gecontroleerde mappingfixture en via de zelfstandige website-previewroute getest. Er is geen naamkoppeling als vervanging ingevoerd en geen analytische tabel aangemaakt. Dit verschil tussen de huidige database en het bestaande websitecontract vraagt herstel of een gecontroleerde overgang voordat een integrale release mogelijk is.

De dashboardbrowserdataset is niet lokaal beschikbaar. De dashboardkoppeling is als component getest, de volledige browserroute nog niet. De Shiny/dashboard-pariteitsaanroep stopt in deze worktree door het ontbrekende `meijendel.sql`-pad. De canonieke export is van 8 oktober 2026 en circa 4,27 GB. Deze export is in deze taak niet opnieuw geparseerd of als actuele database-afspiegeling aangemerkt. De nieuwe gevalideerde dump/cache en browserdataset blijven onderdeel van de releaseketen na officiële levering.

Het projectbrede preflight stopt op het reeds bestaande verschil tussen `VWG_Project/main` en `origin/main`. Dat verschil is niet aangepast.

## Lokaal bekijken en opnieuw maken

Genereer de selectie en presentatie vanuit de opgeslagen bron, zonder nieuwe berekening

```sh
Rscript R/export_trim_bootstrap_selection.R \
  /Users/ton/Documents/GitHub/Meijendel/outputs/trim-2025-validation-500-20261103/input \
  /tmp/bootstrap-selection.json
python3 scripts/build_trim_bootstrap_presentation.py \
  --source trim/bootstrap/species_2025_2000_20261103 \
  --parent-manifest /Users/ton/Documents/GitHub/Meijendel/outputs/trim-2025-validation-500-20261103/input/bundle_manifest.json \
  --selection /tmp/bootstrap-selection.json \
  --output outputs/bootstrap-presentatie-2026
```

De zelfstandige HTML werkt ook rechtstreeks vanaf schijf. Voor de dashboardproef staat `?bootstrapPreview=1` expliciet in de URL. De website en Shiny vragen `MEIJENDEL_BOOTSTRAP_PREVIEW=1` en `MEIJENDEL_BOOTSTRAP_PRESENTATION` met het absolute pad naar de uitvoermap. De website accepteert deze route uitsluitend via loopback. Start een lokale webserver met binding aan `127.0.0.1`. De release op de VPS activeert deze proef niet.

De publieke leden- en gebruikershandleidingen beschrijven formele productie-uitvoer. Deze diagnostische lokale proef verandert die uitleg niet. De technische beheerhandleiding van VWG_M bevat de preview-instellingen en beperkingen.

## Wat nog wacht op de release

De aansluiting van de bestaande 2025-proef is gemaakt. Voor formele 2026-uitvoer blijven de schattergebonden vrijgaveregels en het overeenkomstige productiecontract vast te stellen. De bestaande jaarlijkse trendvelden zijn geen opslagplaats voor de nieuwe netto begin/eindmaat. Een groepsinterval vraagt eigen groepsuitvoer. Daarna volgen officiële bronvalidatie, een goedgekeurde verse dump/cache, herberekening, volledige pariteits- en schermproeven, de definitieve CMS-/uploadvergelijking en expliciete VPS-publicatiegoedkeuring. De ontbrekende websitekoppeltabel en drie lokale archieffoto’s staan vóór die integrale proef open.

## Vervolg 4 november 2026

Ton heeft expliciet ingestemd met een afzonderlijke lokale MySQL-proefdatabase, een tijdelijk SELECT-account en uitsluitend het uitlezen van de twee websitekoppeltabellen, zes websiteviews en drie meeuwenfoto’s op de VPS. De eerste automatische goedkeuringscontrole blokkeerde de lokale database-/accountaanmaak omdat expliciet akkoord ontbrak. Vóór dit akkoord was niets aangemaakt.

De eerdere omschrijving van de ontbrekende koppeltabel als mogelijk databasedefect wordt gecorrigeerd. `docs/database/TAXONREGISTER.md` noemt deze tabellen en views productie-eigen objecten. Zij horen buiten de analytische lokale database te blijven. De bestaande productie-export van 20 september 2026 bevat deze objecten. Voor een definitieve lokale kandidaat wordt de expliciet toegestane actuele productieversie gelezen en in een afzonderlijke proefdatabase gebruikt.

De bewaarde cache met parser 13, bronhash `15de9245b0d0fbbd0a65990c6c0d618ff8f0298f712775210fe0b1566a917913` en cachehash `071e66821f706ae1c0c37b11b3295ddde84a1872b194f9a09f43e595b50252d8` bevat de bron van de bootstrap. Die cache kan zonder nieuwe dump of cacheopbouw voor een bevroren controle worden gebruikt. De toenmalige browsergenerator uit commit `9417636e08ce127d7de583fc35ea730ffae0fbee` heeft daaruit een afzonderlijke browserdataset gemaakt. Deze proefset bevat de gegevens tot en met 2025 en blijft een historische reviewbron. Zij vervangt niet de verse, gevalideerde 2026-releasebron.

### Afgeronde lokale vervolgcontrole

De VPS-leesopdracht is via het standaard macOS Terminal-venster geslaagd. De export bevat uitsluitend de twee afgesproken koppeltabellen en zes views. Zij is 88.015 bytes, gedateerd 4 november 2026 en heeft SHA-256 `6633baff77ebeb45a2db14b735e97b57ad546c342ba5f840c2cb4fec5b1743f9`. De drie foto’s zijn eveneens uitsluitend gelezen. Er is niets op de VPS gewijzigd.

De afzonderlijke MySQL-kandidaat gebruikt de actuele productieobjecten. Zij bevat 381 soortmappingrijen, waarvan 320 voor publieke koppeling zijn geaccepteerd, en 69 kavelmappingrijen. De 320 geaccepteerde soort-ID’s zijn alle in de lokale soortentabel en via het centrale taxonregister bereikbaar. Er is geen soort- of kavelkoppeling op basis van een nieuwe naamsvergelijking gemaakt. De analytische database is niet gewijzigd. De overige brongegevens worden via uitsluitend-lezen-views uit de lokale analytische database gelezen.

Het bestaande PyMySQL-programma werkt hiermee zonder tijdelijke queryadapter. Het tijdelijke testaccount heeft uitsluitend SELECT op de kandidaatdatabase. Een rechtstreekse poging om daarmee de analytische taxonkoppeltabel te lezen werd geweigerd. De privéconfiguratie staat buiten Git in een bestand met modus 0600. Het testaccount wordt na de proef gesloten.

De vier volledige soortpagina’s voor Dodaars, Stormmeeuw, Tapuit en Bijeneter antwoorden met HTTP 200 en verwijzen naar het juiste Meijendel-soortnummer in het bootstrapblok. Ook de drie gecontroleerde verhaalroutes geven HTTP 200. De drie eerder ontbrekende archieffoto’s geven nu HTTP 200 en laden zichtbaar in de browser, elk met een natuurlijke breedte van 577 pixels. Foto’s, captions en bestaande credits zijn inhoudelijk behouden.

De actuele productie-koppeltabel bevat bij één van de 320 geaccepteerde koppelingen een ander opgeslagen EURING-veld dan de huidige lokale soortentabel. Het betreft Witvleugelstern, Meijendel-soort-ID 114, met respectievelijk 6060 en 6280. De soort-ID-koppeling is gelijk. Dit veld is geen sleutel voor de bootstrapaansluiting. De bronwaarden zijn behouden. Neem dit metadata-verschil mee bij de bronvergelijking van de definitieve release, zonder het als een ontbrekende of nieuwe soort te behandelen.

De bevroren Shiny/dashboard-pariteitscontrole over 1958–2025 is groen. Zij gebruikt 67 geselecteerde kavels uit de bestaande cache, waarvan 52 in 1958–2025 ten minste één geteld basisjaar hebben. Die 52 leveren de bootstrapclusters. Vergeleken zijn 1.224 ecologische en 1.628 functionele MSI-regels. De grootste absolute verschillen zijn respectievelijk `4,774847e-12` en `5,115908e-13`, dus uitsluitend numerieke afronding binnen de bestaande tolerantie. Eén bestaande lineaire samenvatting meldt een vrijwel perfecte fit. Dat verandert de geslaagde vergelijking van de MSI-waarden niet.

De browserproef gebruikt de 6.534.620 bytes grote dataset uit de oorspronkelijke parser-13-cache. De dataset heeft SHA-256 `71ab5d6ee0bb7e0fb64ee84a16be217ccc8709cc9664dfa60376af8efb65c991`. Er is geen nieuwe dump of Shiny-cache gebouwd. De huidige dashboardcode leest deze afgebakende proefset. Recente beheer-/toegankelijkheidstabellen die niet in parser 13 stonden zijn hiermee niet gevalideerd.

Tijdens deze volledige schermproef kwamen twee fouten in de vorige aansluiting aan het licht. De bootstrappreview zocht eerst in een gedeeltelijk overzicht en verscheen daardoor niet voor iedere passende soort. Ook ontbraken soorten zonder trend in de TRIM-keuze. De lookup is hersteld en `soorten_modelstatus.csv` levert nu de complete inventaris van 156 soorten over 1958–2025. Een soort zonder model krijgt daarmee wel haar status en het diagnostische overzicht. Er wordt geen index ingevuld. Dodaars en Bijeneter zijn met de echte dashboardroute gecontroleerd. Beide krijgen het juiste bootstrapblok. Geen JavaScriptfouten in deze controle.

De volledige VWG_M-testsuite slaagt nu met 1.036 tests en acht financiële integratietests, zonder skips. Ook de twee-logincontrole slaagt. De nieuwe snapshotselectie, de dashboardregressies en bestaande onzekerheids- en presentatiecontracten zijn groen.

De concrete technische blokkades uit de vorige afronding zijn hiermee lokaal opgelost. Het betreft de websitekoppelingen, gewone MySQL-connector, drie foto’s, de volledige dashboardroute en de Shiny/dashboard-vergelijking voor de bewaarde bron tot en met 2025. Voor de 2026-release blijven de officiële validatie, verse bronproducten, herberekeningen, formele vrijgaveregels en eindcontrole op die nieuwe bron gelden. Deze historische proef promoveert geen diagnostische marges tot formele 95%-intervallen.

De MySQL-proefdatabase met de actuele websiteobjecten blijft herkenbaar als lokale testbasis in het privé-runtimebestand en `provenance.json` onder `outputs/bootstrap-presentatie-2026/website-kandidaat-actueel/`. Beoordeel haar bij de definitieve releaseproef. Bij vervanging door een nieuwe kandidaat kan zij na controle van haar acht gekopieerde objecten en uitsluitend-lezen-bronviews worden verwijderd. De automatische goedkeuringscontrole heeft het verwijderen van de voorafgaande kandidaat uit september geweigerd, omdat de verleende toestemming niet expliciet het verwijderen van die database omvatte. Deze eerdere proefdatabase blijft daarom inactief bewaard. Beide tijdelijke testaccounts zijn aantoonbaar verwijderd en hun wachtwoorden zijn uit de runtimebestanden gehaald. Bronexporten en herkomstbestanden blijven bewaard.
