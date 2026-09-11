# NDFF-protocolaudit per soortgroep

## Besluit

De 810.830 unieke FFV-waarnemingsregels zijn **niet rechtstreeks trendklaar**.
Een gevalideerde waarneming en een geregistreerde protocolnaam bewijzen nog niet
dat de FFV-export alle telbezoeken, inspanning, telobjecten en afleidbare
nulwaarnemingen bevat. Protocolmatig passende gegevens mogen daarom wel
voorlopig en verkennend worden gebruikt, terwijl de leveringsgeschiktheid
afzonderlijk `niet_beoordeeld` blijft. Iedere uitkomst vermeldt deze beperking;
voorlopige toelating is geen definitieve trendvalidatie.

Alleen records uit een voor de soortgroep passend doelgericht meetnet zijn
kandidaat voor vervolg. Daarvoor worden eerst de volledige brondata bij de
meetnetbeheerder opgevraagd. NDFF noemt protocollen gestandaardiseerde
telmethoden, maar vermeldt ook dat bruikbare nullen alleen uit sterke
protocollen met goede metadata afleidbaar en beperkt toegankelijk zijn. CBS
beoordeelt NEM-kwaliteit bovendien per meetprogramma en meetdoel; een landelijke
kwaliteitsbeoordeling is geen automatische lokale Meijendeltrend.

## Toepassing op beveiligde levering 58679

De op 10 september 2026 ontvangen levering bevestigt de protocolaudit. Van de
14.573 positieve records vallen 1.926 onder een passend doelgericht meetnet en
5 onder gebiedsmonitoring. Na de strenge SOVON-plottoewijzing en PQ-poort zijn
1.274 daarvan ruimtelijk geschikt voor een gerichte aanvraag van volledige
brondata. De GeoPackage bevat zelf geen telobjecten, bezoekstructuur,
inspanning, protocolversies of afleidbare nullen; `zoid` en `sessionid` zijn in
alle records 0. Daarom zijn ook in de beveiligde levering nul records direct
trendklaar.

## Reconstructie van de surveystructuur

De mededeling van NDFF dat de GeoPackage alle beschikbare informatie per
waarneming bevat, betekent dat de ontbrekende surveystructuur niet opnieuw bij
NDFF wordt gevraagd. De openbare handleidingen van de meetnetbeheerders zijn
wel voldoende om het **bedoelde ontwerp** te reconstrueren. De feitelijk
uitgevoerde routes, bezoeken, inspanning, doelsoorten, nulresultaten en
historische wijzigingen moeten rechtstreeks bij de oorspronkelijke
bronorganisatie worden opgevraagd.

De 1.274 vervolgkandidaten bestaan uit tien protocol-broncombinaties:

| Protocol | Records | Bronorganisatie | Native telobject | Prioriteit |
|---|---:|---|---|---:|
| Vleermuistransecttelling (NEM) | 572 | Zoogdiervereniging | vaste route/transect | 1 |
| LMF-a | 478 | Dunea en FLORON | vaste looproute in kilometerhok | 1 |
| Slakken van de Habitatrichtlijn | 112 | Stichting ANEMOON | zoek-/proefvlak of monsterlocatie | 2 |
| Monitoring amfibieën (NEM) | 72 | RAVON | telgebied met genummerde wateren | 1 |
| Korstmossen op steen, heiden en stuifzanden | 20 | BLWG | permanent proefvlak | 2 |
| Het Nieuwe Strepen | 12 | FLORON | complete kilometerhokinventarisatie | 3 |
| SNL/N2000-gebiedsmonitoring | 5 | Staatsbosbeheer/opdrachtgever | beheer- of karteringsgebied | 3 |
| Meetnet mossen | 1 | BLWG | geselecteerd kilometerhok | 4 |
| Landelijk Meetnet Vlinders | 1 | De Vlinderstichting | vaste route met secties | 3 |
| RAVON Meetnet Natura 2000 | 1 | RAVON/opdrachtgever | meetpunt, water of traject | 4 |

Prioriteit 1 wordt als eerste opgevraagd. Prioriteit 2 is voorwaardelijk
kansrijk. Prioriteit 3 is vooral bruikbaar binnen het eigen meetnetmodel of
voor periodieke toestand. Prioriteit 4 is in deze levering te klein voor een
lokale trend, tenzij de bronhouder een veel completere reeks kan leveren.

