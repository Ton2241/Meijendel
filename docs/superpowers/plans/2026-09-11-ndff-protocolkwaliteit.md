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
