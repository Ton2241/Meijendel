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

Voor `plot_jaar_infra` blijft de bestaande verwijzing naar `plot_jaar_oppervlak` gelden. De centrale toegankelijkheidsregistraties verwijzen rechtstreeks naar `plots`; hun jaar beschrijft de geregistreerde toestand en is geen bewijs dat in dat jaar vogels zijn geteld. Controleer bron, jaar en plot vóór iedere import.

## Centrale registratie vanaf 16 oktober 2026

De 55 toegankelijkheidsregistraties voor 55 plots in 2024 staan in maatregel_toegankelijkheid_registratie: 20 vrij, 14 beperkt, 12 afgesloten, acht deels beperkt/deels vrij en één deels afgesloten/deels vrij. De deeltabel bevatte nul regels; de twee voorbeeldregels uit de deel-CSV zijn niet geïmporteerd. Status, bronspelling, plotnaam, opmerkingen, lege waarden en NULL blijven herleidbaar. De opmerking bij M36 blijft “nog controleren”. Een gemengde status bewijst geen oppervlakteverdeling.

maatregel_registratie_herkomst bevat 199 technische herkomstkoppelingen met oude sleutels, oorspronkelijke rijwaarden, hashes en precies één canoniek doel. Dit zijn auditgegevens, geen extra beheerfeiten. De 43 inhoudelijke maatregelbronnen zijn behouden; één administratieve bron voor deze migratie brengt maatregel_bron op 44 regels. Overnemen uit de handmatige registratie geeft geen nieuwe onafhankelijke bronbevestiging.

Nieuwe import richt zich op de maatregelregistraties. De drie bestaande import-SQL-bestanden gebruiken alleen tijdelijke staging en schrijven niet naar de compatibiliteitsviews. De oorspronkelijke bronidentiteit blijft bij correctie behouden; identieke herimport en gewijzigde herimport zijn op fixtures getest. LOAD DATA LOCAL vereist local_infile aan client- en serverzijde; de iMac-server heeft dit uitgeschakeld. Die globale instelling is in deze taak niet veranderd. Voer de voorbeeld-CSV’s niet als actuele levering in.

De namen `plot_jaar_toegankelijkheid` en `plot_jaar_toegankelijkheid_deel` zijn leesviews. De import-SQL gebruikt tijdelijke staging en schrijft naar `maatregel_toegankelijkheid_registratie`; de voorbeelden worden niet automatisch ingevoerd.
