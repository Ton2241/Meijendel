# Bronoverstijgende analysegeschiktheid

**Stand: 26 september 2026.**

## Doel

Een onderzoeker moet vóór een analyse kunnen zien welke gegevens daarvoor
bruikbaar zijn. Tot nu toe bestond zo'n fijnmazige classificatie alleen voor
NDFF. De nieuwe laag past dezelfde vijf analysetypen toe op alle aanwezige
ecologische gegevensreeksen, zonder waarnemingen te kopiëren of
bronspecifieke kwaliteitsinformatie te vervangen.

## De vijf analysetypen

- `V`: voorkomen en verspreiding. Een positieve registratie is bruikbaar; een
  ontbrekende registratie is niet automatisch afwezigheid.
- `I`: inventarisatie. Het onderzochte bezoek, monster of gebied en het
  soortenbereik moeten voldoende volledig zijn.
- `TV`: trend in verspreiding of bezetting. Dezelfde of vergelijkbare eenheden
  moeten herhaald zijn onderzocht en niet-waarnemen moet interpreteerbaar zijn.
- `TA`: trend in aantallen, dichtheid of een aantalsindex. Telmethode en
  inspanning moeten bekend en vergelijkbaar zijn.
- `TK`: trend in een vooraf vastgelegde ecologische kwaliteitsmaat, zoals
  vegetatiesamenstelling of bedekking.

Deze letters zijn geen oplopende kwaliteitsklassen. Een collectiegegeven kan
bijvoorbeeld geschikt zijn voor `V` en tegelijk ongeschikt voor `TV` en `TA`.

## Tabellen en views

- `analyse_type` bevat de vijf vaste definities.
- `analyse_datareeks` verwijst naar de bestaande bron en bewaart de kwaliteit
  van locatie, bezoeken, nulwaarnemingen, methode, validatie en beveiliging.
- `analyse_datareeks_geschiktheid` bevat per reeks en analysetype het besluit,
  de voorwaarden en de verplichte kwaliteitsmelding.
- `analyse_recorduitzondering` is uitsluitend bestemd voor bronrecords die van
  het reeksbesluit afwijken. Zij bevat alleen de bronrecordsleutel en geen
  gekopieerde waarnemingsinhoud.
- `v_analyse_catalogus` combineert de generieke reeksbesluiten met de bestaande
  actuele NDFF-v4-besluiten.
- `v_analyse_selectieadvies` geeft per reeks en analysetype de beste beschikbare
  status. De view telt bewust geen recordaantallen uit onderliggende besluiten
  bij elkaar op: dat zou vooral bij NDFF ten onrechte als aantal unieke
  waarnemingen kunnen worden gelezen. Detailselecties blijven via
  `v_analyse_catalogus` controleerbaar.

De eerste catalogusversie bevat achttien aanwezige gegevensreeksen. Voor
zeventien daarvan zijn samen 85 beslisregels vastgelegd. De canonieke NDFF-laag
heeft geen gekopieerde beslisregels: de view leest rechtstreeks uit
`v_ndff_analysebesluit_actueel`.

## Gebruik

Een analysetabel wordt nooit alleen op de letter geselecteerd. Gebruik ook het
eindbesluit en lees de voorwaarden en kwaliteitsmelding. `Toegelaten` betekent
dat de gegevens voor dat analysetype kunnen worden gebruikt binnen de genoemde
afbakening. `Voorlopig_toegelaten` vereist de vermelde selectie of correctie.
`Alleen_context` houdt de bron buiten de gewone Meijendel-modellen.
`Niet_toegelaten` blokkeert dat analysetype voor de huidige gegevensvorm.

Bronrecords blijven in hun bestaande tabellen staan. De catalogus geeft dus
geen nieuwe telling van waarnemingen en verandert de brongegevens niet.

## Installatie en controle

```bash
python3 gis/scripts/import_analysegeschiktheid.py --dry-run
python3 gis/scripts/import_analysegeschiktheid.py --apply
```

De import is idempotent. Schema en beslisregels gebruiken regelversie
`analyse-catalogus-v1`. De contracttests controleren dat iedere generieke reeks
precies vijf besluiten heeft en dat NDFF-besluiten niet worden gekopieerd.