Het native telobject blijft altijd leidend. Dat een afzonderlijke NDFF-
waarneming volledig binnen één SOVON-plot ligt, bewijst niet dat de volledige
route, het water, proefvlak, kilometerhok of karteringsgebied binnen dat plot
ligt. Eerst worden telobject en volledige bezoeken gereconstrueerd. Daarna
wordt de geversioneerde relatie met SOVON-plots vastgelegd. Een route of gebied
wordt niet kunstmatig over vogelplots verdeeld zonder sectiegeometrie en
bijbehorende inspanning.

Voor LMF-a noemen openbare bronnen zowel een drie- als vierjarige cyclus. Dat
is een concrete methodebreuk die vóór analyse moet worden opgelost met
protocolversies, routeversies, doelsoortenlijsten en feitelijke bezoeken.

## Uitkomst per soortgroep

| Soortgroep | Records | Doelmeetnet | SNL | PQ-risico | Advies |
|---|---:|---:|---:|---:|---|
| Amfibieen | 12.982 | 2.560 (19,72%) | 0 | 0 | Kansrijk na brondata |
| Dagvlinders | 129.238 | 80.442 (62,24%) | 247 | 0 | Kansrijk na brondata |
| Eencelligen | 156 | 0 | 0 | 0 | Niet opnemen voor trends |
| Geleedpotigen (overig) | 247 | 0 | 0 | 0 | Niet opnemen voor trends |
| Insecten (overig) | 1.888 | 0 | 0 | 0 | Niet opnemen voor trends |
| Kevers | 8.079 | 0 | 0 | 0 | Niet opnemen voor trends |
| Korstmossen | 28.643 | 643 (2,24%) | 461 | 3.273 | Voorwaardelijk; PQ-blokkade |
| Kranswieren, wieren en algen | 555 | 0 | 33 | 14 | Voorwaardelijk; PQ-blokkade |
| Kreeftachtigen | 2.052 | 0 | 0 | 0 | Niet opnemen voor trends |
| Libellen | 32.325 | 3.280 (10,15%) | 278 | 0 | Kansrijk na brondata |
| Microvlinders | 22.849 | 0 | 0 | 0 | Niet opnemen voor trends |
| Mossen | 32.353 | 424 (1,31%) | 9 | 11.395 | Voorwaardelijk; PQ-blokkade |
| Nachtvlinders | 72.978 | 596 (0,82%) | 0 | 0 | Kansrijk na brondata |
| Ongewervelden (overig) | 1.760 | 0 | 0 | 0 | Niet opnemen voor trends |
| Reptielen | 3.347 | 957 (28,59%) | 0 | 0 | Kansrijk na brondata |
| Schimmels | 77.670 | 4.734 (6,10%) | 0 | 0 | Kansrijk na brondata |
| Snavelinsecten | 7.819 | 0 | 0 | 0 | Niet opnemen voor trends |
| Spinachtigen | 2.480 | 0 | 0 | 0 | Niet opnemen voor trends |
| Sprinkhanen en krekels | 9.163 | 0 | 1.468 | 0 | Alleen periodieke gebiedstoestand na SNL-brondata |
| Vaatplanten | 277.812 | 10.549 (3,80%) | 3.777 | 82.636 | Voorwaardelijk; PQ-blokkade |
| Vissen | 1.280 | 46 (3,59%) | 0 | 0 | Kansrijk na brondata |
| Vleermuizen | 9.912 | 6.596 (66,55%) | 0 | 0 | Kansrijk na brondata |
| Vliegen en muggen | 10.495 | 0 | 0 | 0 | Niet opnemen voor trends |
| Vliesvleugeligen | 12.365 | 0 | 0 | 0 | Niet opnemen voor trends |
| Weekdieren | 13.043 | 2.772 (21,25%) | 0 | 0 | Kansrijk na brondata |
| Zoogdieren (overig) | 39.339 | 16.465 (41,85%) | 0 | 0 | Kansrijk na brondata |

`Doelmeetnet` betekent hier uitsluitend: protocol en soortgroep passen bij
elkaar. Het betekent niet dat deze FFV-regels mogen worden geïmporteerd of
geanalyseerd als trend. Een voorbeeld van de soortgroeptoets: 1.535
Vliesvleugeligen zijn geregistreerd binnen het Vlindermeetnet, maar zijn
bijvangst voor die soortgroep en tellen daarom niet als trendmeetnet.

## Toelatingsklassen

1. **Niet opnemen voor trends:** losse waarnemingen, ObsIdentify, iNaturalist,
   collecties, literatuur en atlasgegevens. Bewaar deze alleen in de externe
   staging als verspreidingscontext.
