# Besluiten

- Het dashboard is leidend voor alle grafieken. De site mag geen eigen afwijkende grafieklogica of cijfers introduceren.
- DuckDB 1.5.5 is op de lokale Apple-Silicon-iMac beschikbaar als aanvullende
  analyselaag voor grote bestanden, staging, ruimtelijke koppelingen en zware
  aggregaties. MySQL 9.7.1 blijft de canonieke schrijfbron en DuckDB vervangt
  de bestaande R-, Shiny- of dashboardketen niet. Bestaande databases worden
  vanuit DuckDB standaard read-only gekoppeld; DuckDB komt niet op de VPS, NAS
  of Samsung T7 zonder expliciete toestemming en een afzonderlijke
  architectuurbeslissing. Een blijvend `.duckdb`-, Parquet- of
  GeoParquet-bestand vereist vooraf een bewust gekozen pad en toestemming.
- Externe bestanden die kandidaat zijn voor import in de life-database worden
  duurzaam opgeslagen onder `/Volumes/T7 Data/Home_Ton/Meijendel data/`; per
  levering wordt een herkenbare submap vastgelegd. Downloads is uitsluitend een
  tijdelijke ontvangstlocatie.
- Open FFV-data en beveiligde onvervaagde NDFF-data blijven strikt gescheiden.
  Ticket 58679 gebruikt lokaal `NDFF/secure/ticket_58679`; de oorspronkelijke
  levering blijft ongewijzigd, krijgt een SHA-256-manifest en wordt niet
  opgenomen in Git, de gewone `Meijendel.sql`, algemene Shiny-caches of
  webpaden. Op uitdrukkelijk besluit van de eigenaar wordt op de fysiek
  beveiligde Samsung T7 geen extra versleutelde ontvangstzone gebruikt.
- De databasegrens is vanaf 11 september 2026 aangescherpt: openbare NDFF-data
  en alle daaruit afgeleide reconstructies staan standaard in `Meijendel`.
  `Meijendel_ndff_secure` bevat uitsluitend individuele waarnemingen waarvan de
  locatie in de openbare NDFF daadwerkelijk is vervaagd, plus de bijbehorende
  onvervaagde leveringsdetails. Afgeleide bezoeken, routes, matrices en
  analyse-uitkomsten zijn niet automatisch beveiligd. Iedere uitbreiding van
  het beveiligde schema vereist voorafgaande uitdrukkelijke toestemming van de
  eigenaar.
- De op 10 september 2026 ontvangen GeoPackage voor ticket 58679 is technisch
  gevalideerd: 14.573 unieke betrouwbare records, 158 taxa met records en geen
  ongeldige geometrieën. De open FFV-identiteit is reproduceerbaar koppelbaar
  als `SHA-256(obs_uri)`; 14.420 records matchen. Exacte datum en geometrie uit
  de beveiligde levering vervangen de open waarden niet maar worden als
  afzonderlijke beveiligde bronlaag bewaard.
- Een NDFF-geometrie is alleen een voorlopige plotkandidaat wanneer zij volledig
  binnen precies één geversioneerd SOVON-plot ligt. Alleen een intersectie of
  een enkel geraakt plot is onvoldoende. Van de levering voldoen 8.777 records
  aan deze ruimtelijke regel; na de PQ-poort resteren 8.494 kandidaten voor
  uitsluitend verspreidingscontext. `Multiple`, `outside` en `single_deels`
  tellen niet als aanwezigheid per plot.
- De beveiligde levering maakt geen record direct trendklaar. Van 1.931 records
  uit doelgerichte meetnetten of gebiedsmonitoring zijn 1.274 ruimtelijk en qua
  PQ-status geschikt voor een gerichte brondata-aanvraag. Zonder telobjecten,
  bezoeken, inspanning, protocolversies en afleidbare nullen blijven ook deze
  buiten trend-, abundantie- en afwezigheidsanalyses.
- NDFF wordt niet opnieuw om de ontbrekende surveystructuur gevraagd, omdat
  NDFF heeft aangegeven die niet te kunnen leveren. Voor de 1.274 geschikte
  vervolgkandidaten wordt de verwachte meetopzet uit officiële protocollen
  gereconstrueerd en worden de feitelijke native meetreeksen rechtstreeks bij
  Zoogdiervereniging, Dunea/FLORON, RAVON, ANEMOON, BLWG, De
  Vlinderstichting en Staatsbosbeheer/opdrachtgever opgevraagd wanneer een
  noodzakelijke sleutel niet kan worden gereconstrueerd. Voor expliciete
  NEM-codes geldt de later vastgelegde uitzondering: de code bewijst een
  protocolgeldig positief bezoek; begin- en eindtijd groeperen de aanwezige
  positieve regels tot dat bezoek.
- De native survey-eenheid blijft behouden: route, water, permanent proefvlak,
  kilometerhok, meettraject of karteringsgebied. De ruimtelijke ligging van één
  positieve NDFF-regel is onvoldoende om de hele survey aan een SOVON-plot toe
  te wijzen. Relatie met geversioneerde vogelplots volgt pas na reconstructie
  van telobject, bezoeken en inspanning; kunstmatig splitsen is alleen
  toegestaan als sectiegeometrie en sectie-inspanning beschikbaar zijn.
- Surveystructuren worden protocol voor protocol vastgelegd en niet in één te
  vroeg generiek schema gedwongen. `03.201` vormt de eerste gerealiseerde
  routeketen; water-, proefvlak-, hok- en transectprotocollen krijgen pas hun
  eigen structuur nadat hun reconstructieregels zijn getoetst.
