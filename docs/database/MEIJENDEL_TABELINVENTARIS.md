# Inventaris `ndff_*`, `externe_ecologie_*` en `vangblik*`

Stand: 26 september 2026. Dit document beschrijft de fysieke tabellen in de
levende lokale database `Meijendel`; het verandert geen tabellen, gegevens,
views of applicatiecode.

## Uitkomst

De drie onderzochte tabelfamilies zijn niet rechtstreeks gekoppeld aan de
publieke website, het reguliere Shiny-dashboard of het openbare
HTML-dashboard:

| Afnemer | Direct gebruik van de 156 tabellen | Controle |
|---|---:|---|
| FastAPI/Jinja-website | nee | Geen tabelnamen aangetroffen in de Python-applicatiecode. |
| Reguliere Shiny-app | nee | De vaste SQL-cachelijst in `shiny_meijendel/helpers.R` bevat geen tabel uit deze inventaris. |
| Openbaar dashboard | nee | De TRIM-, MSI- en dashboardketen gebruikt kern- en afgeleide CSV-tabellen, niet deze drie families. |
| Optionele lokale NDFF-module in Shiny | niet rechtstreeks | De module leest drie views in `Meijendel_ndff_secure`; die drie views gebruiken uitsluitend tabellen in dat beveiligde schema. Andere, niet door deze module gelezen onderzoeksviews verwijzen wel naar tien `ndff_*`-tabellen. |

Daarmee is het risico voor de drie gebruikersinterfaces laag. De ruimte voor
fysieke hernoeming is echter niet overal gelijk. Foreign keys, databaseviews,
import- en auditscripts, exportvalidatie en beveiligde onderzoeksviews blijven
afhankelijkheden die bij een migratie gelijktijdig moeten worden aangepast.

## Omvang en afbakening

De levende lokale MySQL-database bevat op het meetmoment 248 fysieke tabellen.
Deze inventaris omvat daarvan 156 tabellen:

- 146 tabellen met voorvoegsel `ndff_`;
- 4 tabellen met voorvoegsel `externe_ecologie_`;
- 6 tabellen met voorvoegsel `vangblik`.

De vermelde aantallen zijn exacte `COUNT(*)`-uitkomsten uit de levende lokale
database op 26 september 2026 om 22:28 uur. De inhoudelijke periode is in deze
eerste structuurinventaris niet per tabel geprofileerd. Alleen voor de
Vangblikreeks is de periode vastgesteld: 37.770 events van 8 maart 1953 tot en
met 16 maart 1960, verdeeld over acht kalenderjaren. Dat betekent dat de
aantallen geschikt zijn om migraties later te controleren, maar nog niet om de
inhoudelijke dekking van iedere NDFF- of externe dataset te beoordelen.

## Betekenis van de voorlopige beoordeling

- **behouden**: naam en huidige functie zijn voldoende helder; geen reden om
  deze tabel in de eerste opschoningsmigratie te hernoemen;
- **kandidaat**: naam is inhoudelijk te vaag of noemt een organisatie die niet
  de oorspronkelijke bronhouder van alle inhoud is;
- **apart beoordelen**: mogelijke naamverbetering, maar pas na vaststelling van
  herkomst, semantiek en alle technische afhankelijkheden.

`ndff_` betekent in deze inventaris de directe herkomstlaag: de tabellen zijn
gevuld of gereconstrueerd uit de ontvangen NDFF/FFV-levering. Het voorvoegsel
zegt niet dat NDFF de oorspronkelijke waarnemer of bronhouder was. Alleen om
die reden hernoemen naar een vermoedelijke oorspronkelijke organisatie zou
juist nieuwe schijnzekerheid scheppen.

## Externe ecologie

Deze vier tabellen vormen één generiek model: dataset → event → resultaat, met
een afzonderlijke overlapregistratie. Zij hebben onderlinge foreign keys en
worden samen ontsloten door `v_externe_ecologie_analyse`. Buiten die view zijn
geen actuele applicatie-afhankelijkheden gevonden. De naam is technisch
consistent maar inhoudelijk te algemeen. Daarom is dit de duidelijkste
kandidaat om later als complete familie te hernoemen, na keuze van een naam die
de functie benoemt in plaats van alleen “extern”.