2. **Gestructureerde context:** een inventarisatieprotocol kan aanwezigheid
   ondersteunen, maar zonder volledige bezoeken en inspanning geen afwezigheid,
   detectiekans of populatietrend.
3. **Doelgericht meetnet — brondata opvragen:** vraag volledige telobjecten,
   bezoeken, inspanning, protocolversies, tellingen en nullen op bij de
   beheerder. Controleer daarna lokale dekking en continuiteit.
4. **SNL-gebiedsmonitoring — brondata opvragen:** bruikbaar voor periodieke
   toestand of beheercycli indien de volledige meetronden beschikbaar zijn;
   niet automatisch als jaarlijkse trend.
5. **PQ-overlap eerst uitsluiten:** records uit `12.007 Vegetatieopnamen` en
   `12.202 LMF-M&N` blijven buiten de life-tabellen totdat
   `ndff_pq_koppeling` de bronopname heeft beoordeeld. De door Provincie
   Zuid-Holland aangeleverde PQ-reeks in de life-database is de oorspronkelijke
   en gezaghebbende bron. NDFF-PQ blijft uitsluitend secundair QA-materiaal en
   mag de provinciale reeks nooit aanvullen, wijzigen of dubbel tellen.

De PQ-regel geldt niet alleen voor trendanalyse. Ook bij aanwezigheid,
verspreiding, soortenrijkdom, multivariate analyse en inspanningsmaten mogen
`exact`, `waarschijnlijk_dezelfde_opname`, `mogelijk` en
`niet_beoordeelbaar` niet als zelfstandige NDFF-evidentie naast de bestaande
PQ-opname worden geteld. Iedere analyse controleert en rapporteert daarom de
PQ-status en beslisregelversie.

## Minimale acceptatietoets voor brondata

Een meetnetdeel wordt pas kandidaat voor een `ndff_<soortgroep>`-tabel als alle
volgende punten controleerbaar zijn:

- stabiel telobject en geversioneerde geometrie;
- datum en afzonderlijk bezoek-/sampling-event-ID;
- protocolnaam én protocolversie;
- vastgelegde duur, route/lengte/oppervlakte, methode en apparatuur waar
  relevant;
- complete soortenlijst of expliciet afleidbare nulwaarnemingen;
- telling/schaal die binnen jaren vergelijkbaar is;
- bronhouder, validatiestatus en bekende kwaliteitsbeperkingen;
- voldoende herhaalde telobjecten binnen Meijendel en de gekozen analysetijd;
- eenduidige relatie met de geversioneerde SOVON-plotlaag;
- geen onbeoordeelde PQ-dubbeling, vervaging of meerplot-toewijzing.

Pas daarna volgt per soort en meetnet een dekkingstabel `plot x jaar`, controle
op methodebreuken en een modelkeuze die bij het protocol hoort. Ontbrekende
tellingen worden nooit automatisch als nul of met machine learning ingevuld.

## Geïmplementeerde protocolkwaliteitslaag

De beoordeelde matrix staat tevens in
`Natuurprotocollen/Natuurprotocollen_gebruiksmatrix.xlsx`; de inhoudelijke
onderbouwing staat in
`Natuurprotocollen/Classificatie_natuurprotocollen_wetenschappelijk_gebruik.docx`.
De gebruikte bestanden zijn met SHA-256 vastgezet in de importeur.

Regelversie `ndff-protocolkwaliteit-v1` is lokaal in MySQL toegepast voor de
protocolcatalogus, recordkoppelingen en ruimtelijke beoordeling. De actuele
voorlopige analysebesluiten gebruiken na de doelbereiktoets de afzonderlijke
regelversie `ndff-analysebesluit-v4`; de oorspronkelijke v1-, v2- en v3-besluiten
blijven als historische auditlaag beschikbaar. De laag bevat:

- `ndff_protocol`: 54 gestandaardiseerde protocollen;
- `ndff_protocol_mapping`: 91 gecontroleerde tekstkoppelingen uit openbare en
  beveiligde NDFF-records, zonder ongemapte protocoltekst;
- `ndff_open_waarneming_protocol`: precies één protocolkoppeling voor alle
  810.830 openbare records;
- `Meijendel_ndff_secure.ndff_waarneming_protocol`: precies één
  protocolkoppeling voor alle 14.573 beveiligde records;
- `ndff_protocol_gebruik`: 54 wetenschappelijke gebruiksregels;
- `ndff_protocol_soortgroep_geschiktheid`: 114 doelbereikbesluiten op het
  werkelijk voorkomende protocol-soortgroepniveau;
