# Ontwerp bezoekersdruklaag uit Dunea-rapport 2022

Dit document ontwerpt een aparte bezoekersdruklaag op basis van het Dunea-rapport:

- [RAPPORT Trendanalyse Meijendel, 29 november 2022](https://www.dunea.nl/over-dunea/-/media/bestanden/duinen/rapport-trendanalyse-meijendel-29-11-22.pdf)

## Waarom een aparte laag

Deze gegevens horen niet direct in `plot_jaar_infra`.

Reden:

- het rapport werkt vooral met telpunten, bezoekersaantallen en parkeerterreinen
- de gegevens zijn vaak per locatie, seizoen of categorie
- de koppeling naar `plot_id` is meestal niet rechtstreeks gegeven

Dus:

- recreatie-afstanden per plot blijven in `plot_jaar_infra`
- bezoekersdruk uit het rapport komt in een aparte bronlaag

## Wat staat aantoonbaar in het rapport

Volgens het rapport en de begeleidende Dunea-berichten zijn de data opgesplitst in:

- telcijfers
- bezoekersaantallen
- parkeerbezetting

Bronnen:

- [rapport, methodiek](https://www.dunea.nl/over-dunea/-/media/bestanden/duinen/rapport-trendanalyse-meijendel-29-11-22.pdf)
- [Dunea nieuwsbericht 1 december 2022](https://www.dunea.nl/zakelijk/nieuwsbrieven/nieuwsbrief-2022-12/ontwikkeling-bezoek-meijendel-volgt-landelijke-trend)

Verder staat aantoonbaar in het rapport:

- De Vallei is het recreatieve hart van Meijendel
- parkeeranalyse is apart uitgewerkt voor:
  - `P2 en P3 De Vallei`
  - `P1 Kievietstop`
- seizoenen spelen een duidelijke rol
- de hoogste parkeerdruk komt juist vaak in na- en winterseizoen voor op specifieke piekdagen

Bron:

- [rapport, parkeeranalyse en tabellen](https://www.dunea.nl/duinen/-/media/bestanden/duinen/rapport-trendanalyse-meijendel-29-11-22.pdf)

## Ontwerpkeuze

We ontwerpen 3 tabellen:

1. `bezoekersdruk_locatie`
2. `bezoekersdruk_meting`
3. `plot_bezoekersdruk_koppeling`

De eerste 2 tabellen vormen de eigenlijke bronlaag.
De derde tabel is optioneel en pas later nodig als je delen van de bronlaag aan plots wilt koppelen.

## Tabel 1: bezoekersdruk_locatie

Doel:

- vaste lijst met locaties uit het rapport

Voorbeelden van locaties:

- `De Vallei`
- `Kievietstop`
- telpunten op de Meijendelseweg
- telpunten voor fietsverkeer
- eventueel later extra rapportlocaties uit de update 2024

Voorgestelde kolommen:

- `id`
- `naam`
- `locatie_type`
- `bron`
- `omschrijving`
- `geom`

Voor `locatie_type` bijvoorbeeld:

- `gebied`
- `parkeerterrein`
- `telpunt_auto`
- `telpunt_fiets`
- `entree`

## Tabel 2: bezoekersdruk_meting

Doel:

- alle meetwaarden uit het rapport opslaan

Voorgestelde kolommen:

- `id`
- `locatie_id`
- `jaar`
- `seizoen`
- `dagtype`
- `indicator`
- `waarde`
- `eenheid`
- `bron`
- `herkomst`
- `opmerking`

### Uitleg

- `locatie_id`: verwijst naar `bezoekersdruk_locatie`
- `jaar`: bijvoorbeeld `2020`, `2021`, later eventueel `2022`, `2023`
- `seizoen`: bijvoorbeeld `winter`, `voorseizoen`, `hoogseizoen`, `naseizoen`
- `dagtype`: bijvoorbeeld `weekdag`, `weekend`, of leeg als niet van toepassing
- `indicator`: welk soort waarde dit is
- `waarde`: de numerieke waarde
- `eenheid`: bijvoorbeeld `bezoekers_per_dag`, `voertuigen_per_dag`, `pct_bezetting`, `dagen`
- `bron`: bijvoorbeeld `DUNEA_RAPPORT_2022`
- `herkomst`: bijvoorbeeld `tabel`, `grafiek`, `tekst`
- `opmerking`: korte context

## Indicatoren

Gebruik niet te veel vrije tekst.
Leg vaste indicatornamen vast.

Voorgestelde indicatoren:

- `bezoekers_totaal_jaar`
- `bezoekers_per_dag_gemiddeld`
- `autos_per_dag_gemiddeld`
- `fietsen_per_dag_gemiddeld`
- `voetgangers_per_dag_gemiddeld`
- `parkeer_bezetting_gemiddeld_pct`
- `parkeer_dagen_80_90_pct`
- `parkeer_dagen_90_100_pct`
- `parkeer_capaciteit_totaal`
- `parkeer_capaciteit_bezoekers`

## Tabel 3: plot_bezoekersdruk_koppeling

Doel:

- later, alleen als nodig, bezoekersdruklocaties koppelen aan plots

Waarom apart:

- het rapport geeft deze koppeling niet direct
- je wilt niet doen alsof een rapportlocatie automatisch gelijk is aan één plot

Voorgestelde kolommen:

- `plot_id`
- `locatie_id`
- `koppeling_type`
- `gewicht`
- `opmerking`

Voor `koppeling_type` bijvoorbeeld:

- `dichtstbijzijnde`
- `binnen_buffer`
- `handmatig_toegewezen`
- `zelfde_deelgebied`

## SQL-ontwerp

Voorstel:

```sql
DROP TABLE IF EXISTS bezoekersdruk_meting;
DROP TABLE IF EXISTS bezoekersdruk_locatie;

CREATE TABLE bezoekersdruk_locatie (
  id INT NOT NULL AUTO_INCREMENT,
  naam VARCHAR(255) NOT NULL,
  locatie_type VARCHAR(50) NOT NULL,
  bron VARCHAR(50) NOT NULL,
  omschrijving VARCHAR(255) DEFAULT NULL,
  geom GEOMETRY /*!80003 SRID 28992 */ DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE bezoekersdruk_meting (
  id INT NOT NULL AUTO_INCREMENT,
  locatie_id INT NOT NULL,
  jaar INT NOT NULL,
  seizoen VARCHAR(30) DEFAULT NULL,
  dagtype VARCHAR(30) DEFAULT NULL,
  indicator VARCHAR(80) NOT NULL,
  waarde DOUBLE DEFAULT NULL,
  eenheid VARCHAR(50) DEFAULT NULL,
  bron VARCHAR(50) NOT NULL,
  herkomst VARCHAR(30) DEFAULT NULL,
  opmerking VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_bezoekersdruk_locatie_jaar (locatie_id, jaar),
  CONSTRAINT fk_bezoekersdruk_locatie
    FOREIGN KEY (locatie_id)
    REFERENCES bezoekersdruk_locatie (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

Optioneel later:

```sql
DROP TABLE IF EXISTS plot_bezoekersdruk_koppeling;

CREATE TABLE plot_bezoekersdruk_koppeling (
  plot_id INT NOT NULL,
  locatie_id INT NOT NULL,
  koppeling_type VARCHAR(50) NOT NULL,
  gewicht DOUBLE DEFAULT NULL,
  opmerking VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (plot_id, locatie_id, koppeling_type),
  CONSTRAINT fk_pbk_plot
    FOREIGN KEY (plot_id)
    REFERENCES plots (plot_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_pbk_locatie
    FOREIGN KEY (locatie_id)
    REFERENCES bezoekersdruk_locatie (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

## Waarom dit ontwerp goed past

- seizoensinformatie kan netjes worden opgeslagen
- parkeerdruk en bezoekersdruk hoeven niet in dezelfde meeteenheid te zitten
- De Vallei en Kievietstop kunnen als aparte locaties bestaan
- telpunten kunnen later ook worden toegevoegd zonder nieuw schema
- koppeling naar plots blijft optioneel en eerlijk gescheiden van de brondata

## Eerste invulling die hier logisch op volgt

Begin niet meteen met alle grafieken.
Begin eerst met de hardste brononderdelen uit het rapport:

1. locaties:
   - `De Vallei P2_P3`
   - `Kievietstop P1`
2. metingen:
   - parkeercapaciteit
   - gemiddelde bezetting per seizoen
   - aantal dagen met bezetting 80-90%
   - aantal dagen met bezetting 90-100%

Daarna pas:

3. bezoekersaantallen per jaar
4. auto- en fietstelpunten
5. eventuele koppeling naar plots
