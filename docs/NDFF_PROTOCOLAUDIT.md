# NDFF-protocolaudit per soortgroep

## Besluit

De 810.830 unieke FFV-waarnemingsregels zijn **niet als één ongestructureerde
set rechtstreeks trendklaar**.
Een gevalideerde waarneming en een geregistreerde protocolnaam bewijzen nog niet
dat de FFV-export alle telbezoeken, inspanning, telobjecten en afleidbare
nulwaarnemingen bevat. Protocolmatig passende gegevens mogen daarom wel
voorlopig en verkennend worden gebruikt, terwijl de leveringsgeschiktheid
afzonderlijk `niet_beoordeeld` blijft. Iedere uitkomst vermeldt deze beperking;
voorlopige toelating is geen definitieve trendvalidatie.

Alleen records uit een voor de soortgroep passend doelgericht meetnet zijn
kandidaat voor protocolgebonden trendinvoer. Bij een expliciete NEM-code wordt
uitgegaan van een protocolgeldig positief bezoek. De native meeteenheid en
bezoekmatrix moeten nog wel per protocol worden gereconstrueerd. Bruikbare
nullen worden uitsluitend afgeleid binnen de doelsoorten en bezochte
meeteenheden van dat protocol; nooit voor bijvangsten.

### Uitgevoerde reconstructies `03.201` en `07.201`

Voor het Landelijk Meetnet Dagvlinders is bevestigd dat iedere `03.201`-regel
uit een geldig NEM-bezoek komt, dat de bezoekmomenten volledig aanwezig zijn en
dat er geen volledig vlinderloze bezoeken ontbreken. Uit tijd en geometrische
samenhang zijn onder regel `ndff-vlinderroute-v1` 3.126 bezoeken en 11
routefamilies gereconstrueerd. De matrix voor de 34 aangetroffen
dagvlindertaxa bevat 106.284 bezoek-soortregels: 20.075 positief en 86.209 echte
nullen. De 556 nachtvlinderrecords zijn bijvangst en blijven positieve
voorkomensinformatie.

Van de bezoeken zijn er 2.891 aan een waarschijnlijke route gekoppeld. Eén
ruimtelijk uitgerekte familie omvat 172 bezoeken en blijft gemarkeerd voor
handmatige controle. Voor 63 bezoeken met 185 bronrecords kon uit de aanwezige
geometrie geen route worden hersteld. De afgeleide tabellen staan in
`Meijendel`; `--audit-vlinders` controleert aantallen, matrixconsistentie en
dat geen oude afgeleide vlindertabellen in het beveiligde schema achterblijven.

De 1.535 vliesvleugelrecords onder hetzelfde protocol zijn geen bijvangst maar
een zelfstandige NEM-deelreeks. `ndff-vliesvleugelroute-v1` omvat 217 bezoeken
in 2018-2025 en zes gevolgde taxa. De matrix bevat 1.302 regels: 365 positieve
bezoek-taxoncombinaties en 937 echte nullen. Alleen tijdstippen met minstens één
vliesvleugelrecord tellen als bezoek voor deze deelreeks. Daardoor blijven de
43 uitsluitend op vliesvleugeligen gerichte bezoeken buiten de
dagvlindermatrix, terwijl alle 217 vliesvleugelbezoeken in hun eigen matrix
vallen. Controle vindt plaats met `--audit-vliesvleugelen`.

Het Landelijk Meetnet Libellen (`07.201`) is onder
`ndff-libellenroute-v1` uit uitsluitend openbare records gereconstrueerd. De
3.280 bronrecords uit 2007-2021 vormen 461 bezoeken, negen routefamilies en 29
taxa. De bezoek-soortmatrix bevat 13.173 regels: 2.170 positieve combinaties en
11.003 echte nullen. Alle negen routefamilies bevatten door de jaren heen meer
dan één protocoltaxon en zijn daarom als algemene route gekwalificeerd.

Van 60 bezoeken is alleen een grof vlak beschikbaar. Bij 53 daarvan bewijzen
meerdere getelde taxa eveneens het algemene doelbereik. Zeven grove bezoeken
bevatten slechts één taxon; hun doelbereik blijft `onbepaald`. Voor deze zeven
wordt alleen de positieve telling bewaard en worden geen andere soorten als
afwezig ingevuld. De vier `Meijendel.ndff_libel_*`-tabellen worden met
`--audit-libellen` gecontroleerd; er staan geen afgeleide libellengegevens in
het beveiligde schema.

