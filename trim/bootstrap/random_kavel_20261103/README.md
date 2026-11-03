# Vier soorten met gedeeltelijk gedeelde kavelinformatie

Proef afgerond op 3 november 2026. Bron: de bewaarde Meijendel-ontwikkelcontext
1958–2025, vier soorten, 52 kavelclusters en exact dezelfde 50 gestratificeerde
trekkingen als de eerdere pilot. Alleen Koolmees haalt alle vooraf gekozen
criteria. De proef rechtvaardigt geen algemene vervanging van de lange trend.

## Vooraf vastgelegd

[CRITERIA.md](CRITERIA.md) is afzonderlijk gecommit als `c3fc5dfb`, vóór de
berekeningen op de vier soorten. Criteria- en scriptchecksum staan in
[manifest.json](manifest.json); de criteria zijn nadien niet veranderd.

- A: beide uitgangsmodellen volledig geconvergeerd, geldige positieve
  verwachtingen, een schatbare brug en ten minste 48/50 lange trends.
- B: alle getelde validatiecellen precies eenmaal beoordeeld in vijf groepen
  van driejaarsblokken per periode. Nullenkavels blijven inbegrepen.
- C: minder gezamenlijke voorspellingsfout dan hetzelfde kavelmodel zonder
  tijd, per periode hoogstens 10% slechter en ten minste zes van tien
  testgroepen niet slechter. Getoetst op identieke cellen met teldeviantie.
- D: hellingen stabiel bij k=3/7, drie-/vijfjaarsbrug en alleen de
  17 historische kernkavels. Marge: maximaal 1 procentpunt per jaar of 20%
  van de primaire helling, de ruimste van beide. Ook de periodehellingen
  worden getoetst; richtingen binnen ±0,5% worden niet beslist genoemd.

Dit zijn vooraf gekozen praktische pilotgrenzen. Zij bewijzen geen formele
intervaldekking of universele modelgeschiktheid.

## Uitkomst per soort

| Soort | Berekenbaar | A | B | C | D | Uitgangshelling per jaar | Oordeel |
|---|---:|:---:|:---:|:---:|:---:|---:|---|
| Veldleeuwerik | 50/50 | ja | ja | nee | nee | −6,65% | Geen kandidaat voor algemene vrijgave |
| Torenvalk | 49/50 | ja | ja | nee | nee | −3,30% | Geen kandidaat voor algemene vrijgave |
| Tapuit | 45/50 | nee | ja | ja | nee | −13,40% | Geen kandidaat voor algemene vrijgave |
| Koolmees | 50/50 | ja | ja | ja | ja | +3,41% | Kandidaat voor verdere validatie |

De helling vat de modelcurve over de vastgehouden soortspecifieke modeljaren
samen. Een gemiddelde over de hele reeks kan een recente stabilisatie of
omkering verhullen. Het is geen nieuw waargenomen jaarlijks groeipercentage.

**Veldleeuwerik.** De voorspellingsfout is vóór 1984 2,066 maal de fout van
het model zonder tijd; vanaf 1984 1,112 maal. Zes van tien testgroepen zijn
niet slechter, maar de periodegrens van 10% wordt overschreden. Met k=3
verandert de lange helling van −6,65 naar −4,95% en de recente periodehelling
van −10,06 naar −6,46%. Alleen de historische kern geeft voor die periode
−5,60%. De recente stijging van de gladde curve wijkt bovendien zichtbaar af
van de jaarindex. Berekenbaarheid lost deze vorm- en dekkingsgevoeligheid niet op.

**Torenvalk.** De voorspellingsfout is vóór 1984 2,631 maal de referentiefout,
vanaf 1984 0,855 maal; negen van tien testgroepen zijn niet slechter.
De fout in de historische periode verhindert toch criterium C. De historische
periodehelling verandert bij k=7 van −5,72 naar −1,79%. Alleen de historische
kern levert een lange helling van −4,35% tegenover −3,30%. Trekking 28 houdt
een volledig nulbrugvenster: zonder aantoonbare brug volgt geen lange trend.

