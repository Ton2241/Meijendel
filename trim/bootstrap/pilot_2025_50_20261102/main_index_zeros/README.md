# Beoordeling nuljaren in de hoofdindex per soort

**Uitvoering 3 november 2026:** de 45 betrokken periodetrends zijn inmiddels beveiligd; zie [uitvoering en resultaten](../../zero_policy_20261103/README.md). Onderstaande tekst beschrijft de beoordeling van 2 november.

De nulwaarnemingen en jaarindices blijven behouden. Het probleem zit in de
gekozen aanvullende samenvatting: een regressie door log(index) vereist
positieve jaarwaarden. Een echte nul kan daarin niet als eindig getal
meedoen. Dat maakt de nul niet tot een fout in de tellingen. Een nul betekent
geen positieve waarneming op de getelde kavels, geen bewezen afwezigheid in
heel Meijendel.

Deze beoordeling gebruikt de historische ontwikkelbron 1958–2025 met
156 soorten, dezelfde 50 getrokken kavelnetwerken en dezelfde vijfjaarsbrug
als de pilot. Er is geen andere bron, bridgefactor of bestaande
periodemodelconfiguratie gekozen. Er is geen nieuwe algemene bootstraprun
uitgevoerd en geen methode in de hoofdroute vervangen.

## Wat de nuljaren betekenen

Van de 70 soorten met een oorspronkelijke lange trend hebben 21 in minstens
één van de 50 trekkingen een geslaagd periodemodel maar een onbruikbare
logaritmische indexhelling. Door de volgorde van fouttoekenning staan niet
al die gevallen ook als primaire indexfout geregistreerd: een gelijktijdig
model- of brugprobleem kan voorgaan.

De primaire indexfout komt binnen deze 70 soorten 278 keer voor, verdeeld
over twintig soorten: 261 gevallen met nulindices, vijftien met nulindices
én ontbrekende modeljaren, en twee met alleen ontbrekende modeljaren. Die
laatste twee zijn Turkse Tortel, replicaties 44 en 47. Ontbrekende jaren
mogen niet als nul worden aangevuld. De 278 gevallen zijn herhalingen per
soort, geen aantal unieke soorten of jaren.

Bij Veldleeuwerik bevat de oorspronkelijke bron in 2015–2019 en 2021 nul
positieve tellingen op respectievelijk 21, 22, 23, 21, 21 en 22 getelde
kavels. De positieve oorspronkelijke jaarindex berust daar op aanvulling
voor niet-getelde kavels. Als die bijdrage in een trekking wegvalt, kan de
index werkelijk nul worden. Replicatie 1 heeft zo een nul in 2017; replicatie
2 in 2015–2019 en 2021. In beide gevallen is de vijfjaarsbrug berekenbaar.

## Aanvullende bevinding in de afzonderlijke periodetrends

Van de 228 geslaagde oorspronkelijke periodemodellen over 1958–2025
(100 vóór 1984 en 128 vanaf 1984) bevatten er 45 echte nuljaartotalen:
21 vóór 1984 en 24 vanaf 1984, voor samen veertig soorten. Alle 45 krijgen
in het huidige lokale trendcontract het etiket `formeel`.

In de werkelijk gebruikte `rtrim` 2.3.1-functie `overall()` gebeurt echter:
`log_tt[tt < 1e-6] <- 0`. Dat is bij de trendberekening rekenkundig hetzelfde
als deze totalen vervangen door één. Ook de daaropvolgende afleiding van
de variantie gebruikt die vervanging. Dit is geen bronwaarde en geen
inhoudelijk onderbouwde behandeling van een nuljaar.

Een gerichte rekenproef op Veldleeuwerik, periode 1984–2025, bevestigt de
consequentie. Bij replicatie 1 geeft `overall(imputed)` −5,6471% per jaar.
Wanneer dezelfde totalen uitsluitend van rekeneenheid veranderen
(maal tien, variantie maal honderd), wordt dat −6,0862%. Bij replicatie 2
verschuift −10,0974% naar −12,7090%. Een relatieve trend hoort niet van zo'n
eenhedenkeuze af te hangen. Vervanging van de nuljaartotalen door één
reproduceert in beide gevallen exact de oorspronkelijke `overall`-helling.
Dit zijn diagnostische schaalproeven, geen gewijzigde vogeltellingen.

Daarom geldt een aanvulling op het eerdere advies om de afzonderlijke
formele periodetrends primair te houden: **de 45 betrokken overall-
trenduitkomsten vragen herbeoordeling**. Hun tellingen, periodemodellen
en jaarindices zijn daarmee niet automatisch ongeldig. De overige
183 periodemodellen bevatten deze specifieke nuljaartotalen niet.
Er is in deze beoordeling geen status of cijfer in de canonieke uitvoer
gewijzigd.

## Vergelijking van mogelijke routes

1. **Nul door 0,5 of 1 vervangen, nuljaren weglaten of soorten uitsluiten:**
   afwijzen. Dit verandert de informatie of de soort-/jaarselectie. Alleen
   positieve trekkingen overhouden levert evenmin een volledig interval.
2. **Overal volledig modelmatige `fitted`-indices gebruiken:** geen
   automatische oplossing. Ze kunnen positief blijven wanneer de
   waargenomen-plus-aangevulde index nul is. Dat berust op sterkere
   modelaannamen; bij het huidige model 2 zonder breekpunten gaat het om één
   rechte lijn op logschaal over een hele deelperiode. Meer berekenbaarheid
   bewijst niet dat die vorm de gegevens goed beschrijft. Alleen als
   expliciete gevoeligheidsvariant beoordelen.
