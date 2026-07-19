# Wintertellingenpilot 2000/01–2024/25

## Besluit

De midmaandtellingen zijn bruikbaar voor gestandaardiseerde lokale winterindices,
maar niet iedere soort levert een even stabiele uitkomst. De pilot publiceert
uitsluitend soorten met status `betrouwbaar` of `indicatief`. Soorten met status
`alleen_beschrijvend` blijven beschikbaar in de ruwe tellingen.

De analyse schat geen populatiegrootte of absolute dichtheid. De respons is het
opgetelde geregistreerde aantal per soort en geldig bezoek.

## Pilotuitkomst

| Soort | Status | Aantaltrend per jaar | Binaire trend per jaar | Belangrijkste beoordeling |
|---|---|---:|---:|---|
| Tjiftjaf | betrouwbaar | +3,85% | +7,78% | richtingvast, robuust voor extremen en recente telduurcontrole |
| Kuifeend | betrouwbaar | +2,34% | +0,47% | stabiele lange index; binaire ontwikkeling veel vlakker |
| Koolmees | indicatief | +2,46% | +3,94% | recente telduurperiode wijkt af van lange reeks |
| Merel | indicatief | −0,99% | −5,06% | afname richtingvast, maar recente helling duidelijk sterker |
| Houtsnip | indicatief | +1,62% | +2,27% | richtingvast, maar recente periode veel steiler |
| Koperwiek | indicatief | −1,81% | +0,01% | aantals- en binaire ontwikkeling vertellen niet hetzelfde verhaal |
| Meerkoet | indicatief | −0,62% | +0,31% | aantallen en waarnemingskans hebben tegengestelde richting |
| Dodaars | indicatief | +2,31% | +4,24% | lange en recente telduurperiode verschillen van richting |
| Aalscholver | indicatief | +3,42% | +3,17% | richtingvast, maar recente telduurperiode wijkt af |
| Buizerd | alleen beschrijvend | — | — | ten minste één kernmodel convergeerde niet betrouwbaar |

De percentages zijn loglineaire samenvattingen over de hele periode. De
dashboardindex met afzonderlijke winterwaarden is leidend voor de vorm van het
verloop; een gemiddeld percentage veronderstelt niet dat de ontwikkeling ieder
jaar gelijk was.

## Protocol en analyseeenheid

De primaire eenheid is:

`soort × plot × bezoek × datum`

Meerdere ruimtelijke bronregels voor dezelfde soort binnen hetzelfde bezoek
worden eerst opgeteld. Ontbrekende soortregels worden alleen nul wanneer het
bezoek volledig was en de soort binnen het telprotocol viel:

| Soortgroep | Alle vogelsoorten | Watervogels/wetlandsoorten | Onvolledig/overig |
|---|---:|---:|---:|
| landvogel | geldig | `NA` | `NA` |
| watervogel | geldig | geldig | `NA` |

De tien protocolgroepen zijn inhoudelijk in
`R/analyse_wintertellingen_pilot.R` vastgelegd. Uitbreiding naar andere soorten
vereist eerst dezelfde inhoudelijke indeling.

## Modellen

Per soort worden twee kernmodellen gebruikt:

- negatief-binomiaal model van het aantal per geldig bezoek;
- binomiaal model van de waarnemingskans per geldig bezoek.

Beide bevatten winter, maand, telprotocol waar relevant en een random
plotintercept. De jaarindex gebruikt de gemiddelde modelwaarde voor september
tot en met maart en wordt genormaliseerd op het gemiddelde van 2000/01–2004/05
(`100`).

Aanvullende controles vergelijken:

- aantals- en binaire trendrichting;
- onbegrensde aantallen met een analyse waarin de hoogste één procent wordt
  begrensd;
- de lange reeks met een analyse vanaf 2012 waarin telduur als covariaat wordt
  opgenomen;
- modelconvergentie en positieve Hessiaan.

De categorieën zijn:

- `betrouwbaar`: alle kern- en gevoeligheidscriteria groen;
- `indicatief`: kernmodellen bruikbaar, maar minimaal één gevoeligheidscontrole
  vraagt terughoudendheid;
- `alleen_beschrijvend`: geen publiceerbare gestandaardiseerde index.

## Uitvoer

De analyse schrijft naar `wintertellingen/`:

- `winter_jaarindex.csv`;
- `winter_maandpatroon.csv`;
- `winter_plotgebruik.csv`;
- `winter_dekking.csv`;
- `winter_pilot_besluit.csv`;
- `winter_geschiktheid_alle_soorten.csv`;
- `winter_audit_samenvatting.csv`.

Reproduceren en controleren:

```bash
Rscript R/analyse_wintertellingen_pilot.R wintertellingen
Rscript R/check_wintertelling_output.R wintertellingen
```

## Go/no-go

De pilot is een beperkte **go**:

- de analysekern en dashboardpresentatie zijn bruikbaar;
- uitbreiding naar meer soorten is verantwoord na inhoudelijke toekenning van
  protocolgroepen;
- uitbreiding moet gefaseerd gebeuren en iedere soort behoudt een zichtbaar
  kwaliteitslabel;
- een samengestelde wintervogelindicator, causaliteitsanalyse of model voor alle
  238 soorten is nog niet gerechtvaardigd.

Eerstvolgende uitbreiding: beoordeel de soorten met voorlopige klasse
`kansrijk` uit `winter_geschiktheid_alle_soorten.csv`, voeg hun protocolgroep
inhoudelijk toe en voer dezelfde validatie uit.
