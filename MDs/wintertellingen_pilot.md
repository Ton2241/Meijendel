# Wintertellingen 2000/01–2024/25

## Besluit

Het dashboard bevat alle 220 canonieke soorten die in de winterdatabase zijn
geregistreerd. Iedere soort krijgt één van drie kwaliteitslabels:

- `betrouwbaar`: publiceerbare modelindex en groene gevoeligheidscontroles;
- `indicatief`: modelindex bruikbaar als signaal, maar terughoudend interpreteren;
- `alleen_beschrijvend`: uitsluitend geregistreerd gemiddelde en
  waarnemingsfrequentie; geen gestandaardiseerde trend.

De analyse schat geen populatiegrootte, absolute dichtheid of aantal unieke
individuen. De primaire respons is het opgetelde geregistreerde aantal per soort
en volledig regulier bezoek.

## Protocol en analyseeenheid

De primaire eenheid is:

`soort × plot × bezoek × datum`

De vaste telregel is dat tijdens ieder volledig regulier winterbezoek in elk
kavel **alle waargenomen vogels** worden genoteerd. Dat geldt ook voor
watervogels en wetlandsoorten. Daardoor is een ontbrekende soortregistratie op
zowel een volledige telling `Alle vogelsoorten` als een volledige telling
`Watervogels en wetlandsoorten` een geldige nul voor iedere soort.

Onvolledige bezoeken, deelbezoeken, bezoeken voor alleen specifieke soorten en
overige niet-reguliere teltypen leveren geen nul op en blijven buiten de
analysetabel. Het historische teltype blijft in de modellen opgenomen als
controlevariabele voor mogelijke uitvoeringsverschillen, niet als beperking van
het soortenspectrum. De reproduceerbare protocolmatrix staat in
`wintertellingen/winter_soortprotocol.csv`.

Meerdere ruimtelijke bronregels voor dezelfde soort binnen hetzelfde bezoek
worden eerst opgeteld. Historische synoniemen worden vóór modellering
gecanonicaliseerd. In het bijzonder worden broncodes voor `Canadese gans spec.`
en `Grote Canadese gans (maxima)` samengevoegd met `Grote Canadese Gans`.

## Analyse en kwaliteitsindeling

Alle soorten krijgen beschrijvende jaar-, maand- en plotuitvoer. Een volledige
modelvalidatie wordt uitgevoerd bij minimaal vijftien winters en honderd
positieve bezoeken. Per kandidaat worden gebruikt:

- een negatief-binomiaal model van het aantal per geldig bezoek;
- een binomiaal model van de waarnemingskans per geldig bezoek;
- winter, maand, historisch teltype en een random plotintercept;
- controles op trendrichting, extreme aantallen, recente telduur,
  modelconvergentie, Hessiaan en eindige voorspellingen.

De modelindex wordt genormaliseerd op het modelgemiddelde van
2000/01–2004/05 (`100`). Een klassiek occupancy- of N-mixturemodel wordt niet
gebruikt, omdat vrijwel geen gesloten detectiereplicaten bestaan.

## Actuele uitkomst

De gecontroleerde uitvoer bevat 220 soorten en 25 winters:

- 15 soorten met status `betrouwbaar`;
- 45 soorten met status `indicatief`;
- 160 soorten met status `alleen_beschrijvend`;
- 77 soorten volledig modelmatig getest en 143 uitsluitend beschrijvend.

Deze aantallen zijn uitvoer van de huidige vaste beslisregels en kunnen na een
nieuwe dataversie wijzigen. Het dashboard toont alle soorten en laat filteren op
kwaliteitslabel en ecologische soortgroep.

## Uitvoer en reproductie

De analyse schrijft naar `wintertellingen/`:

- `winter_jaarindex.csv`;
- `winter_maandpatroon.csv`;
- `winter_plotgebruik.csv`;
- `winter_dekking.csv`;
- `winter_pilot_besluit.csv`;
- `winter_geschiktheid_alle_soorten.csv`;
- `winter_audit_samenvatting.csv`;
- `winter_soortprotocol.csv`.

Reproduceren en controleren:

```bash
Rscript R/analyse_wintertellingen_pilot.R wintertellingen
Rscript R/check_wintertelling_output.R wintertellingen
```

## Publicatiegrens

Een samengestelde wintervogelindicator en verklarende analyses van beheer,
recreatie, habitat of klimaat maken geen deel uit van deze release. Vergelijking
met passende landelijke Sovon-reeksen volgt pas na afzonderlijke inhoudelijke
beoordeling per soort.