Het NEM-Meetprogramma Reptielen (`10.201`) is onder
`ndff-reptielroute-v1` uit uitsluitend openbare records gereconstrueerd. De 957
bronrecords uit 1990-2025 vormen 14 routefamilies en 660 route-datumbezoeken.
Van die bezoeken zijn er 648 aan een route gekoppeld; twaalf bezoeken hebben
alleen een grof kilometerhok. De 15 historische trajectgeometrieën vormen de
routeankers; 56 latere exacte locaties zijn aan het best passende anker
gekoppeld. Alleen twee protocoltaxa komen voor: Zandhagedis en Hazelworm.

De bezoek-soortmatrix bevat 1.320 regels: 661 positieve combinaties en 659
echte nullen voor Hazelworm. Ieder aangeleverd bezoek bevat minstens een
positieve Zandhagediswaarneming. De FFV-bron bevat dus geen volledig negatieve
reptielenbezoeken; ontbrekende Zandhagedisbezoeken of -nullen worden niet
gereconstrueerd. De 6.286 adulte, 64 subadulte en 761 juveniele dieren blijven
afzonderlijk optelbaar. Begin- en eindtijden worden bewaard, maar de feitelijke
inspanning is `niet_afleidbaar`. De vier `Meijendel.ndff_reptiel_*`-tabellen
worden met `--audit-reptielen` gecontroleerd en staan niet in het beveiligde
schema.

NEM-amfibieënprotocol `01.201` is onder `ndff-amfibiewater-v1` uit de 2.439
onvervaagde openbare records uit 2003-2025 gereconstrueerd. De 52 openbare
watergeometrieën vormen 50 conservatief gekoppelde waterfamilies, 211
telgebiedbezoeken en 1.300 waterbezoeken met minstens één positieve
registratie. Geometrieën worden alleen als versies van hetzelfde water
gekoppeld wanneer hun gebruiksjaren niet overlappen en hun middelpunten
hoogstens 30 meter uiteen liggen.

De matrix bevat 9.100 waterbezoek-taxonregels: 2.274 positief en 6.826 echte
protocolnullen voor zeven openbaar reconstrueerbare taxa. Een echte nul
betekent hier uitsluitend: niet gemeld in een water dat door minstens één
positieve amfibieënregistratie aantoonbaar is bezocht. Volledig negatieve
water- of telgebiedbezoeken kunnen uit de positieve FFV-export niet worden
hersteld. Exacte aantallen, RAVON-presentieklassen, minimumaantallen,
schattingen en gemengde telwaarden blijven afzonderlijk herkenbaar;
presentieklassen worden nooit als exacte aantallen opgeteld. De twee
Bastaardkikkerlabels zijn alleen voor analyse genormaliseerd, met behoud van
beide bronlabels.

De 80 vervaagde Kamsalamanderrecords zijn jaarlijkse aggregaten en vormen geen
reconstrueerbare openbare waterbezoeken. Zij blijven in de bestaande
beveiligde bronlaag; er zijn geen afgeleide `ndff_amfibie_*`-tabellen in
`Meijendel_ndff_secure` en er worden geen Kamsalamandernullen afgeleid. De vijf
openbare tabellen worden gecontroleerd met `--audit-amfibieen`.

## Toepassing op beveiligde levering 58679

De op 10 september 2026 ontvangen levering bevestigt de protocolaudit. Van de
14.573 positieve records vallen 1.926 onder een passend doelgericht meetnet en
5 onder gebiedsmonitoring. Na de strenge SOVON-plottoewijzing en PQ-poort zijn
1.274 daarvan ruimtelijk geschikt voor een gerichte aanvraag van volledige
brondata. De GeoPackage bevat zelf geen telobjecten, bezoekstructuur,
inspanning, protocolversies of afleidbare nullen; `zoid` en `sessionid` zijn in
alle records 0. Daarom waren in de beveiligde levering op zichzelf nul records
direct trendklaar. Dit sluit latere reconstructie met de volledige openbare
reeks en de officiële protocolregels niet uit; `03.201` is inmiddels zo
uitgewerkt.

