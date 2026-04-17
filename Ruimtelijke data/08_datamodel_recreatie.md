# Datamodel recreatie en infrastructuur

Dit document legt eerst het datamodel vast voor recreatie en infrastructuur in de database `meijendel`.
Het doel is om pas daarna de SQL-tabellen en imports te bouwen.

## Waarom dit model

In `Meijendel.sql` bestaat al de tabel `plot_jaar_infra` met deze logica:

- `plot_id`
- `jaar`
- `bron`
- `variabele`
- `waarde`

Die tabel is geschikt voor numerieke waarden per plot per jaar.
Daarom gebruiken we die tabel voor recreatie- en infrastructuurmaten die als getal zijn op te slaan.

Voor toegankelijkheid is een aparte tabel beter, omdat dat geen meetwaarde is maar een status.

## Keuze

### 1. Numerieke recreatievariabelen in `plot_jaar_infra`

Deze variabelen slaan we op als 1 record per `plot_id` + `jaar` + `bron` + `variabele`.

Voorgestelde variabelen:

- `afstand_pad_m`
- `padlengte_m_per_ha`
- `afstand_parkeerplaats_m`
- `afstand_hoofdtoegang_m`

Toelichting:

- `afstand_pad_m`: afstand van het plot tot het dichtstbijzijnde pad, in meters
- `padlengte_m_per_ha`: totale padlengte binnen het plot, omgerekend naar meter per hectare
- `afstand_parkeerplaats_m`: afstand van het plot tot de dichtstbijzijnde parkeerplaats, in meters
- `afstand_hoofdtoegang_m`: afstand van het plot tot de dichtstbijzijnde hoofdtoegang, in meters

### 2. Samenvattende toegankelijkheidsstatus in een aparte tabel

Nieuwe tabel:

- `plot_jaar_toegankelijkheid`

Voorgestelde velden:

- `plot_id`
- `jaar`
- `status_code`
- `bron`
- `opmerking`

Voorgestelde waarden voor `status_code`:

- `afgesloten`
- `beperkt`
- `vrij`

Waarom apart:

- deze informatie is een categorie en geen meetgetal
- de waarden moeten duidelijk leesbaar blijven
- dit voorkomt dat tekststatussen in `plot_jaar_infra` terechtkomen

### 3. Deelvlakken voor gedeeltelijke toegankelijkheid

Aanvullende tabel:

- `plot_jaar_toegankelijkheid_deel`

Voorgestelde velden:

- `plot_id`
- `jaar`
- `bron`
- `deel_label`
- `status_code`
- `aandeel_pct`
- `barriere_type`
- `geom_wkt`
- `opmerking`

Waarom aanvullend:

- een samenvattende plotstatus is te grof voor kavels met meerdere regimes
- `deels beperkt, deels vrij` is voor G.E.E. niet goed genoeg als covariaat
- hiermee kun je exact vastleggen welk deel van een plot onder `afgesloten`, `beperkt` of `vrij` valt
- hiermee kun je ook hekken, stroomdraden en andere barrières expliciet beschrijven

### 4. Bezoekersdruk uit rapport niet direct in `plot_jaar_infra`

Voor bezoekersaantallen, seizoensverschillen, De Vallei en parkeerdruk is een aparte bronstructuur waarschijnlijk beter.
Die informatie is niet vanzelfsprekend exact per plot berekend.

Daarom voorlopig nog niet direct in `plot_jaar_infra`, maar eerst apart uitwerken als bronlaag.

Waarschijnlijke vervolgrichting:

- aparte tabel voor gebieds- of locatiegebonden bezoekersdruk
- daarna pas bepalen welke gegevens verantwoord naar `plot_id` zijn te koppelen

## Bronnen per onderdeel

### BGT

Te gebruiken voor:

- paden
- wegen
- relevante objecten

### OpenStreetMap

Te gebruiken voor:

- `highway`-objecten
- parkeerplaatsen
- voorzieningen

### Dunea rapport trendanalyse Meijendel 2022

Te gebruiken voor:

- bezoekersaantallen
- seizoensverschillen
- aparte informatie over De Vallei
- parkeerdruk

## Jaarlogica

Niet alle recreatievariabelen veranderen elk jaar werkelijk.
Daarom geldt als werkregel:

- als brondata voor meerdere jaren gelijk zijn, mag dezelfde waarde over meerdere jaren worden herhaald
- als een voorziening of afsluiting in een bepaald jaar verandert, dan krijgt dat jaar een nieuwe waarde of status

## Nog niet uitgevoerd

Deze stap legt alleen het model vast.
Nog niet gedaan:

- SQL toevoegen aan `Meijendel.sql`
- importbestanden maken
- brondata uit BGT of OSM ophalen
- rapportgegevens uit pdf omzetten
- HTML-weergave aanpassen
