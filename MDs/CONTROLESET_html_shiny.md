# Controleset HTML en Shiny

Dit bestand is bedoeld als vaste controleset voor de combinatie van:

- de Shiny-app
- de csv-export uit de Shiny-app
- de standalone HTML

Gebruik deze controleset telkens als je iets hebt aangepast aan:

- `shiny_meijendel/app.R`
- `shiny_meijendel/helpers.R`
- `bmp_meijendel_index.html`
- de structuur van `Meijendel.sql`

## Standaardroute

De eenvoudigste werkroute is:

1. Start de Shiny-app.
2. Laad `Meijendel.sql`.
3. Kies kavels en jaren.
4. Klik op `Analyse uitvoeren`.
5. Controleer de uitkomsten in `Soorten`, `Groepen` en `Controle`.
6. Exporteer de csv-bestanden die je wilt bewaren of vergelijken.
7. Open daarna `bmp_meijendel_index.html`.
8. Laad daar `Meijendel.sql` en zo nodig de extra TRIM- of MSI-csv-bestanden.

## Vaste controles

### Controle 1. SQL laden

Doel:
Controleren of de database goed wordt ingelezen.

Controleer:

- de knop `SQL laden` werkt zonder foutmelding
- de kavellijst verschijnt
- de jaarkeuze verschijnt
- de statusmelding zegt dat de SQL is geladen

### Controle 2. Korte selectie

Doel:
Controleren of een gewone analyse zonder problemen draait.

Aanpak:

1. Kies een paar kavels.
2. Kies een korte periode, bijvoorbeeld een beperkt aantal jaren.
3. Klik op `Analyse uitvoeren`.

Controleer:

- er komt geen foutmelding
- in `Selectie` staat een logische samenvatting
- in `Controle` verschijnt dekking per kavel
- in `Controle` verschijnt geteld oppervlak per jaar

### Controle 3. Soortcontrole

Doel:
Controleren of de TRIM-uitkomsten per soort logisch zijn.

Controleer in `Soorten`:

- je kunt een soort kiezen
- de grafiek verschijnt
- de TRIM-index verandert over de jaren
- de GAM-lijn sluit logisch aan op de TRIM-punten
- de tabel toont trenduitleg en analysecategorie

Exporteer daarna:

- `meijendel_shiny_soorttrends_...csv`
- `meijendel_shiny_soortindices_...csv`

### Controle 4. Groepscontrole

Doel:
Controleren of de MSI-uitkomsten per ecologische groep logisch zijn.

Controleer in `Groepen`:

- je kunt een groep kiezen
- de MSI-grafiek verschijnt
- de GAM-lijn sluit logisch aan op de MSI-punten
- de tabel toont een trendoverzicht
- de tabel met soorten in de groep is gevuld

Exporteer daarna:

- `meijendel_shiny_groepstrends_...csv`
- `meijendel_shiny_groep_msi_...csv`

### Controle 5. Randgeval

Doel:
Controleren of de app netjes blijft werken bij een kleine of lastige selectie.

Probeer bijvoorbeeld:

- weinig kavels
- een korte periode
- een selectie met weinig soorten

Controleer:

- meldingen blijven duidelijk
- er komt geen onverwachte lege foutpagina
- tabellen en grafieken geven een begrijpelijke uitkomst of een duidelijke melding

## Koppeling tussen Shiny-export en HTML

De Shiny-app en de HTML hebben verschillende rollen.

- De Shiny-app maakt nieuwe analyses voor een vrije selectie.
- De HTML is vooral een presentatie- en controlepaneel.

Daarom horen de bestanden als volgt bij elkaar:

| Onderdeel | Bestand uit Shiny | Gebruik |
| --- | --- | --- |
| Soorttrends | `meijendel_shiny_soorttrends_...csv` | Controle van trenduitleg en soortsamenvatting |
| Soortindices | `meijendel_shiny_soortindices_...csv` | Controle van de jaarlijkse TRIM-reeks per soort |
| Groepstrends | `meijendel_shiny_groepstrends_...csv` | Controle van trenduitleg per groep |
| Groep-MSI | `meijendel_shiny_groep_msi_...csv` | Controle van MSI per groep per jaar |
| Analysebasis | `meijendel_shiny_analysebasis_...csv` | Controle van selectie, telling en oppervlak |
| Modelstatus | `meijendel_shiny_modelstatus_...csv` | Controle welke soorten wel of niet bruikbaar zijn |

Belangrijk:

- de HTML kan direct werken met `Meijendel.sql`
- voor TRIM- en MSI-panelen gebruikt de HTML aparte csv-bestanden
- de Shiny-export is daarom vooral bedoeld voor controle, vergelijking en archivering

## Praktische eindcontrole

Na een wijziging is de wijziging pas echt geslaagd als:

1. `Meijendel.sql` zonder fout laadt
2. een selectie analyseerbaar is
3. een soortgrafiek logisch oogt
4. een groepsgrafiek logisch oogt
5. csv-export werkt
6. de HTML nog zonder verwarring laat zien welke bron wordt gebruikt
