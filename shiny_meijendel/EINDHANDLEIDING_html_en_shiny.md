# Eindhandleiding HTML en Shiny

Dit is de korte, samengevoegde werkwijze voor het werken met:

- de Shiny-app
- de csv-export uit de Shiny-app
- `bmp_meijendel_index.html`

## Waarvoor gebruik je wat?

Gebruik de Shiny-app als je een nieuwe selectie wilt doorrekenen.

Gebruik de HTML als je gegevens overzichtelijk wilt bekijken en presenteren.

Kort:

- Shiny = rekenen
- HTML = bekijken en uitleggen

## Standaard werkwijze

Gebruik meestal deze volgorde:

1. Start de Shiny-app.
2. Laad `Meijendel.sql`.
3. Kies kavels.
4. Kies `Van jaar` en `Tot jaar`.
5. Klik op `Analyse uitvoeren`.
6. Controleer de uitkomsten in `Soorten`, `Groepen` en `Controle`.
7. Download csv-bestanden als je de uitkomsten wilt bewaren of vergelijken.
8. Open daarna `bmp_meijendel_index.html` als je de gegevens overzichtelijk wilt bekijken.

## Wat controleer je altijd even?

Na een analyse kijk je kort of:

- `Meijendel.sql` zonder fout laadt
- de kavellijst zichtbaar is
- de analyse zonder foutmelding draait
- in `Soorten` een logische TRIM-grafiek verschijnt
- in `Groepen` een logische MSI-grafiek verschijnt
- in `Controle` dekking, oppervlak en modelstatus logisch zijn

## Welke csv-bestanden gebruik je waarvoor?

De Shiny-app maakt onder andere deze bestanden:

| Bestand | Gebruik |
| --- | --- |
| `meijendel_shiny_soorttrends_...csv` | trendoverzicht per soort |
| `meijendel_shiny_soortindices_...csv` | jaarlijkse TRIM-index per soort |
| `meijendel_shiny_groepstrends_...csv` | trendoverzicht per groep |
| `meijendel_shiny_groep_msi_...csv` | MSI per groep per jaar |
| `meijendel_shiny_analysebasis_...csv` | controle van selectie, telling en oppervlak |
| `meijendel_shiny_modelstatus_...csv` | controle welke soorten bruikbaar zijn |

## Welke bron gebruikt de HTML?

In `bmp_meijendel_index.html` gelden deze hoofdregels:

- `Territoria` gebruikt ruwe gegevens uit `Meijendel.sql`
- `Dichtheid (per km²)` gebruikt `Meijendel.sql` plus oppervlak en tellerinformatie
- `TRIM-index` gebruikt aparte TRIM-csv-bestanden
- `GAM (dichtheid)` gebruikt groepsbestanden op basis van dichtheid
- `TRIM-MSI` gebruikt aparte TRIM-MSI-bestanden

## Wanneer is het werk geslaagd?

De werkwijze is geslaagd als:

1. de Shiny-app zonder problemen draait
2. je een selectie kunt analyseren
3. de grafieken logisch ogen
4. de csv-export werkt
5. de HTML duidelijk laat zien welke bron wordt gebruikt

## Handige achtergrondbestanden

Als je meer uitleg wilt, kijk dan in:

- `/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/README_shiny_meijendel.md`
- `/Users/ton/Documents/GitHub/Meijendel/MDs/README_bmp_meijendel_index.md`
- `/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/CONTROLESET_html_shiny.md`
