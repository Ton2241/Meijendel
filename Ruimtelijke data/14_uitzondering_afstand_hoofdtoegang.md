# Uitzondering berekening `afstand_hoofdtoegang_m`

## Aanleiding

Voor een deel van de plots in Meijendel is de standaardberekening van `afstand_hoofdtoegang_m` niet goed genoeg.

Deze plots hebben feitelijk een tweede ingang in het gebied. Bezoekers gebruiken eerst een van de hoofdtoegangen van Meijendel en lopen daarna binnen Meijendel door naar een vast tussenpunt. Pas vanaf dat tussenpunt wordt de afstand naar het plot bepaald.

## Nieuwe rekenregel

Voor de hieronder genoemde plots wordt `afstand_hoofdtoegang_m` berekend als:

1. afstand van de dichtstbijzijnde hoofdtoegang tot het vaste tussenpunt
2. plus de kortste afstand van dat tussenpunt tot het plot

Formule:

`afstand_hoofdtoegang_m = afstand(hoofdingang, tussenpunt) + afstand(tussenpunt, plot)`

## Vast tussenpunt

WGS84:

- latitude: `52.13410461479026`
- longitude: `4.346240758891108`

RD New (`EPSG:28992`):

- `x_rd = 83730.645`
- `y_rd = 461167.042`

## Gebruikte hoofdtoegang voor deze herberekening

Voor deze set plots bleek de kortste route naar het tussenpunt steeds te lopen via:

- `Auto-ingang Wassenaar`

Afstand hoofdtoegang -> tussenpunt:

- `1071.811 m`

## Betrokken plots

De gebruiker noemde:

- `75`
- `10-12-76`
- `8`
- `7`
- `6`
- `4-5`
- `61`
- `62`
- `63`
- `64`
- `65`
- `71`
- `72`
- `12a`
- `73`
- `74`

In de oorspronkelijke lijst kwamen `4-5` en `k 62` dubbel voor. Uiteindelijk gaat het om `16` unieke plots.

## Koppeling kavelnummer naar `plot_id`

| kavel | plot_id |
|---|---:|
| `7` | `3498` |
| `71` | `3501` |
| `10-12-76` | `3502` |
| `63` | `3509` |
| `64` | `3516` |
| `65` | `3518` |
| `12a` | `3519` |
| `62` | `3520` |
| `6` | `3521` |
| `61` | `3522` |
| `72` | `3526` |
| `73` | `3527` |
| `74` | `3528` |
| `8` | `3530` |
| `75` | `3531` |
| `4-5` | `3581` |

## Bijgewerkte waarden voor `2024`

Alleen bijgewerkt in:

- tabel: `plot_jaar_infra`
- jaar: `2024`
- bron: `HANDMATIG`
- variabele: `afstand_hoofdtoegang_m`

| plot_id | kavel | nieuwe waarde (m) |
|---:|---|---:|
| `3498` | `7` | `1539.615` |
| `3501` | `71` | `2503.445` |
| `3502` | `10-12-76` | `2750.274` |
| `3509` | `63` | `1496.909` |
| `3516` | `64` | `1931.542` |
| `3518` | `65` | `2231.049` |
| `3519` | `12a` | `2491.014` |
| `3520` | `62` | `1126.774` |
| `3521` | `6` | `1574.959` |
| `3522` | `61` | `1120.044` |
| `3526` | `72` | `3121.793` |
| `3527` | `73` | `3471.888` |
| `3528` | `74` | `4160.560` |
| `3530` | `8` | `1968.677` |
| `3531` | `75` | `3645.861` |
| `3581` | `4-5` | `1261.064` |

## Praktische waarschuwing

Als `plot_jaar_infra` later opnieuw volledig wordt gevuld vanuit een ouder importbestand of een oudere berekening, kunnen deze aangepaste waarden worden overschreven.

Daarom moeten toekomstige herberekeningen van `afstand_hoofdtoegang_m` deze uitzonderingsregel meenemen.

## Status

Deze waarden zijn op `2026-04-03` herberekend en daarna in de live MySQL-database bijgewerkt.