- Voor expliciet als NEM gecodeerde NDFF-regels geldt vanaf 11 september 2026
  dat de protocolcode een protocolgeldig positief bezoek bewijst. Ontbrekende
  survey-ID's worden waar verantwoord uit tijd, geometrie en protocolbereik
  gereconstrueerd. Echte nullen worden uitsluitend gevormd binnen bevestigde
  bezoeken voor de doelsoorten van dat protocol; bijvangsten krijgen nooit een
  afgeleide nul. Iedere reconstructie houdt haar onzekerheid en regelversie.
- Voor `03.201` is deze reconstructie vastgelegd als
  `ndff-vlinderroute-v1`: 82.217 bronrecords vormen 3.126 bezoeken en 11
  waarschijnlijke routefamilies. De volledige matrix voor 34 aangetroffen
  dagvlindertaxa bevat 106.284 regels, waarvan 20.075 positieve bezoek-soort-
  combinaties en 86.209 echte nullen. De 556 nachtvlinderrecords blijven
  bijvangst en leveren geen nullen. Eén ruimtelijk uitgerekte routefamilie met
  172 bezoeken vereist handmatige controle; 63 bezoeken met 185 records
  hebben geen reconstrueerbare route en blijven
  buiten routegebonden trendanalyse.
- De 1.535 vliesvleugelrecords onder `03.201` vormen vanaf 11 september 2026
  een eigen NEM-deelreeks `ndff-vliesvleugelroute-v1`, niet een bijvangstreeks.
  Zij omvat 217 bevestigde bezoeken en zes gevolgde taxa. De matrix bevat
  1.302 bezoek-taxonregels: 365 positief en 937 echte nullen. Daarvan vallen
  174 bezoeken samen met een dagvlinderbezoek en 43 bezoeken zijn uitsluitend
  op vliesvleugeligen gericht; de reeksen worden niet met elkaar vermengd.
- Voor `07.201` is vanaf 12 september 2026 de openbare libellenreeks vastgelegd
  als `ndff-libellenroute-v1`. De 3.280 bronrecords vormen 461 bezoeken en
  negen routefamilies. De matrix bevat 13.173 bezoek-taxonregels voor 29 taxa:
  2.170 positief en 11.003 echte nullen. Voor 454 bezoeken is een algemeen
  doelbereik aantoonbaar; zeven eensoortbezoeken met uitsluitend grove
  geometrie blijven `onbepaald` en leveren buiten de gemelde soort geen nul.
  Alle vier `ndff_libel_*`-tabellen staan in `Meijendel`; er is geen afgeleide
  libellenstructuur in `Meijendel_ndff_secure`.
- Voor `10.201` is vanaf 12 september 2026 de openbare reptielenreeks
  vastgelegd als `ndff-reptielroute-v1`. De 957 bronrecords vormen 14
  routefamilies en 660 route-datumbezoeken. Opeenvolgende trajectsegmenten die
  op minstens tien gezamenlijke datums zijn geteld en ruimtelijk maximaal twee
  kilometer uiteen liggen, gelden als één route; incidenteel gelijktijdig
  getelde routes niet. De matrix bevat 661 positieve regels en 659 echte nullen
  voor Hazelworm. Voor Zandhagedis en voor geheel ontbrekende bezoeken worden
  geen nullen afgeleid. Inspanning blijft `niet_afleidbaar` en de brondekking
  `alleen_positieve_bezoeken`. Alle vier `ndff_reptiel_*`-tabellen staan in
  `Meijendel`, niet in `Meijendel_ndff_secure`.
- Voor `01.201` is vanaf 12 september 2026 de openbare amfibieënreeks
  vastgelegd als `ndff-amfibiewater-v1`. De 2.439 onvervaagde bronrecords
  vormen 211 telgebiedbezoeken, 50 waterfamilies en 1.300 bevestigde
  waterbezoeken. De matrix bevat 2.274 positieve regels en 6.826 echte
  protocolnullen voor zeven taxa. Alleen een water met minstens één positieve
  registratie geldt aantoonbaar als bezocht. Presentieklassen en overige
  niet-exacte telwaarden worden niet als aantallen opgeteld. De 80 vervaagde,
  jaarlijks geaggregeerde Kamsalamanderrecords blijven buiten deze openbare
  reconstructie; daarvoor worden geen waterkoppelingen of nullen afgeleid.
  Alle vijf `ndff_amfibie_*`-tabellen staan in `Meijendel`; er zijn geen
  afgeleide amfibieëntabellen in `Meijendel_ndff_secure`.
- Voor `17.208` is vanaf 12 september 2026 de openbare vleermuisreeks
  vastgelegd als `ndff-vleermuistransect-v1`. Het zijn twee zelfstandige
  meetreeksen: 26 bezoeken van de noordelijke NEM-VTT-autoroute en 18 bezoeken
  van de zuidelijke vleerMUS-fietsroute. Van 2.624 bronrecords zijn 73
  aantoonbare dubbele vleerMUS-aanleveringen uit 2019 onderdrukt. De 2.551
  behouden regels zijn akoestische detecties, geen aantallen individuen.
  Alleen de vier NEM-VTT-doelsoorten respectievelijk drie vleerMUS-doelsoorten
  krijgen binnen bevestigde bezoeken echte nullen; positieve registraties van
  overige taxa blijven bijvangst. De vijf `ndff_vleermuis_*`-tabellen staan in
  `Meijendel`; er zijn geen afgeleide vleermuistabellen in
  `Meijendel_ndff_secure`.
- Voor `17.209` is vanaf 12 september 2026 de openbare konijnenreeks
  vastgelegd als `ndff-konijnentelling-v1`. De 5.809 positieve records zijn
  exacte sectietellingen, maar de FFV-export bevat geen route- of sectie-id.
  Daarom worden geen routebezoeken of nullen gereconstrueerd en worden 142
  records met een gelijke hok-datum-taxon-telwaarde niet automatisch als
  dubbel verwijderd. De 11 exacte overeenkomsten met `17.204` zijn alleen
  mogelijke overlap. `ndff_konijn_hokdatum_taxon` is een diagnostische proxy,
  geen NEM-meeteenheid. Beide `ndff_konijn_*`-tabellen staan in `Meijendel`;
  `Meijendel_ndff_secure` is niet uitgebreid.
