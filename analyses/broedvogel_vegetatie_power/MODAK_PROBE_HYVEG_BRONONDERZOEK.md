# MODAK, HYVEG en PROBE: betekenis voor de broedvogel–vegetatieanalyse

**Stand:** 26 oktober 2026

## Conclusie

MODAK, HYVEG en PROBE leveren geen bestaand model dat rechtstreeks kan worden
overgenomen om de broedvogelbevolking van Meijendel te voorspellen. De
belangrijkste winst is conceptueel. De KWR-modellen maken duidelijk dat tussen
een externe verandering en de vegetatie eerst bodem-, water- en stressprocessen
liggen. De vegetatie vormt vervolgens pas een mogelijke schakel naar vogels.

Voor de huidige Meijendel-analyse blijft daarom de volgende keten leidend:

> weer, hydrologie, stikstof, begrazing, konijnen en beheer → vegetatie en
> vegetatiestructuur → broedvogels

De drie schakels worden niet tot één ondoorzichtige regressie samengevoegd.
Luchtfoto's blijven nodig om vast te stellen wanneer de horizontale structuur
werkelijk veranderde; de 53.122 PQ-taxonregels uit 2.007 opnamen over 1981–2025
beschrijven vooral soortensamenstelling op punten, en de 220 geharmoniseerde
AHN-regels voor 55 plots en vier meetmomenten in 2008–2023 beschrijven
hoogtestructuur. PROBE kan pas als aanvullende verklarende bron worden gebruikt
wanneer een concrete Meijendel-uitvoer met herleidbare invoer en modelversie
beschikbaar komt.

## Wat de modellen waren

### HYVEG

De gevonden oorspronkelijke publicatie van Vera Noest dateert uit 1994, niet
uit 1992. HYVEG voorspelde voor soorten van vochtige duinvalleien het voorkomen
uit voornamelijk hydrologische standplaatsvariabelen. Een eerdere publicatie
uit 1991 beschrijft een toepassing op honderd plantensoorten. HYVEG is daarmee
inhoudelijk een voorloper van ecohydrologische vegetatiemodellen, maar in de
geraadpleegde bronnen is niet aangetoond dat de programmatuur of de
modelcoëfficiënten rechtstreeks in MODAK of PROBE zijn overgenomen.

### MODAK

MODAK is in 2003 gepubliceerd als *MODAK: naar een geïntegreerd ecosysteemmodel
voor duinen*. Het betreft een Kiwa-rapport van 45 pagina's en wordt in de
onderzoeksregistratie aangeduid als haalbaarheidsstudie. De volledige tekst is
niet openbaar teruggevonden. De uitleg “model dat alles kan” is alleen uit de
toelichting van Harrie Van der Hagen bekend en wordt daarom niet als officiële
betekenis van de naam vastgelegd. Evenmin is in de gevonden primaire bronnen
een formeel ontwikkelbesluit gevonden waarin MODAK in PROBE wordt omgezet.

### PROBE-1 en PROBE-1D

PROBE-1 is in 2006 ontwikkeld. De gebruikershandleiding van 2025 beschrijft
een operationeel scenario-instrument van KWR voor Dunea, PWN en Waternet. Het
berekent op een raster van 5 bij 5 of 10 bij 10 meter de kans op
plantengemeenschappen na veranderingen in grondwater, stikstof- en
fosfordepositie, maaien, plaggen en vegetatiestructuur. Benodigd zijn onder meer
een vegetatiekaart op associatieniveau, calcium in de wortelzone, GVG, GLG en
de ruimtelijke variatie in GLG.

Een schemazoeking in alle tabellen en kolommen van de levende MySQL-database
`Meijendel` op 26 oktober 2026 vond nul namen voor GVG, GLG,
wortelzonecalcium of vegetatieassociatie. Dit bewijst niet dat afzonderlijke
bronnen buiten de database geen hydrologische of vegetatiekundige informatie
bevatten, maar wel dat de voor PROBE herkenbare invoerset niet als zodanig in
de levende database is opgeslagen.

PROBE-1 berekent een ruimtelijk vegetatiepotentieel voor een scenario. Het
model reconstrueert niet in welk historisch jaar een struweel of bosvlak
werkelijk ontstond en voorspelt geen vogels. PROBE-1D kan klimaat en reliëf
meenemen, maar vraagt meer ruimtelijke invoer. De huidige Meijendel-database
bevat niet de volledige combinatie van associatiekaart, wortelzonecalcium en
gebiedsdekkende GVG/GLG die voor een eigen PROBE-berekening nodig is.

### PROBE-3 en droge duinen

PROBE-3 koppelt de modellen SWAP, CENTURY en PROBE en berekent per jaar
hydrologie, bodemontwikkeling, plantproductie en vegetatie. Het KWR-rapport uit
2016 bevat een droge-duinproef voor korte, grondwateronafhankelijke vegetatie in
de Luchterduinen. De vegetatiemodule onderscheidde zes associaties. Bij een
willekeurige halvering van ruim 35.000 landelijke vegetatieopnamen werd 82% van
de achtergehouden opnamen aan de juiste associatie toegewezen.

