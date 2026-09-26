# Meijendel: tabelinventaris en voorstel voor naamgeving

Stand: 26 september 2026. Dit document beschrijft de fysieke tabellen in de
levende lokale database `Meijendel`; het verandert geen tabellen, gegevens,
views of applicatiecode.

## Voorgestelde richting

**Voorstel ter beoordeling; geen migratiebesluit.** Uitwerking op 26 september
2026, met aanvullende read-only controles op dezelfde avond. De gebruiker wil
herkenbare tabelfamilies per soortgroep en meetmethode, waarin rechtstreekse
leveringen van bronorganisaties de huidige NDFF-informatie kunnen verrijken.
Vogels mogen hun bestaande structuur behouden. De provinciale PQ's horen
uitdrukkelijk bij deze beoordeling. Website, dashboard en Shiny moeten goed
blijven functioneren; nieuwe views zijn geen oplossing voor het overzicht.

De gebruiker heeft het behoud van `pq_*` en `vangblik*` inmiddels inhoudelijk
geaccordeerd, met de uitdrukkelijke voorwaarde dat PQ-gegevens uit andere
bronnen de `pq_*`-structuur kunnen aanvullen. Deze voorwaarde is hieronder
uitgewerkt; er is nog geen schema- of gegevensmigratie uitgevoerd.

Het uitgangspunt is het voorstel van de gebruiker: verwijder `ndff_` uit de
tabelnamen en beoordeel daarna waar andere bronnen inhoudelijk kunnen
aansluiten. De live naamcontrole vindt 145 vrije doelnamen voor 146 tabellen.
De uitzondering is `ndff_soorten`: `soorten` bestaat al en is de
vogelgerichte referentie van de applicaties. Die twee tabellen blijven in de
eerste naamswijziging afzonderlijk bestaan.

| Onderdeel | Voorstel | Gevolg |
|---|---|---|
| 145 NDFF-tabellen, uitgezonderd `ndff_soorten` | Alleen het eerste voorvoegsel `ndff_` verwijderen | Bijvoorbeeld `libel_bezoek`, `protocol`, `sovon_plot` en `open_waarneming`; inhoud en sleutels blijven gelijk. |
| `ndff_soorten` en bestaande `soorten` | Beide voorlopig onder hun huidige naam behouden | Geen naamconflict en geen vervanging van vogel-ID's; gezamenlijke taxonomie afzonderlijk ontwerpen. |
| Vier `externe_ecologie_*`-tabellen | `ecologie_dataset`, `ecologie_event`, `ecologie_resultaat`, `ecologie_overlap` | Een kortere naam voor het bestaande generieke model. Dat bevat na hernoeming nog steeds uitsluitend de huidige zes datasets. |
| Zes `vangblik*`-tabellen en de bestaande `pq_*`-tabellen | Namen en meetstructuur behouden | De namen benoemen al een meetmethode; opname, vangstevent en resultaat blijven herkenbaar. |
| 26 soortgroepindexen binnen de 145 NDFF-tabellen | Eerst alleen hernoemen; later afzonderlijk afbouwen | De inhoud is exact reproduceerbaar uit de bestaande soortgroepkoppeltabel. Geen verwijdering in de naamswijziging. |

Dit geeft een complete naamregel voor de eerste 156 geïnventariseerde tabellen:
149 voorgestelde naamswijzigingen en zeven behouden namen. De zeven nu
meegenomen provinciale PQ-tabellen behouden eveneens hun naam. Het volledige
voorstel omvat daarmee 163 fysieke tabellen: 149 hernoemen en veertien
behouden. Alle 149 doelnamen zijn op het controlemoment vrij. Het aantal
fysieke tabellen blijft bij deze
naamswijziging 248. De precieze oude en voorgestelde naam staat per tabel
hieronder.

Naamgeving en inhoudelijke samenvoeging zijn afzonderlijke ingrepen. Een
naamswijziging maakt bijvoorbeeld `libel_bezoek` nog niet geschikt voor
Vangblikvangsten of een willekeurige andere libellenlevering. Eerst moeten
herkomst, sleutels, meeteenheid, methode, inspanning en nulregels passen.

Drie benaderingen zijn afgewogen: alleen namen verbeteren is de kleinste
ingreep; alle brongegevens meteen in één model onderbrengen raakt te veel
verschillende betekenissen tegelijk; namen verbeteren en daarna gericht
gemeenschappelijke referenties en passende meetstructuren verbinden is hier
het aanbevolen doelbeeld.

## Grenzen van de applicatiecontrole

De oorspronkelijke drie onderzochte tabelfamilies zijn niet rechtstreeks
gekoppeld aan de publieke website, het reguliere Shiny-dashboard of het openbare
HTML-dashboard:

| Afnemer | Direct gebruik van de 156 tabellen | Controle |
|---|---:|---|
| FastAPI/Jinja-website | nee | Geen tabelnamen aangetroffen in de Python-applicatiecode. |
| Reguliere Shiny-app | nee | De vaste SQL-cachelijst in `shiny_meijendel/helpers.R` bevat geen van deze 156 tabellen. De later toegevoegde PQ-scope is wel aangesloten. |
| Openbaar dashboard | nee | De TRIM-, MSI- en dashboardketen gebruikt kern- en afgeleide CSV-tabellen, niet deze drie families. |
| Optionele lokale NDFF-module in Shiny | niet rechtstreeks | De module leest drie views in `Meijendel_ndff_secure`; die drie views gebruiken uitsluitend tabellen in dat beveiligde schema. Andere, niet door deze module gelezen onderzoeksviews verwijzen wel naar tien `ndff_*`-tabellen. |

Dit zijn bevindingen uit de onderzochte lokale broncode, SQL-cachelijst en
database-afhankelijkheden; geen uitgevoerde migratieproef of garantie voor
productie. Ook dynamisch opgebouwde SQL, gegenereerde bestanden en de
dump/cacheketen moeten worden meegenomen. Foreign keys, bestaande views,
import- en auditscripts, exportvalidatie en beveiligde onderzoeksviews moeten
na een migratie dezelfde inhoud blijven opleveren. Er worden geen nieuwe
views of compatibiliteitsviews voorgesteld.

## Omvang en afbakening

De levende lokale MySQL-database bevat op het meetmoment 248 fysieke tabellen.
De eerste inventaris omvat daarvan 156 tabellen:

- 146 tabellen met voorvoegsel `ndff_`;
- 4 tabellen met voorvoegsel `externe_ecologie_`;
- 6 tabellen met voorvoegsel `vangblik`.

Daar komen in dit voorstel zeven provinciale `pq_*`-tabellen bij. Hun namen,
aantallen en bestaande applicatiekoppelingen staan in de afzonderlijke
PQ-paragraaf. De conclusie over ontbrekend direct applicatiegebruik geldt dus
uitsluitend voor de eerste 156 tabellen, niet voor de uitgebreide scope.

