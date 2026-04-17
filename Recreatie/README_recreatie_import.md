# Importbestanden recreatie

Dit zijn de startbestanden voor recreatie en toegankelijkheid.

## Bestand 1

[`plot_jaar_infra_recreatie_import.csv`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/plot_jaar_infra_recreatie_import.csv)

Kolommen:

- `plot_id`
- `jaar`
- `bron`
- `variabele`
- `waarde`

Toegestane `variabele`-waarden:

- `afstand_pad_m`
- `padlengte_m_per_ha`
- `afstand_parkeerplaats_m`
- `afstand_hoofdtoegang_m`

Voorkeurs `bron`-waarden:

- `BGT`
- `OSM`
- `HANDMATIG`

## Bestand 2

[`plot_jaar_toegankelijkheid_import.csv`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/plot_jaar_toegankelijkheid_import.csv)

Kolommen:

- `plot_id`
- `jaar`
- `bron`
- `status_code`
- `opmerking`

Toegestane `status_code`-waarden:

- `afgesloten`
- `beperkt`
- `vrij`

Voorkeurs `bron`-waarden:

- `HANDMATIG`
- `DUNEA_RAPPORT_2022`

## Bestand 3

[`plot_jaar_toegankelijkheid_deel_import.csv`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/plot_jaar_toegankelijkheid_deel_import.csv)

Kolommen:

- `plot_id`
- `jaar`
- `bron`
- `deel_label`
- `status_code`
- `aandeel_pct`
- `barriere_type`
- `geom_wkt`
- `opmerking`

Toegestane `status_code`-waarden:

- `afgesloten`
- `beperkt`
- `vrij`

Gebruik dit bestand alleen voor plots die niet volledig in één toegankelijkheidsklasse vallen.

## Import-SQL

Voor `plot_jaar_infra`:

- [`10_import_recreatie_infra.sql`](/Users/ton/Documents/GitHub/Meijendel/Ruimtelijke%20data/10_import_recreatie_infra.sql)

Voor `plot_jaar_toegankelijkheid`:

- [`11_import_toegankelijkheid.sql`](/Users/ton/Documents/GitHub/Meijendel/Ruimtelijke%20data/11_import_toegankelijkheid.sql)

Voor `plot_jaar_toegankelijkheid_deel`:

- [`17_import_toegankelijkheid_deel.sql`](/Users/ton/Documents/GitHub/Meijendel/Ruimtelijke%20data/17_import_toegankelijkheid_deel.sql)

## Belangrijke controle

Elke rij moet verwijzen naar een bestaande combinatie van `plot_id` en `jaar` in `plot_jaar_oppervlak`.
Anders geeft MySQL een foreign key-fout.
