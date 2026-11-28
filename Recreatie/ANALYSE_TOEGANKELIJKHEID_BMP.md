# Broedvogeltrends en toegankelijkheid

Stand: 28 november 2026. Twee analyses op verzoek van Ton. De eerste is uitgevoerd; voor de tweede zijn de beschikbare verkeersbronnen gereconstrueerd en is de resterende gegevensleemte vastgesteld. Alle bestanden met waarnemingen, kaarten en modeluitvoer staan in de geregistreerde T7-taakmap `toegankelijkheid-broedvogels-2026-11-28/outputs` onder `/Volumes/T7 Data/Home_Ton/Proefomgevingen/`.

## Conclusie

De vogelontwikkeling verschilt bij een deel van de soorten met de huidige aandelen afgesloten en dagkaartgebied. De richting hangt echter geregeld samen met habitat: bij het contrast voor afgesloten terrein verandert het teken na toevoeging van bos- en wateraandeel bij 23 van 100 vergelijkbare soorten over 1984–2025 en bij zes van 80 over 2009–2025. Dat ondersteunt geen algemene conclusie dat afsluiting tot meer of minder broedvogels leidt. Het zijn ruimtelijke samenhangen met de kaart van november 2026.

De Dunea-aanvulling uit 2024 maakt een lokale verandering in fietsdruk zichtbaar: voor maart–juni stijgt het aantal uren boven de verkeersdrempel bij Prinsenweg tussen 2022 en 2023 van 355 naar 414, terwijl dit bij Pannenduin/Ganzenhoekweg daalt van 263 naar 215 en bij Waalsdorpervlakte van 203 naar 172. Bij Meijendelseweg stijgt het van twaalf naar veertien. Deze acht seizoenwaarden betreffen vier telpunten en twee jaren. Het zijn uren boven een drempel, geen passageaantallen. De gevraagde koppeling met vogelverandering kan daarmee nog niet worden geschat: dagelijkse passagewaarden en een bronvaste telpunt-route-kavelkoppeling zijn niet beschikbaar in de gecontroleerde levering.

## Populatie en broncontrole

De levende MySQL-database 9.7.4 is alleen gelezen. De veertien actuele gebiedsversies en 110 positieve gebied-kaveldoorsnijdingen zijn vastgelegd, met geometriehashes en exacte SQL in `manifest.json` en `bron_*.tsv`. De veertien gebieden dekken alle 55 actuele kavels. De analyse gebruikt de 53 kavels binnen `plot_analyse_scope`, code `meijendel_natura2000`. M66 en M91 blijven buiten deze analyse. Binnen de 53 kavels bevatten 52 een territoriumreeks.

De bestaande functies `prepare_analysis_basis`, `build_species_matrix` en `apply_territory_observation_gate` leveren 134.097 geldige soort-kavel-jaarwaarden over 1984–2025: 51.686 positieve aantallen en 82.411 letterlijke of volgens het bestaande jaarverslagcontract afgeleide nullen. De gevoeligheidsperiode 2009–2025 bevat 62.535 geldige waarden. Alle 156 vogelcategorieën uit de canonieke selectie blijven in de uitvoer staan. Een ontbrekende of afgekeurde waarde is niet als nul ingevuld. `vogelmatrix_status.csv` bewaart de statusverdeling per jaar; de volledige matrix staat in `vogelmatrix.csv.gz`.

De oppervlakteaandelen zijn opnieuw uit de doorsnijdingsoppervlakten en de actuele kavelgeometrie berekend. De gezamenlijke dekking wijkt per kavel minder dan 0,001 procentpunt af van 100%. De jaarlijkse oppervlakteregistraties over 1984–2025 tonen geen kavelverandering boven 1%. Dat bewijst geen historische geometrische continuïteit. De actuele kavelgrenzen blijven de ruimtelijke referentie van deze analyse. Er is geen oppervlakte-offset gebruikt.

Het oorspronkelijke corridor-GeoPackage is teruggevonden op het geregistreerde T7-pad en is bytegelijk aan de bron van 10 november 2026: SHA-256 `0b59cc88a80de095f9d2473e688c4f823704b8d3454605cecef5bb12d700a79b`. Het bevat vier hartlijntakken met een gezamenlijke lengte van 9.487,702 m. Na ontdubbeling is de unieke lijn 9.454,398 m lang. Buffers van 50, 100 en 200 m zijn om deze bronhartlijn berekend. De tienmeterstrook is niet als maat voor alle verstoring gebruikt.

## Modellen en volledige uitkomsten

