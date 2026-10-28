# Niet-lineaire vertraagde PQ–vogelrelaties — implementatieplan

> **Voor agentische uitvoering:** gebruik `superpowers:executing-plans` en voer
> de taken testgestuurd en in de aangegeven volgorde uit.

**Doel:** bepalen of veranderingen in PQ-vegetatie worden gevolgd door een
onmiddellijke, vertraagde, tijdelijke of blijvende verandering bij
broedvogelsoorten, vogelgroepen of de vogelgemeenschap.

**Architectuur:** de bestaande soort × plot × jaar-modelpopulatie blijft de
vogelbasis, inclusief Natura 2000-plotscope en correctie voor
teller/tellerteam en geregistreerde ervaring. Uit de PQ-soortensamenstelling
worden vooraf ecologisch benoemde vegetatiegradiënten afgeleid. Verandering in
die gradiënten wordt vervolgens gekoppeld aan een begrensde niet-lineaire
responscurve over meerdere jaren; een gebeurtenisanalyse rond grotere
vegetatieveranderingen dient als onafhankelijke gevoeligheidsanalyse.

**Techniek:** R, MySQL 9.7.1, `glmmTMB`, zo nodig `mgcv` of `dlnm`,
geblokkeerde validatie naar plot en tijd, simulatie of bootstrap voor de
uiteindelijke poweranalyse.

**Inhoudelijke specificatie:**
`ANALYSE_HOOFDLIJNEN_EN_UITKOMSTEN.md` en `BESLUITEN.md` in deze directory.

## Vaste uitgangspunten

- De analyse gebruikt standaard uitsluitend plots uit
  `v_meijendel_analyseplot_actueel`; M66 en M91 blijven buiten beschouwing.
- Aalscholver blijft uit de vogel–vegetatiemodellen verwijderd, omdat de
  gebruikte PQ's de nestelplaats van deze kolonievogel niet meten.
- De primaire vraag betreft verandering binnen dezelfde plot. Verschillen
  tussen plots blijven afzonderlijk in het model staan en gelden niet als
  bewijs voor een reactie op vegetatieverandering.
- Verandering wordt per verstreken jaar tussen twee PQ-opnamen uitgedrukt.
  Een interval van één jaar telt dus niet automatisch even zwaar als een
  interval van tien jaar.
- De reactievorm wordt niet vooraf lineair verondersteld. Het model mag een
  drempel, een vertraagde piek, herstel, uitdoving of een blijvend effect
  beschrijven, maar de gladheid wordt begrensd om schijnpatronen te voorkomen.
- De maximale vertraging wordt pas definitief gekozen nadat voor nul tot en
  met vijftien jaar de feitelijke dekking is vastgesteld.
- Alle uitkomsten worden vastgelegd: positieve en negatieve bevindingen,
  numeriek ongeldige modellen en relaties zonder duidelijke ecologische
  betekenis.
- Modelschatting blijft lokaal en buiten Shiny en de VPS. Deze fase verandert
  geen brongegevens in de levende database.

## Vooraf gekozen vegetatie- en vogeluitkomsten

De PQ-soorten worden eerst samengevat in vijf interpreteerbare gradiënten:

1. open zand en pioniervegetatie;
2. duingrasland, mossen en korstmossen;
3. natte vegetatie en riet;
4. struweel en ruigte;
5. bomen en bos.

De vogelrespons wordt op drie niveaus onderzocht:

- territoriumaantal per soort;
- verschijnen of verdwijnen van een soort in een getelde plot;
- verandering van de gemeenschap en vooraf vastgelegde functionele,
  ecologische en habitatgroepen.

Per relatie worden ten minste het directe effect, het jaar van de grootste
reactie, het cumulatieve effect en het voortduren of uitdoven van de reactie
gerapporteerd. Cumulatieve vensters van 0–3, 0–7 en 0–15 jaar worden alleen
gebruikt voor zover de dekkingsanalyse voldoende onafhankelijke plotjaren laat
zien.

## Reviewaandacht

- Een lang PQ-interval mag geen grotere jaarlijkse verandering suggereren
  alleen doordat meer jaren zijn opgeteld.
- Meerdere PQ-opnamen in hetzelfde plotjaar mogen geen vogelresponsrij
  dupliceren.
- Een vogeljaar mag bij een gebeurtenisanalyse niet ongemerkt aan meerdere
  overlappende veranderingsepisoden worden toegeschreven.
- Een lange vertraging met nog maar enkele plots of jaren wordt gerapporteerd,
  maar niet gemodelleerd alsof de dekking gelijk is aan vertraging nul.
- Soorten en groepen worden vooraf ecologisch gekoppeld; achteraf kiezen van
  alleen opvallende relaties is niet toegestaan.

---

## Task 1 — feitelijke dekking voor vertragingen van 0–15 jaar

**Bestanden:**

- wijzigen: `scripts/broedvogel_model_vegetatiesamenstelling_fit.R`;
- wijzigen: `scripts/run_broedvogel_vegetatiesamenstelling.R`;
- wijzigen: `scripts/test_broedvogel_model_vegetatiesamenstelling_fit.R`;
- wijzigen: `scripts/test_broedvogel_vegetatiesamenstelling_pipeline.R`;
- maken: `scripts/pq_vertragingsdekking.R`;
- maken: `scripts/test_pq_vertragingsdekking.R`;
- maken: `scripts/run_pq_vertragingsdekking.sh`;
- maken: `resultaten/pq_vertragingsdekking_laatste.csv`;
- maken: `resultaten/pq_vertragingsdekking_laatste_manifest.json`.

