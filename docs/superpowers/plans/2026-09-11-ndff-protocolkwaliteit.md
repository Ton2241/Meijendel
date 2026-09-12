# NDFF-protocolkwaliteit implementatieplan

**Doel:** voeg uitsluitend een protocolcatalogus, gebruiksmatrix, ruimtelijke kwaliteitslaag en versieerbare analysebesluiten toe aan de lokale Meijendel-database.

**Architectuur:** de bestaande openbare en beveiligde NDFF-waarnemingen blijven ongewijzigde bronregistraties. Niet-gevoelige kwaliteitsmetadata komt in `Meijendel`; exacte beveiligde geometrie blijft uitsluitend in `Meijendel_ndff_secure`. Iedere afleiding bewaart bron- en regelversie.

**Techniek:** MySQL 9.7.1, Python-standaardbibliotheek, gebundelde `openpyxl`
uitsluitend voor de gecontroleerde Excel-naar-seedgeneratie en de bestaande
MySQL-login-path.

## Afbakening

- Geen survey-, route-, sectie- of bezoekentabellen.
- Geen wijzigingen aan vogel-, PQ-, vangblik- of bestaande NDFF-waarnemingstabellen.
- Geen Shiny-, dashboard- of VPS-wijziging.
- Geen automatische toelating tot trend-, abundantie-, afwezigheids- of beheereffectanalyse.

## Uitvoering

- [x] Leg eerst contracttests vast voor tabellen, sleutels, versievelden, bronhashes en conservatieve analysebesluiten.
- [x] Voeg een idempotent DDL-schema toe voor de vier kwaliteitslagen.
- [x] Maak uit de goedgekeurde Excel-matrix een reproduceerbare seed met 54 protocollen.
- [x] Voeg een importer toe die protocolteksten uit beide NDFF-bronnen koppelt, openbare geometrieën tegen SOVON-plotversie 2025 beoordeelt en conservatieve analysebesluiten vult.
- [x] Voer unit- en contracttests uit.
- [x] Pas de migratie lokaal toe en controleer aantallen, referentiële integriteit, dekking en herhaalbaarheid.
- [x] Werk de NDFF-documentatie bij, commit en push de taakbranch.

## Vervolgtaak: protocol per waarnemingsrecord

**Doel:** materialiseer voor ieder openbaar en beveiligd NDFF-record precies
één interne `protocol_id`, zonder protocolidentiteit en analysegeschiktheid te
vermengen.

**Ontwerp:** de betekenisvolle sleutel blijft `ndff_protocol.protocol_sleutel`.
De openbare en beveiligde bronrecords worden niet gewijzigd. Nieuwe
recordkoppeltabellen bewaren uitsluitend `waarneming_id`, `protocol_id`,
`bewijsmethode` en `regelversie`. Een expliciete NDFF-code krijgt
`expliciete_code`; de letterlijk aangeleverde waarde `Losse waarnemingen`
krijgt `expliciet_losse_waarneming` en protocol_sleutel `LOS`. Een lege of
onbekende waarde wordt nooit stilzwijgend als `LOS` behandeld.

- [x] Breid de contracttest eerst uit met beide recordkoppeltabellen, foreign
  keys, toegestane bewijsmethoden en een verbod op wijziging van
  `analyse_status`.
- [x] Controleer dat de nieuwe test om de ontbrekende functionaliteit faalt.
- [x] Breid schema en idempotente import uit en corrigeer de gecontroleerde
  woordenlijst van `ndff_protocol_mapping`.
- [x] Valideer één koppeling per 810.830 openbare en 14.573 beveiligde records,
  volledige dekking van expliciete losse waarnemingen en nul inconsistenties.
- [x] Werk README, besluiten, protocolaudit en werkinstructie bij.
- [x] Voer regressietests en de idempotente lokale migratie uit.
- [x] Commit en push de afgeronde featurebranch.

## Vervolgtaak: canonieke openbare en beveiligde waarnemingslaag

**Doel:** bied lokaal precies één logisch record per NDFF-identiteit, waarbij
de beveiligde levering de openbare representatie vervangt en beveiligde
details uitsluitend in `Meijendel_ndff_secure` blijven.

**Ontwerp:** de interne view `v_ndff_canonieke_waarneming` gebruikt
`open_identity_sha256`/`identiteit_sha256` als stabiele canonieke sleutel.
Gekoppelde beveiligde records leveren datum, validatiestatus en exacte
geometrie; niet-gekoppelde openbare records behouden hun openbare gegevens en
153 beveiligde records zonder openbare tegenhanger worden eenmaal toegevoegd.
De view krijgt geen rechten voor gewone of Shiny-accounts.

- [x] Breid eerst `test_ndff_secure_schema_contract.py` uit met het canonieke
  viewcontract en controleer de verwachte fout omdat de view ontbreekt.
- [x] Voeg de minimale interne view toe aan `ndff_secure_schema.sql` zonder
  bronrecords of bestaande veilige views te wijzigen.
- [x] Pas alleen de nieuwe viewdefinitie lokaal toe.
- [x] Valideer 810.983 unieke canonieke sleutels: 796.410 alleen openbaar,
  14.420 beveiligd in plaats van openbaar en 153 alleen beveiligd.
- [x] Controleer dat geen geometrie ontbreekt, protocol/taxon bij gekoppelde
  records gelijk zijn en beveiligde velden niet in `Meijendel` zijn gekopieerd.
- [x] Werk architectuur, besluiten en werkinstructie bij; voer regressietests,
  `git diff --check` en workspace-preflight uit; commit en push.

## Vervolgtaak: openbare PQ-analysepoort

