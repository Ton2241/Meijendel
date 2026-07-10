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

## Kavelbezetting nieuw jaar

Gebruik voor BMP-kavelbezetting de beveiligde website-export uit VWG_M:

```text
/leden/kavels.csv?year=<jaar>&type_filter=bmp
```

Sla de CSV lokaal op en controleer hem daarna tegen de lokale Meijendel-MySQL:

```bash
cd /Users/ton/Documents/GitHub/Meijendel
scripts/apply_website_kavelbezetting.py dry-run --csv /pad/naar/vwg-m-kavelbezetting-<jaar>-bmp.csv --year <jaar>
scripts/apply_website_kavelbezetting.py plan --csv /pad/naar/vwg-m-kavelbezetting-<jaar>-bmp.csv --year <jaar> --plan /private/tmp/kavelbezetting_<jaar>.sql
```

Pas de data pas toe als de dry-run geen waarschuwingen geeft en het SQL-plan is gecontroleerd:

```bash
scripts/apply_website_kavelbezetting.py apply --csv /pad/naar/vwg-m-kavelbezetting-<jaar>-bmp.csv --year <jaar> --yes
```

Als het doeljaar al regels bevat en bewust opnieuw moet worden opgebouwd:

```bash
scripts/apply_website_kavelbezetting.py apply --csv /pad/naar/vwg-m-kavelbezetting-<jaar>-bmp.csv --year <jaar> --replace-year --yes
```

Het script verwerkt alleen `object_type=plot` en `assignment_type=bmp`. Winterkavels en PTT-routes blijven buiten `plot_jaar_teller`, omdat die Meijendel-tabel alleen BMP-plot/jaar/teller-koppelingen bevat.
