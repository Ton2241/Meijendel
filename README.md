# Meijendel
> Zie voor de overkoepelende projectarchitectuur, ontwikkelworkflow en projectbrede ontwerpkeuzes ook de repository **VWG\_Project**.

Deze repository bevat de database en analysemiddelen voor de vogelgegevens van Meijendel.

## Projectanker voor nieuwe Codex-draden

Lees bij vervolgwerk eerst deze vijf bestanden:

- `README.md`: ingang voor de Meijendel-repo en actuele projectcontext.
- `ARCHITECTURE.md`: samenhang tussen Meijendel, dashboard, Shiny, FastAPI/Jinja-app, VPS en databases.
- `docs/vps_productie.md`: actuele VPS-componenten, softwareversies,
  MySQL-/Shiny-paden en Docker-retentie.
- `STATUS.md`: actuele status, resterende risico's en aanbevolen vervolgstappen.
- `TODO.md`: openstaande punten en operationele aandachtspunten.
- `DECISIONS.md`: gemaakte keuzes die niet opnieuw moeten worden uitgevonden.

Belangrijkste werkpaden:

- Meijendel-bronproject: `/Users/ton/Documents/GitHub/Meijendel`
- FastAPI/Jinja-site: `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app`
- VPS-app-pad: `/srv/vwgm/vwg-m-linux-app`
- Canonieke SQL op VPS: `/srv/vwgm/data/Meijendel.sql`
- Canonieke gedeelde hostinventaris:
  `/Users/ton/Documents/GitHub/VWG_Project/VPS_PRODUCTIESTATUS.md`
- Publieke hoofdhost: `www.vwg-m.nl`.
- `app.vwg-m.nl` verwijst permanent met HTTP 308 naar hetzelfde pad op `www.vwg-m.nl`.

Werk bij nieuwe hoofdopdrachten vanuit een nieuwe draad, maar gebruik deze documenten als werkgeheugen. Start en eindig via `../VWG_Project/scripts/workspace_preflight.sh`; dit controleert vóór fetch of `.git` en gevolgde bestanden werkelijk lokaal beschikbaar zijn. Inspecteer daarna altijd de actuele code en `git status`; neem niet aan dat tijdelijke scripts uit `/private/tmp` nog bestaan. De vaste generatie- en deployscripts voeren dezelfde lokale controle zelf uit. Commit afgeronde wijzigingen standaard met een korte, beschrijvende commitmelding, tenzij expliciet is gevraagd om niet te committen. Als wordt gevraagd een wijziging voor `app.vwg-m.nl` of de VPS-site door te voeren, voer die wijziging zowel lokaal als op de VPS door en controleer de productiepagina of relevante smoke-test na deploy.

Codex start tests, R/Python-generatie en andere opdrachten die tijdelijke
bestanden of caches maken meteen in een lokale uitvoercontext met schrijfbare
macOS-tijdelijke mappen. Een voorafgaande proef in de beperkte sandbox is niet
nodig: `/var/folders/.../T`, `/tmp` en `/var/tmp` kunnen daar onschrijfbaar zijn
en zo een fout veroorzaken voordat de inhoudelijke controle begint. Gebruik
waar beschikbaar altijd het bestaande repositoriespecifieke controle- of
generatiescript.

## Waar begin je?

Als je de repo wilt begrijpen of ermee wilt gaan werken, begin dan in deze volgorde:

1. [`MDs/handboek.md`][1]
2. [`shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md`][2]
3. [`shiny_meijendel/CONTROLESET_html_shiny.md`][3]
4. [`shiny_meijendel/README_shiny_meijendel.md`][4]
5. [`MDs/README_bmp_meijendel_index.md`][5]

## Wat staat waar?

### Hoofdbestanden

- [`meijendel.sql`][6]
  De actuele SQL-dump van de database. De tabel `tellers` bevat daarin alleen `id` en de unieke `tellercode`; persoonsgegevens staan uitsluitend in de afgeschermde PostgreSQL-ledenadministratie.
- [`bmp_meijendel_index.html`][7]
  Standalone HTML voor overzicht, controle en presentatie.
- [`README.md`][8]
  Korte projectingang.

### Documentatie

Projectdocumentatie staat vooral in `MDs/`, met scriptspecifieke documentatie in `R/`.

Belangrijke bestanden zijn:

- [`MDs/handboek.md`][9]
  Doorlopend handboek voor gebruik van de database.