**Tapuit.** De voorspelling verbetert: foutverhoudingen 0,850 vóór en 0,374
vanaf 1984; acht van tien testgroepen niet slechter. Toch zijn vijf trekkingen
ongeldig: 17 en 34 convergeren niet volledig; 4, 46 en 49 leveren geen eindige,
geldige verwachting of onzekerheid. Die worden niet als geslaagde uitkomsten
meegeteld. Alleen de historische kern geeft −21,85% tegenover −13,40% over
het gehele netwerk; de periode vanaf 1984 verandert van −19,30 naar −36,54%.
Dat is afhankelijkheid van de onderzochte kaveldekking, geen bewijs dat de
bronwaarnemingen fout zijn. De algemene lange trend is hiermee niet vrijgegeven.

**Koolmees.** Alle 50 trekkingen zijn berekenbaar. De foutverhoudingen zijn
0,630 vóór en 1,00013 vanaf 1984; zeven van tien groepen niet slechter.
De vrijwel gelijke fout vanaf 1984 is geen aantoonbare verbetering in die
periode; het gezamenlijke criterium wordt wel gehaald. De lange hellingen
bij k=3/7 zijn +3,43/+3,38%, met driejaarsbrug +3,29% en op de historische
kern +3,67%. Dit maakt Koolmees een kandidaat binnen deze proef. Het stelt
geen methode vast voor alle 156 soorten van de ontwikkelbron.

## Wat de 50 trekkingen laten zien

| Soort | Mediaan van geldige hellingen | Kleinste–grootste geldige helling |
|---|---:|---:|
| Veldleeuwerik | −6,50% | −11,17 tot −3,53% |
| Torenvalk | −3,16% | −7,55 tot +0,38% |
| Tapuit | −13,68% | −34,99 tot −10,23% |
| Koolmees | +3,35% | +2,69 tot +4,27% |

Dit zijn beschrijvende spreidingen over respectievelijk 50, 49, 45 en 50
geldige uitkomsten. Geen 95%-betrouwbaarheidsintervallen. Vooral bij Tapuit
kan uitval de getoonde spreiding selectief maken. Meer trekkingen herstellen
een afgewezen modelvorm of afhankelijke kaveldekking niet.

## Methode en grenzen

Per periode is een quasi-Poisson-GAM met loglink, tijdsspline (k=5, REML),
stratum en willekeurig kavelintercept gebruikt. Informatie wordt alleen tussen
kavels van dezelfde soort gedeeld. Alle getelde nulcellen en ook geheel
nul getelde kavels blijven in het model. Ontbrekend wordt niet nul.
De bestaande oppervlaktecorrectie en vaste soortspecifieke jaren blijven gelijk.

Voor de 52 referentiekavels zijn niet-getelde kaveljaren modelverwachtingen.
Bij een geheel niet in de training waargenomen kavel wordt over de geschatte
normale verdeling op logschaal geïntegreerd: exp(eta + tau²/2).
De extra spreiding van die onbekende kavelbijdrage wordt meegenomen in de
fitcontrole. [unknown_site_uncertainty.csv](unknown_site_uncertainty.csv) toont
per soort en periode de variantie op logschaal, de extra standaardafwijking
op logschaal en de relatieve standaardafwijking sqrt(exp(tau²)−1). Dit zijn
modelmatige spreidingsmaten voor een onbekende kavel, geen interval voor
het jaartotaal. Bij de historische Veldleeuwerik is die relatieve spreiding
ongeveer 519 maal de gemiddelde onbekende kavelverwachting; dat laat zien
hoe zwaar de verdelingsaanname hier weegt. De normale kavelverdeling, gelijke tijdsvorm binnen strata en
vergelijkbaarheid van getelde en ongetelde kavels blijven aannamen. Grote
kavelvariantie kan de verwachting en spreiding voor onbekende kavels sterk
vergroten. Quasi-Poisson specificeert geen volledige telkansverdeling; er
wordt geen volledig voorspelinterval voor individuele tellingen geleverd.

