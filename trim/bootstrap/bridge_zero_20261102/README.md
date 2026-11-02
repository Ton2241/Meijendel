# Brugkalibratie bij nuljaartotalen

Stand: 2 november 2026. Ontwikkelvergelijking over 1958–2025; geen formele
bootstrapuitkomst, geen betrouwbaarheidsinterval en geen publicatieproduct.

## Uitgevoerd

De brugfunctie behoudt nu echte nullen in het gemiddelde. Een ontbrekende,
niet-eindige of negatieve jaarwaarde blokkeert de brug; een geheel nulvenster
levert geen positieve brugfactor. De jaarlijkse methode blijft `yearly_trim`,
met een afzonderlijk TRIM-jaareffect voor ieder van de zes brugjaren.

De expliciete kandidaat `window_poisson` schat één gemiddeld jaarlijks niveau
voor 1981–1983 en één voor 1986–1988, met dezelfde bestaande correctie voor
oppervlakte. Per getrokken site worden tellingen en aantallen getelde jaren
per venster geaggregeerd. Conditioneel op de totale telling per site is de
log-odds de gezamenlijke log-niveauverhouding plus `log(n_post/n_pre)`. Een
quasi-binomiale fit geeft dezelfde score als het geprofileerde Poissonmodel
met afzonderlijke site-intercepten en accepteert de bestaande fractietellingen.
Uit deze fit worden geen standaardfouten als formele bootstraponzekerheid
gebruikt. De methode veronderstelt een gemiddeld niveau binnen ieder venster;
het jaarlijkse model laat afzonderlijke jaareffecten vrij.

Alleen tweezijdig bezochte sites dragen bij. Zij moeten samen alle zes
brugjaren dekken, ook na verwijdering van eenzijdig bezochte sites. Sites met
twee nulvensters tellen mee voor de dekkingscontrole, maar bevatten geen
informatie over de verhouding. Ontbrekende bezoeken worden geen nullen.
Een volledig nulvenster blijft ongeldig. Er is geen pseudotelling, nieuwe
trekking of automatische fallback. Een kandidaatbundel vereist een expliciet
vast soortselectiebestand.

## Vergelijking

Bron: dezelfde historische cache als de pilot van 17 oktober 2026, SQL-hash
`15de9245b0d0fbbd0a65990c6c0d618ff8f0298f712775210fe0b1566a917913`.
De cachehash, exacte 33 soort-ID’s, selectiebronhashes, codehashes, seed
20260920 en trekkingsnummers 1–50 staan in `audit_manifest.json`.
`fixed_species_33.csv` bewaart de onveranderde groepspopulatie. De vergelijking
wordt geblokkeerd wanneer de gereconstrueerde soort-ID’s daarvan afwijken.

Beide kalibratiemethoden zijn op de 50 oorspronkelijke plottrekkingen voor
alle 33 vaste soorten uitgevoerd: 3.300 kalibratiefits. De hoofdmodellen en
groepsindicatoren zijn voor deze trekkingen niet opnieuw gebootstrapt.

| Soort | Jaarlijks hulpmodel geldig | Venstermodel geldig |
|---|---:|---:|
| Dodaars | 46/50 | 50/50 |
| Kievit | 47/50 | 50/50 |
| Veldleeuwerik | 35/50 | 50/50 |
| Witte Kwikstaart | 26/50 | 47/50 |
| Roodborsttapuit | 49/50 | 50/50 |
| Overige 28 vaste soorten | ieder 50/50 | ieder 50/50 |

De drie mislukte Witte-Kwikstaartkalibraties zijn trekkingen 15, 34 en 44;
steeds is een volledig venster nul. De bestaande 33-soortselectie omvat
voor deze soort pionierbegroeiingen, bebouwing/overige, bodem-insecteneters
en holenbroeders (functionele groepen binair en gewogen). Die groepsschatters
kunnen op deze 50 trekkingen onder deze kandidaat hoogstens 47/50 geldig
zijn. Dit is een bovengrens, geen gemeten volledige groepsbootstrap.

`points.csv` vergelijkt oorspronkelijke soortschattingen en brugfactoren,
inclusief de bestaande vijf venster-/dekkingsvarianten, voor de eerdere 35
soorten; `fixed_33` markeert de vastgehouden populatie. Primaire
brugfactorveranderingen: Veldleeuwerik −50,98%, Witte Kwikstaart +32,88%,
Roodborsttapuit −12,07%; bij de overige 30 vaste soorten maximaal 4,18% in
absolute relatieve verandering. Geen van de 33 oorspronkelijke soorttrends
wisselt van teken. De verandering van de samengestelde trend bedraagt voor
Veldleeuwerik −1,40 en voor Witte Kwikstaart +0,59 procentpunt per jaar.
`groups.csv` bevat uitsluitend de oorspronkelijke puntschattingen voor de
vaste groepsvarianten; het bevat geen bootstrapverdeling.

De 33-soortselectie bevat nul luchtfoerageerders en één soort voor
bebouwing/overige: Witte Kwikstaart. De twee lege luchtgroepvarianten mogen
niet als schatbare groepsindicatoren worden behandeld.

## Besluit en restant

De vensterkalibratie blijft experimenteel. De nulcorrectie is wel afgerond.
De jaarlijkse comparator blijft standaard; de publieke beschrijvende
brugreeks wordt niet vervangen. De sterke factorverandering bij twee
schaarse soorten ondersteunt geen stille methodewissel.

Een volledige nieuwe 50-pilot is niet gestart. Naast beoordeling van deze
verschillen blijft behandeling van volledig nulvensters nodig. Een grotere
run lost dit informatieprobleem niet op. Na een inhoudelijk methodebesluit
wordt de gekozen schatter consequent gebruikt voor uitgangsschatting en alle
replicaties. De 95%-grens blijft per schatter gelden: uitval bij één groep
hoeft andere groepen niet automatisch te blokkeren. Er is geen 500-run,
2.000-run, databasewijziging, nieuwe dump/cache of VPS-publicatie uitgevoerd.

## Herhalen

```sh
Rscript R/audit_trim_bridge_zero_totals.R \
  /Users/ton/Documents/GitHub/_worktrees/Meijendel/trim-brug-bootstrap \
  /Users/ton/Documents/GitHub/Meijendel/meijendel_tables_cache-p13-15de9245b0d0fbbd0a65990c6c0d618ff8f0298f712775210fe0b1566a917913.rds \
  /Users/ton/Documents/GitHub/Meijendel/outputs/trim-bootstrap-window-20261102/comparison
```

Ruwe kalibratieregels blijven uitsluitend in de genegeerde lokale uitvoermap.
De vier CSV’s hier zijn compacte uitgangs- en geldigheidsdiagnostiek.


## Verdiepende beoordeling 2 november 2026

De vergelijking is uitgesplitst in afronding, modelvorm en plotdekking.
`rtrim::totals()` rondt de uitvoer af; de modelinvoer blijft ongerond. Na
gebruik van de ongeronde jaartotalen resteert bij Witte Kwikstaart 8,21%
verschil met het venstermodel in plaats van 32,88%. De precieze kans op
verlies van alle positieve navensterplots is 4,3182%. De 47/50 bewijst
dus geen structurele uitval boven 5%; de 95%-geldigheidsgrens alleen is
echter onvoldoende om de nulrand in het betrouwbaarheidsinterval te
behandelen. Bij Veldleeuwerik blijft sterke imputatie- en plotgevoeligheid.
Zie `sensitivity/README.md` voor het afgeronde oordeel en het voorstel
voor incidentele soorten. De productiemethode is niet gewijzigd.
