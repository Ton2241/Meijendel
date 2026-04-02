# Werkwijze ruimtelijke data koppelen aan plots

Doel: per plot alleen samengevatte waarden opslaan in MySQL, niet de volledige raster- of vectorbestanden.

## 1. Eerst uitvoeren in MySQL

Open `Ruimtelijke data/01_schema_plot_omgeving.sql` en voer dit bestand uit in database `meijendel`.

Hiermee maak je 2 nieuwe tabellen:

- `plot_env_continuous`
- `plot_landuse`

Belangrijk:

- `plot_id` is in jouw database een getal, geen tekst.
- `jaar` moet altijd bestaan in `plot_jaar_oppervlak`.
- Daardoor kun je alleen gegevens opslaan voor plots en jaren die al geldig zijn in de database.

## 2. Startvolgorde

Werk in deze vaste volgorde:

1. AHN
2. Stikstof
3. Landgebruik

Begin dus niet met landgebruik.

## 3. Voorbereiding in QGIS

Controleer eerst dit:

1. De plotlaag staat in `EPSG:28992`.
2. De externe databron staat ook in `EPSG:28992`.
3. Het juiste jaar van de plotgrenzen is gekozen.

Gebruik per analyse alleen de plotgrenzen van het juiste jaar.

## 4. AHN per plot

Benodigd:

- plotpolygonen
- AHN GeoTIFF

Stappen in QGIS:

1. Laad de plotlaag.
2. Laad het AHN-raster.
3. Controleer bij beide lagen of CRS `EPSG:28992` is.
4. Kies `Raster` -> `Zonal statistics`.
5. Kies als polygonlaag de plots.
6. Kies als rasterlaag het AHN-bestand.
7. Vink minimaal aan:
   - `Mean`
   - `Standard deviation`
8. Voer de bewerking uit.

Resultaat:

De plotlaag krijgt nieuwe kolommen met gemiddelde hoogte en standaardafwijking.

Maak daarna een CSV met minimaal deze kolommen:

- `plot_id`
- `jaar`
- `bron`
- `ahn_mean`
- `ahn_sd`
- `stikstof_mean`
- `stikstof_median`

Voor AHN vul je:

- `bron` bijvoorbeeld met `AHN4`
- `stikstof_mean` als leeg
- `stikstof_median` als leeg

## 5. Stikstof per plot

Benodigd:

- plotpolygonen
- AERIUS Monitor GeoPackage van een expliciet jaar

Stappen in QGIS:

1. Laad de plotlaag.
2. Laad de stikstoflaag.
3. Controleer CRS `EPSG:28992`.
4. Kies `Join attributes by location (summary)`.
5. Gebruik de plotlaag als doellaag.
6. Gebruik de stikstoflaag als joinlaag.
7. Kies het stikstofveld met de depositiewaarde.
8. Laat in elk geval `mean` berekenen.
9. Als QGIS ook `median` kan samenvatten in jouw versie, neem die mee.

Resultaat:

Je krijgt per plot samengevatte stikstofwaarden.

Maak daarna een CSV met minimaal deze kolommen:

- `plot_id`
- `jaar`
- `bron`
- `ahn_mean`
- `ahn_sd`
- `stikstof_mean`
- `stikstof_median`

Voor stikstof vul je:

- `bron` bijvoorbeeld met `AERIUS_2023`
- `ahn_mean` als leeg
- `ahn_sd` als leeg

## 6. Landgebruik per plot

Hier zijn 2 routes.

### Route A: LGN raster

Gebruik:

1. plotlaag laden
2. LGN raster laden
3. CRS controleren op `EPSG:28992`
4. `Zonal histogram` uitvoeren

Resultaat:

Per plot krijg je aantallen pixels per klasse.

Reken daarna per plot om naar:

- `area_m2`
- `pct`

Sla nooit alleen gemiddelden van klassen op.

### Route B: CBS Bodemgebruik vector

Gebruik:

1. plotlaag laden
2. CBS-laag laden
3. CRS controleren op `EPSG:28992`
4. `Intersection` uitvoeren
5. oppervlak per snijvlak berekenen
6. groeperen per `plot_id`, `jaar`, `klasse`

Resultaat:

Per plot en klasse krijg je oppervlak en percentage.

Maak daarna een CSV met deze kolommen:

- `plot_id`
- `jaar`
- `bron`
- `klasse`
- `area_m2`
- `pct`

## 7. Import in MySQL

Voor `plot_env_continuous`:

Gebruik het voorbeeld in `Ruimtelijke data/01_schema_plot_omgeving.sql`.

Voor `plot_landuse`:

Gebruik ook het voorbeeld in datzelfde SQL-bestand.

Belangrijk:

- exporteer vanuit QGIS als CSV met komma als scheidingsteken
- laat de eerste rij bestaan uit kolomnamen
- gebruik lege velden voor niet-beschikbare waarden

## 8. Controle na import

Controleer daarna altijd:

1. Staat elk `plot_id` ook in `plots`?
2. Staat elke combinatie `plot_id + jaar` ook in `plot_jaar_oppervlak`?
3. Is `pct` tussen 0 en 100?
4. Is de som van `pct` per plot ongeveer 100?
5. Zijn `bron` en `jaar` expliciet ingevuld?

## 9. Eerste uitvoering

Voer nu alleen AHN uit als eerste proef.

Kies dus eerst:

1. juiste plotlaag van 1 jaar
2. bijpassend AHN-bestand
3. zonal statistics
4. export naar CSV
5. import in `plot_env_continuous`

Stop daarna en controleer het resultaat voordat je met stikstof verdergaat.