- Voor `17.204` is vanaf 12 september 2026 de openbare DAZ-BMP-reeks
  vastgelegd als `ndff-daz-bmp-v1`. De zoogdieren zijn nevenregistraties
  tijdens BMP-bezoeken door uitsluitend de deelnemende vogeltellers. Een
  positieve regel bevestigt deelname; het ontbreken van 17.204 bij een ander
  BMP-bezoek bewijst geen deelname. Van 10.670 bronrecords koppelen 3.171
  eenduidig aan 1.475 BMP-bezoeken in 49 plots; 1.026 hebben meerdere mogelijke
  bezoeken en 6.473 geen passend bezoek in de lokale BMP-laag. Binnen de
  bevestigde bezoeken zijn 7.552 echte nullen voor zeven DAZ-doelsoorten
  afgeleid. Voor 92 bezoek-taxoncombinaties blokkeert ruimtelijke ambiguïteit
  een nul. Bijvangsten krijgen alleen positieve regels. Alle vier
  `ndff_daz_bmp_*`-tabellen staan in `Meijendel`; het beveiligde schema is niet
  uitgebreid.
- De huidige `ndff-daz-bmp-v1`-koppeling is nadrukkelijk tijdelijk ten opzichte
  van de primaire BMP/SAP-bron. Na afronding van alle NDFF-bewerkingen wordt
  een nieuw volledig BMP/SAP-bestand gedownload met de zoogdierbijvangst per
  telling en zo mogelijk de oorspronkelijke locaties. Die primaire registratie
  krijgt voor bezoekdeelname, telling en nulwaarneming voorrang boven de uit
  openbare NDFF-kilometerhokken gereconstrueerde koppeling. De vervanging wordt
  geversioneerd en laat de oorspronkelijke NDFF-records als controlebron intact.
- Protocol `11.202` wordt onder `ndff-zeereep-v1` op RD-kilometerhok en
  kalenderdatum gereconstrueerd. Alleen de zes typische doelsoorten krijgen
  binnen de 161 bevestigde bezoeken een volledige aanwezig/nul-matrix.
  NMV-klassen blijven vindplaatsklassen en geen vruchtlichaamaantallen. De
  negen vervaagde records worden niet tot bezoek gemaakt; bezoeken buiten
  oktober-december en ontbrekende bezoektijd/waarnemersbekwaamheid blijven
  verplichte kwaliteitswaarschuwingen.
- `12.202` blijft, ondanks de NEM-methodiek, voor dit project uitsluitend een
  secundaire NDFF-weergave van PQ-gegevens. De oorspronkelijke provinciale
  PQ-reeks blijft leidend en wordt niet aangevuld of dubbel geteld met NDFF.
- De reconstructie en latere aanvullende bronvalidatie worden vanaf 11 september 2026 geprioriteerd op
  de volledige canonieke laag van 810.983 records, niet op alleen de 1.274
  kandidaten uit de beveiligde 191-soortenlevering. `03.201` en `07.201` zijn
  inmiddels lokaal gereconstrueerd. EIS Nederland
  en NMV blijven mogelijke aanvullende bronorganisaties als na reconstructie
  noodzakelijke sleutels ontbreken. Dit verandert `ndff-analyseketen-v1` en de
  bestaande algemene analysetoelatingen niet.
- Binnen de beveiligde 191-soortenlevering gaan van de 8.494 ruimtelijke
  verspreidingskandidaten 1.274 passende meetnet-/gebiedsmonitoringrecords door
  naar de brondata-opvraag. Dit is een deelsom; de validatieprioriteit voor de
  volledige NDFF-set wordt bepaald vanuit de 66.125 canonieke kandidaten voor
  minstens één gebruikstype buiten uitsluitend `V`.
  Op uitdrukkelijk besluit van 10 september 2026 mogen alle openbare FFV-regels
  wel als duidelijk gelabelde bronregistratie in nieuwe `ndff_`-tabellen van de
  life-database staan. Databaseopname is geen analysetoelating: zonder
  wetenschappelijk verantwoord analysetype en voldoende inspanningsinformatie
  blijven zij standaard uitgesloten van trend, abundantie, afwezigheid en
  beheer-effectanalyse.
- De voorlopige PQ-audit van ticket 58679 bevat 162 exacte positieve dubbels en
  163 niet-beoordeelbare risicorecords. Beide categorieën tellen niet als
  zelfstandige NDFF-evidentie. De door Provincie Zuid-Holland aangeleverde
  PQ-reeks in de life-database is de oorspronkelijke, gezaghebbende bron.
  Iedere uit NDFF afkomstige PQ-regel is per definitie slechts een secundaire
  controlebron en mag de provinciale reeks nooit aanvullen, wijzigen,
  overschrijven of als extra waarneming meetellen, ook niet wanneer een
  overlapclassificatie `onafhankelijk` zou luiden. Tussen de 158 geleverde
  NDFF-taxa en de 275 taxa
  van de afzonderlijke GBIF-vangblikreeks is geen taxonomische overlap; beide
  bronlagen behouden desondanks hun eigen structuur in de later gezamenlijke
  migratie.
