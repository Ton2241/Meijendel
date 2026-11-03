# Validatie met 500 trekkingen voor alle soorten tot en met 2025

De 500-validatie is afgerond voor alle 156 soorten uit de bewaarde Meijendel-
ontwikkelbron 1958–2025. **Voor 28 soorten is een vervolg met 2.000 zinvol
als verdere validatie.** Negen soorten met een schatbare uitgangsverandering
hebben uitval; 119 hebben voor de vaste lange maat geen schatbare baseline.
Alle 156 blijven in de uitvoer. Er is geen 2.000-run gestart.

Praktisch advies vóór een algemene 2.000-run: beoordeel afzonderlijk de
volledigheidseis voor indexjaren 1984/1985. Die jaren vallen buiten de doel-
en brugvensters, maar blokkeren nu een aantal uitkomsten. Hiervoor is geen
nieuwe trekking of vogeltelmodelfit nodig. Deze vooraf vastgelegde poort is
in deze beoordeling niet achteraf aangepast. Een afgebakende vervolgvalidatie
voor de 28 volledig berekenbare soorten kan volgens de huidige poorten wel.

## Vooraf vastgelegde uitvoering

[CRITERIA.md](CRITERIA.md) en driver zijn vóór de nieuwe berekeningen gecommit
als `936915e9`. Het maatcontract uit `b2d45c6a` blijft gelden: primaire netto-
indexverandering tussen gemiddeld 1958–1962 en 2021–2025; dezelfde jaren
voor iedere soort. Drie- en zevenjaarsvensters blijven gevoeligheidsvarianten.
De gekozen experimentele brug is 1979–1983/1986–1990. Geen andere bron,
jaarselectie, soortfilter of brugmethode gekozen.

Alle 500 replicaties zijn zelfstandig opnieuw berekend met seed 20260920 en
een eigen runidentiteit. De eerste 50 gebruiken dezelfde trekkingen als de
pilot en tellen mee binnen 500, niet als 50 extra. Replicaties 1 en 2
reproduceren de opgeslagen soorten- en indexuitvoer; alle 50 oorspronkelijke
draws zijn identiek en hun eindpuntschattingen/statussen zijn gereproduceerd.
Geen oude batches onder een nieuwe identiteit gezet.

De broncontext, kavelhistorie, strata, soorttargets en oppervlaktecorrectie
zijn gelijk gebleven: 52 kavelgeschiedenissen, gestratificeerd in 17
historische en 35 latere clusters. In iedere trekking zijn de bestaande
periodemodellen en brugkalibratie opnieuw geschat. Het bestaande voorschrift
van de eerste werkende modelvariant is behouden; de gekozen variant kan
per trekking verschillen. Geen nieuwe modelzoekactie of nieuwe baselinefit.

## Poorten na 500

| Uitkomst primaire maat | Soorten | Betekenis |
|---|---:|---|
| 500/500 geldig, schatbare baseline, niet-constant | 28 | Kandidaat voor verdere 2.000-validatie |
| 475–499/500 geldig, schatbare baseline | 7 | Geen interval uit de eindige subset |
| Minder dan 475/500, schatbare baseline | 2 | Geen intervalvrijgave |
| Geen schatbare baseline voor de vaste maat | 119 | Lange maat blijft onbeschikbaar |
| Totaal | 156 | Alle soorten blijven zichtbaar |

De 95%-rekendrempel wordt door 35 soorten gehaald. Zij is geen voldoende
voorwaarde voor een interval; de afgesproken route weigert iedere band
waarvoor ook maar één trekking ontbreekt. In de 50-pilot hadden 33 soorten
volledige uitkomsten; vijf daarvan laten in 500 alsnog uitval zien. Dit is
geen nieuwe vaste soortselectie en geen grens aan het algemene soortenbestand.

De 119 zonder baseline bestaan, volgens de eerder vastgelegde hiërarchie,
uit 45 soorten zonder benodigde beginindexjaren, 11 zonder schatbare brug
en 63 zonder beide benodigde modelperioden. Van die 63 hebben 42 één
periode en 21 geen. Een ontbrekende beginindex is niet hetzelfde als een
ontbrekende brontelling: de bestaande modelroute begint bij het eerste
positieve jaar. Geen terugvoorspelling of nulwaarde toegevoegd.

## Negen soorten met een schatbare baseline en uitval

| Soort | Geldig/500 | Primaire uitval |
|---|---:|---|
| Dodaars | 499 | 1 indexjaar ontbreekt |
| Wintertaling | 330 | 160 nulbrugvensters, 7 modeluitvallen, 3 onvolledige indexreeksen |
| Slobeend | 498 | 2 onvolledige indexreeksen |
| Kuifeend | 499 | 1 indexjaar ontbreekt |
| Torenvalk | 481 | 19 nulbrugvensters |
| Ransuil | 389 | 111 nulbrugvensters |
| Veldleeuwerik | 496 | 3 nulbrugvensters en 1 ontbrekend indexjaar |
| Witte Kwikstaart | 490 | 10 nulbrugvensters |
| Rietgors | 499 | 1 indexjaar ontbreekt |

