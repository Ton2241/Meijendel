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
