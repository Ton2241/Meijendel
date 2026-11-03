# Alle soorten beoordeeld voor onzekerheid over de lange indexverandering

**Advies: ja, een afgebakende 500-validatie kan volgen.** Voor 33 soorten is
intervalvalidatie zinvol; voor twee daarnaast alleen onderzoek van bruguitval.
Alle 156 soorten blijven verwerkt en zichtbaar. Dit is geen toestemming om
nu 500 trekkingen te starten en geen vrijgave van formele onzekerheidsmarges.

De bewaarde Meijendel-ontwikkelbron loopt van 1958 tot en met 2025. Exact de
50 bestaande gestratificeerde trekkingen van 52 kavelgeschiedenissen zijn
hergebruikt. Geen nieuw vogeltelmodel, brug, trekking of bronbestand gemaakt.
De gevolgde indexroute is een modelgecorrigeerde telnetwerkreeks, geen
bewijs van gelijkblijvende bemonstering van heel Meijendel.

## Vastgelegd vóór de berekening

Gebruikersbesluit: de lange verandering beschrijven met vaste begin- en
eindgemiddelden naast jaarindices en afzonderlijke perioden. Eén gemiddeld
jaarlijks groeipad is niet de hoofdmaat. [CRITERIA.md](CRITERIA.md) is vóór
de uitkomstberekening gecommit als `b2d45c6a`.

Primair: 100 × (gemiddelde index 2021–2025 / gemiddelde index 1958–1962 − 1).
Dezelfde kalenderjaren voor iedere soort. Gevoeligheid: drie- en zevenjaars-
vensters met dezelfde vaste buitenjaren. De eerdere vijfjaarsvensterbrug
1979–1983/1986–1990 blijft de gekozen experimentele kalibratievariant.
Geen nieuw bewijs dat deze brug methodeverschil en echte verandering kan
scheiden. De bestaande oppervlakte-, telstatus- en kavelcorrecties blijven gelijk.

Een soort moet alle doelvensterjaren in de opgeslagen reeks hebben; de
volledige eerder vastgelegde soortmodeljaren worden bovendien op gaten,
dubbelen en ongeldige waarden gecontroleerd. Die modeljaren verschillen
soms per soort. Er wordt geen gunstig beginjaar gekozen of ontbrekend jaar
als nul ingevuld. Een nulbegin geeft geen procentuele verhouding. Een
positief begin met nuleinde geeft −100% netto, zonder pseudotelling.

## Uitkomst voor alle 156 soorten

| Oorspronkelijke bronstatus | Soorten |
|---|---:|
| Beide modelperioden en vaste vensters/brug schatbaar | 37 |
| Beide modelperioden, maar benodigde beginindexjaren ontbreken | 45 |
| Beide modelperioden, maar de brug niet schatbaar | 11 |
| Niet beide modelperioden schatbaar | 63 |
| Totaal | 156 |

De laatste 63 bestaan uit 42 soorten met één geslaagde modelperiode en
21 zonder geslaagde modelperiode. Van de 93 soorten met beide perioden
hebben dus 37 een schatbare uitgangsverandering voor deze vaste vensters.
De 45 met ontbrekende beginindexjaren hebben niet noodzakelijk ontbrekende
tellingen: de bestaande modelroute begint bij het eerste positieve jaar.
Die index begint dan na 1958. Deze taak heeft dat begin niet verplaatst,
geen terugvoorspelling gemaakt en geen vroegere telling tot index nul verklaard.
De 11 onschatbare bruggen krijgen geen vaste of geleende factor.

| Beoordeling primaire maat met 50 trekkingen | Soorten | Vervolg |
|---|---:|---|
| Schatbare baseline, 50/50 geldig, niet-constante verdeling | 33 | Kandidaat voor 500-intervalvalidatie |
| Schatbare baseline, 49/50 geldig | 2 | Alleen 500-uitvalonderzoek |
| Schatbare baseline, minder dan 48/50 geldig | 2 | Eerst brugprobleem behandelen |
| Baseline niet schatbaar voor de vaste maat | 119 | Geen formele lange verandering; overige informatie behouden |

De twee met 49/50 zijn **Torenvalk en Witte Kwikstaart**: beide verliezen één
brug. **Wintertaling** heeft 35/50 geldige uitkomsten met 15 bruguitvallen;
**Ransuil** 34/50 met 16 bruguitvallen. Geen band uit de stilzwijgend
verkleinde subset. Hun berekende eindige uitkomsten blijven wel als
beschrijvende diagnostiek beschikbaar, met hun aantallen erbij.