Alle genoemde bruguitvallen hebben de bronreden
`nul_totaal_volledig_venster`. De zeven Wintertaling-modeluitvallen zijn vier
gevallen zonder constant jaarinterval en drie met een verwachte waarde nul.
De volledige redenen en aantallen staan in [failure_reasons.csv](failure_reasons.csv).
Model- en brugvlaggen kunnen overlappen; de tabel gebruikt één primaire
reden per soort-trekkinggeval en telt deze niet dubbel.

### De indexgaten blijken getelde nuljaren buiten de maat te betreffen

Er zijn negen soort-trekkinggevallen met twaalf ontbrekende modelindexjaren:
1984, en bij de drie Wintertaling-gevallen tevens 1985. De getelde broncellen
voor die jaren bevatten echte nullen. Nadat de bestaande fitvoorbereiding
kavels zonder enige positieve telling in de betreffende modelperiode
verwijdert, blijven voor die jaren geen modelcellen over. De oorspronkelijke
modeljaarcontrole vóór dit filter slaagt, maar de resulterende jaarindex
bevat niet alle vereiste kalenderjaren. De nieuwe volledigheidspoort
signaleert dit en laat de band leeg.

[audit indexgaten](index_gaps.csv) bewaart alle twaalf jaarregels, broncellen,
positieve cellen en cellen na het filter. De betrokken replicaties zijn:
Wintertaling 191/198/333; Dodaars 333; Slobeend 198/333; Kuifeend 333;
Rietgors 333; Veldleeuwerik 339. Geen getelde nul is als ontbrekende
brontelling aangemerkt en er is geen ontbrekende index als nul ingevuld.

1984/1985 worden niet gebruikt in de begin- en eindgemiddelden of de
brugvensters. Daarom bewijst deze uitval niet dat de begin/eindverhouding
zelf onschatbaar is. Het is een beperking van het bestaande nulkavelfilter
in combinatie met de vooraf afgesproken eis van volledige modeljaarindices.
Een afzonderlijke beoordeling van die eis kan met de huidige 500-data;
voor deze taak is de poort gehandhaafd. Vooral Dodaars, Slobeend, Kuifeend
en Rietgors worden uitsluitend hierdoor geblokkeerd. Veldleeuwerik en
Wintertaling houden daarnaast eigen brug- of modeluitval.

## Grensstabiliteit bij 250, 375 en 500

De vooraf gekozen regel verlangt per overgang dat beide percentielgrenzen
minder dan 0,10 procentpunt netto én minder dan 5% van de actuele bandbreedte
verschuiven. Er waren 31 diagnostische banden bij 250, 28 bij 375 en 28 bij
500. Bij de laatste overgang voldoen alleen **Bergeend, Scholekster en
Stormmeeuw** aan de regel. Geen van de 28 voldoet bij beide opeenvolgende
controles.

Dit betekent dat de banden op 500 nog niet als numeriek stabiel mogen
worden gepresenteerd. De mate van beweging verschilt sterk. Bij Koolmees
verschuift de bovengrens tussen 375 en 500 ongeveer 2,66 procentpunt; bij
Tjiftjaf ongeveer 874,80 procentpunt op een zeer grote relatieve toename.
Bij Wulp is de absolute verschuiving klein, maar overschrijdt zij 5% van de
zeer smalle band. De regel bevat dus zowel een absolute als relatieve eis.
Alle waarden staan per soort in [per_species.csv](per_species.csv).

Monte-Carlo-onrust is onderscheiden van een structureel ongedefinieerde
uitkomst. Meer trekkingen kunnen de numerieke precisie verbeteren, maar
maken geen onschatbare brug of ontbrekende baseline geldig. Volgens het
voorafcontract kan 2.000 daarom een vervolgstap voor de 28 complete soorten
zijn; dit is geen vrijgave van hun definitieve marges of garantie dat
2.000 aan de stabiliteitsregel zal voldoen.

## Nulgrens, bronsteun en vensterkeuze

De 500 primaire trekkingen per soort omvatten twaalf echte nuleinden:
Wulp negen, Stormmeeuw twee en Tapuit één. Zij blijven als −100% in de
verdeling staan. Er is geen nulbegin waargenomen. De helper weigert
nulbegin, oneindige waarden, een band uit alleen eindige trekkingen en een
schijnzeker interval bij een constante verdeling. De formele 95%-kolommen
zijn voor alle soorten en vensters leeg.