- De openbare GBIF Sampling Event Dataset `Meijendel research 1953-1960`
  (versie 1.7, DOI `10.15468/adsbxs`) blijft een derde, afzonderlijke bronlaag
  onder `NDFF/external_gbif/meijendel_vangblikken_1953_1960`. Zij wordt niet
  tot positieve NDFF-waarnemingen afgevlakt: sampling events, vangblikken,
  inspanning, verplaatsingen en kwaliteitsvlaggen blijven behouden. De reeks
  is op uitdrukkelijk besluit van 10 september 2026 als volledige maar nog niet
  analytisch toegelaten bronreeks in de life-database opgenomen. De twee
  verweesde occurrences zijn bewaard en uitgesloten; lege events zijn geen
  harde nul; predatie-/zoogdierrisico, verplaatsing en vergelijking in 1959
  zijn gelabeld. CC BY-NC 4.0 blijft voorlopig leidend. De afzonderlijke
  bronidentiteit en meetstructuur blijven volledig behouden.
- De beveiligde NDFF-data is op 10 september 2026 in een apart lokaal
  MySQL-schema `Meijendel_ndff_secure` opgenomen. Alle 14.573 regels blijven
  daarin als beveiligde bronregistratie bewaard; 8.494 regels zijn uitsluitend
  als positieve verspreidingscontext toegelaten en 1.274 daarvan zijn gelabeld
  als trendkandidaat die op volledige brondata wacht. Dit label is geen
  trendtoelating. De bestaande vogelgerichte
  tabel `soorten` blijft ongewijzigd; NDFF-taxa komen in `ndff_soorten` en iedere
  oorspronkelijke FFV-soortgroep krijgt een eigen tabel `ndff_<soortgroep>`.
  Exacte geometrie en plotkoppeling blijven lokaal. Alleen afzonderlijk
  goedgekeurde, niet-herleidbare analyseresultaten mogen naar de VPS. De gewone
  life-database is bij deze beveiligde import niet gewijzigd. Later op dezelfde
  datum zijn de openbare FFV- en GBIF-bronnen wel in afzonderlijke nieuwe
  tabellen van `Meijendel` opgenomen; bestaande vogel- en PQ-tabellen bleven
  exact ongewijzigd.
- Een exacte, onvervaagde locatie verbetert de ruimtelijke toewijzing maar maakt
  een positieve FFV-waarneming op zichzelf niet trendklaar. Voor trends blijven
  gereconstrueerde telbezoeken, meeteenheden, protocolbereik en afleidbare
  nullen vereist; de
  bestaande PQ-reeks blijft leidend totdat de afzonderlijke PQ-overlapaudit is
  afgerond.
- Protocolgeschiktheid en geschiktheid van de feitelijk geleverde gegevens
  blijven twee afzonderlijke beoordelingen. De lokale life-database bevat
  daarom vanaf regelversie `ndff-protocolkwaliteit-v1` een niet-gevoelige
  protocolcatalogus, de wetenschappelijke gebruiksmatrix, een afzonderlijke
  ruimtelijke beoordeling van alle 810.830 openbare FFV-records en
  analysebesluiten per bron, soortgroep, protocol en analysetype. Alleen 365.854
  onvervaagde geometrieën die volledig binnen precies één SOVON-plot liggen
  zijn ruimtelijk kandidaat voor plotcontext; ook deze toelating blijft
  afhankelijk van de PQ-poort. Protocolmatig passende doelgroepen voor `V`,
  `I`, `TV`, `TA` en `TK` staan op `voorlopig_toegelaten`; gemengde en
  doelsoortafhankelijke combinaties vereisen eerst de hieronder beschreven
  doelsoortselectie en niet-onderbouwde combinaties blijven uitgesloten. De
  afzonderlijke `gegevensgeschiktheid` blijft `niet_beoordeeld` totdat telobjecten, bezoeken,
  inspanning, nulwaarnemingen en meeteenheden zijn onderzocht. Voorlopige
  toelating maakt verkennend gebruik mogelijk, maar is geen definitieve
  validatie. Iedere analyse-uitvoer toont verplicht de kwaliteitsvermelding uit
  `ndff_analysebesluit.reden`. De nieuwe tabellen wijzigen geen bronrecord en
  bevatten geen beveiligde geometrie.
- De verfijnde voorlopige toelating wordt als afzonderlijke regelversie
  `ndff-analysebesluit-v4` opgeslagen. De eerdere besluiten onder
  `ndff-protocolkwaliteit-v1`, `ndff-analysebesluit-v2` en
  `ndff-analysebesluit-v3` blijven als
  historische auditlagen bewaard en worden niet stilzwijgend herschreven.
- Iedere openbare en beveiligde NDFF-waarneming krijgt precies één afzonderlijke
  recordkoppeling met `ndff_protocol`. Het numerieke `protocol_id` is alleen de
  interne foreign key; `protocol_sleutel` is de stabiele betekenisvolle sleutel.
  Een expliciete NDFF-code krijgt bewijsmethode `expliciete_code`; uitsluitend
  de letterlijk aangeleverde waarde `Losse waarnemingen` krijgt
  `expliciet_losse_waarneming` en sleutel `LOS`. Een lege waarde is nooit bewijs
  voor `LOS`. Protocolkwalificatie wordt niet in analysevelden opgeslagen:
  `analyse_status` is geen protocolstatus en de beveiligde verspreidings-,
  trend- en innamepoorten behouden hun eigen betekenis.
- Records met protocol `12.205` krijgen daarnaast een geversioneerde
  recordtoets in `ndff_snl_waarneming_context`. SNL wordt geïnterpreteerd als
  natuurkwaliteits- en subsidiecontext en niet automatisch als zelfstandige
  bron. De statussen zijn `overlap_bevestigd`, `overlap_mogelijk`,
  `geen_overlap_gevonden` en `onvoldoende_onderzocht`. De derde status bewijst
  geen onafhankelijkheid; daarvoor blijft bevestiging via bronhouder,
  inventarisatieronde of bezoekidentiteit nodig.
