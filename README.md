## Database dump (Meijendel)

Deze repository bevat een MySQL/MariaDB‑dump van de database **Meijendel**.

- Bron: TablePlus 6.8.5
- Generatietijd: 2026-03-09 22:22:45
- Dumpbestand: `20260309.sql`
- Charset/collation: `utf8mb4` / `utf8mb4_0900_ai_ci`
- Bevat `DROP TABLE` + `CREATE TABLE` + `INSERT` statements

### Tabellen (31)
Belangrijke domeinen die in de dump voorkomen:
- Soorten en taxonomie: `soorten`, `familie`, `soort_familie`, `richtlijnen`, `soort_richtlijn`
- Habitat/maatregelen: `habitattypen`, `habitattypen_doelstelling`, `soort_habitat`, `maatregelen`, `maatregel_habitat`
- Plotgegevens en tijdreeksen: `plots`, `plot_jaar_oppervlak`, `plot_jaar_habitat`, `plot_jaar_teller`, `plot_jaar_maatregel`
- Trends en territoria: `trends`, `territoria`
- Weerdata: `weer`, `weer_legenda`
- EVG/vogel/landschap indelingen: `evg_landschapstypen`, `evg_vogelgroepen`, `evg_vogel_landschapgroep`, `evg_vogel_landschapstype`
- Overig/inputs: `import_waarnemingen_breed`, `import_waarnemingen_lang`, `plotkolom_mapping`, `kernopgaven`, `kernopgave_soort`, `kernopgave_habitat`, `BGgroup`, `vogelstand_1924`

### Inhoud (rij‑aantallen)
Onderstaande aantallen zijn afgeleid uit het aantal tuples in de `INSERT`‑statements in de dump.

| Tabel                       | Rijen  |
| --------------------------- | -----: |
| `territoria`                | 70,724 |
| `weer`                      | 24,837 |
| `trends`                    | 11,165 |
| `plot_jaar_oppervlak`       | 5,296  |
| `plot_jaar_teller`          | 2,378  |
| `evg_vogel_landschapstype`  | 622    |
| `soorten`                   | 604    |
| `evg_vogel_landschapgroep`  | 418    |
| `tellers`                   | 199    |
| `soort_familie`             | 181    |
| `soort_richtlijn`           | 174    |
| `BGgroup`                   | 163    |
| `import_waarnemingen_breed` | 156    |
| `vogelstand_1924`           | 75     |
| `familie`                   | 71     |
| `plots`                     | 69     |
| `plotkolom_mapping`         | 54     |
| `plot_jaar_habitat`         | 51     |
| `maatregel_habitat`         | 47     |
| `evg_vogelgroepen`          | 43     |
| `import_waarnemingen_lang`  | 28     |
| `evg_landschapstypen`       | 18     |
| `soort_habitat`             | 18     |
| `habitattypen_doelstelling` | 15     |
| `habitattypen`              | 14     |
| `kernopgave_soort`          | 11     |
| `kernopgave_habitat`        | 9      |
| `maatregelen`               | 9      |
| `weer_legenda`              | 8      |
| `richtlijnen`               | 7      |
| `kernopgaven`               | 4      |

| Tabel                       | Rijen  |
| --------------------------- | -----: |
| `territoria`                | 70,724 |
| `weer`                      | 24,837 |
| `trends`                    | 11,165 |
| `plot_jaar_oppervlak`       | 5,296  |
| `plot_jaar_teller`          | 2,378  |
| `soorten`                   | 604    |
| `evg_vogel_landschapstype`  | 622    |
| `evg_vogel_landschapgroep`  | 418    |
| `soort_familie`             | 181    |
| `soort_richtlijn`           | 174    |
| `BGgroup`                   | 163    |
| `import_waarnemingen_breed` | 156    |
| `plots`                     | 69     |
| `familie`                   | 71     |
| `vogelstand_1924`           | 75     |
| `plotkolom_mapping`         | 54     |
| `plot_jaar_habitat`         | 51     |
| `evg_vogelgroepen`          | 43     |
| `maatregel_habitat`         | 47     |
| `import_waarnemingen_lang`  | 28     |
| `habitattypen_doelstelling` | 15     |
| `habitattypen`              | 14     |
| `kernopgave_soort`          | 11     |
| `kernopgave_habitat`        | 9      |
| `maatregelen`               | 9      |
| `richtlijnen`               | 7      |
| `kernopgaven`               | 4      |
| `evg_landschapstypen`       | 18     |
| `soort_habitat`             | 18     |
| `weer_legenda`              | 8      |

### Foreign keys (uit `Meijendel.dump`)
- `evg_vogel_landschapgroep.groepsnummer` -\> `evg_vogelgroepen.groepsnummer`
- `evg_vogel_landschapgroep.vogel_id` -\> `soorten.id`
- `evg_vogel_landschapstype.landschap_id` -\> `evg_landschapstypen.id`
- `evg_vogel_landschapstype.soort_id` -\> `soorten.id`
- `kernopgave_habitat.habitat_id` -\> `habitattypen.id`
- `kernopgave_habitat.kernopgave_id` -\> `kernopgaven.id`
- `kernopgave_soort.kernopgave_id` -\> `kernopgaven.id`
- `kernopgave_soort.soort_id` -\> `soorten.id`
- `maatregel_habitat.habitat_id` -\> `habitattypen.id`
- `maatregel_habitat.maatregel_id` -\> `maatregelen.id`
- `plot_jaar_habitat.habitat_id` -\> `habitattypen.id`
- `plot_jaar_habitat.plot_id` -\> `plots.plot_id`
- `plot_jaar_maatregel.maatregel_id` -\> `maatregelen.id`
- `plot_jaar_maatregel.plot_id` -\> `plots.plot_id`
- `plot_jaar_oppervlak.plot_id` -\> `plots.plot_id`
- `plot_jaar_teller.teller_id` -\> `tellers.id`
- `plot_jaar_teller.plot_id` -\> `plots.plot_id`
- `plotkolom_mapping.plot_id` -\> `plots.plot_id`
- `soort_familie.familie_id` -\> `familie.id`
- `soort_familie.soort_id` -\> `soorten.id`
- `soort_habitat.habitat_id` -\> `habitattypen.id`
- `soort_habitat.soort_id` -\> `soorten.id`
- `soort_richtlijn.richtlijn_id` -\> `richtlijnen.id`
- `soort_richtlijn.soort_id` -\> `soorten.id`
- `territoria.plot_id, territoria.jaar` -\> `plot_jaar_oppervlak.plot_id, plot_jaar_oppervlak.jaar`
- `territoria.plot_id` -\> `plots.plot_id`
- `territoria.soort_id` -\> `soorten.id`
- `trends.soort_id` -\> `soorten.id`
- `vogelstand_1924.soort_id` -\> `soorten.id`