- [`shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md`][10]
  Korte werkwijze voor HTML en Shiny.
- [`shiny_meijendel/CONTROLESET_html_shiny.md`][11]
  Vaste controlelijst voor gebruik en wijzigingen.
- [`R/trim_soorten_en_msi_evg.md`][12]
  Uitleg van de hoofd-TRIM-analyse.
- [`R/trim_sandra_soorten_en_msi_evg.md`][13]
  Uitleg van de Sandra-variant.
- [`R/analyse_ecologische_groepen.md`][14]
  Uitleg van de MSI- en GAM-analyse voor ecologische groepen.
- [`MDs/import_procedure_territoria.md`][15]
  Jaarlijkse importprocedure voor territoria.
- `MDs/wintertellingen_pilot.md`
  Methode, audit, resultaten en besluitregels van de wintertellinganalyse voor alle soorten.
- `MDs/publieksartikel_25_jaar_wintervogels.md`
  Publicatieklaar conceptartikel op basis van de gevalideerde pilotresultaten.

### Shiny-app

De Shiny-app staat in `shiny_meijendel/`.

Belangrijkste bestanden:

- [`shiny_meijendel/app.R`][16]
- [`shiny_meijendel/helpers.R`][17]
- [`shiny_meijendel/start_shiny_local.sh`][18]
- [`shiny_meijendel/start_shiny_tailscale.sh`][19]

De app is bedoeld voor:

- selectie van kavels
- keuze van periode
- TRIM-analyse per soort
- MSI-analyse per ecologische groep
- controle van analysebasis en modelstatus
- export van resultaten naar CSV
- gebruik van jaarlijkse PQ-vegetatiekenmerken als optionele covariaten in GEE, GLMM, NMDS/envfit en occupancy

### HTML-overzicht

De standalone HTML staat in:

- [`bmp_meijendel_index.html`][20]

De HTML bevat momenteel deze hoofdonderdelen:

- `Trend`
- `Plot`
- `MSI`
- `Tellers`
- `Wintertellingen`, met alle geregistreerde soorten, kwaliteitslabels,
  passende model- of beschrijvende reeksen en een apart gemarkeerde ruwe telling

De HTML gebruikt:

- `meijendel.sql` voor ruwe gegevens
- extra CSV-bestanden voor TRIM- en MSI-weergaven

### R-analyses

De R-scripts staan in `R/`.

Belangrijkste scripts:

- [`R/trim_soorten_en_msi_evg.R`][21]
- [`R/trim_sandra_soorten_en_msi_evg.R`][22]
- [`R/analyse_ecologische_groepen.R`][23]
- `R/analyse_wintertellingen_pilot.R`
- `R/check_wintertelling_output.R`

Belangrijkste outputmappen:

- `trim/soorten/`
- `trim_msi_evg/`
- `trim/sandra/`
- `output_ecologische_groepen/`
- `wintertellingen/`

### SQL-views en hulpmiddelen

De repository bevat veel SQL-bestanden voor:

- analyses per soort
- analyses per plot
- trends
- habitat
- tellers
- richtlijnen
- kernopgaven
- controle en validatie

Belangrijke mappen:

- `Views - soorten/`
- `Views - trends/`
- `Views - plots/`
- `Views - tellers/`
- `Views - Habitat/`
- `Integriteit check/`

### Ruimtelijke en recreatieve data

Ruimtelijke uitbreidingen staan in:

- `Ruimtelijke data/`
- `Recreatie/`

Daarin staan onder andere:

- import-SQL voor AHN, stikstof en landgebruik
- Python-scripts voor ruimtelijke samenvattingen per plot
- bronbestanden uit BGT en OSM
- importbestanden voor recreatie en toegankelijkheid
- documentatie over bezoekersdruk en recreatieve infrastructuur

### NDFF-data

De open FFV-bronbestanden, stagingdataset en rapporten staan uitsluitend op de
Samsung T7 onder `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF`. De ontvangen
onvervaagde levering voor ticket 58679 staat daar fysiek gescheiden onder
`secure/ticket_58679` en komt niet in Git, `meijendel.sql`, de gewone Shiny-app
of webpaden. Zie `docs/NDFF_STAGINGDATASET.md` en
`docs/NDFF_SECURE_ONTVANGST.md`.

