# Vooraf vastgelegde criteria voor de proef met gezamenlijke kavelinformatie

Vastgelegd op 3 november 2026, vóór de modelberekeningen. De criteria worden
als afzonderlijke Git-commit bewaard en in het uitvoermanifest gehasht.

## Vraag en afbakening

Kan een telmodel met gedeeltelijk gedeelde kavelinformatie een verdedigbare
lange populatiecurve schatten zonder nulwaarnemingen te vervangen en zonder
schaarse validatiekavels uit de beoordeling te verwijderen?

Bron: de bewaarde gevalideerde ontwikkelcontext 1958–2025. Vier soorten:
Veldleeuwerik, Torenvalk, Tapuit en Koolmees. Dezelfde 50 gestratificeerde
kavelnetwerktrekkingen als in de eerdere pilot, plus de oorspronkelijke
bron als uitgangspunt. Geen nieuwe trekking, 2026-data, databasebewerking,
500/2.000-run of publicatie. Bestaande tellingen en jaarindices blijven staan.

De lange trend is in deze proef de gemiddelde jaarlijkse verandering van
de geschatte populatiecurve over de eigen vastgehouden modeljaren. Dit is
een modelmatige samenvatting, geen vervanging van de getelde jaarwaarden.
De curve en haar lange helling worden samen beoordeeld.

## Eén hoofdkandidaat

Per bestaande periode afzonderlijk: quasi-Poisson-telmodel met loglink,
een beperkt glad tijdsverloop (cubic regression spline, k=5, REML), een
vast verschil tussen historische kern en later netwerk, en een normaal
verdeeld willekeurig kaveleffect. De kavelinformatie wordt alleen binnen
dezelfde vogelsoort gedeeld. De verdeling en spreiding zijn modelaannamen.
Alle getelde cellen met geldige niet-negatieve aantallen doen mee, ook
kavels zonder positieve telling in de hele periode. Ontbrekende tellingen
blijven ontbrekend. De bestaande oppervlaktecorrectie blijft gelijk.

Referentiepopulatie voor voorspellingen: de vaste 52 plotclusters uit de
bronbundle, met hun bestaande strata. Een niet-geteld kaveljaar blijft
modelvoorspelling. Voorspellingen voor een geheel niet in de training
waargenomen kavel worden over de geschatte kavelverdeling gemiddeld;
zij worden niet gelijkgesteld aan een gemiddelde kavel op logschaal.
De onzekerheid van die onbekende kavelbijdrage wordt apart weergegeven.
Er wordt geen volledig voorspelinterval voor losse tellingen geclaimd:
quasi-Poisson legt daarvoor geen volledige kansverdeling vast.

De twee hoofdperioden, vaste soortspecifieke kalenderjaren en de empirische
brug blijven gelijk. Primair 1979–1983/1986–1990, referentie
1981–1983/1986–1988. De overgangsjaren 1984–1985 kalibreren niet.
Een niet-identificeerbare brug krijgt geen geleende of vaste factor.

## Beoordeling per soort

**A — Berekenbaarheid en convergentie.** Beide oorspronkelijke periodemodellen
zijn volledig geconvergeerd, inclusief gladheidsoptimalisatie; de
verwachtingen zijn eindig en positief. De primaire brug is schatbaar.
Minimaal 48/50 lange-trendherhalingen zijn berekenbaar. Dit is alleen een
rekenkundige pilotdrempel, geen bewijs voor een geldig 95%-interval.

**B — Volledige voorspeltoets.** Dezelfde vijf testgroepen met blokken van
drie kalenderjaren als eerder. Iedere getelde validatiecel wordt precies
één keer beoordeeld, inclusief nullen en kavels zonder positieve training.
Geen hele testgroep laten vervallen vanwege ontbrekende positieve steun.
Alle tien soort-periode-testgroepen (5 vóór en 5 vanaf 1984) leveren een
volledige, geconvergeerde voorspelling. Niet-getelde cellen worden niet
als testnul ingevuld. Onvolledige dekking betekent criterium B niet gehaald.

**C — Voorspelkwaliteit.** Vergelijk op exact dezelfde testcellen met een
referentiemodel met dezelfde strata en willekeurige kavelstructuur, maar
zonder tijdsverloop. Gebruik gemiddelde teldeviantie als verliesfunctie,
geen formele Poisson-p-waarde. Het tijdsmodel heeft over beide perioden
samen een lagere gemiddelde fout en is in geen periode meer dan 10%
slechter. Het is in minimaal 6 van de 10 testgroepen niet slechter.
De 10%-grens en meerderheidseis zijn praktische, vooraf gekozen
pilotcriteria, geen algemene statistische natuurwetten.

**D — Vorm- en bruggevoeligheid.** Herhaal op de oorspronkelijke bron met
k=3 en k=7 en de driejaarsbrug. De richting van de lange trend blijft
gelijk; verschillen blijven binnen max(1 procentpunt per jaar, 20% van
de absolute primaire helling). Pas dezelfde marge toe op de twee
periodemodelhellingen bij k=3/7, zodat tegengestelde afwijkingen niet
wegmiddelen. Bij hellingen binnen ±0,5% per jaar wordt de richting niet
als beslist beschouwd. Daarnaast een baselineproef op alleen de
17 historische kernkavels; een groter verschil dan dezelfde marge wordt
als dekkingsgevoeligheid gemeld en verhindert algemene vrijgave.

## Beslisregel en beperkingen

Een soort is alleen kandidaat voor verdere validatie als A, B, C en D
gehaald zijn. Een grensgeval wordt gemeld, niet achteraf passend gemaakt.
Als één van de drie schaarse soorten faalt, is dat informatie over de
reikwijdte; de soort verdwijnt niet uit het bestand. Geen automatische
algemene vervanging op basis van één geslaagde soort of alleen 50/50.

Dezelfde clusterbootstrap wordt gebruikt voor de diagnostische spreiding
van de curve/helling en de brug. Vijftig herhalingen zijn te weinig om
formele staarten of dekking vast te stellen. Gedeelde kavelinformatie
kan voorspellen waar een los kaveleffect een grens bereikt, maar kan
ontbrekende informatie niet creëren. De veronderstelde vergelijkbaarheid
van kavels en tijdsverloop wordt daarom expliciet als beperking beoordeeld.