**Interface:** `composition_coverage_lags()` levert `0:15`;
`build_multivariate_vegetation_population()` accepteert één gehele vertraging
van 0 tot en met 15; `composition_pipeline_coverage()` rapporteert per
vegetatieblok en vertraging aantallen rijen, vogelplotjaren, plots, soorten en
eerste en laatste vogeljaar.

- [x] Schrijf eerst tests die vertraging 15 accepteren, 16 afwijzen en alle
  zestien vertragingen in oplopende volgorde eisen.
- [x] Voer de tests uit en bevestig dat zij om de ontbrekende uitbreiding
  falen.
- [x] Verruim alleen de dekkingsroute; de formeel geschatte eerdere modellen
  blijven beperkt tot de reeds vastgelegde gelijktijdige analyse.
- [x] Bouw een lichte, alleen-lezen runner die de actuele vogel- en PQ-tabellen
  uit de lokale database leest, geen modellen schat en een CSV plus manifest
  schrijft.
- [x] Voer de runner uit en leg de volledige dekking, inclusief eventuele lege
  vertragingen, vast.

**Uitkomst 28 oktober 2026.** Run
`20261028T142316Z-d6169d52f603` koppelde 1.314 PQ-opnamen uit 1981–2025 aan de
geldige vogelmodelpopulatie. Van 406 vogelplotjaren bij vertraging nul blijven
er 285 bij zeven jaar, 233 bij tien jaar en 180 in 32 plots bij vijftien jaar
over. Geen vertraging is leeg; er is geen model geschat. De uitkomst begrenst
de volgende stap nog niet definitief, omdat eerst de werkelijke veranderingen
tussen opeenvolgende PQ-opnamen per ecologische gradiënt moeten worden geteld.

## Task 2 — ecologische PQ-gradiënten en jaarlijkse verandering

**Bestanden:** te maken na Taak 1 onder `scripts/`, met regressietests in
dezelfde directory.

**Interface:** één tabel per plot en PQ-jaar met vijf gradiëntscores, gevolgd
door één tabel per opeenvolgend PQ-interval met beginjaar, eindjaar,
intervallengte en jaarlijkse verandering per gradiënt.

- [x] Leg de planttaxa vooraf, herleidbaar en zo veel mogelijk meervoudig
  beoordeeld aan de vijf gradiënten vast.
- [x] Bereken gradiëntscores zonder de identiteit en bronbedekking van taxa te
  verliezen.
- [x] Bereken jaarlijkse verandering alleen tussen twee geldige opnamen van
  dezelfde plot en rapporteer de intervalverdeling.
- [x] Beslis op basis van Taak 1 en de intervalverdeling welke maximale
  vertraging modelleerbaar is.

**Uitkomst 28 oktober 2026.** De reproduceerbare run
`20261028T145317Z-3691b52aedc8` gebruikt 1.314 gekoppelde PQ-opnamen, 35.672
taxonregels en 642 taxa uit 1981–2025. EcoDbase uit SynBioSys levert de
vogelonafhankelijke ecologische referentie. Met bestaande taxongroepen voor
mossen, levermossen, korstmossen en algen zijn 528 taxa herleidbaar ingedeeld.
Van 501 PQ-plotjaren in 35 plots voldoen 485 aan minimaal 80% ingedeelde
bronbedekking. Alleen werkelijk opeenvolgende, beide geldige plotjaren zijn
verbonden; dat levert 441 intervallen. Na vijftien jaar blijven 149 intervallen
in 30 plots aan een geldig vogelplotjaar koppelbaar. De maximale reactieduur
blijft daarom vijftien jaar voor gemeenschap en vooraf gekozen vogelgroepen;
per soort beslist de modeldekking opnieuw.

## Task 3 — niet-lineair vertraagd hoofdmodel

**Interface:** per vooraf gekozen vegetatie–vogelrelatie een tweedimensionale
functie van omvang/richting van vegetatieverandering en jaren sinds die
verandering, boven op hetzelfde vogelbasismodel.

- [ ] Vergelijk op exact dezelfde responsrijen een model zonder PQ, een lineair
  vertraagd model en het begrensde niet-lineaire model.
- [ ] Valideer op niet-gebruikte plots en latere jaren; een betere passing in
  de schattingsgegevens alleen geldt niet als voorspellende winst.
- [ ] Rapporteer directe, maximale, cumulatieve en uitdovende effecten plus
  onzekerheid en modelstatus.
- [ ] Voer een gebeurtenisanalyse rond vooraf gedefinieerde grotere
  vegetatieveranderingen uit als gevoeligheidsanalyse.

## Task 4 — power en voorspelbaarheid

- [ ] Voer alleen voor gevalideerde relaties simulaties uit onder de werkelijk
  aangetroffen meetfrequentie, spreiding, teller/tellerteamstructuur en
  ontbrekende jaren.
- [ ] Bepaal welke verandering met de historische meetopzet aantoonbaar was en
  hoeveel toekomstige jaren of metingen nodig zijn voor vooraf gekozen
  effectgroottes.
- [ ] Een gezamenlijk toestandsruimtemodel wordt pas overwogen wanneer Taak 3
  een stabiel voorspellend signaal oplevert; het is geen voorwaarde voor de
  eerste poweranalyse.

## Afrondcriteria

Iedere taak is pas afgerond wanneer de vooraf geschreven tests eerst om de
bedoelde ontbrekende functie hebben gefaald en daarna slagen, compacte
uitkomsten en manifest zijn opgeslagen, nul- en uitvalresultaten zijn
gerapporteerd en de projectpreflight aan het einde groen is. Publicatie naar de
VPS valt buiten dit plan.