Dat cijfer is geen bewijs voor een betrouwbare voorspelling van
vegetatieverandering door de tijd. De veldtoets voor successie bestond uit 30
proefvlakken: vijf vlakken in drie leeftijdsklassen, in zowel kalkrijk als
kalkarm duin. Het rapport noemt te hoge biomassaschattingen, zwakke scheiding
van enkele vegetatietypen, ontbrekende mossen en korstmossen en het ontbreken
van begrazing en konijnen. Verspreiding, vertraagde vegetatiereacties, helling
en temperatuur waren evenmin gemodelleerd. Enkele modelaanpassingen berustten
op deskundigenoordeel en een vierjarig voortschrijdend gemiddelde voor
vertraging was arbitrair gekozen.

De uitspraak dat modellering van droog duin geheel is mislukt, is daarom te
stellig. De gepubliceerde PROBE-3-proef leverde bruikbare deelresultaten, maar
niet de robuuste historische voorspelling die voor de broedvogelanalyse nodig
is. Het door Harrie genoemde Dunea/KWR-project van omstreeks 2023 met een
beroerde voorspellende waarde is in de geraadpleegde openbare bronnen niet als
afzonderlijk rapport geïdentificeerd. Dat specifieke oordeel blijft daarom
ervaringsinformatie. KWR publiceerde in 2025 en 2026 bovendien nieuw empirisch
onderzoek naar korte vegetaties in droge kustduinen. De ontwikkellijn is dus
niet beëindigd.

## Gevolgen voor het Meijendel-model

1. **Geen PROBE-run uitvoeren met de huidige gegevens.** De noodzakelijke
   herkenbare gebiedsdekkende invoer ontbreekt en de modeluitkomst zou
   bovendien geen historische luchtfotoreeks of vogelmodel vervangen.
2. **Proces en waarneming uit elkaar houden.** PQ, luchtfoto's en AHN beschrijven
   waargenomen vegetatie; weer, hydrologie, stikstof, konijnen en beheer zijn
   mogelijke oorzaken. Alleen relaties die buiten de schattingsgegevens blijven
   voorspellen, gaan door naar een poweranalyse.
3. **Vertragingen inhoudelijk kiezen.** Het proefschrift van Van der Hagen laat
   voor de konijnenziekten van 1954 en 1989 zien dat de grote landschappelijke
   gevolgen pas ongeveer vijftien jaar later duidelijk zichtbaar werden. Naast
   korte vertragingen van één tot drie jaar zijn voor zulke gebeurtenissen dus
   afzonderlijke langzame responsen nodig.
4. **Droogtestress niet vervangen door alleen een gemiddeld grondwaterpeil.**
   Het PROBE-onderzoek gebruikt duur en intensiteit van zuurstof- en
   droogtestress. Bij een latere hydrologische uitbreiding moet worden getoetst
   of zulke stressmaten voor Meijendel beschikbaar of verantwoord afleidbaar
   zijn.
5. **PROBE alleen heropenen bij een concrete levering.** Bruikbaar zouden zijn:
   een bestaande Meijendel-modeluitvoer, de exacte PROBE-versie, invoerrasters,
   scenario's, kalibratie- en validatiegegevens en de betekenis van iedere
   uitvoervariabele. Dan kan de extra voorspellende waarde op dezelfde 35
   vogel–PQ-plots en dezelfde achtergehouden perioden worden getoetst.

Dit onderzoek verandert geen databasewaarde en levert geen nieuw powergetal.
Het scherpt de modelopbouw en de eisen aan een eventuele toekomstige
PROBE-levering aan.

## Geraadpleegde bronnen

- Witte, De Haan, Meuleman & Tack (2003), [MODAK: naar een geïntegreerd
  ecosysteemmodel voor duinen](https://research.wur.nl/en/publications/modak-naar-een-ge%C3%AFntegreerd-ecosysteemmodel-voor-duinen/).
- Noest (1994), [A hydrology-vegetation interaction model for predicting
  occurrence of plant species in dune slacks](https://doi.org/10.1006/jema.1994.1008).
- Witte, De Haan & Hootsmans (2007), [PROBE: een model voor
  vegetatiedoelen](https://www.landschap.nl/wp-content/uploads/2007-2_076-087.pdf).
- Clevers e.a. (2025), [Gebruikershandleiding Probe
  Duinen](https://www.kwrwater.nl/wp-content/uploads/2026/01/KWR-2025.082-Gebruikershandleiding-Probe-Duinen.pdf).
- Bartholomeus e.a. (2016), [PROBE-3: A succession model for ecosystem
  services](https://api2.kwrwater.nl/uploads/BTO%202016.071%20PROBE-3%20A%20succession%20model%20for%20ecosystem%20services%20v3.pdf).
- KWR (2025), [Effecten van klimaatverandering op vegetatiebedekking en
  grondwateraanvulling in kustduinen](https://library.kwrwater.nl/publication/110054/effecten-van-klimaatverandering-op-vegetatiebedekking-en-grondwateraanvulling-in-kustduinen/).
- KWR (2026), [Effecten van klimaatverandering op korte vegetaties en de
  waterhuishouding in de kustduinen](https://library.kwrwater.nl/publication/110229/effecten-van-klimaatverandering-op-korte-vegetaties-en-de-waterhuishouding-in-de-kustduinen/).
- Van der Hagen (2022), *Rabbits rule: Evaluating livestock grazing in coastal
  sand dunes of Meijendel, the Netherlands*, lokaal geraadpleegd via Zotero.