De 33 zijn een uitkomst van deze nieuwe soortspecifieke maat en poort;
zij zijn geen hergebruikte groepsselectie of blijvend soortfilter. Alle
156 staan in [PER_SOORT.md](PER_SOORT.md) en [primary.csv](primary.csv).
Het aantal dat de louter rekenkundige grens 48/50 haalt is 35. Volledigheid
voor een diagnostische band is hier vooraf strenger vastgesteld: alle 50.

## Nulgrens en beperkte bronsteun

In alle 7.800 primaire soort-trekkinguitkomsten zijn echte nuleinden
behouden. **Wulp** heeft tweemaal een nul eindgemiddelde en dus −100%.
Die twee waarden blijven in de verdeling staan. Een nulbegin is in deze
uitvoering niet voorgekomen, maar wordt expliciet getest en afgekeurd als
procentuele verhouding. Er zijn geen constante geldige verdelingen bij de
33 kandidaten; de programmatuur weigert daarvoor wel een nulbreed interval.

Vijf van de 33 kandidaten hebben in 2021–2025 hoogstens één positieve
bronkavel: **Scholekster, Wulp, Stormmeeuw, Tortelduif en Tapuit**. Wulp
heeft op de getelde bronkavels in dat venster geen positieve telling; de
positieve uitgangsindex voor het venster komt uit de bestaande aanvulling
van de modelroute. Dat is geen nieuwe waarneming. Deze vijf blijven
kandidaten voor validatie, met expliciete beoordeling van nulgrens en
imputatieafhankelijkheid. Volledige berekenbaarheid bewijst daar geen goede
intervaldekking of afwezigheid in heel Meijendel.

## Venstergevoeligheid

Dezelfde 33 voldoen bij drie, vijf en zeven jaar aan de rekenkundige
validatiepoort. Dezelfde twee blijven bij 49/50. De richting van de
uitgangsverandering wisselt echter bij zes soorten:

| Soort | Drie jaar | Vijf jaar | Zeven jaar |
|---|---:|---:|---:|
| Kuifeend | +74,91% | −30,40% | −57,27% |
| Witte Kwikstaart | −21,12% | −4,45% | +6,75% |
| Gekraagde Roodstaart | −0,57% | +19,45% | +40,91% |
| Grasmus | −4,40% | −7,38% | +0,98% |
| Fitis | +1,95% | −5,91% | −4,03% |
| Kneu | +3,24% | −20,46% | −25,29% |

Een interval voor de vooraf gekozen vijfjaarsmaat blijft voor die maat
betekenisvol, maar mag niet als een vensteronafhankelijke trendklasse
worden gepresenteerd. De drie varianten worden niet tot één 95%-interval
gemengd. Meer trekkingen lossen de keuze van venster of geografisch bereik
niet op. De eerdere vergelijking van 17 kernkavels met het totale netwerk
betreft verschillende kavelpopulaties en is geen eis van gelijke uitkomsten.

## Intervalroute aangepast en gecontroleerd

R/trim_endpoint_bootstrap.R biedt een aparte route voor de 2025-nettomaat.
De gedeelde oudere jaarpercentage- en productiecontracten zijn behouden.
De nieuwe route kan dezelfde uitvoersoort voor 50, 500 en 2.000 trekkingen
beoordelen; deze opdracht heeft alleen de bestaande 50 verwerkt.

- Kandidaat is de percentielmethode op de oorspronkelijke nettoschaal,
  0,025/0,975 en type 7. Er wordt geen log(nul) gebruikt.
- Iedere ontbrekende of ongeldige draw blokkeert de band; de volledige
  verdeling wordt niet vervangen door de eindige subset.
- Een constante verdeling krijgt geen schijnzeker nulbreed interval.
- Bij 50 zijn eventuele banden uitsluitend diagnostisch; bij 500 blijft
  de status validatie. Alle formele 95%-kolommen blijven leeg.
- Zelfs vanaf 2.000 volgt geen automatische publiceerbaarheid: dekking,
  nulgrens, uitval en grensstabiliteit blijven te beoordelen.
- BCa wordt niet geclaimd zonder de benodigde volledige clusterjackknife.
  De percentielroute is een expliciete kandidaat, geen onzichtbare fallback.
- Stabiliteit wordt in procentpunten nettoverandering getoetst: beide
  grensverschuivingen kleiner dan 0,10 procentpunt én 5% van de bandbreedte.