- Openbare en beveiligde NDFF-records worden voor lokale analyse ontsloten via
  `Meijendel_ndff_secure.v_ndff_canonieke_waarneming`. Een beveiligde match
  vervangt de openbare representatie en wordt niet toegevoegd als tweede
  telling; 153 beveiligde records zonder openbare match worden eenmaal
  toegevoegd. De stabiele sleutel is de SHA-256 van de openbare NDFF-identiteit.
  Exacte geometrie en preciezere beveiligde datum blijven uitsluitend in het
  beveiligde schema en de view krijgt geen rechten voor gewone of
  Shiny-accounts.
- De openbare PQ-poort wordt geversioneerd in `ndff_open_pq_koppeling` en
  wijzigt het bronrecord niet. Onder `ndff-open-pq-poort-v1` worden uitsluitend
  protocollen `12.007` en `12.202` als secundaire PQ-controlebron geblokkeerd:
  97.318 records. De overige 713.512 records zijn `niet_van_toepassing`.
  Bronhouder Provincie Zuid-Holland alleen is geen bewijs dat een record uit
  een PQ-opname komt; daarmee zouden 16.419 losse waarnemingen en 306
  epifytenmeetnetrecords ten onrechte zijn geblokkeerd.
- Iedere nieuwe lokale NDFF-analyse begint bij
  `Meijendel_ndff_secure.v_ndff_analyse_record`. Deze centrale analysepoort
  combineert per canonieke waarneming de actuele protocol-, doelsoort-,
  ruimtelijke, PQ- en SNL-besluiten zonder bronrecords te wijzigen. Records met
  `uitgesloten_pq`, `uitgesloten_ruimtelijk` of `uitgesloten_overlap` tellen
  niet mee; `voorlopig_met_overlapwaarschuwing` blijft afzonderlijk herkenbaar.
  `protocol_kandidaattypen` is geen eindvalidatie: zolang
  `gegevensgeschiktheid = niet_beoordeeld` moet iedere uitvoer de meegeleverde
  `kwaliteitsmelding` tonen en mogen ruwe aantallen meldingen niet als
  populatietrend worden uitgelegd.
- Voor reguliere verkennende selecties worden twee afgeleide interne views
  gebruikt. `v_ndff_verspreiding_plot_jaar_taxon` levert uitsluitend positieve
  aanwezigheid op plot-jaar-taxonkorrel;
  `v_ndff_trendkandidaat_plot_jaar_taxon` levert protocolmatige kandidaten op
  plot-jaar-taxon-protocolkorrel. `bronrecords_ter_controle` is in beide views
  geen maat voor aantal individuen, dichtheid of populatieontwikkeling. De
  kandidaatview wordt niet als trenddataset benoemd of gepubliceerd zolang
  `gegevensgeschiktheid` en surveystructuur niet aanvullend zijn beoordeeld.
- Het centrale gebruiksoverzicht is
  `v_ndff_gebruiksdekking_soortgroep_protocol`. Kandidaataantallen in deze view
  tellen alleen records met `record_selectiestatus = voorlopig_bruikbaar`; de
  overige records blijven afzonderlijk zichtbaar per uitsluitingsreden. Dit is
  het standaardoverzicht om vóór iedere analyse de beschikbare omvang en
  beperkingen per soortgroep en protocol vast te stellen.
- De resterende beschrijvende analyses werken op jaarniveau en vullen ontbrekende
  jaren nooit met nul. Eerste en laatste registraties zijn geen vestigings- of
  verdwijnjaren. Verandering in het aantal plots wordt alleen als jaar-op-jaar
  gelezen wanneer `aansluitend_jaar = 1`; bij een grotere `jaarafstand` is het
  uitsluitend een vergelijking tussen twee registratiejaren. Soortenrijkdom en
  waarnemingsintensiteit blijven naast elkaar zichtbaar om veranderende
  zoekinspanning niet voor ecologische verandering aan te zien.
- Op 11 september 2026 is de lokale analyseketen formeel vastgezet als
  `ndff-analyseketen-v1`. De status **gereed** betekent uitsluitend: canonieke
  ontdubbeling, selectiepoorten, beveiliging, documentatie en reproduceerbare
  beschrijvende views zijn technisch gecontroleerd voor verkennende
  verspreidingsanalyse. Zij betekent niet dat surveystructuur, nulwaarnemingen,
  inspanning of trendgeschiktheid zijn gevalideerd. De afzonderlijke
  bronvalidatiefase mag deze versie alleen via een nieuwe expliciete
  ketenversie wijzigen.
- Verkennende berekeningen van registratiepatronen zijn binnen
  `ndff-analyseketen-v1` toegestaan wanneer selectiepoort,
  `gegevensgeschiktheid` en `kwaliteitsmelding` zichtbaar blijven. De
  presentatie gebruikt termen als *geregistreerde aanwezigheid*, *verandering
  in registraties*, *meldingsintensiteit* en *associatie met beheer*. Zonder
  aanvullende validatie worden de uitkomsten niet aangeduid als gevalideerde
  populatietrend, abundantie, afwezigheid of causaal beheereffect. Een
  waarschuwing maakt een ontbrekende surveystructuur niet alsnog beschikbaar.
- De 114 daadwerkelijk voorkomende niet-LOS-combinaties van protocol en
  soortgroep zijn volledig en versieerbaar geclassificeerd onder
  `ndff-protocolbereik-v2`. `ndff_protocol_soortgroep_geschiktheid` is de poort
  voor het inhoudelijke doelbereik: een volledige doelgroep mag de passende
  protocoltypen behouden; bijvangst en algemene bron-/apprecords uitsluitend
  `V`; een doelsoortafhankelijke combinatie uitsluitend `V` totdat een
  gezaghebbende doelsoortenlijst beschikbaar is.