De openbare FFV-staging en historische GBIF-vangblikreeks zijn lokaal als
afzonderlijke bronregistraties in nieuwe tabellen van `Meijendel` opgenomen.
Zij wijzigen de bestaande vogel- en provinciale PQ-tabellen niet en zijn niet
automatisch voor trendanalyse toegelaten. De beveiligde levering blijft in
`Meijendel_ndff_secure`; alleen daar staat de koppeling tussen beveiligde en
openbare records.

## Wat is de normale werkvolgorde?

De praktische volgorde is:

1. werk vanuit `meijendel.sql`
2. gebruik Shiny of R voor nieuwe analyses
3. controleer de uitkomsten
4. gebruik de HTML voor overzicht en presentatie
5. leg wijzigingen vast in Git

Voor alleen bekijken:

1. open `bmp_meijendel_index.html`
2. laad `meijendel.sql`
3. laad waar nodig extra CSV-bestanden

Voor nieuwe analyses:

1. start de Shiny-app
2. laad `meijendel.sql`
3. kies kavels en jaren
4. voer de analyse uit
5. controleer de tabs `Soorten`, `Groepen` en `Controle`
6. exporteer zo nodig CSV-bestanden

### NDFF-protocolkwaliteit

De lokale database bewaart de wetenschappelijke protocolbeoordeling los van de
geschiktheid van de geleverde waarnemingsregels. Regelversie
`ndff-protocolkwaliteit-v1` bevat de catalogus van 54 protocollen, de
gebruiksmatrix en de ruimtelijke beoordeling van alle 810.830 openbare
FFV-records. De actuele voorlopige analysebesluiten staan afzonderlijk onder
`ndff-analysebesluit-v4`; de oorspronkelijke v1-, v2- en v3-besluiten blijven als
historische auditlaag bewaard. De bronrecords zelf zijn niet gewijzigd.

Voor NEM-reeksen wordt nu aanvullend de native bezoekstructuur per protocol
gereconstrueerd. Een NEM-code geldt als protocolbewijs voor de positieve regel,
maar trendinvoer ontstaat pas na reconstructie van meeteenheid, bezoek,
doelsoorten en echte nullen. Voor `03.201` is dat uitgevoerd onder
`ndff-vlinderroute-v1`: 3.126 bezoeken, 11 routefamilies en een matrix van
106.284 bezoek-dagvlindertaxonregels. De zelfstandige NEM-deelreeks voor de
binnen hetzelfde protocol getelde vliesvleugeligen staat onder
`ndff-vliesvleugelroute-v1`: 217 bezoeken, zes taxa en 1.302 matrixregels.
Voor `07.201` staat de libellenreconstructie onder `ndff-libellenroute-v1`:
461 bezoeken, negen routefamilies, 29 taxa en 13.173 matrixregels. Van 454
bezoeken is het algemene doelbereik vastgesteld; zeven grove eensoortbezoeken
behouden alleen hun positieve telling en krijgen geen afgeleide nullen. Alle
openbare afleidingen staan in `Meijendel`. Voor `10.201` staat daarnaast
`ndff-reptielroute-v1`: 957 bronrecords zijn samengebracht tot 14
routefamilies en 660 route-datumbezoeken. De matrix telt 1.320 regels: 661
positieve resultaten en 659 echte nullen voor Hazelworm. Volledig negatieve
bezoeken en de feitelijke inspanning ontbreken in de FFV-bron; voor
Zandhagedis worden daarom geen nullen aangevuld. Controleer de reconstructies
met `--audit-vlinders`, `--audit-vliesvleugelen`, `--audit-libellen` en
`--audit-reptielen`.

Amfibieënprotocol `01.201` staat onder `ndff-amfibiewater-v1` in vijf
openbare `Meijendel.ndff_amfibie_*`-tabellen. De 2.439 onvervaagde bronrecords
uit 2003-2025 vormen 211 telgebiedbezoeken, 50 waterfamilies en 1.300
aantoonbaar bezochte wateren. De matrix bevat 9.100 waterbezoek-taxonregels:
2.274 positieve registraties en 6.826 echte protocolnullen voor zeven taxa.
Exacte aantallen, presentieklassen en gemengde telwaarden blijven
onderscheiden. De 80 jaarlijks geaggregeerde, vervaagde Kamsalamanderrecords
krijgen geen openbare waterkoppeling of afgeleide nul. Controleer deze laag met
`--audit-amfibieen`.