De vijfjaarsbrug is 1979–1983/1986–1990; referentie 1981–1983/1986–1988.
De hoofdtijdvakken zijn vóór 1984 en vanaf 1984; 1984–1985 kalibreren niet.
De gevoeligheid voor de driejaarsbrug blijft bij alle vier binnen de vooraf
gekozen marge. De historische-kernproef verandert de referentiekavelpopulatie
en onderzoekt daarmee de afhankelijkheid van de netwerkdekking; zij is geen
zuivere herhaalde schatting van exact dezelfde geografische populatie.

De volledige voorspeltoets telt 80 model-testgroepcombinaties:
vier soorten × twee perioden × vijf groepen × twee modellen. Alle zijn
berekenbaar, zonder de eerdere uitsluiting van testkavels. Het is een toets
met achtergehouden jaarblokken, geen bewijs voor extrapolatie buiten 2025.

## Figuren en bewijs

De figuren tonen de bestaande jaarindex en de nieuwe modelverwachting,
beide geschaald op gemiddeld 1979–1983 = 100. Positieve modelverwachtingen
vervangen geen echte nul. Geen onzekerheidsband wordt gesuggereerd.

- [Veldleeuwerik](curve_150.png), [Torenvalk](curve_64.png),
  [Tapuit](curve_173.png), [Koolmees](curve_214.png).
- [summary.csv](summary.csv): mechanische A–D-beoordeling.
- [estimates.csv](estimates.csv): uitgangsschattingen en alle 50 trekkingen,
  inclusief uitvalredenen.
- [diagnostics.csv](diagnostics.csv): 408 periodecontroles met aantallen
  gebruikte cellen en nullen, kavelvariantie en onbekende referentiecellen.
- [cv.csv](cv.csv): alle 80 testgroepuitkomsten; [sensitivity.csv](sensitivity.csv):
  16 vorm-, brug- en dekkingsvarianten; [baseline_curves.csv](baseline_curves.csv):
  vier uitgangscurven.
- R/trim_random_plot_trial.R is de reproduceerbare proef;
  R/check_trim_random_plot.R controleert nulbehoud, marginalisatie en testdekking.
  R/render_trim_random_trial.R tekent de vier figuren.

Ruwe checkpoints blijven buiten Git onder
`outputs/trim-random-plot-20261103` in de canonieke repository. Bestaande
brondata, jaarindices en productietabellen zijn in deze taak niet gewijzigd.
Geen 2026-invoer, databasewijziging, nieuwe cache, 500/2.000-run of publicatie.

## Besluit en resterend

De proef is afgerond. De eerdere blokkade van onvolledige testdekking is voor
deze vier soorten opgelost. De algemene methodische kwestie rond de lange
trend is nog niet opgelost: drie soorten halen de vooraf gekozen criteria
niet. Koolmees is kandidaat voor verdere validatie; de andere soorten blijven
zichtbaar met hun tellingen en afzonderlijke perioden. Geen automatische
selectie op gunstige uitkomsten en geen algemene methodeswitch.

## Verificatie

De 50 trekkingen zijn onafhankelijk vergeleken met de originele batches;
alle kavel-ID's, volgorde en manifestverwijzingen komen exact overeen.
De 204 schattingen, 408 periodecontroles, 80 testgroepuitkomsten en de
mechanische A–D-uitkomsten zijn gecontroleerd tegen de checkpoints.
Alle geslaagde modellen behouden het aantal inputcellen én nulcellen.
Per soort en periode tellen de vijf testgroepen voor beide modellen exact
op tot de getelde inputcellen en nullen. De criteria zijn bytegelijk aan
de voorafgaande commit; de proefcode is gelijk aan de manifestchecksum.
Vier bestaande hoofd-CSV's (twee jaarindices, modelstatus en brugfactoren)
hebben hun eerdere checksum behouden. De gerichte controles
`R/check_trim_random_plot.R`, `R/check_trim_zero_count_comparison.R`,
`R/test_trim_trend_contract.R` en `R/check_trim_species_output_contract.R`
slaagden tijdens deze taak. De vier figuren zijn visueel gecontroleerd.

Het bronregister is gelijk bijgewerkt in Markdown en Word. Alle 59
gerenderde Wordpagina’s zijn afzonderlijk visueel beoordeeld; geen
opmaakdefecten. De onafhankelijke code- en resultaatreview is schoon.