De oorspronkelijke 156 rijtellingen zijn exacte `COUNT(*)`-uitkomsten uit de
levende lokale database op 26 september 2026 om 22:28 uur. De uitgebreidere
controle later die avond omvat ook de zeven PQ-tabellen en de zes externe
datasets met hun eventjaren. De Vangblikreeks omvat 37.770 events van 8 maart
1953 tot en met 16 maart 1960, verdeeld over acht kalenderjaren. De inhoudelijke
periode is niet voor iedere NDFF-reconstructietabel afzonderlijk onderzocht.
De rijtellingen dienen als technische nulmeting, niet als oordeel over de
volledigheid of bruikbaarheid van een meetreeks.

## Leeswijzer bij de namen

De kolom **Voorgestelde naam** vervangt de eerdere voorlopige labels
“behouden”, “kandidaat” en “apart beoordelen”. Die eerdere labels waren te
behoudend: technische afhankelijkheden vragen om een gecontroleerde migratie,
maar bepalen niet welke naam inhoudelijk het duidelijkst is.

De huidige NDFF-tabellen bevatten een levering of een reconstructie daaruit.
Na hernoeming blijft die herkomst bestaan. Oorspronkelijke bronhouder,
aanleverroute en bewerkingsversie moeten herkenbaar blijven in de aanwezige
bronvelden, importregistratie en reeksmetadata. Het weghalen van `ndff_`
verandert geen bronhouder, rechten, analysetoelating of beveiligingsgrens.

## Externe ecologie

Deze vier tabellen vormen één generiek model: dataset → event → resultaat, met
een afzonderlijke overlapregistratie. Zij hebben onderlinge foreign keys en
worden samen ontsloten door `v_externe_ecologie_analyse`. Import en
overlapaudit verbinden deze familie al met NDFF en provinciale PQ. In de
onderzochte website-, dashboard- en reguliere Shiny-code zijn geen directe
tabelverwijzingen gevonden. Het voorstel is uitsluitend `externe_` te
schrappen; de zes datasets worden daarmee niet inhoudelijk samengevoegd met
de andere families.

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `externe_ecologie_dataset` | 6 | datasetregister | `ecologie_dataset` |
| `externe_ecologie_event` | 10.994 | meet- of waarnemingsevent | `ecologie_event` |
| `externe_ecologie_resultaat` | 98.916 | resultaat per event | `ecologie_resultaat` |
| `externe_ecologie_overlap` | 87.053 | overlap- en herkomstcontrole | `ecologie_overlap` |

## Vangblik

Dit is een afgebakende, bron- en methodeherkenbare familie. De zes tabellen
hebben geen databaseview en geen actuele koppeling met website, Shiny of
dashboard. Wel lezen analysescripts en het ruimtelijke-lagen-importscript delen
van deze familie. `vangblik` is daarom geen problematisch voorvoegsel en kan
worden behouden.

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `vangblik_import_batch` | 1 | importregistratie | `vangblik_import_batch` |
| `vangblik_locatieversie` | 135 | versie van vanglocatie | `vangblik_locatieversie` |
| `vangblik_event` | 37.770 | vangstevent, 1953–1960 | `vangblik_event` |
| `vangblik_event_plot` | 37.770 | koppeling event–Meijendelplot | `vangblik_event_plot` |
| `vangblik_soorten` | 275 | bronspecifieke taxonomie | `vangblik_soorten` |
| `vangblik_vangst` | 60.560 | vangstresultaat per event en soort | `vangblik_vangst` |

## NDFF: kern, protocol en beslislaag

Deze tabellen zijn de centrale, technisch sterk verknoopte laag. Vooral
`ndff_open_waarneming` en `ndff_protocol` hebben veel verwijzende tabellen.
Tien tabellen worden bovendien gebruikt door beveiligde onderzoeksviews:
`ndff_analysebesluit`, `ndff_open_pq_koppeling`,
`ndff_open_ruimtelijke_beoordeling`, `ndff_open_waarneming_protocol`,
`ndff_protocol`, `ndff_protocol_soort_geschiktheid`,
`ndff_protocol_soortgroep_geschiktheid`, `ndff_snl_waarneming_context`,
`ndff_open_leveringsverrijking` en `ndff_open_waarneming`.

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `ndff_open_import_batch` | 1 | registratie NDFF-open levering | `open_import_batch` |
| `ndff_open_waarneming` | 810.830 | centrale geleverde waarneming | `open_waarneming` |
| `ndff_soorten` | 9.828 | taxonomie van de levering | `ndff_soorten` |
| `ndff_open_soortgroep_koppeling` | 811.063 | waarneming–soortgroep | `open_soortgroep_koppeling` |
| `ndff_open_waarneming_protocol` | 810.830 | protocolduiding per waarneming | `open_waarneming_protocol` |
| `ndff_open_leveringsverrijking` | 14.420 | verrijking op geleverde records | `open_leveringsverrijking` |
| `ndff_open_ruimtelijke_beoordeling` | 810.830 | ruimtelijke toelatingscontrole | `open_ruimtelijke_beoordeling` |
| `ndff_open_pq_koppeling` | 1.621.660 | kandidaatkoppelingen met PQ | `open_pq_koppeling` |
| `ndff_protocol` | 54 | protocolregister | `protocol` |
| `ndff_protocol_gebruik` | 54 | vastgelegd toegestaan gebruik | `protocol_gebruik` |
| `ndff_protocol_mapping` | 91 | mapping bronprotocol–canoniek protocol | `protocol_mapping` |
| `ndff_protocol_soort_geschiktheid` | 664 | geschiktheid per protocol en soort | `protocol_soort_geschiktheid` |
| `ndff_protocol_soortgroep_geschiktheid` | 228 | geschiktheid per protocol en soortgroep | `protocol_soortgroep_geschiktheid` |
| `ndff_analysebesluit` | 4.160 | analysebesluit per bronselectie | `analysebesluit` |
| `ndff_snl_waarneming_context` | 6.273 | SNL-context bij geleverde waarneming | `snl_waarneming_context` |
| `ndff_sovon_plot` | 55 | SOVON-plotreferentie | `sovon_plot` |
| `ndff_sovon_plotversie` | 1 | versiebeheer SOVON-plotlaag | `sovon_plotversie` |

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

| Tabel | Records | Voorgestelde naam |
|---|---:|---|
| `ndff_amfibieen` | 12.982 | `amfibieen` |
| `ndff_dagvlinders` | 129.238 | `dagvlinders` |
| `ndff_eencelligen` | 156 | `eencelligen` |
| `ndff_geleedpotigen_overig` | 426 | `geleedpotigen_overig` |
| `ndff_insecten_overig` | 1.888 | `insecten_overig` |
| `ndff_kevers` | 8.079 | `kevers` |
| `ndff_korstmossen` | 28.643 | `korstmossen` |
| `ndff_kranswieren_wieren_algen` | 555 | `kranswieren_wieren_algen` |
| `ndff_kreeftachtigen` | 2.052 | `kreeftachtigen` |
| `ndff_libellen` | 32.325 | `libellen` |
| `ndff_microvlinders` | 22.849 | `microvlinders` |
| `ndff_mossen` | 32.353 | `mossen` |
| `ndff_nachtvlinders` | 72.978 | `nachtvlinders` |
| `ndff_ongewervelden_overig` | 1.760 | `ongewervelden_overig` |
| `ndff_reptielen` | 3.347 | `reptielen` |
| `ndff_schimmels` | 77.724 | `schimmels` |
| `ndff_snavelinsecten` | 7.819 | `snavelinsecten` |
| `ndff_spinachtigen` | 2.480 | `spinachtigen` |
| `ndff_sprinkhanen_en_krekels` | 9.163 | `sprinkhanen_en_krekels` |
| `ndff_vaatplanten` | 277.812 | `vaatplanten` |
| `ndff_vissen` | 1.280 | `vissen` |
| `ndff_vleermuizen` | 9.912 | `vleermuizen` |
| `ndff_vliegen_en_muggen` | 10.495 | `vliegen_en_muggen` |
| `ndff_vliesvleugeligen` | 12.365 | `vliesvleugeligen` |
| `ndff_weekdieren` | 13.043 | `weekdieren` |
| `ndff_zoogdieren_overig` | 39.339 | `zoogdieren_overig` |