## NEM-reconstructie op de volledige canonieke laag

De eerdere vervolgselectie van 1.274 records was uitsluitend gebaseerd op de
beveiligde levering van 191 soorten. Zij is geen rangorde voor alle NDFF-data.
Na voltooiing van `ndff-analyseketen-v1` is de prioriteit opnieuw bepaald op de
810.983 unieke canonieke records. Daarvan zijn 66.169 records voorlopig
kandidaat voor minstens één protocolmatig gebruikstype buiten uitsluitend
positieve voorkomensinformatie (`V`). `Gegevensgeschiktheid` blijft in de
algemene analysepoort `niet_beoordeeld`; een voltooide protocolreconstructie
krijgt daarnaast haar eigen, strengere matrix en audit.

| Protocol | Records | Bezoeken | Jaren | Stand |
|---|---:|---:|---|---|
| `03.201` Dagvlinders | 82.217 | 3.126 | 1990-2025 | gereconstrueerd |
| `03.201` Vliesvleugeligen | 1.535 | 217 | 2018-2025 | zelfstandige NEM-deelreeks gereconstrueerd |
| `07.201` Libellen | 3.280 | 461 | 2007-2021 | negen routefamilies en bezoek-soortmatrix gereconstrueerd |
| `10.201` Reptielen | 957 | 660 | 1990-2025 | 14 routefamilies en bezoek-soortmatrix gereconstrueerd |
| `01.201` Amfibieën | 2.519 | 225 | 2003-2025 | eerst deelprotocol per bezoek bepalen |
| `17.208` Vleermuistransect | 2.624 | 85 | 2013-2025 | transect en vier doelsoorten reconstrueren |
| `17.209` Konijnen in de duinen | 5.809 | 812 | 1984-2023 | eerst overlap met bestaande tellingen toetsen |
| `11.202` Zeereeppaddenstoelen | 3.738 | 83 | 2014-2025 | zes doelsoorten en vaste plots reconstrueren |
| `02.202` Korstmossen | 384 | 15 | 2000-2025 | proefvlakken en doelsoortenlijst reconstrueren |
| `02.204` Mossen | 377 | 22 | 2000-2011 | meeteenheid en doelsoortenlijst reconstrueren |
| `11.201` Bospaddenstoelen | 982 | 216 | 1999-2016 | vaste plots; soort- en habitatgeschiktheid behouden |
| `12.204` Het Nieuwe Strepen | 4.569 | 1.145 | 2012-2024 | onafhankelijke hokbezoeken eerst onderscheiden |
| `17.204` DAZ-BMP | 10.670 | 1.681 | 1994-2022 | doelsoorten en overlap met vogelreeks toetsen |
| `03.203` Nachtvlinders | 596 | 4 | 2019-2025 | geen nullen uit huidige NDFF-regels afleiden |
| `11.204` Bospaddenstoelen verspreiding | 14 | 2 | 2017 | te klein voor lokale trend |
| `13.201` Beek- en poldervissen | 20 | 6 | 2014 | te klein voor lokale tijdreeks |
| `17.207` Bever en otter | 3 | 3 | 2024 | te klein en slechts één lokaal taxon |
| `12.202` LMF-M&N | 15.129 | 329 | 1981-2024 | niet naast provinciale PQ gebruiken |

Record- en bezoekaantallen zijn bron- en reconstructiecontroles, geen
populatieomvang. Per protocol worden vóór nullen de native meeteenheid, het
volledige doelsoortenbereik en eventuele overlap met primaire bronnen getoetst.

Daarnaast zijn omvangrijke inventarisatiereeksen aanwezig: `03.001` (1.834),
`04.004` (1.282), `12.001` (1.150), `12.204` (929), `07.001` (850) en `12.006`
(661). Deze krijgen een tweede validatieronde gericht op complete soortenlijsten,
bezoekduur en onderzochte eenheid. Zij kunnen vooral inventarisatie- en
verspreidingsanalyses verbeteren; hun omvang maakt ze niet automatisch geschikt
voor aantalstrends.

Aanvullende bronvragen worden pas gesteld wanneer tijd, geometrie en de
officiële protocolomschrijving een noodzakelijke sleutel niet kunnen leveren.
Zij blokkeren de technisch verantwoorde reconstructies niet.