Per soort zijn Poissonmodellen met kavel- en jaareffecten geschat. De termen combineren tijd in decennia met de aandelen afgesloten, seizoensgebonden en dagkaartgebied, telkens per tien procentpunt extra oppervlak en met vrij toegankelijk als referentie. Het resultaat is een verhouding van de ontwikkeling per decennium. Het model beschrijft aantallen territoria; het is geen causale maat voor recreatieschade.

De vooraf vastgelegde praktische gevoeligheidsgrens is RR 1,10 of het omgekeerde 0,909 per decennium en tien procentpunt. Deze grens is geen voor alle soorten gevalideerde ecologische norm. De gerapporteerde 95%-intervallen gebruiken op kavel geclusterde standaardfouten en zijn verkennende modelintervallen. Een richting met een breed interval wordt niet als vastgesteld effect beschreven.

Naast het basismodel zijn uitgevoerd: interacties met bos- en wateraandeel in 2010; beperking tot het gemeenschappelijke bos-/waterbereik van overwegend vrije en overwegend afgesloten kavels; bezoekaantal en geregistreerd beheer; bezoektiming, deelbezoeken en geregistreerde tellerwisselingen; bosontwikkeling binnen de meetperiode 2010–2022; drie corridorbuffers; vier geografische weglaatproeven. Covariaattoetsen bewaren een basismodel op exact dezelfde invoerrijen. Niet-lineaire effecten, overige habitatkenmerken en volledige historische beheerintensiteit zijn hiermee niet afgedekt.

Bosontwikkeling gebruikt lineaire interpolatie tussen de beschikbare CBS-kaartjaren 2010, 2015, 2017 en 2022, uitsluitend binnen die periode. Dit is een gevoeligheidsaanname. Een ontbrekende beheerregistratie betekent geen geregistreerde uitvoering en bewijst niet dat geen beheer plaatsvond. Tellerwisselingen zijn alleen afgeleid tussen aansluitende jaren met een geregistreerde bezetting. Jaarlijkse kavel- en jaareffecten corrigeren geen onbekende wijzigingen in teltoegang.

De resultaten en modelstatus staan volledig in `effecten.csv` en `modelstatus.csv`. Er zijn 4.992 modelpogingen voor 156 vogelcategorieën: 3.429 convergeerden zonder numerieke waarschuwing, zes kregen ondanks optimizerconvergentie een waarschuwing over de berekening van de vaste effecten, 377 convergeerden niet, 686 hadden onvoldoende invoer en 494 waren niet schatbaar. Ook zeven van de 377 niet-geconvergeerde modellen hebben die waarschuwing. Vervallen termen, gebruikte en uitgevallen kavels en numerieke waarschuwingen blijven per model herkenbaar. Een numeriek teruggegeven coëfficiënt is niet automatisch geschikt voor inferentie. De praktische filter verlangt onder meer convergentie zonder numerieke waarschuwing, een eindig interval, minimaal tien overgebleven kavels, minimaal vijf kavels met minstens 10% van het betreffende oppervlak en blootstelling in minstens twee geografische blokken.

| Contrast | Periode | Ruimtelijk en numeriek voldoende ondersteunde soorten | Interval geheel boven 1 | Interval geheel onder 1 |
|---|---|---:|---:|---:|
| Afgesloten tegenover vrij | 1984–2025 | 100 | 15 | 14 |
| Afgesloten tegenover vrij | 2009–2025 | 80 | 9 | 6 |
| Dagkaart tegenover vrij | 1984–2025 | 94 | 5 | 16 |
| Dagkaart tegenover vrij | 2009–2025 | 68 | 4 | 10 |
| Seizoensgebonden tegenover vrij | beide perioden afzonderlijk | 0 | 0 | 0 |

Deze tabel telt nominale intervallen. Voor meervoudige toetsing staan ook Benjamini–Hochbergwaarden in de volledige effecttabel. Het seizoenscontrast wordt door te weinig onafhankelijk blootgestelde vogelkavels gedragen. Daaruit volgt geen conclusie over aanwezigheid of afwezigheid van een seizoenwerking.

`alle_soorten_hoofdresultaten.csv` bevat voor iedere vogelcategorie, beide hoofdperioden en elk statuscontrast een expliciete uitkomst, ook zonder schatting. `gevoeligheid_per_soort.csv`, `geografische_weglaatproeven.csv` en `corridor_gevoeligheid.csv` bewaren alle berekende gevoeligheden. `samenvatting.csv` en `gevoeligheid_samenvatting.csv` zijn uitsluitend afgeleide tellingen; zij vervangen de uitkomsten per soort niet.