- `ndff_protocol_soort_geschiktheid`: 606 protocol-taxonbesluiten voor negen
  gemengde combinaties;
- `ndff_open_ruimtelijke_beoordeling`: 810.830 beoordelingen tegen de
  SOVON-plotlaag 2025;
- `ndff_snl_waarneming_context`: recordgebonden bronoverlapstatus voor de
  6.273 openbare records met protocol `12.205`;
- `ndff_analysebesluit`: 1.040 besluiten per bron, soortgroep, protocol en
  analysetype.

### Doelsoorten en bijvangsten

De 114 werkelijk voorkomende openbare combinaties van een gecodeerd protocol
en een FFV-soortgroep zijn onder `ndff-protocolbereik-v2` volledig beoordeeld:

- 53 combinaties (`269.627` records) vallen als geheel binnen de doelgroep;
- 4 combinaties (`2.158` records) zijn bijvangst: Nachtvlinders en
  Vliesvleugeligen binnen `03.201`, overige zoogdieren binnen vogelprotocol
  `14.204`, en Vleermuizen binnen DAZ-BMP `17.204`;
- 37 combinaties (`78.158` records) zijn algemene bron-, literatuur-,
  collectie- of appregistraties en ondersteunen alleen `V`;
- 11 combinaties (`6.673` records) gebruiken een beperkte of
  projectspecifieke doelsoortenafbakening die niet per NDFF-record is
  meegeleverd; ook daar is voorlopig alleen `V` toegestaan;
- 9 combinaties (`24.048` records) zijn gemengd en zijn daarom ook per taxon
  beoordeeld.

Binnen de negen gemengde combinaties zijn 606 aanwezige
protocol-taxoncombinaties vastgelegd: 66 doelsoortbesluiten met samen 16.963
records, 539 bijvangstbesluiten met samen 7.081 records en één taxonomisch
onbepaald besluit met 4 records. Die laatste categorie betreft
`Plecotus auritus/austriacus`: de naam omvat zowel een doelsoort als een
niet-doelsoort van de zoldertelling en ondersteunt daarom alleen `V`.
Deze soortindeling staat in
`ndff_protocol_soort_geschiktheid`; de groepsindeling staat in
`ndff_protocol_soortgroep_geschiktheid`.

### Uitwerking van de 19 doelsoortafhankelijke combinaties

De officiële protocolbronnen leveren de volgende beslissingen op:

| Protocol en soortgroep | Besluit v2 | Vastgestelde doelafbakening |
|---|---|---|
| `02.204` Mossen | doelgroep | Het gekozen kilometerhok wordt zo volledig mogelijk op mossen geïnventariseerd; alle gemelde mossen vallen binnen het doelbereik. |
| `04.006` Weekdieren | gemengd | Nauwe korfslak (`Vertigo angustior`), Zeggekorfslak (`V. moulinsiana`) en Platte schijfhoren (`Anisus vorticulus`); overige weekdieren zijn bijvangst. |
| `10.002` Amfibieën | blijft afhankelijk | eDNA is een techniek; de doelsoort volgt uit het project of de gebruikte assay en ontbreekt in de levering. |
| `11.201` Schimmels | gemengd | De officiële historische lijst omvat 110 telsoorten. Van de aangetroffen taxa zijn 49 gecontroleerd aan die lijst gekoppeld; `Fungi sp. indet.` is geen doelsoort. |
| `11.202` Schimmels | gemengd | Duinfranjehoed, Zeeduinchampignon, Duinstinkzwam, Duinveldridderzwam, Helmharpoenzwam en Zandtulpje; overige schimmels zijn begeleidende soorten/bijvangst. |
| `12.015` Kranswieren, wieren en algen | blijft afhankelijk | De doelsoortenlijst hoort bij de concrete Staatsbosbeheer-karteringsopdracht en is niet uit het record afleidbaar. |
| `12.205` zeven soortgroepen | blijft afhankelijk | Kwalificerende soorten verschillen per SNL-beheertype en versie. Beheertype en versie ontbreken in de records. |
| `13.201` Vissen | gemengd | Beekprik, beekdonderpad, bittervoorn, grote en kleine modderkruiper, rivierdonderpad en rivierprik; overige vissen zijn bijvangst. |
| `13.202` Amfibieën en Vissen | gemengd | Kamsalamander, beekprik, rivierdonderpad, bittervoorn, kleine en grote modderkruiper; andere amfibieën en vissen zijn bijvangst. |
| `17.202` Vleermuizen | gemengd | Voor populatietrend zijn Ingekorven vleermuis en Grijze grootoorvleermuis doelsoort; overige zolderwaarnemingen zijn verspreidingsinformatie. |
| `17.505` en `17.506` Vleermuizen | blijft afhankelijk | Doelsoort en onderzochte functie volgen uit het projectplan; de protocolcode alleen legt die niet vast. |