- Tien combinaties zijn gemengd: HabSlak, Meetnet Bospaddenstoelen,
  Zeereeppaddenstoelen, Beek- en poldervissen, Natura 2000-amfibieën en -vissen,
  zoldertellingen vleermuizen, DAZ-BMP, Vleermuistransecttelling en Konijnen in
  de duinen. Alle 620 daarin
  aangetroffen protocol-taxoncombinaties zijn daarom afzonderlijk vastgelegd in
  `ndff_protocol_soort_geschiktheid`.
  Niet-V-gebruik vereist een expliciete match met `doelrelatie='doelsoort'`;
  bijvangsten en taxonomisch onbepaalde records mogen nooit door overerving van
  het groepsprotocol als trenddata worden geselecteerd.
- Acht van de 19 eerdere doelsoortafhankelijke combinaties zijn met officiële
  protocolinformatie opgelost. De elf resterende combinaties blijven onder
  `wacht_op_doelsoortafbakening`: eDNA `10.002`, florakartering `12.015`, zeven
  SNL-combinaties `12.205` en de Vleermuisprotocollen `17.505` en `17.506`.
- `alleen_na_doelsoortselectie` is een uitvoerbare soortfilteropdracht, terwijl
  `wacht_op_doelsoortafbakening` betekent dat voorlopig alleen `V` gebruikt mag
  worden. In alle gevallen blijft `gegevensgeschiktheid='niet_beoordeeld'`
  totdat de surveystructuur is onderzocht.
- Iedere analyse waarin NDFF-data wordt gebruikt, past verplicht de
  NDFF/PQ-analysepoort toe. Aanleiding is dat 1.039 van 2.007 PQ-opnamen
  (51,77%) en 24.804 van 53.122 PQ-soortwaarnemingen (46,69%) in de open
  NDFF-staging herkenbaar zijn, met een sterke daling van de dekking vanaf 2018.
  Iedere NDFF-waarneming krijgt vóór analyse een
  auditeerbare status `exact`, `waarschijnlijk_dezelfde_opname`, `mogelijk`,
  `onafhankelijk`, `niet_beoordeelbaar` of `niet_van_toepassing`, met een
  versie van de beslisregel. Alleen `onafhankelijk` en `niet_van_toepassing`
  mogen als zelfstandige NDFF-informatie meetellen wanneer het record tevens
  geen PQ-bronrecord is. De overige statussen en alle NDFF-PQ-bronrecords mogen
  hoogstens als gelabelde context worden getoond en leveren geen extra telling,
  soortenrijkdom, aanwezigheid, trend- of inspanningsbewijs naast de bestaande
  PQ-opname. Iedere analyse-uitvoer rapporteert de aantallen per status en de
  gebruikte beslisregelversie; ontbreken van deze controle blokkeert publicatie.