De onafhankelijke controle vergelijkt het basismodel voor Merel bovendien met een gewone Poisson-GLM met expliciete kavel- en jaardummy's. Het maximale verschil tussen de drie trendcoëfficiënten is kleiner dan 0,000001. De controle toetst daarnaast unieke matrixsleutels, nul-/ontbrekend onderscheid, analysescope en gelijke invoer bij covariaatvergelijkingen. Zie `controlebewijs.json`.

## Gemeten recreatie

Gecontroleerd zijn de lokale tabellen `bezoekersdruk_locatie` en `bezoekersdruk_meting`, de bestaande import-CSV, projectdocumentatie, de lokale Zotero-catalogus en T7-bestanden, de WUR-catalogus en de officiële Dunea-rapporten van 2022 en 2024. De 36 databaseregels uit 2020–2021 hebben dezelfde indicatorverdeling als de 36 CSV-regels. De vier geregistreerde locaties missen geometrie. De regels bevatten onder meer parkeerbezetting en gebiedstotalen; zij bevatten geen meerjarige telpuntgebonden passagegegevens voor het broedseizoen.

WUR-deel XXIV, *Analyse van het recreatieverkeer en het recreatiebezoek in 2010* (2011; 102 pagina's; ISBN 9789461730725), en deel XXIII, *Het gebruik van Fietspad 10* (2011; 23 pagina's; ISBN 9789461730718), zijn bibliografisch bevestigd. De volledige teksten zijn in deze controle niet verkregen. Een ontbrekende download bewijst niet dat de ruwe gegevens bij WUR of Dunea ontbreken. De aanvullende WUR-variantenstudie uit 2004 beschrijft een geplande verbinding over de Waalsdorpervlakte; zij bewijst geen feitelijke openstellingsdatum. Fietspad 10 en de geregistreerde kustcorridor zijn daarom niet gelijkgesteld.

Het Dunea-rapport van 29 november 2022 geeft zeven telpuntlocaties en meetperioden in paragraaf 2.2 en figuur 3. De telling van 2016 betreft 6 september–1 december; deze periode is niet gelijkgesteld aan een broedseizoen. De meetperiode 2021–2022 is evenmin als een volledig kalenderjaar 2021 gebruikt. Bij Prinsenweg en Ganzenhoekweg ontbreken volgens het rapport tellingen over 2004–2006; voor Waalsdorpervlakte is in dat rapport één teljaar beschikbaar. Veel tussenjaren in de gepubliceerde trendlijnen zijn geïnterpoleerd en 2025/2030 zijn projecties. Voetgangersaantallen in 2009–2010 bevatten een methodebreuk. Deze waarden zijn niet als onafhankelijke route-jaarmetingen ingevoerd.

Uit tabellen 9 en 10 van de Dunea-aanvulling van 16 september 2024 zijn 96 maandwaarden overgenomen: vier fietstelpunten, twaalf maanden en twee jaren. De acht jaarsommen zijn exact gelijk aan tabel 6. De bron noemt 364 meetdagen per jaar; de ontbrekende datum is niet gegeven. Drempels zijn 250 fietsers per uur in beide richtingen voor telpunten 2, 4 en 5 en 100 voor telpunt 6. De waarden tussen verschillende drempels zijn niet als identieke passageaantallen vergeleken. Er zijn geen afzonderlijke honden- of wandelaartellingen in deze aanvullende meetreeks.

`telpunten.csv` bevat de zeven locaties, nadere ligging uit figuur 2 van het rapport uit 2024, vervoerswijze, meetvenster en nog niet vastgestelde coördinaten. `recreatie_drukke_uren_maand.csv` bevat de 96 gecontroleerde bronwaarden. `recreatie_vergelijkbare_perioden.csv` bevat de acht vergelijkbare maart–junisommen. `verkeersmodel_status.csv` vermeldt expliciet dat nul routes beschikken over zowel passende ruwe passagewaarden als een gevalideerde kavelkoppeling. Daarom is geen verkeers-vogelcoëfficiënt geschat. Een route die aan meer kavels wordt gekoppeld, zou nog steeds eenmaal als onafhankelijke blootstellingsroute tellen.

## Historische scenario's

`scenariomatrix.csv` bevat 37 regels: veertien brongebonden kaartregistraties, veertien maximale terugprojecties, zes nog niet invulbare vroege/middelste/late varianten bij de krantenankers uit 1959 en 1969 en drie corridorvarianten. Niet onderbouwde ingangsdatums en geometrieën zijn leeg gelaten. Het overgangsbroedseizoen kan pas worden aangewezen nadat het datuminterval bekend is.