## Reconstructie van de surveystructuur

De mededeling van NDFF dat de GeoPackage alle beschikbare informatie per
waarneming bevat, betekent dat de ontbrekende surveystructuur niet opnieuw bij
NDFF wordt gevraagd. De openbare handleidingen van de meetnetbeheerders bepalen
het bedoelde ontwerp. Feitelijke bezoeken worden waar mogelijk uit gelijke
begin- en eindtijden gereconstrueerd en meeteenheden uit geometrische samenhang.
Alleen niet-reconstrueerbare sleutels of historische wijzigingen worden later
gericht bij de bronorganisatie nagevraagd.

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
- `ndff_open_pq_koppeling`: 810.830 geversioneerde PQ-poortbesluiten, waarvan
  97.318 secundaire PQ-controlebron en 713.512 niet van toepassing;
- `ndff_snl_waarneming_context`: recordgebonden bronoverlapstatus voor de
  6.273 openbare records met protocol `12.205`;
- `ndff_analysebesluit`: 1.040 besluiten per bron, soortgroep, protocol en
  analysetype.

De interne view `Meijendel_ndff_secure.v_ndff_analyse_record` materialiseert
deze regels niet, maar brengt ze bij raadpleging samen tot één analysebesluit
per canonieke waarneming. De livecontrole omvat 810.983 unieke records zonder
ontbrekende protocol-, ruimtelijke, PQ- of gegevensgeschiktheidsstatus. Daarvan
zijn 303.319 voorlopig bruikbaar, 4 voorlopig bruikbaar met een
overlapwaarschuwing, 97.333 uitgesloten via de PQ-poort en 410.327 ruimtelijk
uitgesloten. De 430.263 expliciet losse waarnemingen hebben uitsluitend
kandidaattype `V`. Alle records behouden
`gegevensgeschiktheid = niet_beoordeeld`; de view levert daarom tevens een
verplichte `kwaliteitsmelding` en is geen verklaring dat trendgebruik al
volledig is gevalideerd.

Voor praktisch gebruik zijn twee verder geaggregeerde interne views gebouwd.
`v_ndff_verspreiding_plot_jaar_taxon` bevat 105.999 positieve
plot-jaar-taxonsignalen uit 303.319 voorlopig bruikbare bronrecords.
`v_ndff_trendkandidaat_plot_jaar_taxon` bevat 11.083
plot-jaar-taxon-protocolcombinaties uit 65.044 bronrecords met minimaal één
protocolmatige kandidaatmogelijkheid buiten `V`. Alle 11.083 combinaties
behouden momenteel `gegevensgeschiktheid = niet_beoordeeld`; zij zijn dus een
prioriteiten- en selectielaag, geen berekende trend. De dagvlindercontrole vond
binnen de kandidaatview 5.161 combinaties voor protocollen `03.001`, `03.201`,
`102.005` en `102.007`; protocol `LOS` komt er nul keer in voor.

De aanvullende view `v_ndff_gebruiksdekking_soortgroep_protocol` maakt de
selectiestatus direct raadpleegbaar voor 142 combinaties van 28 soortgroepen en
54 protocollen. De som van alle statuskolommen sluit per combinatie en over het
geheel exact aan op 810.983 canonieke records. Er zijn 303.319 voorlopig
bruikbare V-kandidaten, 6.133 I-kandidaten, 60.015 TV-kandidaten, 57.605
TA-kandidaten en 4.727 TK-kandidaten. Deze aantallen mogen worden gecombineerd
in selecties, maar niet worden opgeteld omdat één record meerdere kandidaattypen
kan ondersteunen. Voor alle records blijft aanvullende gegevensvalidatie
wenselijk.

De vier aanvullende jaarniveau-views maken stap 3 compleet. De
soortenrijkdoms- en dekkingsviews bevatten beide 12.611 sluitend vergelijkbare
plot-jaar-soortgroepregels; zij omvatten 105.999 positieve taxonsignalen en
303.319 bronrecords. Daarvan zijn 201.372 records losse waarnemingen en 101.947
protocolgebonden. De eerste/laatste-view bevat 42.714 plot-taxonreeksen. De
verspreidingsveranderingsview bevat 33.022 taxon-jaarregels. Van de mogelijke
jaarvergelijkingen springen 8.059 over minstens één ontbrekend jaar; die zijn
expliciet gemarkeerd met `aansluitend_jaar = 0` en mogen niet als jaar-op-jaar
worden gerapporteerd. Alle views beschrijven geregistreerde positieve
aanwezigheid en produceren geen nulwaarnemingen.