Vleermuistransectprotocol `17.208` staat onder
`ndff-vleermuistransect-v1` in vijf openbare `Meijendel.ndff_vleermuis_*`-
tabellen. De 2.624 bronrecords uit 2013-2025 bevatten twee afzonderlijke
meetreeksen: 26 bezoeken van de noordelijke NEM-VTT-autoroute en 18 bezoeken
van de zuidelijke vleerMUS-fietsroute. Na onderdrukking van 73 aantoonbare
dubbele aanleveringen uit 2019 blijven 2.551 akoestische detecties over: 2.410
van protocol-doelsoorten en 141 positieve bijvangsten. De bezoek-soortmatrix
bevat 242 regels, waaronder 32 echte nullen die uitsluitend binnen het
doelsoortenbereik van de betreffende meetreeks zijn afgeleid. Akoestische
detecties zijn geen aantallen individuele vleermuizen. Controleer deze laag
met `--audit-vleermuizen`.

Zeereeppaddenstoelenprotocol `11.202` staat onder `ndff-zeereep-v1` in drie
openbare `Meijendel.ndff_zeereep_*`-tabellen. De 3.729 onvervaagde records
vormen 161 hok-datumbezoeken in 21 RD-kilometerhokken. De matrix voor zes
typische doelsoorten bevat 224 positieve combinaties en 742 protocolafgeleide
nullen. NMV-vindplaatsklassen blijven ordinaal en worden niet als aantallen
vruchtlichamen opgeteld. Negen vervaagde records zijn uitgesloten; 61 bezoeken
buiten oktober-december en de nog niet gevalideerde bezoektijd en
waarnemersbekwaamheid blijven als kwaliteitswaarschuwing aanwezig. Controleer
de laag met `--audit-zeereeppaddenstoelen`.

Konijnentelprotocol `17.209` staat onder `ndff-konijnentelling-v1` in twee
openbare `Meijendel.ndff_konijn_*`-tabellen. De 5.809 positieve records uit
1984-2023 bevatten 5.095 Konijnrecords en 714 positieve bijvangsten. Het zijn
exacte sectietellingen, maar de FFV-export bevat geen route- of sectie-id en
alle 11 kilometerhokken raken meerdere SOVON-plots. Daarom worden gelijke
waarden niet automatisch ontdubbeld, kilometerhok-datumcombinaties niet als
bezoek beschouwd en geen nullen afgeleid. De 11 exacte overeenkomsten met
DAZ-BMP (`17.204`) zijn alleen als mogelijke overlap gemarkeerd. Controleer de
laag met `--audit-konijnen`.

DAZ-BMP-protocol `17.204` staat onder `ndff-daz-bmp-v1` in vier openbare
`Meijendel.ndff_daz_bmp_*`-tabellen. Het betreft zoogdierregistraties door het
deel van de BMP-vogeltellers dat aan DAZ deelnam, niet vogelwaarnemingen. Van
10.670 bronrecords koppelen 3.171 eenduidig aan 1.475 bestaande BMP-bezoeken
in 49 SOVON-plots. Voor die bevestigde bezoeken bevat de matrix 10.325 regels
voor zeven DAZ-doelsoorten: 2.681 positieve regels, 7.552 echte nullen en 92
onbesliste regels doordat een record meerdere bezoeken kan betreffen. De 161
bijvangst-bronrecords krijgen uitsluitend positieve voorkomensstatus; 50
daarvan koppelen eenduidig en vormen 49 bezoek-taxonregels. Overige
BMP-bezoeken worden niet als DAZ-bezoek verondersteld. Controleer de laag met
`--audit-daz-bmp`.

De 114 daadwerkelijk voorkomende niet-LOS-combinaties van protocol en
soortgroep zijn onder `ndff-protocolbereik-v2` ingedeeld in
`ndff_protocol_soortgroep_geschiktheid`. De klassen zijn `doelgroep`,
`bijvangst`, `algemene_bron`, `doelsoortafhankelijk` en `gemengd`. Voor alle
gemengde combinaties staat de verdere indeling van ieder aangetroffen taxon in
`ndff_protocol_soort_geschiktheid`: 620 protocol-taxonbesluiten. Bijvangst en
algemene bronnen ondersteunen uitsluitend positieve voorkomensinformatie
(`V`). Een gemengde combinatie mag
voor een ander analysetype alleen na een expliciete selectie van de daar als
`doelsoort` geregistreerde taxa worden gebruikt.

