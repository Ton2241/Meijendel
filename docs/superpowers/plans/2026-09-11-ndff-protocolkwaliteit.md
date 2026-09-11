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