| Tabel | Records | Functie | Voorlopig |
|---|---:|---|---|
| `externe_ecologie_dataset` | 6 | datasetregister | kandidaat |
| `externe_ecologie_event` | 10.994 | meet- of waarnemingsevent | kandidaat |
| `externe_ecologie_resultaat` | 98.916 | resultaat per event | kandidaat |
| `externe_ecologie_overlap` | 87.053 | overlap- en herkomstcontrole | kandidaat |

## Vangblik

Dit is een afgebakende, bron- en methodeherkenbare familie. De zes tabellen
hebben geen databaseview en geen actuele koppeling met website, Shiny of
dashboard. Wel lezen analysescripts en het ruimtelijke-lagen-importscript delen
van deze familie. `vangblik` is daarom geen problematisch voorvoegsel en kan
worden behouden.

| Tabel | Records | Functie | Voorlopig |
|---|---:|---|---|
| `vangblik_import_batch` | 1 | importregistratie | behouden |
| `vangblik_locatieversie` | 135 | versie van vanglocatie | behouden |
| `vangblik_event` | 37.770 | vangstevent, 1953–1960 | behouden |
| `vangblik_event_plot` | 37.770 | koppeling event–Meijendelplot | behouden |
| `vangblik_soorten` | 275 | bronspecifieke taxonomie | behouden |
| `vangblik_vangst` | 60.560 | vangstresultaat per event en soort | behouden |

## NDFF: kern, protocol en beslislaag

Deze tabellen zijn de centrale, technisch sterk verknoopte laag. Vooral
`ndff_open_waarneming` en `ndff_protocol` hebben veel verwijzende tabellen.
Tien tabellen worden bovendien gebruikt door beveiligde onderzoeksviews:
`ndff_analysebesluit`, `ndff_open_pq_koppeling`,
`ndff_open_ruimtelijke_beoordeling`, `ndff_open_waarneming_protocol`,
`ndff_protocol`, `ndff_protocol_soort_geschiktheid`,
`ndff_protocol_soortgroep_geschiktheid`, `ndff_snl_waarneming_context`,
`ndff_open_leveringsverrijking` en `ndff_open_waarneming`.

| Tabel | Records | Functie | Voorlopig |
|---|---:|---|---|
| `ndff_open_import_batch` | 1 | registratie NDFF-open levering | behouden |
| `ndff_open_waarneming` | 810.830 | centrale geleverde waarneming | behouden |
| `ndff_soorten` | 9.828 | taxonomie van de levering | behouden |
| `ndff_open_soortgroep_koppeling` | 811.063 | waarneming–soortgroep | behouden |
| `ndff_open_waarneming_protocol` | 810.830 | protocolduiding per waarneming | behouden |
| `ndff_open_leveringsverrijking` | 14.420 | verrijking op geleverde records | behouden |
| `ndff_open_ruimtelijke_beoordeling` | 810.830 | ruimtelijke toelatingscontrole | behouden |
| `ndff_open_pq_koppeling` | 1.621.660 | kandidaatkoppelingen met PQ | behouden |
| `ndff_protocol` | 54 | protocolregister | behouden |
| `ndff_protocol_gebruik` | 54 | vastgelegd toegestaan gebruik | behouden |
| `ndff_protocol_mapping` | 91 | mapping bronprotocol–canoniek protocol | behouden |
| `ndff_protocol_soort_geschiktheid` | 664 | geschiktheid per protocol en soort | behouden |
| `ndff_protocol_soortgroep_geschiktheid` | 228 | geschiktheid per protocol en soortgroep | behouden |
| `ndff_analysebesluit` | 4.160 | analysebesluit per bronselectie | behouden |
| `ndff_snl_waarneming_context` | 6.273 | SNL-context bij geleverde waarneming | behouden |
| `ndff_sovon_plot` | 55 | SOVON-plotreferentie | apart beoordelen |
| `ndff_sovon_plotversie` | 1 | versiebeheer SOVON-plotlaag | apart beoordelen |