`scenario_kaveljaar.csv` bevat 8.162 afgeleide combinaties: 53 actuele kavelgeometrieën, 77 jaren over 1950–2026 en twee scenario's. Dit zijn huidige geografische voetafdrukken, geen bewijs dat dezelfde onderzoekskavels al in 1950 bestonden. In het brongebonden jaarscenario is voor alle jaren het aandeel onbekend 100%: de kaart van november 2026 bewijst ook voor 2026 zelf geen regime tijdens het eerdere broedseizoen. Dat betekent dat deze broncontrole geen onafhankelijke gebiedsgrens én jaarlijkse periode heeft vrijgegeven; het is geen uitspraak dat alle historische toegankelijkheidsinformatie ontbreekt. De kaartstand zelf blijft volledig bekend in `kavelcontrasten.csv`. In de maximale terugprojectie wordt de kaart vanaf 1955 vast gehouden, uitsluitend als stresstest.

Voor de vogelmodellen over 1984–2025 veranderen de vaste covariaten niet wanneer de kaart vanaf 1955 wordt teruggeprojecteerd. De kaartvergelijking en deze stresstest hebben daardoor exact hetzelfde ontwerp. Een afzonderlijk effect van historische openstelling is niet identificeerbaar. De twintig archiefdossiers zijn nog niet ingezien; de bestaande ontvangstcontrole voor 4 januari 2027 blijft staan. Historische effectschatting blijft afhankelijk van een onafhankelijk gedateerde grens, vergelijkingskavels, minimaal vijf geldige BMP-seizoenen voor en na, toetsbare voortrends en controle op gelijktijdig beheer en bezoekersverplaatsing.

## Herhalen en releasevoorbereiding

Gebruik een geregistreerde T7-werkmap en een R-tempverwijzing zonder spaties die fysiek naar de T7-tempmap wijst. Het R-pakket `fixest` 0.14.2 is uitsluitend in de T7-taakmap geïnstalleerd. Voer vanuit de repository uit:

```sh
Rscript R/analyse_toegankelijkheid_bmp.R '<geregistreerde T7-taakmap>'
Rscript R/check_toegankelijkheid_bmp.R '<geregistreerde T7-taakmap>'
python3 -B scripts/prepare_recreatie_toegankelijkheid.py '<geregistreerde T7-taakmap>'
```

De kaart `kavelcontrasten.png`, de brongeometrieën in `kavelcontrasten.gpkg`, de telpuntentabel en de scenariomatrix zijn de eerste concrete producten. De controle bewaart ook nulbevindingen, niet-schatbare soorten en collineaire termen. De afgeleide modellen wijzigen geen gebiedsregistraties, vogelwaarden of analysetoelatingen in MySQL.

Deze onderzoeksuitvoer heeft eindjaar 2025 en blijft verkennend. Zij wordt niet automatisch door website, dashboard of Shiny gelezen. Het manifest met bronqueries, uitvoerchecksums en controlebewijs hoort bij de lokale releasevoorbereiding. Een latere presentatie gebruikt één gezamenlijk gevalideerd bronproduct voor alle drie afnemers; daarvoor zijn eerst bron- en interpretatiebeoordeling, eventuele 2026-herberekening en afzonderlijk publicatieakkoord nodig. De zware export- en cacheketen is niet gestart.

## Bronnen

- [Dunea Trendanalyse Meijendel 2022](https://www.dunea.nl/over-dunea/-/media/bestanden/duinen/rapport-trendanalyse-meijendel-29-11-22.pdf), paragraaf 2.2, figuur 3 en paragraaf 2.4.
- [Dunea Update Trendanalyse Meijendel 2024](https://www.dunea.nl/algemeen/-/media/bestanden/nieuws/update-trendanalyse-meijendel_def_sept-2024_publieksversie.pdf), figuur 2 en tabellen 6, 9 en 10.
- [WUR deel XXIV](https://research.wur.nl/en/publications/analyse-van-het-recreatieverkeer-en-het-recreatiebezoek-in-2010/), bibliografische controle.
- [WUR Het gebruik van Fietspad 10](https://research.wur.nl/en/publications/het-gebruik-van-fietspad-10/), bibliografische controle.
- [WUR Alterra-rapport 1027](https://edepot.wur.nl/22231), variantenstudie uit 2004.
- [Bronregister](../docs/MEIJENDEL_BRONREGISTER.md), actuele toegankelijkheidsregistraties, BMP en archiefantwoord.