## NDFF: gereconstrueerde meetstructuren

De resterende 103 `ndff_*`-tabellen reconstrueren bezoeken, locaties,
doelbereik, taxonlijsten en recordselecties uit de geleverde waarnemingen. De
tabellen zijn per protocolfamilie onderling via foreign keys verbonden; veel
`*_recordselectie`-tabellen verwijzen tevens naar
`ndff_open_waarneming`. Zij worden niet door de drie gebruikersinterfaces
gelezen, maar wel door import-, audit- en analysescripts.

Het voorstel is bij alle 103 tabellen het voorvoegsel `ndff_` te
verwijderen. Reconstructieversies, bronselecties, sleutels en methodeverschillen
blijven daarbij behouden. Deze tabellen blijven aanvankelijk reconstructies
van de huidige levering; een neutrale naam bewijst geen bronoverstijgende
geschiktheid.

### Amfibieën en RAVON

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `ndff_amfibie_bezoek` | 211 | bezoek | `amfibie_bezoek` |
| `ndff_amfibie_waterbezoek` | 1.300 | waterbezoek | `amfibie_waterbezoek` |
| `ndff_amfibie_waterbezoek_taxon` | 9.100 | taxonbereik waterbezoek | `amfibie_waterbezoek_taxon` |
| `ndff_amfibie_waterfamilie` | 50 | waterlocatiefamilie | `amfibie_waterfamilie` |
| `ndff_amfibie_watergeometrie` | 52 | geometrie waterlocatie | `amfibie_watergeometrie` |
| `ndff_ravon_n2000_monsterlocatieproxy` | 25 | gereconstrueerde monsterlocatie | `ravon_n2000_monsterlocatieproxy` |
| `ndff_ravon_n2000_recordselectie` | 67 | selectie geleverde records | `ravon_n2000_recordselectie` |

### Bospaddenstoelen, mossen en korstmossen

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `ndff_bospaddenstoel_bezoek` | 110 | bezoek | `bospaddenstoel_bezoek` |
| `ndff_bospaddenstoel_bezoek_taxon` | 2.934 | taxonbereik bezoek | `bospaddenstoel_bezoek_taxon` |
| `ndff_bospaddenstoel_doelbereik` | 76 | beoogd taxonbereik | `bospaddenstoel_doelbereik` |
| `ndff_bospaddenstoel_geometrie` | 6 | meetgeometrie | `bospaddenstoel_geometrie` |
| `ndff_bospaddenstoel_jaar_taxon` | 977 | jaar–taxoncombinatie | `bospaddenstoel_jaar_taxon` |
| `ndff_bospaddenstoel_meetpunt` | 3 | meetpunt | `bospaddenstoel_meetpunt` |
| `ndff_bospaddenstoel_recordselectie` | 982 | selectie geleverde records | `bospaddenstoel_recordselectie` |
| `ndff_bospaddenstoel_verspreiding_bezoek` | 2 | verspreidingsbezoek | `bospaddenstoel_verspreiding_bezoek` |
| `ndff_bospaddenstoel_verspreiding_bezoek_taxon` | 14 | taxonbereik verspreidingsbezoek | `bospaddenstoel_verspreiding_bezoek_taxon` |
| `ndff_bospaddenstoel_verspreiding_recordselectie` | 14 | selectie verspreidingsrecords | `bospaddenstoel_verspreiding_recordselectie` |
| `ndff_korstmos_bezoek` | 32 | bezoek | `korstmos_bezoek` |
| `ndff_korstmos_bezoek_taxon` | 960 | taxonbereik bezoek | `korstmos_bezoek_taxon` |
| `ndff_korstmos_doelbereik` | 30 | beoogd taxonbereik | `korstmos_doelbereik` |
| `ndff_korstmos_meetlocatie` | 12 | meetlocatie | `korstmos_meetlocatie` |
| `ndff_korstmos_recordselectie` | 364 | selectie geleverde records | `korstmos_recordselectie` |
| `ndff_mos_datumcluster` | 21 | gereconstrueerd bezoekcluster | `mos_datumcluster` |
| `ndff_mos_doelbereik` | 111 | beoogd taxonbereik | `mos_doelbereik` |
| `ndff_mos_inventarisatie` | 7 | inventarisatie | `mos_inventarisatie` |
| `ndff_mos_inventarisatie_taxon` | 777 | taxonbereik inventarisatie | `mos_inventarisatie_taxon` |
| `ndff_mos_recordselectie` | 376 | selectie geleverde records | `mos_recordselectie` |

### Zoogdieren en braakballen

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `ndff_braakbal_hokjaar` | 37 | hok–jaar-eenheid | `braakbal_hokjaar` |
| `ndff_braakbal_hokjaar_taxon` | 226 | taxonbereik hok–jaar | `braakbal_hokjaar_taxon` |
| `ndff_braakbal_recordselectie` | 389 | selectie geleverde records | `braakbal_recordselectie` |
| `ndff_daz_bmp_bezoek` | 1.475 | gereconstrueerd bezoek uit gecombineerde context | `daz_bmp_bezoek` |
| `ndff_daz_bmp_bezoek_taxon` | 10.374 | taxonbereik bezoek | `daz_bmp_bezoek_taxon` |
| `ndff_daz_bmp_recordkandidaat` | 5.404 | kandidaatselectie | `daz_bmp_recordkandidaat` |
| `ndff_daz_bmp_recordselectie` | 10.670 | selectie geleverde records | `daz_bmp_recordselectie` |
| `ndff_konijn_hokdatum_taxon` | 5.084 | hok–datum–taxoncombinatie | `konijn_hokdatum_taxon` |
| `ndff_konijn_recordselectie` | 5.809 | selectie geleverde records | `konijn_recordselectie` |
| `ndff_otter_bever_hokjaar` | 1 | hok–jaar-eenheid | `otter_bever_hokjaar` |
| `ndff_otter_bever_hokjaar_taxon` | 1 | taxonbereik hok–jaar | `otter_bever_hokjaar_taxon` |
| `ndff_otter_bever_recordselectie` | 3 | selectie geleverde records | `otter_bever_recordselectie` |