De twee `ndff_sovon_*`-namen zijn inhoudelijk het minst zuiver, maar technisch
niet losstaand. De view `v_meijendel_sovon_plot_actueel`, ruimtelijke tabellen
en `meijendel_waarneming_ruimtelijke_status` hangen ervan af. Een eventuele
hernoeming is dus een afzonderlijke migratie, niet een eenvoudige cosmetische
actie.

## NDFF: soortgroepindexen

De volgende 26 tabellen bevatten ieder alleen `waarneming_id`. Het zijn geen
zelfstandige broncollecties, maar snelle projecties van
`ndff_open_waarneming` per soortgroep. De aantallen betreffen daarom
indexlidmaatschappen in dezelfde levering, niet 26 onafhankelijke datasets.

| Tabel | Records | Voorlopig |
|---|---:|---|
| `ndff_amfibieen` | 12.982 | behouden |
| `ndff_dagvlinders` | 129.238 | behouden |
| `ndff_eencelligen` | 156 | behouden |
| `ndff_geleedpotigen_overig` | 426 | behouden |
| `ndff_insecten_overig` | 1.888 | behouden |
| `ndff_kevers` | 8.079 | behouden |
| `ndff_korstmossen` | 28.643 | behouden |
| `ndff_kranswieren_wieren_algen` | 555 | behouden |
| `ndff_kreeftachtigen` | 2.052 | behouden |
| `ndff_libellen` | 32.325 | behouden |
| `ndff_microvlinders` | 22.849 | behouden |
| `ndff_mossen` | 32.353 | behouden |
| `ndff_nachtvlinders` | 72.978 | behouden |
| `ndff_ongewervelden_overig` | 1.760 | behouden |
| `ndff_reptielen` | 3.347 | behouden |
| `ndff_schimmels` | 77.724 | behouden |
| `ndff_snavelinsecten` | 7.819 | behouden |
| `ndff_spinachtigen` | 2.480 | behouden |
| `ndff_sprinkhanen_en_krekels` | 9.163 | behouden |
| `ndff_vaatplanten` | 277.812 | behouden |
| `ndff_vissen` | 1.280 | behouden |
| `ndff_vleermuizen` | 9.912 | behouden |
| `ndff_vliegen_en_muggen` | 10.495 | behouden |
| `ndff_vliesvleugeligen` | 12.365 | behouden |
| `ndff_weekdieren` | 13.043 | behouden |
| `ndff_zoogdieren_overig` | 39.339 | behouden |

## NDFF: gereconstrueerde meetstructuren

De resterende 103 `ndff_*`-tabellen reconstrueren bezoeken, locaties,
doelbereik, taxonlijsten en recordselecties uit de geleverde waarnemingen. De
tabellen zijn per protocolfamilie onderling via foreign keys verbonden; veel
`*_recordselectie`-tabellen verwijzen tevens naar
`ndff_open_waarneming`. Zij worden niet door de drie gebruikersinterfaces
gelezen, maar wel door import-, audit- en analysescripts.

De voorlopige keuze is daarom **behouden**, behalve waar de naam verschillende
bronnen of methoden lijkt te vermengen. De bronhouder en oorspronkelijke
meetmethode horen afzonderlijk in bron- en protocolmetadata te staan; ze zijn
niet veilig uit alleen de tabelnaam af te leiden.

### Amfibieën en RAVON

| Tabel | Records | Functie | Voorlopig |
|---|---:|---|---|
| `ndff_amfibie_bezoek` | 211 | bezoek | behouden |
| `ndff_amfibie_waterbezoek` | 1.300 | waterbezoek | behouden |
| `ndff_amfibie_waterbezoek_taxon` | 9.100 | taxonbereik waterbezoek | behouden |
| `ndff_amfibie_waterfamilie` | 50 | waterlocatiefamilie | behouden |
| `ndff_amfibie_watergeometrie` | 52 | geometrie waterlocatie | behouden |
| `ndff_ravon_n2000_monsterlocatieproxy` | 25 | gereconstrueerde monsterlocatie | behouden |
| `ndff_ravon_n2000_recordselectie` | 67 | selectie geleverde records | behouden |