De nieuwe band moet dus niet worden verward met de min/max-spreiding,
een gevoeligheidsenvelop of een gevalideerd 95%-betrouwbaarheidsinterval.
De validatie met 500 kan de numerieke staarten en uitval beter onderzoeken;
zij bewijst op zichzelf geen 95%-dekking van de werkelijke vogelpopulatie.

## Advies over 500 en grenzen van deze taak

**Ga desgewenst naar een 500-validatie met alle 156 soorten in de uitvoer.**
Interpreteer daarvan de 33 complete soorten als kandidaten voor
intervalvalidatie; onderzoek bij Torenvalk en Witte Kwikstaart eerst of
bruguitval een verdedigbaar interval verhindert. De overige 121 blijven
zichtbaar met hun concrete blokkade. De vijf soorten met schaarse
venstersteun en de zes venstergevoelige soorten krijgen de benoemde
extra beoordeling. Dat is een validatie, geen automatische vrijgave.

Deze beoordeling gaat over de lange begin/eindverandering. Zij vervangt
geen jaarindex of afzonderlijke periodetrend en berekent daarvoor geen
nieuwe formele marges. Een ontbrekende lange uitkomst maakt bestaande
tellingen en wel schatbare afzonderlijke perioden niet ongeldig. Een
bootstrap geeft bovendien geen nieuwe positieve waarnemingen aan een
soort zonder steun in de bron.

Niet uitgevoerd: 500/2.000 nieuwe trekkingen, nieuwe model-/brugfits,
nieuwe bronexport, databasewijziging, 2026-invoer, cachebouw, hoofdindex-
vervanging of publicatie naar dashboard/VPS. De beoordeling en aanpassing
van de aparte intervaldiagnostiek zijn afgerond.

## Bestanden en reproductie

- [PER_SOORT.md](PER_SOORT.md): leesbaar overzicht van alle 156 soorten.
- [primary.csv](primary.csv): 156 primaire soortregels inclusief poorten,
  schaarse bronsteun, venstergevoeligheid en diagnostische band/status.
- [summary.csv](summary.csv): 468 soort-vensterbeoordelingen.
- [estimates.csv](estimates.csv): 23.868 soort-draw-vensterregels, inclusief
  468 oorspronkelijke bronuitkomsten en 23.400 bestaande getrokken uitkomsten.
- [coverage.csv](coverage.csv): 312 bronvensterregels met getelde en
  positief getelde kavels. Geen nieuwe database-inventarisatie.
- [manifest.json](manifest.json): bron-, criteria-, code- en afhankelijkheids-
  checksums en alle oorspronkelijke draw-identiteiten.

Reproductie: Rscript R/trim_endpoint_bootstrap.R REPO PILOTRUN UITVOER 50.
Voor een latere zelfstandige 500-run zijn een bijpassende runidentiteit en
500 complete oorspronkelijke batches nodig, niet het opnieuw tellen van
50 opgeslagen draws alsof het 500 zijn. Batches met verschillende
identiteiten worden door de bestaande merge geweigerd.

De reconstructie uit ongewijzigde periodeindices en opgeslagen brugfactoren
reproduceert alle 70 oude loghellingen (maximale afwijking 4,5×10⁻¹⁴) en de
vier eerdere baselinecurven (maximaal 1,3×10⁻¹¹), zonder een vogeltelmodel te
fitten. R/check_trim_endpoint_bootstrap.R test nulbegin/einde, vaste jaren,
ontbrekende/dubbele waarden, schaal, bruguitval, degeneratie, weigering van
conditionele banden, 50/500/2.000-status en nettoschaalstabiliteit.

## Verificatie

Onafhankelijke eindreview zonder Critical-, Important- of Minor-bevindingen.
Alle 23.868 uitkomsten en statusredenen opnieuw nagerekend, maximaal
CSV-afrondverschil 4,91×10⁻¹¹. Alle 50 echte batchtrekkingen, 468
samenvattingen, 312 bronvensterregels en poorten 33/2/121 bevestigd.
Criteria bytegelijk aan de voorafgaande commit; code- en afhankelijkheids-
checksums passen bij het manifest. De gerichte endpointcheck en bestaande
indexsamenvattingscheck zijn groen. Vier beschermde hoofd-CSV's behouden
hun checksum. Registertekst Markdown/Word inhoudelijk gelijk; alle 60
pagina's van de actuele v2-render zijn afzonderlijk visueel gecontroleerd
zonder opmaakdefecten. Geen nieuwe vogeltelmodellen of 500-run uitgevoerd.