`ndff_daz_bmp_*` wordt `daz_bmp_*`, maar blijft de secundaire
reconstructie. Volgens het bestaande besluit is de oorspronkelijke
`sovon_avimap_*`-levering primair. De bestaande vervangings- en
conflictkoppeling blijft gelden: een naamswijziging mag de NDFF-reconstructie
niet naast de primaire SOVON-regel opnieuw laten meetellen.

### Flora en overige vegetatiekaders

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `ndff_florbase_doelbereik` | 857 | beoogd taxonbereik | `florbase_doelbereik` |
| `ndff_florbase_inventarisatie` | 183 | inventarisatie | `florbase_inventarisatie` |
| `ndff_florbase_inventarisatie_taxon` | 101.126 | taxonbereik inventarisatie | `florbase_inventarisatie_taxon` |
| `ndff_florbase_recordselectie` | 21.161 | selectie geleverde records | `florbase_recordselectie` |
| `ndff_hns_doelbereik` | 703 | beoogd taxonbereik | `hns_doelbereik` |
| `ndff_hns_hok_jaar_taxon` | 8.436 | hok–jaar–taxoncombinatie | `hns_hok_jaar_taxon` |
| `ndff_hns_inventarisatie` | 26 | gereconstrueerde inventarisatie | `hns_inventarisatie` |
| `ndff_hns_inventarisatie_taxon` | 16.169 | taxonbereik inventarisatie | `hns_inventarisatie_taxon` |
| `ndff_hns_recordselectie` | 4.569 | selectie geleverde records | `hns_recordselectie` |

### Vlinders, libellen en overige insectenroutes

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `ndff_libel_bezoek` | 461 | bezoek | `libel_bezoek` |
| `ndff_libel_bezoek_taxon` | 13.173 | taxonbereik bezoek | `libel_bezoek_taxon` |
| `ndff_libel_routefamilie` | 9 | routefamilie | `libel_routefamilie` |
| `ndff_libel_routegeometrie` | 18 | routegeometrie | `libel_routegeometrie` |
| `ndff_lmfa_bezoek` | 124 | bezoek | `lmfa_bezoek` |
| `ndff_lmfa_bezoek_taxon` | 9.300 | taxonbereik bezoek | `lmfa_bezoek_taxon` |
| `ndff_lmfa_doelsoort` | 75 | doelsoort | `lmfa_doelsoort` |
| `ndff_lmfa_recordselectie` | 5.980 | selectie geleverde records | `lmfa_recordselectie` |
| `ndff_lmfa_route` | 30 | route | `lmfa_route` |
| `ndff_nachtvlinder_hokjaar` | 5 | hok–jaar-eenheid | `nachtvlinder_hokjaar` |
| `ndff_nachtvlinder_hokjaar_taxon` | 84 | taxonbereik hok–jaar | `nachtvlinder_hokjaar_taxon` |
| `ndff_nachtvlinder_recordselectie` | 596 | selectie geleverde records | `nachtvlinder_recordselectie` |
| `ndff_vliesvleugel_bezoek` | 217 | bezoek | `vliesvleugel_bezoek` |
| `ndff_vliesvleugel_bezoek_taxon` | 1.302 | taxonbereik bezoek | `vliesvleugel_bezoek_taxon` |
| `ndff_vliesvleugel_routefamilie` | 2 | routefamilie | `vliesvleugel_routefamilie` |
| `ndff_vliesvleugel_routegeometrie` | 40 | routegeometrie | `vliesvleugel_routegeometrie` |
| `ndff_vlinder_bezoek` | 3.126 | bezoek | `vlinder_bezoek` |
| `ndff_vlinder_bezoek_taxon` | 102.489 | taxonbereik bezoek | `vlinder_bezoek_taxon` |
| `ndff_vlinder_route_identificatie` | 11 | identificatie bronroute | `vlinder_route_identificatie` |
| `ndff_vlinder_routefamilie` | 11 | routefamilie | `vlinder_routefamilie` |
| `ndff_vlinder_routegeometrie` | 455 | routegeometrie | `vlinder_routegeometrie` |

### Reptielen, vleermuizen, vissen en weekdieren

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `ndff_habslak_hokjaar` | 66 | hok–jaar-eenheid | `habslak_hokjaar` |
| `ndff_habslak_monster` | 251 | monster | `habslak_monster` |
| `ndff_habslak_monster_taxon` | 1.730 | taxonbereik monster | `habslak_monster_taxon` |
| `ndff_habslak_recordselectie` | 2.772 | selectie geleverde records | `habslak_recordselectie` |
| `ndff_poldervis_bezoek` | 6 | bezoek | `poldervis_bezoek` |
| `ndff_poldervis_bezoek_taxon` | 19 | taxonbereik bezoek | `poldervis_bezoek_taxon` |
| `ndff_poldervis_recordselectie` | 20 | selectie geleverde records | `poldervis_recordselectie` |
| `ndff_poldervis_waterlocatie` | 3 | waterlocatie | `poldervis_waterlocatie` |
| `ndff_reptiel_bezoek` | 660 | bezoek | `reptiel_bezoek` |
| `ndff_reptiel_bezoek_taxon` | 1.320 | taxonbereik bezoek | `reptiel_bezoek_taxon` |
| `ndff_reptiel_routefamilie` | 14 | routefamilie | `reptiel_routefamilie` |
| `ndff_reptiel_routegeometrie` | 71 | routegeometrie | `reptiel_routegeometrie` |
| `ndff_vleermuis_bezoek` | 44 | bezoek | `vleermuis_bezoek` |
| `ndff_vleermuis_bezoek_taxon` | 242 | taxonbereik bezoek | `vleermuis_bezoek_taxon` |
| `ndff_vleermuis_recordselectie` | 2.624 | selectie geleverde records | `vleermuis_recordselectie` |
| `ndff_vleermuis_routefamilie` | 2 | routefamilie | `vleermuis_routefamilie` |
| `ndff_vleermuis_routegeometrie` | 2.023 | routegeometrie | `vleermuis_routegeometrie` |

### Brede tellingen en losse protocolfamilies

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `ndff_kwartiertelling_interval_soortgroep` | 18 | soortgroepbereik interval | `kwartiertelling_interval_soortgroep` |
| `ndff_kwartiertelling_interval_taxon` | 49 | taxonbereik interval | `kwartiertelling_interval_taxon` |
| `ndff_kwartiertelling_recordselectie` | 102 | selectie geleverde records | `kwartiertelling_recordselectie` |
| `ndff_kwartiertelling_telinterval` | 17 | telinterval | `kwartiertelling_telinterval` |
| `ndff_liveatlas_bezoek` | 64 | bezoek | `liveatlas_bezoek` |
| `ndff_liveatlas_bezoek_soortgroep` | 87 | soortgroepbereik bezoek | `liveatlas_bezoek_soortgroep` |
| `ndff_liveatlas_bezoek_taxon` | 169 | taxonbereik bezoek | `liveatlas_bezoek_taxon` |
| `ndff_liveatlas_recordselectie` | 231 | selectie geleverde records | `liveatlas_recordselectie` |
| `ndff_tuintelling_geometrie` | 6 | tuingeometrie | `tuintelling_geometrie` |
| `ndff_tuintelling_periode_soortgroep` | 213 | soortgroepbereik telperiode | `tuintelling_periode_soortgroep` |
| `ndff_tuintelling_periode_soortgroep_taxon` | 1.645 | taxonbereik telperiode | `tuintelling_periode_soortgroep_taxon` |
| `ndff_tuintelling_recordselectie` | 309 | selectie geleverde records | `tuintelling_recordselectie` |
| `ndff_tuintelling_telperiode` | 125 | telperiode | `tuintelling_telperiode` |
| `ndff_tuintelling_tuinvakfamilie` | 3 | tuinvakfamilie | `tuintelling_tuinvakfamilie` |
| `ndff_zeereep_bezoek` | 322 | bezoek | `zeereep_bezoek` |
| `ndff_zeereep_bezoek_taxon` | 1.932 | taxonbereik bezoek | `zeereep_bezoek_taxon` |
| `ndff_zeereep_kilometerhok` | 42 | kilometerhok | `zeereep_kilometerhok` |

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

