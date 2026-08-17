# NDFF-stagingdataset Meijendel

## Status

De geïntegreerde, ontdubbelde stagingdataset voor alle 26 niet-vogelgroepen is
op 17 augustus 2026 gebouwd en gevalideerd. De life Meijendel-database is niet
gewijzigd.

- canonieke opslagmap: `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF`
- opslag- en verplaatsingsnotitie: `README_NDFF_OPSLAG.md` in die map
- GeoPackage: `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/ndff_meijendel_staging_1950_2025.gpkg`
- manifest en bouwrapport: hetzelfde pad met extensie `.json`
- bouwscript: `gis/scripts/build_ndff_staging.py`
- selectie: 34 hokken, periode 1950–2025, GeoPackage RD (EPSG:28992), geen Vogels
- bron: 84 fysieke bestanden, 26 aanvraagsoortgroepen en 78 logische bundels

## Resultaat

| Controle | Uitkomst |
|---|---:|
| Fysieke bronrecords | 886.762 |
| Unieke waarnemingen op `Identiteit` | 810.830 |
| Verwijderde extra exportvoorkomens | 75.932 |
| Identiteiten met meer dan één bronvoorkomen | 52.409 |
| Inhouds- of geometrieconflicten | 0 |
| Onvervaagde waarnemingen | 764.185 |
| Vervaagd op 1 km | 40.243 |
| Vervaagd op 5 km | 5.653 |
| Vervaagd op 10 km | 749 |
| Unieke combinaties van soortgroep en soortnamen | 9.828 |

Bij 74.896 extra bronvoorkomens verschilt alleen `Hoknummer`. Dat veld blijkt
de exportcontext van het aangevraagde hok te zijn: alle overige bronvelden en
de geometrie zijn gelijk. Daarom telt `Hoknummer` niet mee in de
inhoudsvergelijking. Iedere oorspronkelijke waarde blijft wel per fysiek
bronrecord bewaard in `ndff_waarneming_bron.bron_hoknummer`.

De oorspronkelijke datumintervallen zijn ongewijzigd bewaard. Sommige brede
intervallen beginnen vóór 1950 en de bovengrens kan als `2026-01-01` zijn
vastgelegd. Dat is geen reden om ze als exacte waarnemingen uit die jaren te
interpreteren; de aanvraagmetadata bevestigt steeds de selectie 1950–2025.

## Lagen

- `ndff_waarnemingen`: canonieke waarnemingen met geometrie, ruwe FFV-velden,
  afgeleide vervagingsstatus en vervagingsniveau.
- `ndff_bronbestanden`: manifest met selectiegegevens, recordaantallen en
  SHA-256 per origineel GeoPackage.
- `ndff_waarneming_bron`: alle 886.762 fysieke bronvoorkomens, gekoppeld aan de
  canonieke waarneming en het bronbestand.
- `ndff_conflicten`: gereserveerde auditlaag; nu leeg omdat geen echte
  inhouds- of geometrieconflicten zijn gevonden.
- `ndff_soorten`: staginglijst van unieke combinaties van soortgroep,
  Nederlandse naam en wetenschappelijke naam. Dit is nog geen import in de
  toekomstige life-tabel `ndff_soorten`.
- `ndff_kwaliteitscontrole`: samenvatting van de bouw- en dekkingscontroles.

## Ontdubbelregel

`Identiteit` is verplicht en binnen ieder bronbestand uniek. Bij herhaling wordt
één canoniek record behouden. Het eerste bestand in alfabetische volgorde is
canoniek; alle fysieke voorkomens blijven in de herkomstlaag. De inhoudshash
omvat alle FFV-velden behalve het exportcontextveld `Hoknummer`, plus de exacte
geometrie. Afwijkingen zouden in `ndff_conflicten` komen en mogen niet stil
worden samengevoegd.

## Validatie

- SQLite `integrity_check`: `ok`.
- 810.830 verschillende `Identiteit`-waarden bij 810.830 stagingrecords.
- som `bronrecord_aantal`: 886.762, gelijk aan de herkomstlaag en de som van de
  bronbestanden.
- ruimtelijke index: 810.830 regels.
- geometrieën: 810.828 polygonen en 2 multipolygonen; geen lege, ontbrekende of
  ongeldige geometrieën.
- SHA-256 GeoPackage:
  `2c0fef7b7b7557e19157f61af7c68294769b74dfc980f0ad2f89975cd1485182`.

## Reproduceerbaar bouwen

```bash
PYTHONDONTWRITEBYTECODE=1 python3 gis/scripts/build_ndff_staging.py \
  --source-dir '/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF' \
  --output '/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/ndff_meijendel_staging_1950_2025.gpkg' \
  --replace
```

Voer dit commando alleen uit wanneer de Samsung T7 gemount is. Downloads is
geen blijvende bronlocatie meer.

