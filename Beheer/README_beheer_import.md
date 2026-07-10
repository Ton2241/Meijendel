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

Voor een nieuw, nog leeg jaar kan de data daarna in een keer worden toegepast:

```bash
scripts/apply_website_kavelbezetting.py apply --csv /pad/naar/vwg-m-kavelbezetting-<jaar>-bmp.csv --year <jaar> --yes
```

Voor een lopend jaar met wijzigingen in bestaande kavelbezetting: gebruik de diff-route. Die toont eerst welke teller/kavel-regels toegevoegd en verwijderd worden:

```bash
scripts/apply_website_kavelbezetting.py diff-run --csv /pad/naar/vwg-m-kavelbezetting-<jaar>-bmp.csv --year <jaar>
scripts/apply_website_kavelbezetting.py diff-plan --csv /pad/naar/vwg-m-kavelbezetting-<jaar>-bmp.csv --year <jaar> --plan /private/tmp/kavelbezetting_<jaar>_diff.sql
scripts/apply_website_kavelbezetting.py diff-apply --csv /pad/naar/vwg-m-kavelbezetting-<jaar>-bmp.csv --year <jaar> --confirm-full-year --yes
```

`--confirm-full-year` is verplicht zodra de diff verwijderingen bevat. Gebruik dit alleen als de CSV een complete jaarexport uit de website is, niet bij een handmatig gefilterde of gedeeltelijke CSV.

Als een doeljaar bewust volledig opnieuw moet worden opgebouwd:

```bash
scripts/apply_website_kavelbezetting.py apply --csv /pad/naar/vwg-m-kavelbezetting-<jaar>-bmp.csv --year <jaar> --replace-year --yes
```

Pas data alleen toe als de dry-run/diff-run geen onbeoordeelde waarschuwingen geeft en het SQL-plan is gecontroleerd. Het script verwerkt alleen `object_type=plot` en `assignment_type=bmp`. Winterkavels en PTT-routes blijven buiten `plot_jaar_teller`, omdat die Meijendel-tabel alleen BMP-plot/jaar/teller-koppelingen bevat.
