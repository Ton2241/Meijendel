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

## CSV-export

De app kan nu exporteren naar csv voor:

- soorttrends
- soortindices
- groepstrends
- groep-MSI
- analysebasis
- modelstatus

## Tailscale voor Shiny

Er staat ook een startscript klaar voor Tailscale:

```bash
/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_tailscale.sh
```

Dat script doet twee dingen:

1. het start de Shiny-app lokaal op `127.0.0.1:3867`
2. het probeert daarna `tailscale serve` te activeren voor die poort

Daarvoor moet de Tailscale commandoregeltool op jouw Mac wel goed werken. Op dit moment staat de Tailscale-app er wel, maar de CLI gaf tijdens mijn test nog een voorkeurenfout. De voorbereidende bestanden staan nu klaar, maar het echte activeren van `tailscale serve` moet nog even worden afgemaakt zodra de CLI normaal reageert.

## Beperkingen

Deze versie is nog steeds een werkmodel.

Er zit nog niet in:

- kaartweergave van kavels
- meerdere lijnen tegelijk in de soortgrafiek
- onzekerheidsbanden in de grafieken
- volledig afgeronde Tailscale-configuratie vanuit de app zelf

Maar methodisch doet deze versie wel al wat nodig is:

- opnieuw rekenen voor de gekozen kavels
- correcte `0` voor wel geteld maar niet aanwezig
- lege waarde voor niet geteld
- TRIM per soort
- MSI per ecologische groep
