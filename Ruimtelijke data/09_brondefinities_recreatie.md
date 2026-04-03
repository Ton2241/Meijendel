# Brondefinities recreatie en infrastructuur

Dit document werkt stap 2 uit:
per variabele vastleggen welke bron we gebruiken, wat we precies meten en hoe we de uitkomst veilig naar `plot_id` en `jaar` vertalen.

## Waarom deze stap nodig is

De grootste fout die hier kan ontstaan is dat we gegevens met een andere schaal door elkaar halen:

- BGT en OSM zijn ruimtelijke objectbronnen
- het Dunea-rapport uit 2022 bevat vooral gebieds- en telpuntinformatie

Daarom leggen we eerst de meetregels vast voordat we SQL-tabellen of imports maken.

## Bronoverzicht

### 1. BGT

Te gebruiken voor:

- paden
- wegen
- relevante objecten in de openbare ruimte

Rol in dit project:

- hoofdbron voor geometrie van paden en wegen
- controlebron naast OSM

Belangrijke beperking:

- BGT geeft objecten, maar niet automatisch recreatieve druk of bezoekersaantallen

### 2. OpenStreetMap

Te gebruiken voor:

- `highway`-objecten
- parkeerplaatsen
- voorzieningen
- ingangen en andere recreatief relevante objecten, voor zover aanwezig

Rol in dit project:

- bron voor parkeerplaatsen, voorzieningen en aanvullende infrastructuur
- extra controle op paden en wegen naast BGT

Belangrijke beperking:

- dekking en detaillering kunnen per object verschillen
- niet ieder object heeft een expliciet label `hoofdtoegang`

### 3. Dunea-rapport 2022

Bron:

- [RAPPORT Trendanalyse Meijendel, 29 november 2022](https://www.dunea.nl/duinen/-/media/bestanden/duinen/rapport-trendanalyse-meijendel-29-11-22.pdf)

Wat hierin aantoonbaar staat:

- De Vallei is het recreatieve kerngebied rond De Tapuit.
- Er is aparte informatie over parkeerplaatsen P1, P2 en P3.
- Het rapport gebruikt telpunten voor fiets- en gemotoriseerd verkeer.
- Het rapport bevat parkeerbezetting, bezoekersaantallen en seizoensinvloed.

Belangrijke beperking:

- dit rapport levert niet rechtstreeks een waarde per `plot_id`
- het bevat vooral gegevens voor gebied, telpunt, parkeerlocatie of periode

Conclusie:

- deze bron gebruiken we niet direct als vulling van `plot_jaar_infra`
- eerst moet een aparte bronlaag of vertaaltabel worden gemaakt

## Definities per variabele

### Variabele 1: `afstand_pad_m`

Betekenis:

- kortste afstand in meters van het plot naar het dichtstbijzijnde pad

Voorkeursbron:

- BGT

Controlebron:

- OSM `highway`-objecten die als pad of weg relevant zijn

Meetregel:

- bepaal de minimale afstand van de plotgeometrie tot de dichtstbijzijnde padgeometrie

Jaarlogica:

- alleen per jaar wijzigen als padennetwerk aantoonbaar is veranderd
- anders dezelfde waarde herhalen over meerdere jaren

### Variabele 2: `padlengte_m_per_ha`

Betekenis:

- totale lengte van paden binnen het plot, omgerekend naar meter per hectare plotoppervlak

Voorkeursbron:

- BGT

Controlebron:

- OSM `highway`-objecten

Meetregel:

- knip paden op plotgrenzen
- tel de lengte binnen het plot op
- deel door het plotoppervlak in hectare

Jaarlogica:

- alleen aanpassen bij aantoonbare wijziging in paden of plotgrens

### Variabele 3: `afstand_parkeerplaats_m`

Betekenis:

- kortste afstand in meters van het plot naar de dichtstbijzijnde parkeerplaats

Voorkeursbron:

- OSM parkeerobjecten

Controlebron:

- BGT objecten of handmatige lijst van bekende parkeerlocaties

Meetregel:

- minimale afstand van de plotgeometrie tot de dichtstbijzijnde parkeerplaatsgeometrie of parkeerpunt

Jaarlogica:

- alleen aanpassen als een parkeerplaats is toegevoegd, verwijderd of verplaatst

### Variabele 4: `afstand_hoofdtoegang_m`

Betekenis:

- kortste afstand in meters van het plot naar een gedefinieerde hoofdtoegang van Meijendel

Voorkeursbron:

- handmatig vastgelegde lijst van hoofdtoegangen, ondersteund door OSM en Dunea-context

Waarom niet alleen BGT of OSM:

- `hoofdtoegang` is meestal een beheerkeuze, niet alleen een objecttype

Meetregel:

- maak eerst een vaste lijst met hoofdtoegangspunten
- bereken daarna de minimale afstand van het plot tot die punten

Jaarlogica:

- alleen aanpassen als de definitie of ligging van hoofdtoegang verandert

## Toegankelijkheidsstatus

Nieuwe categorische variabele per `plot_id` en `jaar`:

- `afgesloten`
- `beperkt`
- `vrij`

Voorkeursbron:

- beheerinformatie van Dunea of handmatige registratie op basis van bekende zonering en afsluiting

Niet geschikt als primaire bron:

- BGT
- OSM
- Dunea trendanalyse 2022

Reden:

- toegankelijkheidsstatus is een beheersbesluit en staat niet betrouwbaar als standaard objectattribuut in deze bronnen

## Dunea-rapport: wat we er wel mee doen

Het rapport gebruiken we later voor een aparte laag met bezoekersdruk, bijvoorbeeld:

- gebied
- locatie
- parkeerterrein
- telpunt
- jaar
- seizoen
- indicator
- waarde
- bronverwijzing

Voorbeelden van indicatoren:

- `bezoekers_totaal_jaar`
- `parkeerdruk_piek`
- `fietsers_daggemiddelde`
- `autos_daggemiddelde`

## Veilig databeginsel

We slaan alleen iets direct op per `plot_id` als de koppeling verdedigbaar is.

Dus:

- afstands- en padvariabelen: wel direct per plot
- toegankelijkheidsstatus: wel direct per plot
- bezoekersaantallen uit rapport: nog niet direct per plot

## Uitkomst van stap 2

Na deze stap is duidelijk:

- welke bron per variabele leidend is
- welke meeteenheid we gebruiken
- welke gegevens direct per plot mogen worden opgeslagen
- welke gegevens eerst een aparte tussenlaag nodig hebben