- De tabel `weer` blijft een ruwe bron met stationsafhankelijke schalen. Alle analyses lezen uit `weer_analyse`; die view normaliseert eenheden, bewaart spoorneerslag en spoorzonneschijn als aparte vlaggen en levert bij een onbekend station bewust `NULL` voor stationsafhankelijk genormaliseerde waarden.
- Het PQ-vegetatiemeetnet wordt rechtstreeks beheerd in de levende MySQL-database en niet handmatig in `meijendel.sql`. De genormaliseerde brontabellen gebruiken het prefix `pq_`; historische geometrie blijft per opname behouden. Dashboard en Shiny lezen alleen de afgeleide korrel `pq_plot_jaar_vegetatie`, de website alleen de veilige view `website_plot_vegetatie_jaar`.
- Voorlopige PZH-imports worden versieerbaar opgeslagen met bestands-SHA en bronstatus. `SRTNUM` is de interne soortidentiteit binnen de geregistreerde soortenlijstversie; `PLABED` blijft een ruwe broncode. Afwijkende nieuw aangeleverde bodemcodes overschrijven de bestaande waarde pas na bevestiging door PZH.
- Webgrafieken worden gevoed door vooraf gegenereerde dashboard-output/CSV; lokale `meijendel.sql` wordt niet per request geparsed.
- Dashboard, Shiny, SQL en dashboard-output zijn leden-only via Caddy `forward_auth`.
- Shiny is toegankelijk vanaf niveau 2; gewone leden niveau 1 zien/activeren Shiny niet.
- Autorisatieniveaus: 1 lid, 2 redacteur, 3 bestuurslid, 4 webmaster, 5 systeembeheer.
- Bestuursleden mogen ledenadministratie en kavelbeheer bewerken, maar rollen/rechten wijzigen blijft voor webmaster en systeembeheer.
- Runtime-data zoals uploads, archiefdocumenten en productiebeelden gaan niet in Git; Git bevat code, scripts, documentatie en lege mapstructuur waar nodig.
- CMS-afbeeldingen die vanuit nieuwsberichten worden geupload zijn runtime-data onder `app/static/uploads/cms`; deploys en back-ups moeten deze map behouden.
- Canoniek SQL-bestand op de VPS is `/srv/vwgm/data/Meijendel.sql`; oude SQL-locaties mogen hoogstens symlink zijn.
- MySQL `tellers` bevat uitsluitend `id` en een unieke `tellercode`. Namen, contactgegevens, lidsoort en bandnummer worden alleen in de afgeschermde PostgreSQL-ledenadministratie beheerd en mogen niet terugkeren in `meijendel.sql` of algemene MySQL-back-ups.
- `www.vwg-m.nl` wordt na DNS-cutover de hoofdhost; `app.vwg-m.nl` blijft voorlopig werkende alias.
- Algemene publieke zoekfunctie mag geen besloten ledenarchief of andere ledenroutes indexeren of tonen.
- Nieuwe functionaliteit moet waar relevant zichtbaar worden in auditlogging en in `handleiding_beheer.md`.
- Afgeronde wijzigingen worden standaard in Git gecommit met een korte, beschrijvende commitmelding, tenzij expliciet anders gevraagd.
- Als een wijziging voor `app.vwg-m.nl` of de VPS-site wordt gevraagd, is de standaard scope lokaal aanpassen plus deploy naar de VPS en verificatie op productie.
- Nieuwsoverzichten tonen geen volledige nieuwsitems meer: startpagina en `/nieuws/index.asp` tonen lijsten of korte tekstsamenvattingen, terwijl de detailpagina achter `Lees verder` het volledige bericht toont.
- Als een nieuwsbericht met een afbeelding begint, wordt die afbeelding in de overzichtssamenvatting overgeslagen; de samenvatting bevat alleen tekst.
- Gepubliceerde nieuwsitems worden met het nieuwste item bovenaan getoond. Bij gelijke publicatiedatum is de nieuwste database-id de tie-breaker.
- Gewone leden krijgen alleen beperkte Contentbeheer-toegang als zij in het lopende jaar als BMP- of winterteller aan een kavel zijn gekoppeld; zij zien dan alleen `Kavels` en alleen hun eigen actuele kavelteksten.
- Niveau 4 en 5 behouden volledige Contentbeheer-toegang tot vaste pagina's, soortteksten en alle kavelteksten.
- De ledenpagina toont BMP-kavels, winterkavels en PTT-route uit dezelfde actuele jaartoewijzingen als de ledenadministratie; `app.teller_assignments` is de voorkeursbron, met fallback naar oudere app-/legacyvelden.
- Vogelrichtlijnsoorten worden als lijstgroep gekoppeld via `richtlijn_id = 7`; er komt geen aparte gebieds-/doelentabel voor website- en dashboardgroepen.
- De publieke Vogelrichtlijn-groepsgrafiek gebruikt dezelfde vooraf gegenereerde CSV-output als andere groepen; `chart_id = vogelrichtlijn` is de vaste sleutel.
- De vaste tekst van de Vogelrichtlijn-groep wordt beheerd via app-CMS-key `groups:vogelrichtlijn`; oude CMS-content mag de vastgestelde titel/tekst niet stilzwijgend blijven overschrijven na zo'n wijziging.
- Vogelsoortdetailpagina's mogen Meijendel-kenmerkdata read-only tonen als aanvullend blok `Vogelkenmerken`; dit blok vervangt of overschrijft geen CMS-/legacyteksten voor `Beschrijving` en `Voorkomen`.
- Publieke kenmerken op soortpagina's worden compact en leesbaar weergegeven als doorlopende tekst; technische veldcodes en primair/secundair-labels blijven uit de publieke tekst.
- De knop `Kenmerken` verschijnt alleen als er daadwerkelijk kenmerkdata is, zodat soorten zonder kenmerken geen lege navigatie of leeg blok krijgen.
- Functionele vogelgroepen vormen een aanvullende, niet-exclusieve analysedimensie en vervangen de ecologische vogelgroepen van Sierdsema niet.
- Versie 1 gebruikt zes groepen: bodemfoeragerende insecteneters, luchtfoerageerders, grondbroeders, holenbroeders, langeafstandstrekkers en zaadeters.
- Primair groepslidmaatschap krijgt voor gewogen gevoeligheidsanalyses gewicht `1,0`, secundair substantieel lidmaatschap `0,5`; daarnaast wordt altijd een binaire analyse uitgevoerd. Incidenteel gebruik telt niet mee en onbekend blijft `NULL`.
- Een hoofdgroep vereist minimaal tien soorten met een bruikbare trend. Vijf tot en met negen soorten is uitsluitend exploratief; minder dan vijf soorten wordt niet als groepsindicator geanalyseerd.
- Bestaande `F`- en `V`-codes worden niet hernoemd of stilzwijgend geherinterpreteerd. Nieuwe traits gebruiken een versiegebonden namespace `TR1_*` en legacyvertalingen worden afzonderlijk vastgelegd.
- De huidige kenmerkdata gelden voor migratie als `legacy_ongevalideerd` zolang bron, context en inhoudelijke controle ontbreken. Afwezigheid van een rij betekent niet dat een eigenschap afwezig is.
- Aanvullen van ontbrekende soortkenmerken hoort bij fase B. Fase A registreert de hiaten; fase C mag een groep pas afleiden nadat alle verplichte traits zijn aangevuld of expliciet als onbekend zijn beoordeeld.
- De migratie bouwt een nieuwe traitlaag naast de bestaande tabellen. Bestaande lezers schakelen pas om na inhoudelijke goedkeuring en groene dashboard/Shiny/website-pariteitscontroles.
- Mondiale of Europese soorttraits worden niet automatisch verheven tot een
  Nederlandse of Meijendel-broedpopulatiewaarde. Bronwaarden behouden hun eigen
  geografische, seizoens- en populatiecontext; de vereiste lokale doelcontext
  blijft `unknown` totdat zij afzonderlijk is goedgekeurd.
- TR1 bevat naast 15 verplichte doeltraits acht ondersteunende brontraits. Deze
  bewaren binaire of semikwantitatieve broninformatie zonder een kunstmatig lokaal
  percentage te construeren.
- Zaadeters worden bepaald met `TR1_DIET_SEED_SHARE`: primair vanaf `0,50`,
  secundair vanaf `0,25` en uitgesloten daaronder. De waarde betreft volwassen
  vogels in het broedseizoen en is een reproduceerbare klasseproxy, geen lokaal
  gemeten dieetaandeel.
- Taxonomische bronkoppelingen worden expliciet en controleerbaar opgeslagen. Bij
  de Europese life-historydataset wordt voor de import de oorspronkelijke
  combinatie `Genus` + `Species` gebruikt, omdat het meegeleverde gestandaardiseerde
  veld aantoonbaar ten minste één foutieve soortomzetting bevat.