## Doelbeeld: gegevens per soortgroep en meetmethode

De neutrale tabelnaam moet ruimte bieden voor verrijking door de oorspronkelijke
bronorganisatie. Bij vlinders en libellen blijven locaties/routes, bezoeken en
taxonresultaten herkenbare onderdelen. De oorspronkelijke levering en een
afgeleide reconstructie blijven herleidbaar. Zij hoeven niet eeuwig in twee
losse analytische werelden te blijven bestaan.

| Inhoud | Herkenbare tabelfamilie | Wat kan daarin aansluiten? |
|---|---|---|
| Dagvlinderroutes | `vlinder_routefamilie`, `vlinder_routegeometrie`, `vlinder_bezoek`, `vlinder_bezoek_taxon` | Oorspronkelijke route-ID's, volledige bezoeken, deelname en doelbereik uit een rechtstreekse levering; na expliciete koppeling met de reconstructie. |
| Libellenroutes | `libel_routefamilie`, `libel_routegeometrie`, `libel_bezoek`, `libel_bezoek_taxon` | Rechtstreekse route- en bezoekgegevens die dezelfde meetstructuur beschrijven. |
| Andere protocollen | De overeenkomstige namen zonder `ndff_`, zoals `amfibie_waterbezoek` en `korstmos_bezoek` | Aanvullingen per protocol; een waterbezoek blijft onderscheiden van een routebezoek of hokinventarisatie. |
| Vegetatie en permanente quadraten | `pq_vegetatie_*` voor PQ-metingen uit alle passende bronnen; een bredere vegetatie-opnamefamilie alleen waar nodig | Zowel provinciale als andere leveringen kunnen bestaande PQ's verrijken of nieuwe gelokaliseerde PQ's toevoegen. Een LVD-opname krijgt alleen een bestaande PQ-identiteit wanneer die koppeling is vastgesteld. |
| Vangblikken | `vangblik_event`, `vangblik_vangst`, locaties en taxa | Rechtstreekse verrijking van deze vangstreeks. Hetzelfde event kan meerdere soortgroepen opleveren en wordt niet per soortgroep gekopieerd. |
| Collecties en overige ecologische resultaten | Voorgesteld `ecologie_dataset/event/resultaat/overlap` | Bronnen met dit generieke event–resultaatmodel. Museumexemplaren worden geen routebezoeken. |
| Vogels | Bestaande `soorten`, `territoria`, dagbezoeken en dagwaarnemingen | Behouden als expliciet geaccepteerde uitzondering. |

Een tabelfamilie per soortgroep betekent geen aparte tabel per afzonderlijke
soort. Taxa blijven gegevens binnen de familie. Evenmin wordt een gemengde
vangst of vegetatieopname opgesplitst in onafhankelijke events: samenhang tussen
soorten binnen hetzelfde monster blijft behouden.

Er zijn daarbij twee functies: de bronlaag bewaart wat is ontvangen, de
meetstructuur beschrijft welke routes, bezoeken, opnamen en resultaten bij
elkaar horen. Aanvullende leveranciers sluiten op dezelfde passende
meetstructuur aan via vastgelegde bronkoppelingen. Er komt niet voor iedere
leverancier weer een eigen analytische vlinder- of libellenfamilie. Een
vangst wordt evenmin gekopieerd naar meerdere soortgroeptabellen alleen om
haar vindbaar te maken; de taxonkoppeling verbindt haar met die soorten.

De 26 kale soortgroeptabellen, zoals het toekomstige `libellen`, zijn
aanvankelijk nog uitsluitend NDFF-selecties. Zij bevatten alleen
`waarneming_id`, verwijzend naar de centrale openbare waarnemingen.
Het zijn **geen** bronoverstijgende invoertabellen en ook geen volledige
soortgroepsregisters. Rechtstreekse aanvullingen horen in een passende
meetstructuur, niet blind in deze enkelkolomsindexen.

### Wat moet vóór de eerste rechtstreekse verrijking worden geregeld?

Een tabel hernoemen verandert de kolommen en sleutels niet. Veel reconstructietabellen
gebruiken nu een sleutel met `reconstructieversie` en lokaal afgeleide route-
of bezoek-ID's. Dat is nog geen algemene identiteit voor alle leveranciers.

Voor iedere te verrijken familie gelden daarom deze concrete eisen:

1. Leg per levering bronorganisatie, aanleverroute, oorspronkelijke dataset,
   versie, bestandshash en rechten vast. Hergebruik de aanwezige
   importregistraties en `analyse_datareeks`; bouw geen tweede gelijksoortige
   broncatalogus. De bestaande zes-datasetregistratie wordt niet door alleen
   hernoemen een register van alle bronnen.
2. Bewaar oorspronkelijke locatie-, route-, bezoek- en taxon-ID's binnen hun
   eigen bron en versie. Hetzelfde nummer uit twee leveringen is niet
   automatisch hetzelfde object. Geef de gemeenschappelijke meeteenheid een
   eigen stabiele identiteit en leg de gecontroleerde bronkoppeling vast.
3. Scheid een bevestigde bronmeting van een gereconstrueerde meting. Een
   nieuwe originele route-ID mag een bestaande afgeleide route identificeren,
   maar mag niet stilzwijgend een andere geometrie of bezoekgeschiedenis
   overschrijven. Bewaar de oorspronkelijke bewijsgrond en beslisversie.
4. Onderscheid vier uitkomsten: aanvullende metadata, nieuwe onafhankelijke
   meting, tweede levering van dezelfde meting, of inhoudelijk conflict.
   Leg bij een vervanging vast welk record voor welk gebruik primair is en
   behoud het secundaire bronrecord voor controle.
5. Neem meeteenheid en nulbetekenis mee. Bedekkingspercentage,
   vruchtlichaamklasse, vangstaantal en akoestische detectie zijn geen
   uitwisselbare aantallen. Een volledig bezoek kan nieuwe nullen
   onderbouwen; een extra positieve waarneming bewijst dat niet.