## Formele gereedstatus analyseketen

De lokale databaseketen is op 11 september 2026 vastgezet als
`ndff-analyseketen-v1`. De reproduceerbare eindaudit controleert in één opdracht
de canonieke representaties, dubbele sleutels, verplichte velden,
recordstatussen, alle afgeleide viewtotalen, tijdsaansluitingen en ongewenste
grants:

```bash
python3 gis/scripts/import_ndff_protocolkwaliteit.py --audit-live
```

De gecontroleerde audit slaagt met 810.983 unieke canonieke records, nul
dubbelen, nul ontbrekende kernstatussen, nul afwijkende ketenversies en nul
grants op de nieuwe interne views voor gewone of Shiny-accounts. Daarmee is de
keten gereed voor verkennende analyses van geregistreerde aanwezigheid en
verspreiding. Ook verkennende berekeningen van verandering, meldingsintensiteit
en associaties met beheer zijn toegestaan wanneer de selectieregels en
kwaliteitsmelding zichtbaar blijven. Zonder aanvullende bron- en
surveyvalidatie worden de resultaten niet gepresenteerd als een gevalideerde
populatietrend, abundantie, afwezigheid of causaal beheereffect. De afzonderlijke
validatiefase is nodig om te bepalen welke kandidaten later wel zo kunnen worden
gebruikt.

### Doelsoorten en bijvangsten

De 114 werkelijk voorkomende openbare combinaties van een gecodeerd protocol
en een FFV-soortgroep zijn onder `ndff-protocolbereik-v2` volledig beoordeeld:

- 54 combinaties (`271.162` records) vallen als geheel binnen de doelgroep;
- 3 combinaties (`623` records) zijn bijvangst: Nachtvlinders binnen `03.201`,
  overige zoogdieren binnen vogelprotocol `14.204`, en Vleermuizen binnen
  DAZ-BMP `17.204`;
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
- [Netwerk Ecologische Monitoring - kwaliteit](https://www.netwerkecologischemonitoring.nl/)
- [NDFF 03.201 Landelijk Meetnet Dagvlinders](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/3-201-landelijk-meetnet-vlinders-nem/)
- [NDFF 07.201 Landelijk Meetnet Libellen](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/7-201-landelijk-meetnet-libellen-nem/)
- [NDFF 03.203 Landelijk Meetprogramma Nachtvlinders](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/3-203-landelijk-meetprogramma-nachtvlinders-nem/)
- [Zoogdiervereniging Vleermuistransecttelling](https://www.zoogdiervereniging.nl/sites/default/files/2024-10/Handleiding%20Vleermuis%20transecttellingen.pdf)
- [FLORON Het Nieuwe Strepen](https://www.floron.nl/meedoen/het-nieuwe-strepen)
- [RAVON monitoring amfibieën](https://www.ravon.nl/publicaties/handleiding-voor-het-monitoren-van-amfibieen-in-nederland/)
- [RAVON Meetnet Natura 2000](https://www.ravon.nl/publicaties/handleiding-meetnet-amfibieen-en-vissen-in-natura-2000-gebieden/)
- [ANEMOON HabSlak-protocollen](https://www.anemoon.org/projecten/natura2000/habslak-protocollen)
- [BLWG Meetnet korstmossen](https://www.blwg.nl/meetnet-korstmossen-in-stuifzanden-nem)
- [De Vlinderstichting vlinderroute](https://vlinderstichting.nl/wat-kan-jij-doen/tellen/meetnetten/een-route-tellen/vlinderroute-tellen/)
- [BIJ12 Werkwijze Monitoring en Beoordeling Natuurkwaliteit](https://www.bij12.nl/wp-content/uploads/2023/11/WW-00-TEXT-%E2%80%93-Monitoring-en-Beoordeling-Natuurkwaliteit-EHS-en-Natura-2000.pdf)