Van de 19 eerder doelsoortafhankelijke combinaties zijn er acht opgelost met
officiële protocolafbakening. Elf blijven afhankelijk van ontbrekende
projectcontext: eDNA `10.002`, Staatsbosbeheer-florakartering `12.015`, de zeven
SNL-soortgroepen van `12.205` en de Vleermuisprotocollen `17.505` en `17.506`.

Ieder NDFF-record heeft daarnaast precies één genormaliseerde
protocolkoppeling. Openbare koppelingen staan in
`ndff_open_waarneming_protocol`; beveiligde koppelingen staan uitsluitend in
`Meijendel_ndff_secure.ndff_waarneming_protocol`. Een aangeleverde NDFF-code
krijgt bewijsmethode `expliciete_code`. De letterlijke waarde
`Losse waarnemingen` krijgt `expliciet_losse_waarneming` en de stabiele
`protocol_sleutel` `LOS`. Het numerieke `protocol_id` is alleen een interne
foreign key. `analyse_status` is geen protocolstatus en blijft een afzonderlijke
toelatingspoort voor analyses. Lege protocolwaarden mogen nooit automatisch als
`LOS` worden behandeld.

Voor de 6.273 openbare records met SNL-protocol `12.205` staat de afzonderlijke
bronoverlaptoets in `ndff_snl_waarneming_context`. De statussen zijn
`overlap_bevestigd`, `overlap_mogelijk`, `geen_overlap_gevonden` en
`onvoldoende_onderzocht`. Afwezigheid van een gevonden match wordt nooit als
bewezen onafhankelijkheid uitgelegd. SNL blijft een natuurkwaliteits- en
subsidiecontext; bevestigde dubbelen tellen niet als zelfstandige evidentie.
De eerste toets vond 97 mogelijke overlaps en bij 6.176 records geen overlap;
geen van beide uitkomsten bewijst zelfstandig verzamelde trenddata.

De interne beveiligde view `v_ndff_canonieke_waarneming` combineert beide
NDFF-leveringen zonder dubbeltelling. Zij bevat 810.983 unieke waarnemingen:
796.410 alleen openbaar, 14.420 met de beveiligde representatie in plaats van
de openbare en 153 alleen beveiligd. Omdat de view exacte geometrie bevat,
blijft zij uitsluitend lokaal in `Meijendel_ndff_secure` en buiten de rechten
van gewone en Shiny-accounts.

De geversioneerde openbare PQ-poort staat in `ndff_open_pq_koppeling`.
Regelversie `ndff-open-pq-poort-v1` blokkeert 97.318 records met protocol
`12.007` of `12.202` als secundaire controlebron naast de provinciale PQ-reeks;
713.512 records zijn expliciet `niet_van_toepassing` en geen record blijft
onbeoordeeld. Alleen Provincie Zuid-Holland als bronhouder is niet voldoende
voor een PQ-classificatie.

De centrale lokale analysepoort is
`Meijendel_ndff_secure.v_ndff_analyse_record`. Deze view bevat 810.983 unieke
canonieke records en brengt per record de protocolkandidaten en de ruimtelijke,
PQ- en SNL-poorten samen. De actuele verdeling is 303.319
`voorlopig_bruikbaar`, 4 `voorlopig_met_overlapwaarschuwing`, 97.333
`uitgesloten_pq` en 410.327 `uitgesloten_ruimtelijk`. Alle 430.263 records met
protocol `LOS` ondersteunen alleen voorkomens- en verspreidingsinformatie
(`V`). `gegevensgeschiktheid` is voor alle records nog `niet_beoordeeld`:
iedere uitvoer moet daarom `kwaliteitsmelding` tonen en mag de kandidaattypen
niet als definitief gevalideerde trenddata presenteren. De view bevat geen
geometrie of exacte datum, maar blijft intern en is niet aan de Shiny-account
toegekend.

Voor analyse zijn daarboven twee lokale, geaggregeerde views beschikbaar:

- `v_ndff_verspreiding_plot_jaar_taxon`: 105.999 positieve
  plot-jaar-taxonsignalen, gebaseerd op 303.319 voorlopig bruikbare
  bronrecords;
- `v_ndff_trendkandidaat_plot_jaar_taxon`: 11.138
  plot-jaar-taxon-protocolcombinaties, gebaseerd op 66.125 records waarvan het
  protocol naast `V` minimaal één kandidaatmogelijkheid `I`, `TV`, `TA` of
  `TK` ondersteunt.

