# Shiny-app Meijendel

Dit is een werkende Shiny-opzet voor vrije TRIM-selecties op kavels.

De app staat in:

- `/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/app.R`

## Wat de app nu kan

- kavels aanklikken om ze te selecteren
- snel `Alle kavels` of `Geen kavels` kiezen
- een begin- en eindjaar kiezen
- per soort een nieuwe TRIM-analyse draaien
- per ecologische groep een nieuwe MSI berekenen
- duidelijke statusmeldingen tonen bij laden en analyseren
- een GAM-lijn over de soort- en groepsgrafieken tekenen
- uitkomsten exporteren naar csv
- een eenvoudige cache gebruiken zodat het laden van `Meijendel.sql` na de eerste keer sneller gaat

Tabbladen:

- `Selectie`
- `Soorten`
- `Groepen`
- `Controle`

## Nodige packages

Voor deze app zijn in elk geval nodig:

- `shiny`
- `rtrim`
- `mgcv`
- `bslib`

## Starten

Open R of RStudio en voer uit:

```r
setwd("/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel")
shiny::runApp(host = "127.0.0.1", port = 3867)
```

Of gebruik het startscript:

```bash
/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_local.sh
```

Daarna open je:

- `http://127.0.0.1:3867`

## Werkwijze in de app

1. Klik op `SQL laden`.
2. Wacht op de melding dat de SQL is geladen.
3. Klik kavels aan om ze aan de selectie toe te voegen.
4. Kies `Van jaar` en `Tot jaar`.
5. Klik op `Analyse uitvoeren`.

Daarna kun je:

- in `Soorten` de TRIM-index en de GAM-lijn bekijken
- in `Groepen` de MSI en de GAM-lijn bekijken
- in `Controle` de analysebasis en modelstatus controleren
- via de knoppen csv-bestanden downloaden

## Standaardroute

Gebruik bij voorkeur steeds deze vaste route:

1. Start de Shiny-app.
2. Klik op `SQL laden`.
3. Kies kavels.
4. Kies `Van jaar` en `Tot jaar`.
5. Klik op `Analyse uitvoeren`.
6. Controleer de uitkomsten in `Soorten`, `Groepen` en `Controle`.
7. Download de csv-bestanden die je wilt bewaren.
8. Open daarna pas `bmp_meijendel_index.html` als je de gegevens ook in de standalone HTML wilt bekijken.

## CSV-export

De app kan nu exporteren naar csv voor:

- soorttrends
- soortindices
- groepstrends
- groep-MSI
- analysebasis
- modelstatus

De bestandsnamen beginnen nu steeds met `meijendel_shiny_`.
Zo kun je Shiny-exports makkelijker onderscheiden van andere csv-bestanden in deze repository.

## Koppeling met de HTML

De Shiny-app en de HTML zijn niet precies hetzelfde.

- De Shiny-app is bedoeld om nieuwe selecties door te rekenen.
- De HTML is bedoeld om gegevens overzichtelijk te tonen.

Praktisch:

- gebruik de Shiny-app om een selectie te analyseren
- gebruik de Shiny-csv's om resultaten te controleren of te bewaren
- gebruik de HTML om `Meijendel.sql` en de vaste TRIM- en MSI-bestanden zichtbaar te maken

Voor een vaste controleset kun je ook kijken in:

- `/Users/ton/Documents/GitHub/Meijendel/CONTROLESET_html_shiny.md`

## Tailscale voor Shiny

Er staat ook een startscript klaar voor Tailscale:

```bash
/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_tailscale.sh
```

Dat script doet nu in één keer:

1. het start de Shiny-app lokaal op `127.0.0.1:3867`
2. het opent lokaal de app in je browser
3. het activeert `tailscale serve` voor die poort
4. het toont de lokale URL en de Tailscale-URL in de Terminal

De huidige Tailscale-URL voor deze Mac is:

- `https://imac-van-antonius-2.tailaba97d.ts.net/`

Deze URL werkt alleen zolang:

- Tailscale actief is op deze Mac
- de Shiny-app draait
- het apparaat waarmee je kijkt ook in jouw tailnet zit

Praktisch gebruik:

- op de iMac zelf: `http://127.0.0.1:3867`
- op een ander Tailscale-apparaat: `https://imac-van-antonius-2.tailaba97d.ts.net/`

## Beperkingen

Deze versie is nog steeds een werkmodel.

Er zit nog niet in:

- kaartweergave van kavels
- meerdere lijnen tegelijk in de soortgrafiek
- volledig afgeronde Tailscale-configuratie vanuit de app zelf

Maar methodisch doet deze versie wel al wat nodig is:

- opnieuw rekenen voor de gekozen kavels
- correcte `0` voor wel geteld maar niet aanwezig
- lege waarde voor niet geteld
- TRIM per soort
- MSI per ecologische groep
