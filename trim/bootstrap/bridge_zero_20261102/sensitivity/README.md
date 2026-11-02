# Beoordeling van brugverschillen en nulvensters

Stand: 2 november 2026. Historische ontwikkelcache 1958–2025; zes brugjaren
1981–1983 en 1986–1988. Detailcontrole voor Veldleeuwerik (150) en Witte
Kwikstaart (162); kans op volledig verlies van positieve vensterinformatie
voor alle 33 vaste soorten. Geen nieuwe bootstrap, databasebewerking of
wijziging van de primaire methode.

## Afronding blijkt een afzonderlijk technisch effect

`rtrim` 2.3.1 bewaart de fractietellingen in de modelinvoer en berekening.
De tabel uit `totals()` bevat echter afgeronde jaartotalen. Het huidige
jaarlijkse brug-hulpmodel gebruikt die tabel. De interne `tt_imp` en de
kolomsommen van de geïmputeerde telmatrix zijn ongerond; hun gelijkheid
is in deze controle getoetst. De eerdere suggestie van afgeronde
modelinvoer is hiermee gecorrigeerd: de precisie verdwijnt bij uitlezen.
Een fictieve controle met totaal 6,9 geeft intern 6,9 en via `totals()` 7.

| Soort | Jaarlijks, huidige afgeronde uitvoer | Jaarlijks, ongerond | Venstermodel |
|---|---:|---:|---:|
| Veldleeuwerik | 1,08197 | 1,09903 | 0,53037 |
| Witte Kwikstaart | 0,41667 | 0,51165 | 0,55368 |

Dit zijn kalibratieniveauverhoudingen na/voor, geen populatietrends. De
brugfactor verandert binnen een soort met dezelfde relatieve verhouding,
omdat de ankers uit de hoofdmodellen bij de vergelijking vastliggen.
Voor Witte Kwikstaart resteert na verwijdering van het afrondingseffect
8,21% verschil tussen de modelvormen; de eerder genoemde 32,88% bevatte
beide effecten. Voor Veldleeuwerik blijft het verschil groot: −51,74%.
De productiefunctie is in deze beoordeling niet aangepast. Advies: lees
vóór verdere methodekeuze gevalideerde ongeronde totalen uit en leg dit
met een regressietest vast.

## Veldleeuwerik is sterk afhankelijk van imputatie

Van de 33 kandidaatplots leveren voor Veldleeuwerik in 1986 negen plots
geldige soortcellen. Daarin zijn twee territoria geregistreerd. Het
jaarlijkse hulpmodel komt op 46,72537, waarvan 44,72537 door imputatie
van ontbrekende cellen: circa 95,7% van het totaal. De grootste aanvullingen
zijn M33 (17,30), M17a (9,31) en M36 (7,97). Dit zijn modelschattingen,
geen waargenomen territoria. De officiële definitie van geïmputeerde
TRIM-totalen is waargenomen tellingen plus voorspellingen voor ontbrekende
site-tijdcellen: https://search.r-project.org/CRAN/refmans/rtrim/html/totals.html

Weglaten van M75 verhoogt de ongeronde jaarlijkse niveauverhouding van
1,099 naar 2,982 (+171%). De venstermethode is minder extreem, maar ook
gevoelig: weglaten van M33 verlaagt de verhouding van 0,530 naar 0,380
(−28%). Dat ondersteunt geen automatische keuze op grond van meer
geslaagde fits. Beide methoden veronderstellen ruimtelijk gedeelde
veranderingen; het venstermodel voegt de aanname van één niveau per
driejaarsvenster toe.

De twintig generiek in alle zes jaren getelde plots zijn niet per se voor
iedere soort volledig bruikbaar. De soortpoort behoudt onbekende cellen als
ontbrekend. Werkelijk volledige zesjaarssoortdekking resteert voor
Veldleeuwerik op vijf plots; daar ontbreekt in het gehele voorvenster
positieve informatie. Voor Witte Kwikstaart zijn zestien plots volledig.
Op die zestien plots stemmen de ongeronde jaarlijkse methode, de
venstermethode en de verhouding van de waargenomen totalen overeen op
0,526555. Dit is een onafhankelijke controle van de modelvergelijking.

## Exacte kans op verlies van positieve vensterinformatie

