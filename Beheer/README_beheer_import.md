# Importbestanden beheer en maatregelen

Dit zijn de startbestanden voor beheerinformatie die later als covariaten in G.E.E. gebruikt kunnen worden.

## Bestand 1

[`plot_jaar_maatregel_import.csv`](/Users/ton/Documents/GitHub/Meijendel/Beheer/plot_jaar_maatregel_import.csv)

Kolommen:

- `plot_id`
- `jaar`
- `bron`
- `maatregel_id`
- `intensiteit_code`
- `uitvoerder_of_diersoort`
- `deel_label`
- `dekking_pct`
- `opmerking`

Belangrijk:

- gebruik `maatregelen.id` als verwijzing
- `Begrazing` wordt gespecificeerd via `intensiteit_code` en `uitvoerder_of_diersoort`
- `deel_label` gebruik je alleen als een maatregel niet voor het hele plot geldt

Toegestane `intensiteit_code`-waarden:

- leeg
- `extensief`
- `intensief`
- `variabel`
- `onbekend`

Import-SQL:

- [`16_import_maatregelen.sql`](/Users/ton/Documents/GitHub/Meijendel/Ruimtelijke%20data/16_import_maatregelen.sql)