3. **Een samenvatting gebruiken die nulindices kan meenemen:** een
   zinvolle kandidaat, mits duidelijk is dat de trendmaat verandert. De
   verkenning hieronder past een quasi-Poisson-regressie met loglink toe op
   de gekoppelde jaarindices, inclusief nul. Er wordt dus niet log(nul)
   uitgerekend. Dit is een exponentiële samenvatting van een indexreeks,
   geen Poisson-likelihood voor de oorspronkelijke vogeltellingen.
   De GLM-standaardfouten worden niet gebruikt als onzekerheidsmarge.
4. **Een langetermijntrend rechtstreeks uit een telmodel schatten:**
   inhoudelijk te verkiezen boven een onbeoordeelde noodgreep in de
   eindindex, wanneer één trendpercentage gewenst is. Daarvoor horen
   teldekking, kavelverschillen, methodebrug en een passende tijdsvorm
   expliciet bij de modelkeuze. Ook een telmodel kan onvoldoende informatie
   of een ongeschikte tijdsvorm hebben. Dit is advies voor een gerichte
   vergelijking, geen al gekozen vervanger van de huidige route.

De kleine verkenning onder optie 3 gebruikt alle bestaande trekkingen,
periodemodellen, ankers en brugfactoren. Binnen de 70 soorten met een
oorspronkelijke lange trend stijgt het aantal soorten met 50/50 berekenbare
uitkomsten van 48 naar 60; met minstens 48/50 van 52 naar 64.

| Soort | Log-indexhelling berekenbaar | Nulvriendelijke kandidaat berekenbaar | Mediaan gepaard verschil in procentpunten per jaar |
|---|---:|---:|---:|
| Veldleeuwerik | 31/50 | 50/50 | +1,77 |
| Witte Kwikstaart | 49/50 | 49/50 | −0,04 |
| Torenvalk | 10/50 | 49/50 | +3,66 |
| Matkop | 17/50 | 50/50 | +3,50 |
| Tapuit | 29/50 | 50/50 | +14,64 |

Het gepaarde verschil gebruikt alleen dezelfde trekkingen waarin beide
hellingen berekenbaar zijn. De soms grote verschuiving bewijst dat dit
geen technische reparatie met dezelfde betekenis is. De mediaan van de
oude en nieuwe eindige hellingen staat ook in `per_species.csv`, maar die
medianen kunnen op verschillende aantallen trekkingen berusten en zijn
daarom niet als gepaarde vergelijking gebruikt.

## Advies en kleinste vervolgstap

Behoud echte nullen in de tellingen en in de gewone jaarindex. Houd
ontbrekende cellen en ontbrekende modeljaren apart. Onzekerheidsmarges
voor een jaarindex worden op de oorspronkelijke indexschaal beoordeeld,
waar een grens van nul mogelijk is. Een getelde nul bewijst geen afwezigheid
buiten de getelde kavels en een nulbreedte-interval uit uitsluitend
nuluitkomsten bewijst geen perfecte zekerheid.

Beveilig eerst de beoordeling van de 45 overall-trenduitkomsten tegen de
hier aangetoonde impliciete vervanging door één. Gebruik voor deze
uitkomsten voorlopig geen onbeoordeeld formeel trendetiket. Dat vraagt een
expliciete, afzonderlijke uitvoeringsstap; die is hier niet uitgevoerd.

Vergelijk vervolgens een telmodel en de nulvriendelijke indexsamenvatting
inhoudelijk voor Veldleeuwerik, Torenvalk en Tapuit, naast Koolmees als goed meetbare
controlesoort. Beoordeel de aansluiting bij hun volledige jaarverloop en
hoe sterk de uitkomst van de modelvorm afhangt. De bestaande trekkingen
kunnen opnieuw worden gebruikt. Het doel is kiezen wat de lange trend
inhoudelijk samenvat; uitsluitend uitvalpercentages vergelijken is nu niet
voldoende. Neem daarna pas een methodebesluit en start een grotere
bootstrap. Voor een soort die geen verdedigbare lange helling heeft,
blijven de waarnemingen en jaarindices zichtbaar.

Deze beoordeling gaat over soortindices. Er zijn geen groepsindicatoren
berekend; een oplossing voor de soorthelling is geen automatisch besluit
over nulwaarden in een meetkundig gemiddelde van meerdere soorten.

## Herkomst en controle

Reproduceerbaar met `R/audit_trim_main_index_zeros.R REPO PILOTRUN UITVOER`.
Het script controleert de contextchecksum, gebruikt exact de 50 bestaande
replicatie-ID's en controleert dat nul→één de twee geteste `overall`-
hellingen reproduceert. De context bevat alleen 1958–2025. Brongegevens,
SQL-cache en analyse-/publicatieroutes zijn niet gewijzigd.

`original.csv` geeft alle 228 oorspronkelijke geslaagde periodemodellen,
met nuljaren en hun huidige trendstatus. `per_species.csv` bevat alle
156 soorten en de verkennende samenvattingsvergelijking.
`overall_scale_checks.csv`, `skylark_source_zeros.csv` en
`skylark_index_cases.csv` leggen de gerichte controles vast.
De individuele foutclassificaties staan uitsluitend in de genegeerde lokale
uitvoermap; `manifest.json` bevat aantallen, bron- en code-identiteit.

Geraadpleegd: de geïnstalleerde code van rtrim 2.3.1;
[rtrim FAQ, met name vragen 8, 29–33 en 39–41](https://cran.r-universe.dev/rtrim/doc/FAQ.html);
[broncode van overall](https://rdrr.io/cran/rtrim/src/R/trim_overall.R).
Onafhankelijke beoordeling bevestigt de 228/45/40-aantallen, de
nulconventie, de foutclassificatie en het verschil in trendmaat. Er is geen
nieuwe productiemethode vastgesteld.