Beide views bevatten `gegevensgeschiktheid` en een verplichte
`kwaliteitsmelding`. `bronrecords_ter_controle` is geen abundantie. Losse
waarnemingen ontbreken volledig uit de trendkandidaatview. De views bevatten
geen geometrie, dagdatum of bronidentiteit en hebben nog geen extra grants.

Het compacte selectieoverzicht
`v_ndff_gebruiksdekking_soortgroep_protocol` bevat 142 sluitende combinaties
uit 28 soortgroepen en alle 54 aanwezige protocolwaarden. De subtotalen sluiten
aan op 810.983 canonieke records. Daarbinnen zijn momenteel 303.319 records
kandidaat voor `V`, 6.133 voor `I`, 60.015 voor `TV`, 57.605 voor `TA` en
4.727 voor `TK`. Deze categorieën overlappen: één record kan voor meer dan één
analysetype kandidaat zijn. Alle 810.983 records blijven aangemerkt als
aanvullend te valideren. De view is het standaardstartpunt om vóór een analyse
de beschikbare omvang en beperkingen te beoordelen.

De beschrijvende jaarniveau-views van stap 3 zijn eveneens beschikbaar:

- `v_ndff_soortenrijkdom_plot_jaar`: 12.611 plot-jaar-soortgroepregels en
  105.999 positieve taxonsignalen;
- `v_ndff_eerste_laatste_plot_taxon`: 42.714 reeksen van eerste tot laatste
  positieve registratie, zonder deze jaren als vestiging of verdwijning te
  duiden;
- `v_ndff_verspreidingsverandering_taxon_jaar`: 33.022 registratiejaarregels;
  8.059 vergelijkingen springen over een of meer ontbrekende jaren en zijn via
  `aansluitend_jaar = 0` herkenbaar;
- `v_ndff_dekking_intensiteit_plot_jaar_soortgroep`: 12.611 dekkingsregels uit
  303.319 bronrecords, waarvan 201.372 losse en 101.947 protocolgebonden
  registraties.

Ontbrekende jaren worden niet toegevoegd en nergens als nulwaarneming of
afwezigheid geïnterpreteerd. Ook deze views blijven lokaal zonder extra grants.

De keten is op 11 september 2026 formeel vastgezet als
`ndff-analyseketen-v1` en gereed verklaard voor **verkennende
verspreidingsanalyse**. De reproduceerbare, alleen-lezen eindaudit is:

```bash
python3 gis/scripts/import_ndff_protocolkwaliteit.py --audit-live
```

De audit controleert 810.983 unieke canonieke records, alle status- en
viewtotalen, jaargaten, ontbrekende velden en ongewenste grants. Een geslaagde
audit maakt de gegevens niet automatisch trendklaar. Alle 810.983 records
behouden in deze versie aanvullende validatiebehoefte. Verkennende berekeningen
van registratie- en verspreidingspatronen, meldingsintensiteit en associaties
met beheer zijn wel toegestaan wanneer de kwaliteitsmelding wordt getoond.
Zonder de later afgesproken bronvalidatie mogen deze uitkomsten niet als een
gevalideerde populatietrend, abundantie, afwezigheid of causaal beheereffect
worden gepresenteerd.

Een record kan alleen kandidaat zijn voor positieve plotcontext wanneer de
openbare geometrie onvervaagd en volledig binnen precies één geversioneerd
SOVON-plot ligt. Daarna blijft de afzonderlijke PQ-toets verplicht.
Protocolmatig passende analysetypen krijgen `voorlopig_toegelaten`. Gemengde
combinaties krijgen voor niet-V-gebruik `alleen_na_doelsoortselectie` en een
nog niet uit het record afleidbare doelsoortenlijst krijgt
`wacht_op_doelsoortafbakening`. De leveringsgeschiktheid blijft afzonderlijk
`niet_beoordeeld`. Deze statussen maken gecontroleerd verkennend gebruik
mogelijk, maar bevestigen niet dat een trend, afwezigheid, abundantie of
beheereffect al voldoende is gevalideerd. Iedere uitvoer moet daarom de
kwaliteitsvermelding uit `ndff_analysebesluit.reden` tonen.

Reproduceerbare controle en lokale toepassing:

```bash
python3 gis/scripts/test_ndff_protocolkwaliteit.py
python3 gis/scripts/import_ndff_protocolkwaliteit.py --dry-run
python3 gis/scripts/import_ndff_protocolkwaliteit.py
```

### Weergegevens: verplicht analysecontract