De trekking gebruikt 17 historische kernclusters en 35 latere clusters.
Voor een venster met k positieve clusters binnen een stratum van n
clusters is de kans dat zij alle worden gemist `(1-k/n)^n`. Vermenigvuldig
dit over de twee strata. Voor verlies in minstens één venster wordt
inclusie-exclusie gebruikt met de vereniging van beide positieve sets.
Dit is exacte kansrekening voor het bestaande resamplingontwerp, geen
extra simulatie en geen ecologisch betrouwbaarheidsinterval. Andere
model- of dekkingsuitval wordt hiermee niet meegerekend.

| Soort | Positieve plots voor/na | Kans op verlies van minstens één venster |
|---|---:|---:|
| Witte Kwikstaart | 7 / 3 | 4,3182% |
| Roodborsttapuit | 4 / 7 | 1,3668% |
| Veldleeuwerik | 7 / 5 | 0,5653% |

Voor Witte Kwikstaart dragen na de methodebreuk alleen M10-12-76, M6 en
M74 positieve informatie in de brugjaren. Twee liggen in het historische
stratum en één in het latere stratum. De kans om ze alle te missen is
`(15/17)^17 * (34/35)^35 = 0,043181755`. Dit verklaart de drie nulvensters
in de eerdere 50 trekkingen (15, 34 en 44); de verwachting is 2,16 op 50.
De 47/50 is dus geen bewijs dat een grotere run onder 95% geldigheid zal
blijven. Bij 2.000 trekkingen verwacht dit mechanisme circa 86 gevallen;
dat is een berekende verwachting, geen uitgevoerde run.

De nuance verandert de intervalbeoordeling niet automatisch. Ongeveer
4,296% kans betreft een nul-navenster met een positief voorvenster; dan
ligt de niveauverhouding op de rand nul. Circa 0,022% betreft verlies van
beide vensters. Omdat de eerste kans groter is dan 2,5%, raakt de onderste
staart van een tweezijdig 95%-percentielinterval de rand nul. Zulke
trekkingen verwijderen en alleen de resterende eindige logschattingen
gebruiken levert een conditioneel interval. Een grens van 95% geslaagde
fits alleen borgt daarom niet de bedoelde onvoorwaardelijke onzekerheid.
Er is geen formeel interval berekend.

## Besluit en voorstel voor incidentele soorten

De afzonderlijke TRIM-perioden blijven primair. Voor Veldleeuwerik blijft
een aanvullende formele brug onvoldoende onderbouwd wegens de grote
imputatie- en plotgevoeligheid. Bij Witte Kwikstaart is het verschil
tussen de modelvormen na correctie veel kleiner; drie dragende
navensterplots en de randmassa blijven de beperkende factoren.

Advies voor incidentele, nieuw verschenen of verdwenen soorten: dwing
geen brug af. Stel brugbaarheid afzonderlijk vast uit positieve
plotdekking, vensterdekking en gevoeligheid; beoordeel zeldzaamheid over
de relevante hele reeks, niet uitsluitend op afwezigheid in de brugjaren.
Behoud alle soorten in de ecologische soortenlijsten en bronoverzichten.
Gebruik per periode een formele soorttrend waar de gegevens die dragen;
toon anders geregistreerde aanwezigheid en aantallen met hun teldekking.
Een onbekende cel blijft onbekend; een geldige getelde afwezigheid blijft nul.

Verbreed brugvensters eventueel vooraf en op inhoudelijke gronden voor
alle soorten op dezelfde manier, als gevoeligheidsanalyse. Kies niet per
soort achteraf de jaren waarin zij toevallig wel voorkwam. Een bredere
brug vermengt tevens meer werkelijke ecologische verandering met de
methodische aansluiting en is daarom geen automatische oplossing.
Geef groepen met onvoldoende onderbouwde brug geen geforceerd formeel
interval; laat de ecologische samenstelling daarbij intact. Gebruik geen
brugfactor 1, pseudotelling of overgenomen factor van een andere soort
zonder een afzonderlijk, gevalideerd model.

`annual.csv`, `sites.csv`, `imputation_cells.csv`, `influence.csv` en
`fits.csv` bevatten de detailcontroles. `zero_probability.csv` bevat
alle 33 soorten. Bron- en code-identiteit staan in `manifest.json`.
De scripts zijn lokaal herhaalbaar met dezelfde argumenten als
`R/audit_trim_bridge_zero_totals.R`, met als script
`R/audit_trim_bridge_sensitivity.R` en een eigen uitvoermap.