### Bospaddenstoelen, mossen en korstmossen

| Tabel | Records | Functie | Voorlopig |
|---|---:|---|---|
| `ndff_bospaddenstoel_bezoek` | 110 | bezoek | behouden |
| `ndff_bospaddenstoel_bezoek_taxon` | 2.934 | taxonbereik bezoek | behouden |
| `ndff_bospaddenstoel_doelbereik` | 76 | beoogd taxonbereik | behouden |
| `ndff_bospaddenstoel_geometrie` | 6 | meetgeometrie | behouden |
| `ndff_bospaddenstoel_jaar_taxon` | 977 | jaar–taxoncombinatie | behouden |
| `ndff_bospaddenstoel_meetpunt` | 3 | meetpunt | behouden |
| `ndff_bospaddenstoel_recordselectie` | 982 | selectie geleverde records | behouden |
| `ndff_bospaddenstoel_verspreiding_bezoek` | 2 | verspreidingsbezoek | behouden |
| `ndff_bospaddenstoel_verspreiding_bezoek_taxon` | 14 | taxonbereik verspreidingsbezoek | behouden |
| `ndff_bospaddenstoel_verspreiding_recordselectie` | 14 | selectie verspreidingsrecords | behouden |
| `ndff_korstmos_bezoek` | 32 | bezoek | behouden |
| `ndff_korstmos_bezoek_taxon` | 960 | taxonbereik bezoek | behouden |
| `ndff_korstmos_doelbereik` | 30 | beoogd taxonbereik | behouden |
| `ndff_korstmos_meetlocatie` | 12 | meetlocatie | behouden |
| `ndff_korstmos_recordselectie` | 364 | selectie geleverde records | behouden |
| `ndff_mos_datumcluster` | 21 | gereconstrueerd bezoekcluster | behouden |
| `ndff_mos_doelbereik` | 111 | beoogd taxonbereik | behouden |
| `ndff_mos_inventarisatie` | 7 | inventarisatie | behouden |
| `ndff_mos_inventarisatie_taxon` | 777 | taxonbereik inventarisatie | behouden |
| `ndff_mos_recordselectie` | 376 | selectie geleverde records | behouden |

### Zoogdieren en braakballen

| Tabel | Records | Functie | Voorlopig |
|---|---:|---|---|
| `ndff_braakbal_hokjaar` | 37 | hok–jaar-eenheid | behouden |
| `ndff_braakbal_hokjaar_taxon` | 226 | taxonbereik hok–jaar | behouden |
| `ndff_braakbal_recordselectie` | 389 | selectie geleverde records | behouden |
| `ndff_daz_bmp_bezoek` | 1.475 | gereconstrueerd bezoek uit gecombineerde context | apart beoordelen |
| `ndff_daz_bmp_bezoek_taxon` | 10.374 | taxonbereik bezoek | apart beoordelen |
| `ndff_daz_bmp_recordkandidaat` | 5.404 | kandidaatselectie | apart beoordelen |
| `ndff_daz_bmp_recordselectie` | 10.670 | selectie geleverde records | apart beoordelen |
| `ndff_konijn_hokdatum_taxon` | 5.084 | hok–datum–taxoncombinatie | behouden |
| `ndff_konijn_recordselectie` | 5.809 | selectie geleverde records | behouden |
| `ndff_otter_bever_hokjaar` | 1 | hok–jaar-eenheid | behouden |
| `ndff_otter_bever_hokjaar_taxon` | 1 | taxonbereik hok–jaar | behouden |
| `ndff_otter_bever_recordselectie` | 3 | selectie geleverde records | behouden |

`ndff_daz_bmp_*` combineert in de naam een taxon, een telmethode en de
NDFF-leveringslaag. Dat kan correct zijn, maar is zonder aanvullende semantische
controle niet vanzelfsprekend. Daarom is deze kleine familie een gerichte
vervolgkandidaat, zonder nu al een nieuwe naam te kiezen.

### Flora en overige vegetatiekaders