Daarmee zijn acht van de negentien combinaties opgelost. Elf blijven bewust
`doelsoortafhankelijk`: één eDNA-combinatie, één florakartering, zeven
SNL-combinaties en twee Vleermuisprotocol-combinaties. Dit is geen ontbrekende
algemene handleiding, maar ontbrekende projectcontext. Gokken op basis van de
aangetroffen soort is niet toegestaan.

### SNL is context, geen automatische onafhankelijke bron

SNL staat voor Subsidiestelsel Natuur en Landschap. Kwalificerende soorten
worden gebruikt bij beoordeling van natuurkwaliteit en kunnen mede relevant
zijn voor subsidiëring. Protocolcode `12.205` bewijst daarom niet dat een record
uit een zelfstandige inventarisatie komt; dezelfde onderliggende waarneming kan
ook onder een andere bron of protocolregistratie voorkomen.

Regelversie `ndff-snl-overlap-v1` gebruikt vier statussen:

- `overlap_bevestigd`: dezelfde onderliggende waarneming is met bewijs
  vastgesteld; niet zelfstandig meetellen;
- `overlap_mogelijk`: dezelfde soort, exacte starttijd en openbare geometrie
  komen ook onder een ander protocol voor; handmatige of broncontrole nodig;
- `geen_overlap_gevonden`: binnen deze toets is geen kandidaat gevonden, maar
  onafhankelijkheid is niet bewezen;
- `onvoldoende_onderzocht`: de noodzakelijke sleutelvelden of toetsing
  ontbreken.

Een bevestigde onafhankelijke inventarisatie vergt aanvullende herkomst-,
bezoek- of telronde-informatie en wordt daarom niet als vijfde automatische
status ingevoerd.

De eerste toepassing op alle 6.273 SNL-records leverde 97 keer
`overlap_mogelijk` en 6.176 keer `geen_overlap_gevonden` op. Er zijn nog geen
records als `overlap_bevestigd` aangemerkt en geen record kreeg
`onvoldoende_onderzocht`. De mogelijke matches zijn kandidaten voor nadere
controle en worden niet automatisch als dubbel verwijderd.