Het bestaande bouwmanifest `ndff_meijendel_staging_1950_2025.json` behoudt
bewust de oorspronkelijke waarden van `source_directory` en `output`. Dit zijn
historische bouwgegevens, geen actuele opslagverwijzingen. De actuele locatie
staat hierboven en in `README_NDFF_OPSLAG.md` op de T7.

## Kwaliteitsanalyse 17 augustus 2026

De volledige stagingdataset is beschrijvend geanalyseerd met
`gis/scripts/analyse_ndff_kwaliteit.py`. De life-database is daarbij uitsluitend
gelezen voor de PQ-vergelijking en niet gewijzigd.

- 554.438 records (68,38%) zijn voorlopige ruimtelijke kandidaten: niet
  vervaagd en met een brongeometrie kleiner dan 1 km². Dit is nog geen
  plottoewijzing.
- 209.747 records (25,87%) zijn niet vervaagd maar hebben een geometrie van
  minstens 1 km²; 46.645 records (5,75%) zijn vervaagd.
- 430.166 records (53,05%) zijn losse waarnemingen. De protocolmix verandert
  sterk door de tijd; ruwe jaartotalen zijn daarom geen populatietrend.
- Van 9.828 taxoncombinaties zijn er 1.991 met zowel vervaagde als onvervaagde
  records en 208 uitsluitend met vervaagde records.
- Onder de gezamenlijke gestructureerde protocollen `12.007 Vegetatieopnamen`
  en `12.202 Landelijk Meetnet Flora- Milieu- en Natuurkwaliteit (NEM)` zijn
  1.039 van 2.007 PQ-opnamen (51,77%) herkenbaar via minstens één datum-, taxon-
  en locatiematch. Dit betreft 24.804 van 53.122 PQ-soortwaarnemingen (46,69%).
  Bij 650 opnamen matcht minstens 90% van de soortenlijst en bij 147 alle nu
  herkenbare namen. Abundantie-/Braun-Blanquetcompatibiliteit en taxonomische
  synoniemen moeten nog worden gecontroleerd voordat een match definitief
  `exact` heet.
- De PQ-dekking is selectief: 937 van 1.331 opnamen uit 1981-2017 zijn
  herkenbaar (70,40%), tegenover 102 van 676 uit 2018-2025 (15,09%). Voor 2025
  is onder de twee gestructureerde protocollen geen PQ-opname gevonden. Van de
  253 vóór 2018 bemonsterde PQ-locaties zijn er 149 steeds, 38 wisselend en 66
  nooit herkenbaar. Alle gestructureerde kandidaatmatches hebben bronhouder
  `Zuid-Holland (provincie)`.
- Alle overige protocollen samen verhogen de ruime bovengrens slechts tot
  1.067 herkenbare opnamen (53,16%). Losse meldingen, ObsIdentify en
  collectierecords gelden niet als bewijs dat dezelfde PQ-bronopname is
  overgenomen.
- 233 canonieke records behoren via hun bronbestanden tot twee aangevraagde
  FFV-soortgroepen. Het databaseschema moet groepslidmaatschap daarom als een
  many-to-many-relatie vastleggen.

De volgende fase is de geversioneerde SOVON-plotintersectie, de inhoudelijke
PQ-audit en het vaststellen van toelatingsregels per analysetype. Pas daarna
volgen het definitieve databaseschema en een eventuele import.

## Protocolaudit 17 augustus 2026

De protocoltoets per FFV-soortgroep is afgerond en reproduceerbaar vastgelegd in
`gis/scripts/analyse_ndff_protocollen.py` en `docs/NDFF_PROTOCOLAUDIT.md`.

- De staging bevat 54 protocolnamen in 26 aanvraagsoortgroepen.
- 130.064 records (16,04%) behoren tot een voor de soortgroep passend
  doelgericht meetnet; dit zijn alleen kandidaten om de volledige brondata op
  te vragen, geen direct trendklare FFV-regels.
- 6.273 records (0,77%) behoren tot SNL-gebiedsmonitoring en zijn hoogstens
  kandidaat voor periodieke toestand-/beheeranalyse na ontvangst van volledige
  meetronden.
- 97.318 records (12,00%) vallen onder de conservatieve PQ-blokkade voor
  `12.007` of `12.202` en worden niet als zelfstandige telling toegelaten.
- Voor 11 soortgroepen ontbreekt in deze levering een passend doelmeetnet; zij
  worden niet voor trends in de life-database opgenomen.

Geen enkele FFV-waarnemingsregel wordt op protocolnaam alleen geïmporteerd.
Vereist zijn de volledige telobjecten, bezoeken, inspanning, protocolversie en
afleidbare nullen, gevolgd door lokale dekkings-, ruimte- en methodecontrole.