| Tabel | Records | Functie | Voorlopig |
|---|---:|---|---|
| `ndff_florbase_doelbereik` | 857 | beoogd taxonbereik | behouden |
| `ndff_florbase_inventarisatie` | 183 | inventarisatie | behouden |
| `ndff_florbase_inventarisatie_taxon` | 101.126 | taxonbereik inventarisatie | behouden |
| `ndff_florbase_recordselectie` | 21.161 | selectie geleverde records | behouden |
| `ndff_hns_doelbereik` | 703 | beoogd taxonbereik | behouden |
| `ndff_hns_hok_jaar_taxon` | 8.436 | hok–jaar–taxoncombinatie | behouden |
| `ndff_hns_inventarisatie` | 26 | gereconstrueerde inventarisatie | behouden |
| `ndff_hns_inventarisatie_taxon` | 16.169 | taxonbereik inventarisatie | behouden |
| `ndff_hns_recordselectie` | 4.569 | selectie geleverde records | behouden |

### Vlinders, libellen en overige insectenroutes

| Tabel | Records | Functie | Voorlopig |
|---|---:|---|---|
| `ndff_libel_bezoek` | 461 | bezoek | behouden |
| `ndff_libel_bezoek_taxon` | 13.173 | taxonbereik bezoek | behouden |
| `ndff_libel_routefamilie` | 9 | routefamilie | behouden |
| `ndff_libel_routegeometrie` | 18 | routegeometrie | behouden |
| `ndff_lmfa_bezoek` | 124 | bezoek | behouden |
| `ndff_lmfa_bezoek_taxon` | 9.300 | taxonbereik bezoek | behouden |
| `ndff_lmfa_doelsoort` | 75 | doelsoort | behouden |
| `ndff_lmfa_recordselectie` | 5.980 | selectie geleverde records | behouden |
| `ndff_lmfa_route` | 30 | route | behouden |
| `ndff_nachtvlinder_hokjaar` | 5 | hok–jaar-eenheid | behouden |
| `ndff_nachtvlinder_hokjaar_taxon` | 84 | taxonbereik hok–jaar | behouden |
| `ndff_nachtvlinder_recordselectie` | 596 | selectie geleverde records | behouden |
| `ndff_vliesvleugel_bezoek` | 217 | bezoek | behouden |
| `ndff_vliesvleugel_bezoek_taxon` | 1.302 | taxonbereik bezoek | behouden |
| `ndff_vliesvleugel_routefamilie` | 2 | routefamilie | behouden |
| `ndff_vliesvleugel_routegeometrie` | 40 | routegeometrie | behouden |
| `ndff_vlinder_bezoek` | 3.126 | bezoek | behouden |
| `ndff_vlinder_bezoek_taxon` | 102.489 | taxonbereik bezoek | behouden |
| `ndff_vlinder_route_identificatie` | 11 | identificatie bronroute | behouden |
| `ndff_vlinder_routefamilie` | 11 | routefamilie | behouden |
| `ndff_vlinder_routegeometrie` | 455 | routegeometrie | behouden |

### Reptielen, vleermuizen, vissen en weekdieren

| Tabel | Records | Functie | Voorlopig |
|---|---:|---|---|
| `ndff_habslak_hokjaar` | 66 | hok–jaar-eenheid | behouden |
| `ndff_habslak_monster` | 251 | monster | behouden |
| `ndff_habslak_monster_taxon` | 1.730 | taxonbereik monster | behouden |
| `ndff_habslak_recordselectie` | 2.772 | selectie geleverde records | behouden |
| `ndff_poldervis_bezoek` | 6 | bezoek | behouden |
| `ndff_poldervis_bezoek_taxon` | 19 | taxonbereik bezoek | behouden |
| `ndff_poldervis_recordselectie` | 20 | selectie geleverde records | behouden |
| `ndff_poldervis_waterlocatie` | 3 | waterlocatie | behouden |
| `ndff_reptiel_bezoek` | 660 | bezoek | behouden |
| `ndff_reptiel_bezoek_taxon` | 1.320 | taxonbereik bezoek | behouden |
| `ndff_reptiel_routefamilie` | 14 | routefamilie | behouden |
| `ndff_reptiel_routegeometrie` | 71 | routegeometrie | behouden |
| `ndff_vleermuis_bezoek` | 44 | bezoek | behouden |
| `ndff_vleermuis_bezoek_taxon` | 242 | taxonbereik bezoek | behouden |
| `ndff_vleermuis_recordselectie` | 2.624 | selectie geleverde records | behouden |
| `ndff_vleermuis_routefamilie` | 2 | routefamilie | behouden |
| `ndff_vleermuis_routegeometrie` | 2.023 | routegeometrie | behouden |