- Technische voltooiing van fase B is geen toestemming voor fase C: pas na
  inhoudelijke beoordeling van de gapmatrix mogen groepslidmaatschappen worden
  gegenereerd.
- Voor de inhoudelijke fase-B-aanvulling geldt de vaste bronhiërarchie
  Nederland > Europa > mondiaal. Het Nederlands Soortenregister en de
  Vogelbescherming-vogelgids zijn voor alle 95 soorten vastgelegd; Europese en
  mondiale datasets worden alleen als fallback en inhoudelijke controle gebruikt.
- Kwalitatieve Nederlandse soortteksten mogen via versiegebonden, vaste klassen
  worden omgezet naar semikwantitatieve analyseproxies. `approved` betekent hier
  reproduceerbaar en geschikt voor de fase-C-selectieregel, niet dat een lokaal
  populatieaandeel rechtstreeks is gemeten. Confidence en afleidingsnotitie zijn
  daarom verplicht en fase C voert drempelgevoeligheidsanalyses uit.
- Tegenstrijdige of ecologisch onwaarschijnlijke mondiale coderingen worden niet
  gemiddeld met Nederlandse informatie. De Nederlandse bron gaat voor; de
  afwijkende mondiale waarde blijft uitsluitend als herleidbare bronwaarde of
  controle behouden.
- Fase-C-groepsafleiding gebruikt behalve de aandeelgrenzen ook de in fase A
  verplichte contextgates. Bodem-insecteneters vereisen een passend substraat én
  grond-/strooiselmethode en sluiten dominante luchtvangst uit;
  luchtfoerageerders vereisen uitvaljacht of continue luchtjacht. Nest- en
  trekgroepen vereisen respectievelijk passende nesthoogte/holtetype en een
  langeafstandswinterregio.
- De baseline wordt altijd naast een inclusieve drempelverschuiving van −0,10 en
  een strikte verschuiving van +0,10 opgeslagen. Leave-one-species-out controleert
  minimaal of de publicatiestatus van de groepsomvang door één soort verandert.
- De fase-C-baseline levert vier robuuste hoofdgroepen op. De groep
  luchtfoerageerders telt zeven soorten en mag daarom uitsluitend exploratief
  worden gebruikt. De bodem-insectengroep daalt in de strikte variant naar 16
  soorten en is dus niet drempelrobuust. Geen van de lijsten wordt gepubliceerd
  voordat zij inhoudelijk is geaccordeerd en analysepariteit groen is.
- Fase D gebruikt voor functionele groepen dezelfde gebrugde TRIM-soortindices
  en dezelfde volledige/robuuste soortselectie als de bestaande MSI-keten.
  Binaire en gewogen MSI zijn gewogen geometrische gemiddelden op logschaal.
- Functionele groepen krijgen geen landelijke vergelijkingslijn zolang geen
  landelijk bronbestand met exact dezelfde traitdefinities, groepsregels en
  gewichten beschikbaar is; dashboard en website tonen wel de Meijendel-lijn.
- De website toont per functionele groep afzonderlijk de binaire en gewogen
  dashboardreeks. Luchtfoerageerders blijven expliciet exploratief en de
  bodem-insectengroep houdt een zichtbare drempelwaarschuwing.
- Nederlandse soortnaamsynoniemen voor uitwisseling met de VWG-M-website staan
  centraal in `R/species_name_synonyms.R`. Analyses en databasekoppelingen blijven
  op `soort_id` en Euring-code draaien; alleen invoerresolutie en publieke
  weergavenamen worden gecanonicaliseerd. Soortrecords worden niet samengevoegd,
  omdat onder meer Barmsijs en Kleine Barmsijs afzonderlijke IDs en taxa hebben.
- Traitverrijking wordt niet langer begrensd door vooraf bepaalde
  modelleerbaarheid. `BROEDVOGELS_MEIJENDEL_V1` bevat alle 159 soorten met een
  positief territorium sinds 1958; `TRIM_BRUIKBAAR_V1` blijft uitsluitend een
  afzonderlijke analyse-/robuustheidsscope van 95 soorten.
- Voor gedomesticeerde vormen, exoten en taxa zonder volledige externe dekking
  wordt een expliciete stamsoort-/synoniemmapping en lagere confidence gebruikt.
  Ontbrekende externe data wordt niet als nul geïnterpreteerd en klasseproxies
  worden nooit als gemeten Meijendel-populatiepercentages gepresenteerd.
- Bij ieder volledig regulier winterbezoek worden in elk kavel alle waargenomen
  vogels genoteerd, inclusief water- en wetlandsoorten. Zowel volledige bezoeken
  `Alle vogelsoorten` als `Watervogels en wetlandsoorten` leveren daarom voor
  iedere soort geldige nullen; het historische teltype blijft alleen als
  modelcovariaat aanwezig. Deelbezoeken, soortgerichte en overige tellingen
  blijven uitgesloten.
- Wintertellingindices gebruiken aantallen per volledig regulier bezoek, met een
  negatief-binomiaal model en een binaire gevoeligheidsanalyse.
  Index 100 is het modelgemiddelde over 2000/01–2004/05. Een klassiek occupancy-
  of N-mixturemodel wordt niet gebruikt omdat vrijwel geen gesloten
  detectiereplicaten bestaan. Alle 220 canonieke geregistreerde soorten staan in
  het dashboard: `betrouwbaar` en `indicatief` krijgen een gestandaardiseerde
  index, `alleen_beschrijvend` krijgt uitsluitend geregistreerde gemiddelden en
  waarnemingsfrequenties. Historische codes `Canadese gans spec.` en `Grote
  Canadese gans (maxima)` worden onder `Grote Canadese Gans` samengevoegd. De
  bestaande seizoenssom blijft uitsluitend als duidelijk gewaarschuwde ruwe
  telling beschikbaar.