De vijf eerder gemarkeerde kandidaten met hoogstens één positieve
bronkavel in 2021–2025 blijven van toepassing: Scholekster, Wulp,
Stormmeeuw, Tortelduif en Tapuit. Bij Wulp is er in dat eindvenster geen
positieve telling op de getelde bronkavels; de positieve uitgangsindex
berust op de bestaande modelaanvulling. Een kleine band betekent daar
geen bewezen zekerheid over afwezigheid in heel Meijendel.

De eerdere zes richtingswisselaars tussen de drie-, vijf- en zevenjaars-
uitgangsvensters blijven Kuifeend, Witte Kwikstaart, Gekraagde Roodstaart,
Grasmus, Fitis en Kneu. Deze gevoeligheid is niet in één 95%-band gemengd.
De uitkomst beschrijft de bestaande modelgecorrigeerde telnetwerkroute,
geen bewezen gelijk bemonsterde geografische vogelpopulatie. De historische-
kernvergelijking betreft een andere kavelpopulatie. De gekozen brug kan
methodeverschillen en echte verandering tussen de brugvensters niet volledig
scheiden; extra trekkingen nemen die aannamen niet weg.

## Rekentijd en begrenzing

Honderd batches van vijf, één lokale worker, nul batchfouten. Geregistreerde
batchtijd 11.146,64 seconden, ongeveer 3 uur en 6 minuten. Voorbereiding,
beoordeling en rapportage vallen daarbuiten. De grootste R-geheugenmaat
was circa 397 MB; dit is de gc-diagnostiek, geen volledige proces-RSS.
De grootste gemeten systeembrede swapgroei binnen één batch was circa
1,076 GB. Bij de daaropvolgende controle was 43% geheugenruimte vrij en
gebruikte R circa 410 MiB RSS. De systeemswapmeting is niet aan R alleen
toe te schrijven; er is geen geheugenblokkade vastgesteld.

Geen databasebewerking, nieuwe dump/cache, 2026-invoer, nieuwe modelmethode,
nieuwe soortselectie, dashboard/VPS-publicatie of 2.000-run. De bekende
jaarindices en afzonderlijke perioden zijn behouden. Deze beoordeling
gaat over de lange begin/eindmaat en berekent geen nieuwe formele marges
voor jaarlijkse of afzonderlijke periode-uitkomsten.

## Bewijs

- [PER_SOORT.md](PER_SOORT.md): alle 156 soorten met uitkomst, bandstatus,
  poort, grenscontrole en aandachtspunten.
- [per_species.csv](per_species.csv), [primary_estimates.csv](primary_estimates.csv):
  156 soortoverzichten en 78.156 primaire bron-/trekkingregels.
- [window_sensitivity.csv](window_sensitivity.csv): 468 soort-vensterregels;
  [coverage.csv](coverage.csv): 312 ongewijzigde bronvensterregels.
- [index_gaps.csv](index_gaps.csv), [failure_reasons.csv](failure_reasons.csv):
  concrete jaarindexgaten en primaire redenfrequenties.
- [resources.json](resources.json), [manifest.json](manifest.json):
  herkomst, bron-/codehashes, timing en status.

De ruwe honderd RDS-batches en de volledige 234.468 soort-draw-vensterregels
blijven buiten Git in outputs/trim-2025-validation-500-20261103 van de
canonieke repository. De compacte eindresultaten hierboven zijn vastgelegd.
Uitvoering: R/run_trim_2025_validation.R; beoordeling:
R/assess_trim_500_validation.R; gerichte gap-audit:
R/audit_trim_500_index_gaps.R. Er zijn geen 95%-p-waarden of automatische
BCa-fallback gebruikt. De percentielmethode blijft een expliciete kandidaat.

## Verificatie

De onafhankelijke eindreview is schoon, zonder Critical-, Important- of
Minor-bevindingen met gebruikersimpact. Alle honderd batches en precies
1–500 zijn gecontroleerd, met gelijke bronpayload, nul batchfouten en
reproductie van de oorspronkelijke vijftig trekkingen en eindpuntschattingen.
De poorten 28/9/119, de lege formele CI-kolommen, drie laatste stabiele en
nul beide stabiele banden zijn onafhankelijk bevestigd. De jaarindexaudit
bevestigt negen gevallen en twaalf jaarregels. Criteria-, code- en audit-
checksums kloppen. De gerichte R-controles zijn groen; de eerdere vier
50-resultaatCSV's blijven bytegelijk na de geheugenaanpassing. Vier beschermde
hoofd-CSV's hebben hun checksum behouden. Alle 61 pagina's van het actuele
bronregister zijn visueel gecontroleerd; Word en Markdown zijn inhoudelijk
gelijk. Een bestaande andere zinsvolgorde bij BLWG is niet gewijzigd.

De soortenweergave voorkomt een afgeronde schijnnul bij een positieve
maar zeer kleine eindindex: waarden vlak boven −100% krijgen meer decimalen.
Deze presentatiecontrole faalde eerst op de Wulp-puntwaarde en slaagt nu;
de bron-CSV's en de 156 soortenregels zijn behouden.