Gebruikte primaire bronnen zijn onder meer [BLWG Meetnet Mossen](https://www.verspreidingsatlas.nl/projecten/blwg/meetnetmossen.aspx),
[ANEMOON HabSlak](https://www.anemoon.org/projecten/natura2000/habslak-protocollen),
[NDFF-protocollen](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/),
[RAVON Natura 2000](https://www.ravon.nl/publicaties/handleiding-meetnet-amfibieen-en-vissen-in-natura-2000-gebieden/),
[BIJ12 SNL](https://www.bij12.nl/onderwerp/natuurinformatie/monitoring-en-natuurinformatie/werkwijze-monitoring-beoordeling-natuurnetwerk-natura-2000/)
en de handleidingen van NMV en Zoogdiervereniging in de protocoldocumentatie.

Voor niet-V-analyses gelden hierdoor drie verschillende uitkomsten:

- `voorlopig_toegelaten`: de gehele soortgroep valt binnen het doelbereik;
- `alleen_na_doelsoortselectie`: gebruik uitsluitend expliciet geregistreerde
  doelsoorten uit de soorttabel;
- `wacht_op_doelsoortafbakening`: de doelstatus is nog niet uit het record of
  een voldoende specifieke bronlijst afleidbaar; alleen `V` is nu bruikbaar.

Deze doelbereiktoets vervangt de latere leveringsvalidatie niet.
`gegevensgeschiktheid` blijft voor alle v4-besluiten `niet_beoordeeld` en de
kwaliteitsmelding blijft verplicht bij iedere uitkomst.

De recordkoppelingen gebruiken `protocol_id` uitsluitend als interne foreign
key. `protocol_sleutel` blijft de stabiele identificatie. Van de openbare
records hebben 380.664 bewijsmethode `expliciete_code` en 430.166
`expliciet_losse_waarneming`; bij de beveiligde records zijn dit respectievelijk
4.913 en 9.660. De laatste categorie verwijst naar sleutel `LOS` en is geen
onderzoeksprotocol. De import blokkeert lege protocolwaarden in plaats van deze
stilzwijgend als losse waarneming te classificeren. `analyse_status` is geen
protocolstatus; wetenschappelijke toelating blijft uitsluitend via de aparte
analysebesluiten, ruimtelijke toets en PQ-poort verlopen.

Van de openbare records zijn 365.854 onvervaagde geometrieën volledig binnen
precies één plot gelegen. Dit is uitsluitend een ruimtelijke toelatingsvoorwaarde
voor positieve verspreidingscontext. `Single_deels`, `multiple`, `outside` en
alle vervaagde geometrieën zijn ruimtelijk geblokkeerd. De PQ-poort blijft een
afzonderlijke verplichte voorwaarde. Protocolmatig passende besluiten voor
inventarisatie, verspreidingstrend, aantalsindex en kwaliteitstrend zijn
`voorlopig_toegelaten`. Zij mogen verkennend worden gebruikt, met de verplichte
melding dat leveringsgeschiktheid en verdere validatie nog niet zijn beoordeeld.
Niet-onderbouwde protocol–analysetypecombinaties blijven uitgesloten.

Het schema en de reproduceerbare invoer staan in:

- `gis/database/ndff_protocolkwaliteit_schema.sql`;
- `gis/database/ndff_protocolkwaliteit_seed.csv`;
- `gis/scripts/build_ndff_protocolkwaliteit_seed.py`;
- `gis/scripts/import_ndff_protocolkwaliteit.py`;
- `gis/scripts/test_ndff_protocolkwaliteit.py`.

## Reproduceerbare bestanden

- script: `gis/scripts/analyse_ndff_protocollen.py`;
- rapport: `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/open_ffv/reports/ndff_protocolaudit_1950_2025/ndff_protocolaudit_meijendel_1950_2025.html`;
- soortgroepsamenvatting: dezelfde map, `ndff_protocolaudit_soortgroepen.csv`;
- volledige protocolmatrix: dezelfde map, `ndff_protocolaudit_protocolmatrix.csv`;
- alle berekeningen en bronnen: dezelfde map, `ndff_protocolaudit_resultaten.json`.

## Officiële methodische bronnen

- [NDFF Protocollen](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/)
- [NDFF Bijsluiter](https://ndff.nl/natuurdata/bijsluiter/)
- [NDFF Flora- en Faunaverkenner](https://ndff.nl/natuurdata/afnemen-en-gebruiken/flora-fauna-verkenner/)
- [NDFF Vegetatieopname](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-007-vegetatieopname/)
- [NDFF LMF-M&N](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-202-landelijk-meetnet-flora-milieu-en-natuurkwaliteit/)
- [NDFF LMF-a](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-211-landelijk-meetnet-flora-aandachtssoorten-lmf-a/)
- [CBS Kwaliteitsrapportage NEM 2025](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/meetprogrammas/)
- [CBS methode kwaliteitsbeoordeling](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/kwaliteitsbeoordeling/)
- [Zoogdiervereniging Vleermuistransecttelling](https://www.zoogdiervereniging.nl/sites/default/files/2024-10/Handleiding%20Vleermuis%20transecttellingen.pdf)
- [FLORON Het Nieuwe Strepen](https://www.floron.nl/meedoen/het-nieuwe-strepen)
- [RAVON monitoring amfibieën](https://www.ravon.nl/publicaties/handleiding-voor-het-monitoren-van-amfibieen-in-nederland/)
- [RAVON Meetnet Natura 2000](https://www.ravon.nl/publicaties/handleiding-meetnet-amfibieen-en-vissen-in-natura-2000-gebieden/)
- [ANEMOON HabSlak-protocollen](https://www.anemoon.org/projecten/natura2000/habslak-protocollen)
- [BLWG Meetnet korstmossen](https://www.blwg.nl/meetnet-korstmossen-in-stuifzanden-nem)
- [De Vlinderstichting vlinderroute](https://vlinderstichting.nl/wat-kan-jij-doen/tellen/meetnetten/een-route-tellen/vlinderroute-tellen/)
- [BIJ12 Werkwijze Monitoring en Beoordeling Natuurkwaliteit](https://www.bij12.nl/wp-content/uploads/2023/11/WW-00-TEXT-%E2%80%93-Monitoring-en-Beoordeling-Natuurkwaliteit-EHS-en-Natura-2000.pdf)
