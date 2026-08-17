# NDFF-stagingdataset Meijendel

## Status

De geïntegreerde, ontdubbelde stagingdataset voor alle 26 niet-vogelgroepen is
op 17 augustus 2026 gebouwd en gevalideerd. De life Meijendel-database is niet
gewijzigd.

- GeoPackage: `/Users/ton/Library/Mobile Documents/com~apple~CloudDocs/Downloads/ndff_meijendel_staging_1950_2025.gpkg`
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
  --source-dir '/Users/ton/Library/Mobile Documents/com~apple~CloudDocs/Downloads' \
  --output '/Users/ton/Library/Mobile Documents/com~apple~CloudDocs/Downloads/ndff_meijendel_staging_1950_2025.gpkg' \
  --replace
```

De volgende fase is analyse van vervaging, vaststellingsmethode,
onderzoeksstructuur en mogelijke PQ-herkomst. Pas daarna volgen het definitieve
databaseschema, de SOVON-plotkoppeling en een eventuele import.