6. Toets toelating, overlap en resultaat vóór en na verrijking. De bestaande
   primaire provinciale PQ-reeks en primaire SOVON/AVIMAP-laag houden hun
   vastgelegde positie. Een naamswijziging geeft geen nieuw analysebesluit.

Een concreet toekomstscenario: een levering van De Vlinderstichting bevat een
oorspronkelijke route-ID en complete bezoeklijst. We koppelen die eerst aan
de bestaande routefamilie, bewaren het bron-ID, onderscheiden nog niet
geleverde bezoeken van reeds bekende bezoeken en herzien pas daarna het
doelbereik en eventuele nullen. De oorspronkelijke NDFF-regels blijven als
herkomstbewijs beschikbaar; zij tellen niet nogmaals mee naast dezelfde
oorspronkelijke telling. Dit is een ontwerpvoorbeeld, geen claim over de
inhoud van een nog te ontvangen levering of aanleiding voor een nieuw verzoek.

## Provinciale PQ's: expliciet onderdeel van het voorstel

Read-only momentopname 26 september 2026: de provinciale reeks bevat 254
PQ-locaties, 2.007 opnamen en 53.122 taxonregels; de opnamejaren lopen van
1981 tot en met 2025. De afgeleide tabel bevat 513 plot-jaarregels uit dezelfde
periode. Deze aantallen beschrijven de fysieke reeks, niet een nieuwe
ruimtelijke of analytische toelating.

| Tabel | Records | Functie | Voorgestelde naam |
|---|---:|---|---|
| `pq_vegetatie_import` | 1 | importregistratie voor de reeks 1981–2025 | `pq_vegetatie_import` |
| `pq_vegetatie_pq` | 254 | permanente meetlocaties van deze reeks | `pq_vegetatie_pq` |
| `pq_vegetatie_opname` | 2.007 | opname per meetlocatie en datum/jaar, 1981–2025 | `pq_vegetatie_opname` |
| `pq_vegetatie_opname_plot` | 1.336 | bestaande opname–SOVON-plotkoppelingen | `pq_vegetatie_opname_plot` |
| `pq_vegetatie_taxon` | 714 | soortenlijstreferenties voor de reeks | `pq_vegetatie_taxon` |
| `pq_vegetatie_waarneming` | 53.122 | bedekkingsresultaten per opname en taxon, 1981–2025 | `pq_vegetatie_waarneming` |
| `pq_plot_jaar_vegetatie` | 513 | afgeleide vegetatiekenmerken per vogelplot en jaar, 1981–2025 | `pq_plot_jaar_vegetatie` |

Het voorstel om deze namen te behouden is inhoudelijk: `pq` benoemt een
meeteenheid en geen leverancier. De provincienaam zit niet in de tabelnaam.
Het behoud is door de gebruiker geaccordeerd onder de voorwaarde dat ook
PQ-gegevens uit andere bronnen kunnen aansluiten. De provinciale reeks is
de bestaande basis, geen exclusieve toegangseis voor deze tabelfamilie.

Het huidige schema moet daarvoor gericht worden uitgebreid. `pq_nummer` is
nu een globale sleutel en het PQ-locatieregister verwijst naar één
importregistratie. Twee organisaties kunnen hetzelfde nummer voor
verschillende locaties gebruiken; andersom kunnen twee broncodes juist
dezelfde locatie of opname aanduiden. Alleen de huidige import herhalen
met een nieuwe bron is daarom nog geen veilige bronoverstijgende import.

De vereiste uitbreiding heeft de volgende betekenis:

- behoud de bestaande interne PQ-, opname- en taxon-ID's; leg daarnaast per
  bron/dataset en versie het oorspronkelijke PQ-nummer en opname-ID vast;
- laat meerdere bronidentificaties naar dezelfde interne PQ of opname
  verwijzen wanneer die gelijkheid is vastgesteld, met bron en bewijsgrond;
- voeg nieuwe, aantoonbaar lokaliseerbare permanente quadraten en werkelijk
  nieuwe opnamen toe met eigen interne identificaties;
- verrijk dezelfde opname met aanvullende metadata of taxoninformatie na
  inhoudelijke controle; registreer een tweede levering van hetzelfde
  bedekkingsresultaat als bronkoppeling in plaats van als extra resultaat;
- bewaar conflicterende waarden en de keuze voor de primaire waarde met
  herkomst, leveringsversie en validatiestatus. De eerdere status van een
  provinciale levering gaat niet automatisch over op een andere bron;
- behoud methode, bedekkingsschaal, soortenlijstversie, opnamedatum en
  locatiekwaliteit. Een eenmalige vegetatieopname zonder bewijs van een
  permanente meetlocatie wordt niet alleen vanwege haar bronlabel een PQ.

De technische migratie moet de huidige analyse-uitkomsten behouden. Na een
afzonderlijk beoordeelde inhoudelijke aanvulling mogen nieuwe of verbeterde
PQ-gegevens ook doorwerken in analyse, Shiny en website. Daarbij worden de
gewijzigde bronselectie en uitkomsten expliciet gevalideerd; de provinciale
selectie blijft als controlebasis reproduceerbaar. Het ontwerp bevriest de
inhoud dus niet permanent op de huidige provinciale levering.

De koppeling met de toepassingen is werkelijk aanwezig:

- Shiny leest `pq_plot_jaar_vegetatie` uit de dump en neemt de tabel op in de
  vooraf gebouwde cache. De kenmerken soortenrijkdom, bedekkingssom en Shannon
  worden via plot en jaar toegevoegd aan model- en omgevingsgegevens, onder
  meer bij multivariate analyse en occupancy. Bronstatus, importversie en
  soortenlijstversie worden ook getoond.
- De website leest bij kavels de bestaande view
  `website_plot_vegetatie_jaar`, die rechtstreeks naar
  `pq_plot_jaar_vegetatie` verwijst.
- De berekeningen lopen via de bestaande
  `pq_vegetatie_opname_metrics` en `pq_plot_jaar_vegetatie_berekend`.
  Exportvalidatie verlangt bovendien `pq_vegetatie_pq`.

Deze bestaande views zijn afhankelijkheden, geen voorgestelde nieuwe
overzichtslaag. Een eventuele latere verbreding van de fysieke
vegetatieopslag moet dezelfde provinciale selectie, kolommen en uitkomsten
voor deze afnemers blijven leveren. Het toevoegen van LVD aan de
Shiny-afleiding zonder afzonderlijk inhoudelijk besluit zou de betekenis van
de vegetatiekenmerken veranderen en hoort niet bij opschonen.

Een kale start- of HTTP-test is onvoldoende: Shiny leest de tabel met een
optionele parser; de website vangt een fout in de vegetatiequery af en kan dan
een leeg vegetatieonderdeel tonen. Vergelijk daarom de bestaande plot-jaarregels,
kenmerken, ontbrekende waarden en zichtbare bronvermelding vóór en na de
migratie. Een verdwenen vegetatieonderdeel is een regressie, ook bij HTTP 200.

## Soortinformatie: huidige sleutels en gemeenschappelijke koppeling