**Doel:** voorkom dat de 97.318 herkenbare openbare NDFF-PQ-bronrecords naast
de gezaghebbende provinciale PQ-reeks worden geteld, zonder de overige 713.512
records onnodig te blokkeren.

**Ontwerp:** laat het bronrecord ongewijzigd en gebruik de afzonderlijke,
geversioneerde tabel `ndff_open_pq_koppeling`. Uitsluitend protocol `12.007` en
protocol `12.202` krijgen
`niet_beoordeelbaar`; alle overige records krijgen `niet_van_toepassing`.
De automatische regel kent nooit `exact`, `onafhankelijk` of een andere
inhoudelijke matchstatus toe.

- [x] Leg de beslisregel en verwachte aantallen eerst vast in de bestaande
  protocolkwaliteitscontracttest en controleer de verwachte fout.
- [x] Voeg de idempotente PQ-poort toe aan de bestaande importeur.
- [x] Pas de poort lokaal toe en valideer 97.318 geblokkeerde, 713.512
  niet-PQ-records en nul onbeoordeelde records.
- [x] Werk documentatie en werkinstructie bij; test, commit en push.

## Vervolgtaak: centrale analysepoort per canoniek record

**Doel:** maak voor iedere canonieke NDFF-waarneming direct zichtbaar welk
gebruik protocolmatig kandidaat is en welke ruimtelijke, PQ-, overlap- en
validatiebeperkingen gelden.

**Ontwerp:** de interne view `v_ndff_analyse_record` bevat één rij per
canonieke identiteit en geen geometrie of exacte datum. Zij combineert de
actuele protocol-, doelsoort-, ruimtelijke, PQ- en SNL-regelversies. De
protocoltypen blijven kandidaten; `gegevensgeschiktheid` blijft
`niet_beoordeeld` tot de latere surveyvalidatie.

- [x] Breid eerst het beveiligde schemacontract uit en controleer de verwachte
  fout omdat de view ontbreekt.
- [x] Voeg de minimale interne view toe zonder bestaande bron- of analysevelden
  te wijzigen.
- [x] Pas alleen de nieuwe viewdefinitie lokaal toe en valideer precies 810.983
  unieke records en volledige protocol-, ruimtelijke en PQ-dekking.
- [x] Controleer uitsluitingsredenen en kandidaat-analysetypen op dagvlinders
  en op losse waarnemingen.
- [x] Werk documentatie bij; voer regressietests uit; commit en push.

## Voortgang geprioriteerde gebruiksketen

1. **Canonieke NDFF-waarnemingslaag — gereed.** Openbare en beveiligde
   representaties zijn ontdubbeld; beveiligde details blijven lokaal en PQ- en
   SNL-regels blijven herkenbaar.
2. **Centrale gebruiksselectie per record — gereed.** De interne view
   `v_ndff_analyse_record` combineert alle actuele analysepoorten en de
   verplichte kwaliteitsmelding.
3. **Direct bruikbare analyseviews — gereed.** Positieve aanwezigheid,
   soortenrijkdom, eerste/laatste registratie, verspreidingsverandering,
   afzonderlijke dekking/waarnemingsintensiteit en protocolmatige
   trendkandidaten zijn op jaarniveau beschikbaar. Ontbrekende jaren worden
   nergens als nul of afwezigheid ingevuld.
4. **Dagvlinderproef — technisch gereed.** Ontdubbeling, protocollen,
   plotkoppeling, waarschuwingen en reproduceerbare selectie zijn gecontroleerd.
   Native route-identiteiten blijven onderdeel van latere bronvalidatie.
5. **Toepassing op alle soortgroepen — administratief gereed.** De view
   `v_ndff_gebruiksdekking_soortgroep_protocol` omvat 28 soortgroepen, 54
   protocollen en 142 sluitende combinaties. Inhoudelijke aanvullende validatie
   blijft apart zichtbaar.
6. **Resterende protocolafbakening — gedeeltelijk en geparkeerd.** SNL-overlap
   is voorlopig geclassificeerd; verdere SNL-, eDNA- en
   florakarteringsafbakening heeft lagere prioriteit. Vleermuistransectprotocol
   `17.208` is inmiddels in de vervolguitvoering gereconstrueerd.
7. **Database formeel gereed verklaren — gereed voor verkennende analyse.**
   De vaste versie `ndff-analyseketen-v1` is in alle analyseviews opgenomen.
   De reproduceerbare live-audit controleert totalen, dubbelen, kernstatussen,
   jaargaten, beveiliging en grants en is op 11 september 2026 volledig
   geslaagd. Verkennende berekeningen van registraties, verspreiding en
   associaties zijn toegestaan met de verplichte kwaliteitsmelding. Zonder
   aanvullende validatie worden zij niet gepresenteerd als gevalideerde
   populatietrends, abundantie, afwezigheid of causale effectanalyse; daarvoor
   begint nu de afzonderlijke bronvalidatiefase.

## Vervolguitvoering 12 september 2026

Protocol `17.208` is na dit oorspronkelijke plan aanvullend gereconstrueerd als
`ndff-vleermuistransect-v1`. De openbare laag in `Meijendel` onderscheidt de
NEM-VTT-autoroute van de vleerMUS-fietsroute, bewaart 44 bezoeken en een
bezoek-soortmatrix met methodegebonden doelsoorten en echte nullen. Van 2.624
bronregels zijn 73 aantoonbare dubbele aanleveringen uit 2019 onderdrukt; 2.551
akoestische detecties blijven behouden. Alle afleidingen staan in `Meijendel`;
`Meijendel_ndff_secure` is niet uitgebreid.