### Brede tellingen en losse protocolfamilies

| Tabel | Records | Functie | Voorlopig |
|---|---:|---|---|
| `ndff_kwartiertelling_interval_soortgroep` | 18 | soortgroepbereik interval | behouden |
| `ndff_kwartiertelling_interval_taxon` | 49 | taxonbereik interval | behouden |
| `ndff_kwartiertelling_recordselectie` | 102 | selectie geleverde records | behouden |
| `ndff_kwartiertelling_telinterval` | 17 | telinterval | behouden |
| `ndff_liveatlas_bezoek` | 64 | bezoek | behouden |
| `ndff_liveatlas_bezoek_soortgroep` | 87 | soortgroepbereik bezoek | behouden |
| `ndff_liveatlas_bezoek_taxon` | 169 | taxonbereik bezoek | behouden |
| `ndff_liveatlas_recordselectie` | 231 | selectie geleverde records | behouden |
| `ndff_tuintelling_geometrie` | 6 | tuingeometrie | behouden |
| `ndff_tuintelling_periode_soortgroep` | 213 | soortgroepbereik telperiode | behouden |
| `ndff_tuintelling_periode_soortgroep_taxon` | 1.645 | taxonbereik telperiode | behouden |
| `ndff_tuintelling_recordselectie` | 309 | selectie geleverde records | behouden |
| `ndff_tuintelling_telperiode` | 125 | telperiode | behouden |
| `ndff_tuintelling_tuinvakfamilie` | 3 | tuinvakfamilie | behouden |
| `ndff_zeereep_bezoek` | 322 | bezoek | behouden |
| `ndff_zeereep_bezoek_taxon` | 1.932 | taxonbereik bezoek | behouden |
| `ndff_zeereep_kilometerhok` | 42 | kilometerhok | behouden |

## Technische afhankelijkheden buiten de drie gebruikersinterfaces

Een fysieke naamswijziging moet ten minste deze ketens meenemen:

1. foreign keys binnen de tabelgroepen en naar onder meer `plots`;
2. de views `v_externe_ecologie_analyse`,
   `v_meijendel_sovon_plot_actueel`, `v_ndff_analysebesluit_actueel` en
   `v_analyse_catalogus`;
3. beveiligde onderzoeksviews in `Meijendel_ndff_secure` die de tien hierboven
   genoemde NDFF-tabellen gebruiken;
4. import- en auditscripts onder `gis/scripts/`, in het bijzonder de
   protocolkwaliteit- en ruimtelijke-lagenketen;
5. analysescripts die NDFF- of Vangblikgegevens doelgericht lezen;
6. `scripts/validate_meijendel_export.sh`, dat
   `ndff_open_waarneming` expliciet als verplichte exporttabel controleert;
7. de gegenereerde dump `Meijendel.sql` en iedere releasevalidatie die schema
   en kernrijtellingen vergelijkt.

## Veilige volgende stap

De inventaris rechtvaardigt geen brede hernoemactie. De kleinste veilige
vervolgstap is een naamgevingsbesluit voor uitsluitend de vier
`externe_ecologie_*`-tabellen. Die familie is geïsoleerd van website, Shiny en
dashboard en heeft één overzichtelijke view als directe afnemer. Daarna kan een
reversibel migratieplan worden gemaakt met oude→nieuwe namen, aangepaste view,
scriptverwijzingen, dumpcontrole en rollback.

`vangblik*` kan blijven staan. Voor `ndff_*` is eerst alleen een gerichte
semantische beoordeling van `ndff_sovon_*` en `ndff_daz_bmp_*` zinvol; de rest
is als leverings- en reconstructielaag coherenter dan de naam op het eerste
gezicht suggereert.