Onderstaande aantallen zijn exacte tellingen op 26 september 2026. De
referentietabellen hebben geen eigen waarnemingsperiode; waar mogelijk staat
de bijbehorende meetreeks erbij. Een referentierecord is niet vanzelfsprekend
één geaccepteerde biologische soort.

| Opslag | Omvang en bijbehorende reeks | Identificatie en betekenis |
|---|---|---|
| `soorten` | 628 referentieregels; vogelreferentie, onder meer voor territoria 1958–2025 | `id`, unieke EURING-code; 623 verschillende opgeslagen Latijnse naamwaarden. Bestaande applicatiesleutels behouden. |
| `ndff_soorten` | 9.828 referentieregels in de huidige openbare levering; geen eigen meetperiode | Unieke `soort_key`, berekend uit soortgroep, Nederlandse en wetenschappelijke naam; 9.825 verschillende wetenschappelijke naamwaarden. Dit is geen bronoverstijgende taxonomische sleutel. |
| `vangblik_soorten` | 275 referentieregels bij de vangstreeks 1953–1960 | Eigen ID en hash van wetenschappelijke naam plus taxonomische hiërarchie; geen gedeelde sleutel met NDFF. |
| `pq_vegetatie_taxon` | 714 referentieregels bij opnamen 1981–2025 | Eigen `taxon_id`, 714 gevulde `srtnum`-waarden en soortenlijstversie. Alle 714 koppelingen hebben nog de opgeslagen status `onbeoordeeld`; het officiële naamveld is bij alle 714 leeg, maar de Latijnse bronnaam is bij alle 714 beschikbaar. |
| `sovon_avimap_taxon` | 35 referentieregels bij 19.960 niet-vogelwaarnemingen uit 2009–2026 | Samengestelde sleutel batch–soortgroep–soortnummer. 28 regels verwijzen al naar `ndff_soorten`; zeven hebben een handmatige referentie zonder die foreign key. |
| `externe_ecologie_resultaat` | 98.916 resultaatregels uit zes datasets, samen 1875–2025; 2.894 verschillende opgeslagen wetenschappelijke naamwaarden | Soortnamen en taxonrang staan bij het resultaat, inclusief oorspronkelijke naam. Geen afzonderlijke soortentabel of gedeelde taxon-foreign-key. |

Daarnaast bestaan al `trait_taxon_mapping` (786 koppelingen voor 159
vogelsoorten; referentiemetadata zonder meetperiode) en
`ioc_euring_mapping` (nul regels op dit meetmoment). De eerste koppelt
vogeltraits aan hun bronnen; geen van beide is momenteel een algemene
verbinding tussen NDFF, Vangblik, PQ en externe ecologie.

Een letterlijke, hoofdlettergevoelige vergelijking met de opgeslagen
NDFF-naamwaarden geeft:

| Vergeleken verzameling | Eén gelijknamige NDFF-sleutel | Geen letterlijke match |
|---|---:|---:|
| 275 Vangblik-referentieregels, vangstreeks 1953–1960 | 95 | 180 |
| 714 PQ-referentieregels, opnamen 1981–2025 | 602 | 112 |
| 2.894 verschillende externe naamwaarden, resultaten 1875–2025 | 1.411 | 1.483 |

Voor deze drie vergelijkingen vond geen naam meerdere NDFF-sleutels.
Dit zijn uitsluitend naamovereenkomsten. Niet-gelijknamig betekent niet
“nieuwe soort”; synoniemen, auteursnamen, ondersoorten en verzamelgroepen
kunnen verschillen. Gelijknamig bewijst evenmin dat taxonconcept en rang
identiek zijn. De verschillen bevestigen dat uitsluitend
`ndff_soorten` hernoemen naar `soorten` geen integratie oplevert.

Het voorgestelde eindbeeld is een gedeelde taxonreferentie voor de
bronoverstijgende verbinding, met behoud van de broneigen identificaties:

- `taxon`: interne stabiele identificatie, naam, rang en expliciete
  taxonomische referentie/versie. Geen automatische gelijkstelling op naam.
- `taxon_bronkoppeling`: koppeling van bron, bronversie en brontaxonsleutel
  naar die referentie, met methode, bewijs en beoordelingsstatus.
  Een niet-beoordeelde of ambigue koppeling mag geen zekere identiteit
  suggereren. Een split/lump of bredere/engere determinatie wordt niet in een
  gedwongen één-op-één-koppeling geperst.

Beide namen zijn op het controlemoment vrij; het zijn voorgestelde toekomstige
tabellen en ze worden niet in de naamswijziging aangemaakt. Bestaande mappings,
waaronder de 28 SOVON–NDFF-koppelingen, worden eerst hergebruikt en gecontroleerd.
Vogels blijven hun huidige `soorten.id` gebruiken. Een eventuele koppeling
naar `taxon` ligt daarnaast en verandert hun applicatiecontract niet.
De bronnaam blijft altijd bewaard, ook wanneer een geaccepteerde naam wijzigt.

Voor externe ecologie moet de brontaxonidentiteit per dataset worden bepaald
uit de aanwezige bronmetadata, naam en rang. In de 98.916 bestaande
resultaat-JSON's komen de drie expliciet getoetste sleutels `taxonID`,
`taxonKey` en `acceptedNameUsageID` niet voor. Dat zegt alleen iets over
die opgeslagen velden; niet dat de oorspronkelijke bron geen identificaties
heeft. Een eventuele toekomstige verrijking begint daarom bij de reeds
aanwezige bronbestanden en metadata, niet bij een nieuwe externe uitvraag.

## Bestaande verbindingen en werkelijke vereenvoudiging

De vier externe tabellen zijn al verbonden met andere gegevenslagen. De
87.053 overlaprelaties hebben betrekking op externe resultaten met eventjaren
1950–2023: 73.806 mogelijke NDFF-relaties en 13.247 PQ-relaties, waarvan 8.034
`exact` en 5.213 `waarschijnlijk`. Dit zijn de bestaande geregistreerde
statussen, geen nieuwe beoordeling. Het aantal relaties is geen aantal unieke
metingen; een bronresultaat kan meerdere relaties hebben. Het weghalen van
een voorvoegsel creëert of verwijdert deze verbindingen niet.

De zes externe datasets blijven in hun eigen betekenis herkenbaar:

| Dataset | Events | Resultaten | Eventjaren |
|---|---:|---:|---|
| STOWA/Limnodata | 44 | 1.036 | 1992–2010 |
| ENDURE-helmduinfauna | 15 | 9.072 | 2018 |
| LVD | 3.437 | 81.310 | 1959–2015 |
| NMR-vlinders | 4.748 | 4.748 | 1955–2015 |
| Naturalis Botany | 1.881 | 1.881 | 1875–2025 |
| Naturalis Coleoptera | 869 | 869 | 1906–2023 |

De 26 soortgroepindexen zijn read-only in beide richtingen vergeleken met
`ndff_open_soortgroep_koppeling`, gefilterd op de betreffende soortgroep.
Alle 26 hebben nul extra en nul ontbrekende ID's. Deze controle betreft
volledige fysieke selecties van de huidige levering, geen afzonderlijke
periode- of geschiktheidsselectie. Na aanpassing van de import- en
auditafnemers kunnen deze kopieën dus eventueel vervallen zonder hun
lidmaatschapsinformatie te verliezen. Daarvoor zijn geen vervangende views
nodig: de bestaande koppeltabel bevat de informatie al.