De tabel `weer` bevat ruwe bronwaarden met een stationsafhankelijke schaal en
mag daarom niet rechtstreeks in analyses worden gebruikt. Gebruik altijd de
view `weer_analyse`, met expliciete eenheden in de kolomnamen: `tg_c`, `tn_c`,
`tx_c`, `rh_mm`, `fg_ms`, `sq_uur`, `pg_hpa` en `ug_pct`.

- station 210 (Valkenburg, tot en met 2 mei 2016): `TG`, `TN`, `TX` en `RH`
  worden met 10 vermenigvuldigd;
- station 215 (Voorschoten, vanaf 3 mei 2016): dezelfde ruwe velden worden
  door 10 gedeeld;
- `rh_spoor` en `sq_spoor` markeren KNMI-code `-1`; de bijbehorende
  analysewaarde is dan nul.

Bij een nieuw station of een gewijzigde import moet eerst het profiel in
`weer_analyse` worden uitgebreid en moeten de weercontroles in
`Integriteit check/Database Validatie Check.sql` groen zijn.

## Shiny starten

In R of RStudio:

```r
setwd("/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel")
shiny::runApp(host = "127.0.0.1", port = 3867)
```

Of via Terminal:

```bash
/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_local.sh
```

## Belangrijke aandachtspunten

- De SQL-dump is de bron. Werk zorgvuldig als je die wijzigt.
- De lokale MySQL-server, `mysql`, `mysqldump` en de VPS-container moeten exact versie 9.7.1 gebruiken. Generatie en deploy blokkeren bij een afwijking.
- Lees voor weeranalyses uitsluitend uit `weer_analyse`, nooit rechtstreeks uit `weer`.
- Voeg aan MySQL `tellers` geen persoonsgegevens toe: alleen `id` en `tellercode` zijn toegestaan. Weergavenamen worden door de website uit PostgreSQL gehaald.
- De PQ-vegetatiebron vormt hierop een expliciete uitzondering: `pq_vegetatie_import`, `pq_vegetatie_pq`, `pq_vegetatie_opname`, `pq_vegetatie_taxon`, `pq_vegetatie_waarneming`, `pq_vegetatie_opname_plot` en `pq_plot_jaar_vegetatie` worden in de levende MySQL-database beheerd. Wijzig deze gegevens niet handmatig in `meijendel.sql`; genereer de dump na databasevalidatie opnieuw.
- De Shiny-app en HTML hebben verschillende rollen: Shiny rekent, HTML presenteert.
- Niet alle documentatie in de repo is even recent; de documenten in `MDs/` zijn nu leidend.
- De worktree hoort buiten een expliciet actieve taak schoon te zijn. Onderzoek iedere vooraf aangetroffen wijziging, rond bedoelde wijzigingen af met commit/push en haal gegenereerde caches of runtime-output uit Git en zet die in `.gitignore`.

## Samenvatting

Deze repository is geen losse SQL-dump meer, maar een complete werkomgeving rond de Meijendel-database:

- database
- documentatie
- analyses
- visualisaties
- ruimtelijke uitbreidingen
- import- en controlehulpmiddelen

Voor dagelijks gebruik is [`MDs/handboek.md`][24] nu het beste startpunt.

[1]:	/Users/ton/Documents/GitHub/Meijendel/MDs/handboek.md
[2]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md
[3]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/CONTROLESET_html_shiny.md
[4]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/README_shiny_meijendel.md
[5]:	/Users/ton/Documents/GitHub/Meijendel/MDs/README_bmp_meijendel_index.md
[6]:	/Users/ton/Documents/GitHub/Meijendel/meijendel.sql
[7]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html
[8]:	/Users/ton/Documents/GitHub/Meijendel/README.md
[9]:	/Users/ton/Documents/GitHub/Meijendel/MDs/handboek.md
[10]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md
[11]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/CONTROLESET_html_shiny.md
[12]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.md
[13]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_sandra_soorten_en_msi_evg.md
[14]:	/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.md
[15]:	/Users/ton/Documents/GitHub/Meijendel/MDs/import_procedure_territoria.md
[16]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/app.R
[17]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/helpers.R
[18]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_local.sh
[19]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_tailscale.sh
[20]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html
[21]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R
[22]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_sandra_soorten_en_msi_evg.R
[23]:	/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R
[24]:	/Users/ton/Documents/GitHub/Meijendel/MDs/handboek.md