Dat blijft een afzonderlijk besluit. Het huidige projectbesluit schrijft
juist fysieke soortgroeptabellen voor. De huidige opdracht verandert dat
besluit niet en verwijdert geen tabel. Ook een naam als `libellen` mag niet
de verwachting wekken dat deze kopie alle rechtstreekse libellenleveringen
bevat. Op termijn geven de `libel_*`-meetstructuur en de bron-/taxonkoppeling
een betere toegang dan zo'n NDFF-only kopie.

## Migratiegevolgen en concrete uitvoervolgorde

**Eerst een samenhangende naamsmigratie voorbereiden, dan gericht verrijken.**
De complete naamkaart staat hierboven. De aanbevolen eerste technische proef
omvat de vier `ndff_libel_*`-tabellen: routefamilie, routegeometrie, bezoek en
bezoek_taxon worden `libel_*`. Daarmee wordt één complete meetfamilie
herkenbaar, met een afgebakende interne relatiestructuur en zonder direct
gebruik door de drie gebruikersinterfaces. Schema, import, audits en overige
verwijzingen naar deze vier namen moeten gezamenlijk mee.

De gedeelde `ndff_sovon_plot` en `ndff_sovon_plotversie` worden volgens dezelfde
naamkaart `sovon_plot` en `sovon_plotversie`, maar zijn vanwege hun vele
ruimtelijke afnemers geen eenvoudigere eerste proef alleen omdat het twee
tabellen zijn. Daarna volgen in gecontroleerde groepen de overige namen;
de naamkaart hoeft niet als één grote live-ingreep te worden uitgevoerd.

De kleinste inhoudelijke vervolgstap na naamgeving is één meetfamilie
geschikt maken voor aantoonbaar passende rechtstreekse bronverrijking. Vlinders
of libellen liggen voor de hand zodra de inhoud van de verwachte levering
dat rechtvaardigt. Reeds ontvangen gegevens en verzonden verzoeken worden
eerst gecontroleerd; dit ontwerp vraagt geen nieuwe levering aan.

| Te controleren onderdeel | Concreet gevolg van de naamkaart |
|---|---|
| Fysieke schema's en relaties | Alle veranderde objectnamen en foreign keys controleren; indexes, PK's, kolommen en bron-ID's inhoudelijk gelijk houden. Geen blind zoek-en-vervang op iedere tekenreeks `ndff_`. |
| Huidige databaseviews | Definities aanpassen waar ze naar hernoemde tabellen verwijzen. Bestaande viewnamen behouden om onnodige wijzigingen bij afnemers te voorkomen. Geen nieuwe compatibiliteitsviews. |
| Databasegedrag en rechten | Eventuele triggers, routines, geplande events en objectgebonden rechten op de gekozen tabellen inventariseren en testen. Dezelfde accounts houden dezelfde begrensde toegang; geen ruimere grants om een naamsfout te omzeilen. |
| Beveiligde onderzoekslaag | De verwijzingen vanuit `Meijendel_ndff_secure` naar openbare tabellen aanpassen; de beveiligde tabellen zelf, toegangsrechten en beveiligingsgrens blijven buiten de naamscope. |
| Dynamische SQL | Naast letterlijke namen ook `table_prefix`, `GROUP_CODES` en geconstrueerde `ndff_{code}`-namen bijwerken, inclusief schema- en importcontracttests. |
| Tabelnamen als gegevens | `analyse_datareeks.bron_object` en `meijendel_waarneming_ruimtelijke_status.bron_tabel` meenemen. Historische audits leesbaar houden met een versiegebonden naamvertaling; geen blinde wijziging van oude bronpayloads of bronidentiteiten. |
| Regels en bronidentiteit | Labels zoals `ndff-libellenroute-v1`, protocolcodes, hashes en overlapaanduidingen niet alleen om cosmetische redenen wijzigen. Ze zijn bewijs- of regelidentiteiten, geen fysieke tabelnamen. |
| Import, analyse en overlapaudit | Openbare import, protocolreconstructie, ruimtelijke lagen en externe overlapaudit moeten dezelfde records en selecties blijven opleveren. |
| Export, cache en afnemers | Verplichte tabelnamen in exportvalidatie en kandidaatcontrole bijwerken. Verse dump en Shiny-cache uitsluitend uit de gevalideerde levende database. |
| Provinciale PQ | Bestaande 513 plot-jaarregels uit 1981–2025 en alle daaruit getoonde waarden behouden; ook websitequery, Shiny-covariaten en bronvermelding inhoudelijk testen. |
| Beheer en documentatie | Naamverwijzingen in actuele AGENTS, schema's, README, taakdocumentatie en bronregister bij de daadwerkelijke migratie bijwerken; historische leveringsbestanden niet herschrijven. |

Voor uitvoering wordt eerst op een geïsoleerde databasekopie bewezen dat de
oude en nieuwe naamkaart dezelfde inhoud opleveren: volledige sleutelsets,
rijtellingen en inhoudshashes, plus dezelfde toegelaten selecties,
nulstatussen en overlapbesluiten. De proef maakt geen import in de levende
database. De terugweg bestaat uit de inverse naamkaart plus de bijpassende
versie van code, bestaande viewdefinities en tekstverwijzingen; een algemene
transactie-rollback mag niet als herstelstrategie voor alle schemawijzigingen
worden aangenomen.

Bij daadwerkelijke uitvoering: gecontroleerde back-up, geen gelijktijdige
schrijvers/imports, lokale migratie en verificatie, vervolgens gevalideerde
dump/cache, kandidaatcontrole en de normale releaseketen vanaf `main`.
De uitrol mag pas worden afgerond als ook de bestaande website- en
Shiny-inhoud aantoonbaar aanwezig is. Deze ontwerpbeoordeling heeft geen
migratie, dumpgeneratie, cacheverversing of productiedeploy uitgevoerd.

## Bewijs en afbakening van deze beoordeling

Gecontroleerd zijn het levende lokale `information_schema`, exacte tellingen
en de hierboven beschreven read-only vergelijkingen. De schema- en
importdefinities zijn gelezen in `gis/database/ndff_public_schema.sql`,
`ndff_protocolkwaliteit_schema.sql`, `external_ecology_schema.sql` en de
bijbehorende import- en overlapscripts. Voor de afnemers zijn onder meer
`shiny_meijendel/helpers.R`, `app.R`, `ndff_local.R`,
`R/test_meijendel_cache_contract.R`, de exportvalidatie en
`VWG_M/website/vwg-m-linux-app/app/queries.py` gecontroleerd.

De 163 tabelregels in dit document vormen een structuurvoorstel; geen
herbeoordeling van de inhoudelijke toelating, rechten of bruikbaarheid van
een bron. Die bronstatussen en de bronregisterversies zijn in deze taak niet
gewijzigd. Bestaande besluiten blijven gelden tot een concrete migratie of
verrijking afzonderlijk is besloten en uitgevoerd.
