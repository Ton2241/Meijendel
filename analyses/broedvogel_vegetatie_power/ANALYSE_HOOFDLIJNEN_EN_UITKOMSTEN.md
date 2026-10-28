# Analyse op hoofdlijnen en uitkomsten

**Stand:** 26 oktober 2026

**Status:** analysematrix, tellergevoeligheid, vegetatiestappen,
AHN-structuurproef, luchtfotoproef en de aanvullende modellen met stikstof en
CBS-landgebruik uitgevoerd; geen van de gerichte habitat- of
omgevingsmodellen voldoet aan de vooraf vastgelegde poort naar een formele
poweranalyse

**Beoogd eindproduct:** artikel voor *Holland's Duinen*

## Doel

De lange broedvogelreeks laat zien hoe aantallen en soortensamenstelling in
Meijendel zijn veranderd. Deze analyse stelt een volgende vraag: in hoeverre
hangen die veranderingen samen met vegetatie en andere biotische en abiotische
omstandigheden, hoeveel daarvan wordt beïnvloed door verschillen tussen
tellers en hoe gevoelig is de meetopzet voor zulke relaties en veranderingen?

Het doel is niet zoveel mogelijk variabelen in één model te plaatsen. We bouwen
een controleerbare reeks modellen. Eerst het waarnemingsproces. Daarna de
ecologische verklaringen. Vervolgens toetsen we of deze buiten de gebruikte
gegevens blijven voorspellen. Pas daarna volgt de poweranalyse.

Een statistische samenhang is niet automatisch een een-op-een-oorzaak-gevolg-
relatie. Vegetatie, voedsel, water, bodem, weer, beheer, begrazing, predatie,
verstuiving en rust kunnen tegelijk werken en elkaar versterken of verzwakken.

## Wat we nu weten

De meetreeks kan niet worden gelezen alsof ieder verschil in territoriumaantal
uitsluitend een verschil in vogelstand is. Ook nadat soort, tijd, plot,
oppervlakte, bron, jaar en plotjaar zijn verwerkt, blijven systematische
verschillen die samenhangen met teller/tellerteam over. Het waarnemingsproces
moet daarom in alle
volgende verklarende modellen worden meegenomen.

Dat gebeurt niet door bestaande territoriumaantallen te veranderen. Het model
schat voor ieder teller/tellerteam een afwijking ten opzichte van het gemiddelde
houdt daarnaast afzonderlijk rekening met eerder geregistreerde ervaring in
dezelfde plot en elders in Meijendel. De tellerfase bepaalt dus de vorm van de
correctie, niet één universele correctiefactor.

Over 1958–2025 is geen gemiddeld leereffect binnen dezelfde plot aangetoond.
Er is wel een positief verband met eerder geregistreerde ervaring in andere
plots. Dat kan op algemene tellerervaring wijzen, maar is geen bewijs dat een
beginner een bepaald percentage vogels mist. Daarvoor ontbreken betrouwbare
tellerkoppelingen per afzonderlijk bezoek en volledig vastgelegde ervaring van
vóór de Meijendelregistratie.

De correctie verandert de mediane soorttrend weinig, maar bij een aanmerkelijke
groep soorten wel. Bovendien neemt de berekende onzekerheid toe. Dat is geen
verlies van kwaliteit: het voorkomt dat verschillen tussen tellers ten
onrechte volledig als veranderingen in de vogelstand of als ecologische
relatie worden geïnterpreteerd.

## Onderzoeksvragen

1. Hoe verandert de broedvogelgemeenschap door de tijd en tussen plots?
2. Hoeveel van die verschillen hangt samen met de gemeten PQ-vegetatie?
3. Voegt PQ-vegetatie voorspellende informatie toe boven tijd, plot,
   oppervlakte, methode, telinspanning, teller en weer?
4. Reageren functionele, habitatgebonden en andere ecologische vogelgroepen
   verschillend?
5. Verandert de functionele samenstelling van de gemeenschap, bijvoorbeeld het
   aandeel grondbroeders, holenbroeders, insecteneters of
   langeafstandstrekkers?
6. Hoeveel extra voorspellende informatie leveren stikstof, landgebruik en
   ruimtelijke kenmerken?
7. Welke relaties of veranderingen konden de historische gegevens aantonen en
   hoeveel toekomstige meetjaren zijn nodig om vooraf gekozen veranderingen
   betrouwbaar te detecteren?

## Gegevensbasis bij aanvang

De stand hieronder is een startmoment, geen vast eindtotaal. Iedere formele
modeluitvoering herhaalt de tellingen uit de levende database en legt de
uitkomst in een uitvoermanifest vast.

### Broedvogels

De standaard Natura 2000-selectie uit `territoria` bevat op 9 oktober 2026
151.583 bronregels in 52 plots en 2.107 getelde plotjaren uit 1958–2025. Binnen
deze selectie zijn 156 soorten ten minste eenmaal met een positief territorium
vastgesteld. M66 en M91 blijven buiten deze selectie.

De analyse gebruikt de centrale territoriumpoort. Letterlijke SOVON-nullen uit
1984–2025 blijven nul; lege SOVON-cellen blijven `NA`; formeel afgekeurde
SOVON-plotjaren leveren geen SOVON-analysewaarde. Voor geldige
jaarverslag-plotjaren geldt de afzonderlijk vastgelegde regel voor afgeleide
jaarverslagnullen. De bron en nulstatus blijven per analysewaarde herleidbaar.

### PQ-vegetatie

De provinciale PQ-verzameling omvat 254 PQ's, 2.007 vegetatieopnamen en 53.122
taxonregels uit 1981–2025. Na koppeling aan de standaard vogelplots zijn 501
PQ-plotjaren in 35 plots beschikbaar. De bruto overlap met getelde
vogelplotjaren bedraagt 407 combinaties in hetzelfde jaar, 392 bij één jaar
vertraging, 372 bij twee jaar en 350 bij drie jaar.

De provinciale `pq_*`-reeks is leidend. NDFF-PQ is uitsluitend een secundaire
controlebron en telt niet zelfstandig mee. De velden voor milieu-indicatie en
afwijkende bodemcodes worden pas gebruikt nadat hun betekenis en kwaliteit uit
de bronmetadata zijn vastgesteld.

### Overige verklarende lagen

- `weer` en de genormaliseerde view `weer_analyse` bevatten 24.837 dagrecords
  van 1 januari 1958 tot en met 31 december 2025.
- `plot_jaar_stikstof` bevat 1.027 plotjaren in 55 plots uit 2005–2023.
- `plot_jaar_landgebruik` bevat 918 klasseregels voor 275 plotjaren in 55
  plots uit 1996–2022. Dit zijn kaartmomenten, geen jaarlijkse metingen.
- `plot_jaar_habitat` bevat 384 habitatregels voor 55 plots, uitsluitend voor
  2014.
- `plot_jaar_ahn_dtm` bevat 55 plotregels voor 2025.
- `plot_jaar_infra` bevat 220 waarden voor 55 plots, uitsluitend voor 2024.
- `plot_jaar_toegankelijkheid` bevat 55 plotregels voor 2024.
- `plot_jaar_maatregel` bevat 144 registraties in 16 plots uit 1991–1999,
  uitsluitend begrazing. Dit is geen gebiedsdekkende beheerreeks.

Deze aantallen beschrijven de volledige brontabellen. Bij modelbouw wordt
opnieuw de standaard Natura 2000-scope toegepast, zodat records voor M66 en
M91 niet stilzwijgend in de analyse terechtkomen.

Habitat, hoogte, infrastructuur en toegankelijkheid kunnen voorlopig alleen
blijvende ruimtelijke verschillen tussen plots helpen verklaren. Met één
peiljaar kunnen zij geen verandering binnen een plot verklaren.

De aantallen en bronbeperkingen in deze startstand zijn ontleend aan de levende
database op 9 oktober 2026 en getoetst aan
[`docs/MEIJENDEL_BRONREGISTER.md`](../../docs/MEIJENDEL_BRONREGISTER.md),
[`DECISIONS.md`](../../DECISIONS.md) en de selectie- en nulregels in
[`R/meijendel_cache_contract.R`](../../R/meijendel_cache_contract.R).

## Uitkomsten die worden onderzocht

### Soorten

De primaire respons is het territoriumaantal per soort, plot en jaar. Soorten
delen in een hiërarchisch model informatie, maar mogen verschillend reageren.
Soortspecifieke uitkomsten worden alleen afzonderlijk gepubliceerd wanneer de
gegevens daarvoor voldoende zijn.

### Gehele gemeenschap

We onderzoeken ten minste soortensamenstelling, soortenrijkdom en totale
territoriumdichtheid. Een multivariate gemeenschapsuitkomst en een opgetelde
dichtheid beantwoorden verschillende vragen en blijven daarom gescheiden.

### Functionele groepen

De levende database bevat zes goedgekeurde functionele groepen. Binnen de 156
positief vastgestelde soorten uit de standaardscope zijn bij aanvang gekoppeld:

| Groep | Primair | Secundair | Geselecteerd | Gewogen omvang |
|---|---:|---:|---:|---:|
| Bodemfoeragerende insecteneters | 35 | 40 | 75 | 55,0 |
| Grondbroeders | 62 | 7 | 69 | 65,5 |
| Holenbroeders | 38 | 1 | 39 | 38,5 |
| Langeafstandstrekkers | 42 | 4 | 46 | 44,0 |
| Luchtfoerageerders | 8 | 7 | 15 | 11,5 |
| Zaadeters | 28 | 33 | 61 | 44,5 |

We rapporteren een strikte variant met primaire leden en een inclusieve of
gewogen variant met secundaire leden. Vooral de kleinere groep
luchtfoerageerders vraagt een gevoeligheidsanalyse.

### Habitat- en ecologische groepen

De database bevat 51 deels geneste EVG-landschapsgroepen. De hoofdanalyse
begint met acht brede groepen: water-, riet-, pionier-, open-heide-, weide-,
struweel-, bosrand- en bosvogels. Kleinere groepen worden alleen vooraf en op
ecologische gronden gekozen. We zoeken dus niet achteraf tussen 51 uitkomsten
naar toevallige significantie.

Daarnaast zijn 72 van de 156 positief vastgestelde soorten aan acht Natura
2000-habitattypen gekoppeld. Hiervoor worden twee vooraf vastgelegde varianten
gebruikt: alleen sterke bindingen en sterke plus matige bindingen.

Soorten kunnen in verschillende groepen voorkomen. Groepsuitkomsten zijn dus
niet onafhankelijk en worden niet behandeld als 51 losse, onderling
vergelijkbare toetsen.

### Continue functionele kenmerken

De database bevat 23 goedgekeurde vogelkenmerken. Zestien daarvan zijn bij
aanvang voor alle 156 positief vastgestelde soorten gevuld. Naast vaste groepen
berekenen we daarom per plotjaar onder meer het gewogen aandeel
grondbroeders, holenbroeders, insecteneters, zaadeters en
langeafstandstrekkers en, waar verantwoord, de gemiddelde nesthoogte en wijze
van foerageren.

Deze continue kenmerken benutten verschillen tussen soorten zonder voor ieder
kenmerk een harde groepsgrens te moeten kiezen.

## Modelopbouw

### 1. Reproduceerbare analysematrix

De soort–plot–jaar-matrix wordt rechtstreeks uit de levende database gebouwd.
De analyse neemt de centrale Natura 2000-scope, bronstatus, nulregels en
formele afkeur over. Iedere waarde behoudt bron en nulstatus. Een groepswaarde
wordt alleen berekend wanneer voor alle samenstellende soorten een geldige
analysewaarde beschikbaar is; een gedeeltelijke som blijft `NA`.

Deze stap is op 9 oktober 2026 uitgevoerd. De standaardmatrix bevat 328.692
soort–plot–jaarcellen: 156 soorten maal 2.107 werkelijk in `territoria`
aanwezige plotjaren in 52 Natura 2000-plots, over 1958–2025. De 123
plotjaarcombinaties die alleen in `plot_jaar_teller` staan, creëren nadrukkelijk
geen analysejaar.

Van de 328.692 cellen hebben 68.504 een positief territoriumaantal. Er zijn
142.802 geldige nullen: 76.686 letterlijk door de bron geleverde nullen en
66.116 volgens de vastgelegde jaarverslagregel afgeleide nullen. Voor 117.120
cellen ontbreekt een soortregel en 266 cellen behouden de status
`formeel_afgekeurd`; deze 117.386 cellen krijgen geen modelwaarde. De vijf
M35-plotjaren met een afgekeurde SOVON-status bevatten daarnaast zelfstandige
geldige jaarverslag- of meeuwenliteratuurwaarden. Die blijven volgens de
brongebonden regel bruikbaar en herkenbaar.

Voor 2.007 van de 2.107 territorium-plotjaren is minstens één teller
geregistreerd; voor 100 niet. M62/2016, de afzonderlijke roofvogeltelling, is
voor de algemene vogelmatrix als bronwaarde behouden. Bij de volgende stap,
de analyse van teller en tellerervaring, wordt deze combinatie overeenkomstig
het bestaande besluit uitgesloten. Dan resteren 99 plotjaren zonder
tellerregistratie.

De volledige matrix staat lokaal, buiten Git, in de uitvoermap
`resultaten/runs/`. De compacte actuele samenvatting en het controlemanifest
staan in `resultaten/analysematrix_laatste_samenvatting.csv` en
`resultaten/analysematrix_laatste_manifest.json`.

### 2. Waarnemingsmodel

De formele uitvoering gebruikt 203.628 geldige soort–plot–jaarrijen uit 2.007
plotjaren met bekend teller/tellerteam, voor 156 soorten en
de periode 1958–2025. M62/2016 en 99 plotjaren zonder tellerregistratie zijn
niet in deze primaire tellervergelijking opgenomen. Binnen iedere vergelijking
zijn exact dezelfde responsrijen gebruikt. Alle achttien gezamenlijke modellen
slaagden zonder convergentiewaarschuwing.

Het model onderscheidt drie zaken. Eerst de vogelontwikkeling die samenhangt
met soort, tijd en plot. Vervolgens de blijvende afwijking van teller/tellerteam
ten opzichte van het gemiddelde. Ten slotte twee vormen van ervaring:
eerdere geregistreerde teljaren in dezelfde plot en eerdere geregistreerde
teljaren in andere Meijendelplots. Beide ervaringsvariabelen zijn doorlopend;
er bestaat dus geen kunstmatige grens tussen “onervaren” en “ervaren”.

De geschatte standaardafwijking die samenhangt met teller/tellerteam bedraagt op
logschaal 0,382, ofwel een factor 1,47. Als het model voor een gemiddeld
teller/tellerteam tien
territoria verwacht, ligt één standaardafwijking naar beneden op ongeveer 6,8
en één standaardafwijking naar boven op ongeveer 14,7. Dit maakt de omvang van
de spreiding concreet. Het is geen ranglijst van tellers en ook geen bewijs dat
een laag uitkomend teller/tellerteam 32% van de vogels heeft gemist of een hoog
uitkomend teller/tellerteam 47% te veel heeft geteld. Teller/tellerteam kan
tevens verschillen in inzet, toedeling, omstandigheden en niet-gemeten
kenmerken.

Voor ervaring in dezelfde plot was het gemiddelde effect 0,008 per
gestandaardiseerde eenheid, met een standaardfout van 0,018. Dat ligt zo dicht
bij nul dat de lange reeks geen algemeen leereffect binnen dezelfde plot
aantoont. Voor ervaring elders was het effect 0,066 met een standaardfout van
0,017. Omgerekend waren de verwachte aantallen na één, drie en vijf eerder
geregistreerde teljaren elders gemiddeld 4,2%, 8,6% en 11,2% hoger dan bij nul
eerdere jaren. De analyse met uitsluitend 1.804 één-teller-plotjaren gaf
hetzelfde hoofdpatroon. Het resultaat wordt dus niet gedragen door de manier
waarop ervaring binnen tellerteams is samengevat.

De afzonderlijke analyse van 120.731 soort–plot–jaarrijen met bekende
bezoekinspanning over 1984–2025 liet het positieve verband met ervaring elders
eveneens zien. In deze kortere periode werd ook voor ervaring binnen dezelfde
plot een positief verband geschat. Omdat tegelijk periode, beschikbare soorten
en gegevenssamenstelling veranderen, is dit geen zelfstandig bewijs voor een
leereffect.

Voor alle 121 voldoende gedekte soorten leverde het hoofdmodel een bruikbare
uitkomst. Door teller/tellerteam en ervaring toe te voegen veranderde de
jaarlijkse
trend mediaan met −0,033 procentpunt; de mediane absolute verschuiving was
0,545 procentpunt. Bij 67 soorten bedroeg de absolute verandering meer dan 0,5
procentpunt en bij 31 meer dan één procentpunt per jaar. De mediane breedte van
het onzekerheidsinterval nam met 11% toe. Tellerinvloed is dus gemiddeld geen
grote verschuiving van de trend, maar kan voor afzonderlijke soorten wel
inhoudelijk belangrijk zijn. De bredere intervallen geven bovendien eerlijker
weer welk deel van de variatie niet zonder meer aan de vogelstand kan worden
toegeschreven.

De GEE was een tweede berekeningswijze, niet het beslissende model. Zij gaf
voor 105 van de 121 soorten een technisch geldig resultaat. Bij acht soorten
werd de vaste tijdslimiet bereikt en bij acht leverde de methode geen
wiskundig betrouwbare oplossing. Dat is geen oordeel over die soorten: hun
hiërarchische hoofdmodel slaagde wel. Bij de 105 geldige GEE-uitkomsten wees
het ervaringseffect in dezelfde plot voor 78,1% en elders voor 80,0% in
dezelfde richting als in het hoofdmodel. Het algemene patroon is daarmee
redelijk robuust, maar soortspecifieke ervaringseffecten zijn niet overal
methode-onafhankelijk.

### Correctie in de volgende modellen

De territoriumaantallen zelf worden niet aangepast. Ieder volgend primair
ecologisch model bevat een random intercept voor teller/tellerteam en de twee
variabelen `log(1 + eerdere geregistreerde jaren in dezelfde plot)` en
`log(1 + eerdere geregistreerde jaren elders)`. Soorten mogen van het
gemiddelde ervaringseffect afwijken. De effecten worden opnieuw geschat binnen
de exacte plots, jaren en soorten van dat model; de factor 1,47 en de
percentages 4,2%, 8,6% en 11,2% worden niet als vaste correctie opgelegd.

Plotjaren zonder bekende teller kunnen geen teamcorrectie krijgen. Zij blijven
daarom buiten de primaire, voor teller gecorrigeerde analyse en worden alleen
in een afzonderlijke gevoeligheidsanalyse gebruikt. Een vergelijking met
hetzelfde model zonder teller blijft zinvol om zichtbaar te maken hoeveel de
ecologische relatie en haar onzekerheid door deze correctie veranderen. Zij is
niet bedoeld om teller achteraf alsnog uit het model te selecteren.

### 3. Vegetatiemodel

PQ-kenmerken worden gesplitst in:

- het gemiddelde verschil tussen plots;
- de afwijking in een bepaald jaar binnen dezelfde plot.

Zo blijft het verschil zichtbaar tussen “bosrijke plots hebben andere vogels”
en “de vogels veranderen nadat de vegetatie binnen dezelfde plot verandert”.
Vertragingen worden vooraf beperkt tot hetzelfde jaar, één jaar en, indien
ecologisch verdedigbaar, twee of drie jaar.

Deze stap is uitgevoerd op 37.140 geldige soort–plot–jaarrijen uit 406
vogelplotjaren in 35 plots, voor 154 soorten en 1989–2025. Muskuseend heeft in
deze overlap geen geldige modelrij. Aalscholver is alleen uit het PQ-model
verwijderd, omdat de nestelplaats van deze kolonievogel niet door de gebruikte
PQ-maten wordt gemeten. De technische
modelterm `tellerteam_factor` kan zowel één teller als een tellerteam van twee
of meer tellers aanduiden. Teller/tellerteam en beide ervaringsmaten zijn in
ieder model opnieuw geschat. Bij vertraging één, twee en drie jaar bleven
respectievelijk 390, 372 en 349 vogelplotjaren beschikbaar.

De drie PQ-maten geven op de volledige gegevens een duidelijk gemiddeld
verschil tussen plots. Bij één standaardafwijking hogere
plantensoortenrijkdom, Shannon of totale bedekking is het verwachte
territoriumaantal per soort gemiddeld een factor 0,80, 0,88 en 0,85 lager.
Dat mag niet worden gelezen als “meer planten veroorzaken minder vogels”. De
plots verschillen ook in habitat, ligging en andere niet volledig gemeten
omstandigheden, en soorten reageren onderling verschillend.

De voor de veranderingsvraag beslissende binnen-plotreacties liggen met
factoren 0,99, 0,98 en 1,01 rond één en zijn niet duidelijk van geen gemiddeld
effect te onderscheiden. Ook bij één tot drie jaar vertraging ontstaat geen
consistent binnen-plotverband. Met deze drie brede PQ-maten is geen
bestendige extra voorspellende waarde over zowel nieuwe plots als latere jaren
aangetoond. Dit betekent niet dat de veranderingen in de PQ's te gering waren;
dat is zonder een afzonderlijke poweranalyse niet vastgesteld. De maten kunnen
ook ecologisch te grof zijn, tegengestelde soortreacties middelen of relevante
structuurkenmerken niet meten.

### Volledige PQ-samenstelling en IPI

Deze vervolgstap gebruikt de 53.122 taxonregels uit 2.007 provinciale
PQ-opnamen over 1981–2025. Daarvan zijn 1.314 opnamen, 501 plotjaren en 642
centrale taxa aan 35 actieve vogelplots gekoppeld. De gelijktijdige
vogelvergelijking bevat 37.140 geldige soort–plot–jaarrijen, 406
vogelplotjaren, 35 plots en 154 soorten over 1989–2025. Dezelfde bron-, nul-,
scope- en tellercorrecties zijn gebruikt als in het brede PQ-model;
Aalscholver blijft alleen uit de vogel–vegetatiemodellen verwijderd.

De Hellinger-getransformeerde taxonsamenstelling is samengevat in drie
compositieassen. Zij verklaren respectievelijk 12,1%, 9,1% en 6,6%, samen
27,8%, van de variatie. De eerste as onderscheidt vooral houtige en ruigere
vegetatie met onder meer zomereik, eenstijlige meidoorn en grote brandnetel van
open droog duin met mossen, fijn schapengras en geel walstro. De tweede as
onderscheidt vooral natte vegetatie met riet, watermunt, kruipwilg en zeggen van
houtige vegetatie. Het teken van een compositieas is op zichzelf willekeurig;
de taxa aan beide uiteinden geven haar inhoud.

In het volledige model ligt geen van de drie gemiddelde veranderingen binnen
dezelfde plot duidelijk van nul af. De verwachte verhoudingen per
standaardafwijking zijn 0,987, 0,991 en 0,992. Toch verbetert de compositie de
ruimtelijke logscore gemiddeld met 0,093 en is zij in vier van vijf
achtergehouden plotblokken beter. Voor latere jaren is de logscore in beide
tijdsblokken juist iets slechter. De volledige taxonsamenstelling beschrijft
daarmee verschillen tussen plots beter, maar voorspelt met deze drie assen nog
geen verandering door de tijd.

IPI is samengebracht tot open duin, nat/water, struweel en bos. Dit zijn
aandelen van de bemonsterde PQ-opnamen, geen oppervlakteaandelen van de
vogelplot. Ook hier zijn de gemiddelde binnen-ploteffecten vrijwel nul. De
ruimtelijke logscore verbetert gemiddeld met 0,036 en in drie van vier geldige
plotblokken; één van vijf modellen had een niet-positief-definiete Hessiaan.
Beide tijdsblokken worden iets slechter. IPI levert dus een bescheiden
ruimtelijke habitatbeschrijving, geen aangetoonde temporele voorspelling.

De vertragingen van één tot en met drie jaar zijn alleen qua dekking
vastgelegd: 390, 372 en 349 vogelplotjaren. Omdat het gelijktijdige model geen
tijdswinst oplevert, zijn daarvoor niet alsnog 42 kostbare lag-validatiemodellen
geschat.

### Onafhankelijke landbedekking 2001 en 2022

Online Resource 2 van Schmidt-Tauscher, Häger en Van der Hagen bevat zeven
landbedekkingsklassen voor 25 BMP-plots en de jaren 2001 en 2022. De
oppervlakten zijn omgerekend naar aandelen binnen het geclassificeerde deel.
Bij M71 is in beide jaren 47,89 van de opgegeven 48,46 hectare geclassificeerd;
de ontbrekende 0,57 hectare, 1,2%, blijft zichtbaar en is niet aan een klasse
toegerekend. M17 heeft in de actuele vogelmatrix geen territoriumplotjaar.
Daardoor gebruiken de groepsmodellen maximaal 24 plots. De vogeldata zijn
zonder jaarlijkse interpolatie samengevat in de vensters 1997–2001 en
2018–2022.

De volledige modellen slagen voor water-, riet- en struweelvogels. Het model
met landbedekking is numeriek ongeldig voor pionier/open-duinvogels en
boomgroepvogels; bij bosvogels is het basismodel ongeldig. Hun coëfficiënten
kunnen daarom niet als geldige modelvergelijking worden gelezen. Van de vijftig
geblokkeerde vergelijkingen voor compositie, IPI en landbedekking slagen er 31
en hebben er 19 een niet-positief-definiete Hessiaan of een andere expliciet
vastgelegde convergentiewaarschuwing.

Wateroppervlak levert het duidelijkste ruimtelijke landbedekkingssignaal: de
logscore is in alle vijf plotblokken beter, hoewel MAE en RMSE slechts in drie
blokken verbeteren. De binnen-plotreactie is niet duidelijk. Bij rietvogels
zijn drie van vijf ruimtelijke blokken geldig; twee daarvan verbeteren. Het
volledige model schat bij meer riet binnen dezelfde plot een verhouding van
0,884 per standaardafwijking. Dat onverwachte negatieve verband is met slechts
twee kaartmomenten, gemengde voorspelscores en één geldig tijdsblok geen bewijs
dat uitbreiding van riet rietvogels doet afnemen. Voor struweelvogels zijn vier
van vijf ruimtelijke logscores iets beter, maar één duidelijk slechter blok
maakt het gemiddelde negatief en het tijdsmodel is ongeldig. Voor
open-duin-, boomgroep- en bosvogels is de numerieke dekking te instabiel voor
een stevige uitspraak.

De landbedekking bevestigt dus dat een ecologisch specifieke kaartlaag nuttige
ruimtelijke informatie kan bevatten. Zij levert nog geen algemeen geldig model
van vogelverandering. Twee momentopnamen meten bovendien geen verticale
gelaagdheid, vegetatiehoogte, voedsel of nestgelegenheid.

Op 19 oktober 2026 zijn ook de oorspronkelijke classificatierasters en de
grenzen van de 25 bronplots ontvangen. De twee rasters bevatten 369.710
geldige pixels voor 2001 en 369.662 voor 2022. Alle pixels konden aan een van
de zeven gepubliceerde klassen en een bronplot worden toegewezen. Over 350
plot–klasse–jaarvergelijkingen wijkt de opnieuw berekende oppervlakte
gemiddeld 0,0032 hectare en maximaal 0,030 hectare af van de supplementtabel.
De bron is daarmee ruimtelijk herleidbaar, niet alleen als oppervlaktetabel.

Per plot en klasse zijn nu ook aantal en dichtheid van aaneengesloten vlakken,
aandeel van het grootste vlak en randdichtheid berekend. Per plot zijn
klassenrijkdom, Shannon-diversiteit en totale interne randdichtheid bepaald.
Tussen 2001 en 2022 stijgt de mediane interne randdichtheid over de 25 plots
met 49,0 meter per hectare en de mediane Shannon-diversiteit met 0,049; de
mediane klassenrijkdom verandert niet. Dat zijn beschrijvende veranderingen
in het kaartpatroon. Met twee meetmomenten bewijzen zij geen ecologische
oorzaak en leveren zij nog geen tijdsvalidatie voor vogelverandering.

### Gerichte habitatmodellen met AHN en landbedekking

De hoogteproef is op 12 oktober 2026 opnieuw opgebouwd met AHN2 uit 2008,
AHN3 uit 2014, AHN4 uit 2020 en AHN5 uit 2022–2023. Voor 55 vogelplots zijn
220 plot–cyclusregels afgeleid uit de officiële DSM- en DTM-tegels. Alle vier
cycli zijn eerst met dezelfde rekenregel gemiddeld naar exact hetzelfde
tweemetergrid; pas daarna is DSM minus DTM berekend. Per plot zijn aandelen
open terrein, lage vegetatie, struweel en bomen plus hoogteverdeling en
randlengte bepaald. Hoogten boven 45 meter zijn als niet-vegetatieve uitbijter
uitgesloten. Alle controles op vier cycli, 55 plots per cyclus, identieke
resolutie, unieke plot–cycluscombinaties en optellende hoogteklassen slagen.

De harmonisatie wijzigt de eerdere lezing van AHN3 en AHN4. Over 55 plots
neemt open terrein tussen 2014 en 2020 gemiddeld met 2,94 procentpunt toe, niet
met ongeveer elf procentpunt zoals uit de eerder gemengde services volgde. De
gemiddelde boomfractie neemt tussen 2008 en 2014 met 5,27 procentpunt toe,
tussen 2014 en 2020 met 0,55 en tussen 2020 en 2023 met 0,63 procentpunt. Dit
zijn beschrijvende verschillen uit 220 afgeleide structuurregels, geen
causale vegetatietrends.

De gerichte modellen combineren deze AHN-structuur of de landbedekking van
2001 en 2022 met vooraf passende vogelgroepen. Zij corrigeren voor tijd,
oppervlakte, bron, bezoekduur, wel of niet geregistreerde ongunstige
bezoeksomstandigheden, teller/tellerteam, geregistreerde ervaring en vier
weermaten: wintertemperatuur, vorstdagen, voorjaarstemperatuur en
voorjaarsneerslag. Aalscholver blijft uitgesloten. Afhankelijk van groep en
bron bevatten de tien modellen 1.741–10.340 soort–plot–jaarrijen, 15–36
soorten en 22–52 plots. De zes landbedekkingsmodellen gebruiken tien
vogeljaren. De vier AHN-modellen gebruiken elf vogeljaren: 2009–2011,
2014–2016, 2021–2022 en 2023–2025. Het jaar 2023 wordt daarbij uitsluitend
aan het recentere AHN5-moment gekoppeld.

Van de twintig volledige basis- en habitatmodellen zijn twaalf numeriek geldig
en acht ongeldig. Van de vijftig ruimtelijke validaties slagen 24 en vallen 26
numeriek uit. Die aantallen veranderen niet door AHN2 en AHN5, maar de vier
AHN-tijdstoetsen zijn nu inhoudelijk uitvoerbaar: zij leren uit AHN2 en AHN3
en toetsen op de latere AHN4- en AHN5-vensters. Alleen het boomgroepmodel
slaagt numeriek. Toevoeging van de boomfractie verbetert de gemiddelde
logscore daar met 0,0024; het binnen-ploteffect is een factor 1,029 per
standaardafwijking, met p = 0,439. De tijdswinst verdwijnt bovendien wanneer
een ongunstige soort wordt weggelaten: de minimale logscoreverandering is
−0,0174. De AHN-tijdstoetsen voor open-duin-, struweel- en bosvogels vallen
door niet-positief-definiete Hessian-matrices uit. Dat is modeluitval, geen
ecologische nul. Geen van de vier AHN-modellen en geen van de zes
landbedekkingsmodellen voldoet aan de vooraf vastgelegde poort naar power.

AHN1 uit 1997–1998 is apart als historische haalbaarheids- en
gevoeligheidsanalyse gereconstrueerd. De tien oorspronkelijke grond- en
niet-grondbestanden voor vijf kaartbladen bevatten binnen het analysevenster
12.318.672 punten, of gemiddeld 0,296 punt per vierkante meter. Op een raster
van vijf meter bevat 68,17% van de 1.663.416 cellen een grondpunt en 71,36%
enig punt. Twee verdedigbare DSM-afleidingen geven echter zeer verschillende
uitkomsten voor dezelfde 55 plots: de geschatte open fractie verschilt
gemiddeld 48,0 procentpunt, de boomfractie 14,0 procentpunt en de 95e
hoogtepercentiel 4,81 meter. AHN1 is dus technisch beschikbaar, maar niet
vergelijkbaar genoeg om als vijfde punt aan AHN2–AHN5 toe te voegen.

De aansluitende luchtfotoproef is uitgevoerd met RGB en CIR voor 2016, 2020,
2022, 2023 en 2024. Van de 55 bronplots zijn M66 en M91 uitgesloten, zodat 53
Natura 2000-plots zijn onderzocht. De vier AHN-afgeleide hoogteklassen blijken
niet voldoende tussen beeldjaren overdraagbaar. De ruwe kenmerken behalen
macro-F1 0,469 voor 2020 naar 2023 en 0,420 in omgekeerde richting, beneden de
vooraf gekozen grens van 0,60. Normalisatie en beeldtextuur verbeteren dit
niet. De redelijke ruimtelijke rangorde van houtige bedekking in 24 plots in
2022 weegt daar niet tegenop: de gemiddelde absolute fout blijft circa 10
procentpunt. Water en kaal zand waren in deze proef zonder pixelreferenties
niet afzonderlijk gevalideerd. De later ontvangen classificatierasters geven
voor 2001 en 2022 wel de pixelindeling, maar de oorspronkelijke
trainingspolygonen en validatiepunten ontbreken. Daardoor kan de
overdraagbaarheid naar 2016, 2020, 2023 en 2024 nog steeds niet onafhankelijk
worden getoetst. Daarom volgt geen jaarlijkse reeks. Luchtfoto's vervangen de
hoogte-informatie niet en herstellen AHN1 niet; een vervolg vereist
onafhankelijke referenties voor meer beeldjaren.

### Aanvullende modellen met stikstof en CBS-landgebruik

De laatste verklarende stap gebruikt dezelfde soortgerichte modelbasis als de
eerdere analyses. Tijd, oppervlakte, bron, teller/tellerteam, geregistreerde
ervaring, bezoekduur, registratie van ongunstige bezoeksomstandigheden en vier
weermaten blijven in het model. Stikstof en landgebruik worden steeds gesplitst
in een gemiddeld verschil tussen plots en een verandering binnen dezelfde
plot. Daardoor wordt een blijvend verschil tussen plaatsen niet verward met de
vraag of vogels reageren nadat de omgevingswaarde in een plot verandert.

Het stikstofmodel bevat 60.127 soort–plot–jaarrijen uit 674 plotjaren in 51
plots, voor 155 soorten en 2005–2023. Zowel het basis- als het stikstofmodel is
numeriek geldig. Tussen plots bedraagt de geschatte verhouding 1,157 per
standaardafwijking hogere gemiddelde depositie; binnen dezelfde plot is zij
1,002, met p = 0,924. De beschikbare reeks laat dus een ruimtelijk verschil
zien, maar geen gemiddelde vogelverandering die meeloopt met een verandering
in stikstofdepositie. Van de vijf ruimtelijke validatieblokken slaagt er één;
daar verslechtert de logscore met 0,0315. De tijdstoets leert uit 2005–2018 en
toetst op 2019–2023, maar beide modellen vallen numeriek uit. Er is daarom geen
bestendige voorspellende meerwaarde.

Het CBS-landgebruik bevat in de bron 918 klasseregels voor 55 plots en vijf
kaartmomenten, 1996–2022. De codes van 1996 zijn niet zonder aanvullende
bronvertaling vergelijkbaar met de latere klassen en zijn niet stilzwijgend
gehercodeerd. De modellen gebruiken daarom 2010, 2015, 2017 en 2022. Na de
Natura 2000- en vogelselectie resteren 15.039 soort–plot–jaarrijen uit 168
plotjaren in 49 plots, voor 155 soorten. Getoetst zijn open natuurlijk terrein,
bos, water, deze drie gezamenlijk en de combinatie met stikstof.

Van de twaalf volledige basis- en omgevingsmodellen zijn vier numeriek geldig;
alleen het stikstofpaar is aan beide zijden geldig. Van 36 validaties slagen er
twaalf en vallen er 24 uit. Bos verbetert de logscore in vier van vier geldige
ruimtelijke blokken en water in twee van twee. Dat is een aanwijzing dat deze
kaartklassen plaatsverschillen kunnen beschrijven, geen gevalideerd model van
verandering: de volledige modellen zijn ongeldig, de overige plotblokken
vallen uit en geen van de zes tijdstoetsen slaagt. De tijdstoetsen voor
landgebruik leren uit 2010 en 2015 en toetsen op 2017 en 2022. Drie vallen door
modeluitval uit; bij twee kan door een rangdeficiënte trainingsmatrix niet op
de latere jaren worden voorspeld. Dit is technische modeluitval, geen
ecologische nulbevinding.

De conclusie is begrensd. De beschikbare stikstof- en CBS-landgebruiksgegevens
leveren geen bestendig model waarmee vogelverandering in latere jaren of
andere plots kan worden voorspeld. Daarmee is niet aangetoond dat stikstof of
landgebruik ecologisch onbelangrijk zijn. Wel is aangetoond dat deze gegevens,
in deze modelopzet en met deze dekking, niet voldoen aan de vooraf bepaalde
toegangspoort tot de poweranalyse.

De soort- en groepsuitvoer is wel volledig bewaard: 930 soortregels en 84
regels voor acht ecologische en zes functionele groepen. Alleen de veertien
stikstofgroepen berusten op een volledig geldig modelpaar. Hun geschatte
binnen-plotverhoudingen liggen tussen 0,985 en 1,012 per standaardafwijking en
dus alle dicht bij één. Dit zijn beschrijvende, gedeeltelijk gepoolde
soortreacties; door de mislukte externe validatie zijn zij geen afzonderlijk
bewijs voor een stikstofeffect op een vogelgroep.

### 4. Aanvullende verklarende blokken

We voegen verklarende informatie in herkenbare blokken toe:

1. weer;
2. stikstof;
3. landgebruik;
4. vaste ruimtelijke context;
5. alleen waar de dekking het toestaat: andere biotische informatie.

Een variabele wordt niet toegevoegd omdat zij toevallig in de database staat.
Koppeling, meeteenheid, periode, ontbrekende waarden en inhoudelijke betekenis
moeten eerst bij de onderzoeksvraag passen.

### 5. Groeps- en traituitkomsten

Het soortmodel is leidend. De voorspelde soortreacties en hun onzekerheid
worden daarna samengebracht voor functionele, ecologische en habitatgroepen.
Een rechtstreeks model van het groepstotaal dient als gevoeligheidsanalyse,
niet als zelfstandig bewijs wanneer het soortmodel een andere uitkomst geeft.

### 6. Voorspellende toets

Modellen worden niet alleen beoordeeld met significantie of AIC. Zij moeten
voorspellen voor gegevens die niet voor schatting zijn gebruikt:

- achtergehouden jaren toetsen voorspelling in de tijd;
- achtergehouden plots toetsen voorspelling op andere plaatsen;
- dezelfde uitsplitsing wordt gebruikt bij vergelijking van het basismodel en
  het model met PQ of andere verklarende blokken.

De toegevoegde waarde van PQ is het verschil in voorspelfout tussen modellen op
exact dezelfde gegevens, niet alleen een significante regressiecoëfficiënt.

Deze toets is uitgevoerd met vijf achtergehouden plotblokken en twee
achtergehouden perioden. Totale bedekking verbeterde de ruimtelijke logscore
gemiddeld licht en was in drie van vijf blokken beter. Soortenrijkdom was in
vier van vijf blokken beter, maar door één duidelijk slechter blok gemiddeld
vrijwel gelijk. Shannon verslechterde gemiddeld en was in twee van vijf
blokken beter. Er is daarmee geen ruimtelijke winst die bestendig is over de
drie maten en vijf plotblokken.

Voor latere jaren waren de logscore, MAE en RMSE met PQ voor alle drie maten in
beide tijdsblokken iets beter. Na verwijdering van Aalscholver verdween de
eerdere voorspelling van 14.804 territoria bij een nulwaarneming. Het hoogste
modelgemiddelde was nu 133 Vinken tegenover 11 getelde in M55/2025. De
absolute extrapolatie is dus sterk verbeterd maar nog niet volledig goed
gekalibreerd. De bescheiden relatieve tijdswinst weegt daarom mee als positieve
modeldiagnose, niet als zelfstandig bewijs dat deze drie PQ-maten de latere
vogelstand betrouwbaar voorspellen.

### 7. Poweranalyse

De historische trend en de poweranalyse blijven gescheiden. De historische
analyse beschrijft wat de bestaande gegevens laten zien. De poweranalyse
simuleert daarna welke vooraf omschreven toekomstige of hypothetische
verandering met deze meetopzet aantoonbaar is.

De simulatie neemt ten minste de werkelijke plots, perioden, ontbrekende
waarden, nulregels, overdispersie, temporele samenhang en modeluitval over.
Power wordt afzonderlijk bepaald voor relevante soorten, groepen,
gemeenschapskenmerken en relaties met vegetatie. Niet-convergerende modellen
tellen niet als gedetecteerd.

### 8. Niet-lineaire en vertraagde verandering van PQ naar vogels

De eerdere PQ-modellen toetsten gelijktijdige relaties en afzonderlijke
vertragingen van één tot drie jaar. De nieuwe fase stelt een andere vraag:
volgt na een verandering van de vegetatie binnen dezelfde plot een
onmiddellijke, vertraagde, tijdelijke of blijvende verandering bij vogels? De
reactie wordt niet vooraf lineair verondersteld en mag meerdere jaren beslaan.

De PQ-soortensamenstelling wordt hiervoor eerst samengevat in vijf ecologisch
benoemde gradiënten: open zand/pionier, duingrasland/mossen/korstmossen,
nat/riet, struweel/ruigte en bomen/bos. Verandering wordt gedeeld door het
aantal jaren tussen twee opeenvolgende PQ-opnamen. Daarna wordt de omvang en
richting van die verandering gezamenlijk gemodelleerd met het aantal jaren
sinds de verandering. Hetzelfde vogelbasismodel blijft staan, inclusief
Natura 2000-scope, teller/tellerteam, geregistreerde ervaring, plot- en
jaarstructuur. Een basis-, lineair en begrensd niet-lineair model worden op
dezelfde responsrijen en met achtergehouden plots en jaren vergeleken.

De eerste uitvoering bepaalt uitsluitend de beschikbare koppelingen. Run
`20261028T142316Z-d6169d52f603` gebruikt de actuele lokale database, 1.314
plotgekoppelde PQ-opnamen uit 1981–2025 en de vogelmodelpopulatie met bekende
teller/tellerteam. Aalscholver is conform het bestaande besluit uitgesloten.
De dekking bedraagt:

| Vertraging | Vogelplotjaren | Plots | Soort–plot–jaarrijen | Aandeel van vertraging 0 |
|---:|---:|---:|---:|---:|
| 0 jaar | 406 | 35 | 37.140 | 100% |
| 3 jaar | 349 | 35 | 32.117 | 86% |
| 7 jaar | 285 | 35 | 26.461 | 70% |
| 10 jaar | 233 | 35 | 21.626 | 57% |
| 15 jaar | 180 | 32 | 16.761 | 44% |

Er is dus geen harde datagrens bij drie jaar. Zelfs bij vijftien jaar blijven
180 vogelplotjaren in 32 plots over. Dit is nog geen bewijs dat een
vijftienjarige responscurve verantwoord kan worden geschat. De tabel telt
mogelijke koppelingen van een PQ-toestand aan een later vogeljaar; zij telt nog
niet de onafhankelijke veranderingen per vegetatiegradiënt. De volgende stap
is daarom de vijf gradiënten opbouwen, opeenvolgende PQ-intervallen bepalen en
vaststellen hoeveel veranderingen bij iedere mogelijke reactieduur werkelijk
beschikbaar zijn. Pas daarna wordt de maximale vertraging gekozen.

### KWR-modelonderzoek: HYVEG, MODAK en PROBE

Op 26 oktober 2026 zijn HYVEG, MODAK en de PROBE-familie aan de hand van de
oorspronkelijke publicaties en actuele KWR-documentatie beoordeeld. MODAK was
in 2003 een haalbaarheidsstudie. PROBE-1, ontwikkeld in 2006, berekent het
ruimtelijke potentieel van plantengemeenschappen onder scenario's en vraagt
onder meer een associatiekaart, wortelzonecalcium, GVG en GLG. De huidige
Meijendel-database bevat deze invoer niet als volledige gebiedsdekkende set.

PROBE-3 berekent wel ontwikkeling door de tijd. De droge-duinproef uit 2016
onderscheidde zes vegetatieassociaties en classificeerde 82% van een
achtergehouden helft van ruim 35.000 landelijke vegetatieopnamen juist. De
temporele veldtoets omvatte slechts 30 proefvlakken in de Luchterduinen en
modelleerde onder meer begrazing, konijnen, verspreiding en vertraagde reacties
niet. Het model is daarom geen vervanging voor de waargenomen PQ-, AHN- en
luchtfotoreeksen en evenmin een directe voorspeller van vogels.

De bruikbare les is de causale volgorde: externe druk en gebeurtenissen werken
via bodem, water en vegetatie(structuur) op vogels. Deze blokken blijven in de
Meijendel-analyse afzonderlijk herkenbaar en worden alleen samengebracht als de
toegevoegde voorspelling standhoudt in achtergehouden plots en jaren. Er is
geen PROBE-run uitgevoerd, geen databasewaarde gewijzigd en geen nieuw
powergetal berekend. Het volledige brononderzoek staat in
`MODAK_PROBE_HYVEG_BRONONDERZOEK.md`.

## Drie analysevensters

1. **Lange vogelreeks, 1958–2025.** Beschrijving van verandering en bepaling
   van waarnemingsstructuur. Ecologische verklaringen zijn beperkt tot de
   bronnen die voor het betreffende jaar beschikbaar zijn.
2. **Kernmodel vogels–PQ, 1981–2025.** Dezelfde 35 plots vormen de basis voor
   vergelijking van modellen zonder en met PQ.
3. **Verrijkt model, in beginsel 2005–2023.** Binnen de feitelijke overlap kan
   stikstof worden toegevoegd. Landgebruik en ruimtelijke momentopnamen worden
   alleen overeenkomstig hun werkelijke meetjaren gebruikt.

Een korter model is geen vervanging van de lange vogelreeks. Het beantwoordt
een rijkere vraag over een kortere periode.

## Reproduceerbaarheid per uitvoering

Iedere formele uitvoering krijgt een eigen identificatie en legt vast:

- uitvoerdatum en Git-commit;
- databaseschema en controleerbare databasevingerafdruk;
- alle berekende uitkomsten, inclusief nulbevindingen, inhoudelijk niet
  betekenisvolle uitkomsten en modeluitval, telkens met gegevensverzameling,
  aantal, periode en modelstatus;
- gebruikte tabellen, views, perioden en filters;
- aantallen regels, soorten, plots en plotjaren na iedere selectie;
- bron-, nul- en afkeurstatussen;
- groepsdefinities en traitversies;
- modelformules, pakketversies en toevalszaad;
- trainings- en validatiesplitsingen;
- convergentiewaarschuwingen en mislukte modellen;
- geproduceerde tabellen en figuren;
- gevolgen voor de conclusies en het artikel.

Een andere onderzoeker moet daarmee de analyse op hoofdlijnen kunnen herhalen
zonder afhankelijk te zijn van mondelinge toelichting. Toegang tot de levende
brondata blijft vanzelfsprekend nodig om de getallen exact te reproduceren.

## Stand van de uitkomsten

| Onderdeel | Status | Vastgestelde uitkomst |
|---|---|---|
| Bronnen en Natura 2000-scope | Vastgesteld | M66 en M91 vallen standaard buiten de plotgebonden analyse. |
| Bronafhankelijke nulregels | Geïmplementeerd | Letterlijke SOVON-nul, lege cel, afgeleide jaarverslagnul en formele afkeur blijven onderscheiden. |
| Functionele groepen | Beschikbaar | Zes goedgekeurde groepen met primaire, secundaire en gewogen koppeling. |
| Ecologische groepen | Beschikbaar | 51 EVG-groepen; hoofdanalyse begint met acht brede groepen. |
| Habitatgroepen | Beschikbaar | Acht habitattypen; analysevarianten sterk en sterk plus matig. |
| Continue vogelkenmerken | Beschikbaar | 23 goedgekeurde kenmerken; zestien gevuld voor alle 156 positieve soorten. |
| Teller- en ervaringsmodel | Uitgevoerd | Teller/tellerteam blijft als random effect in volgende modellen; ervaring in dezelfde plot en elders blijven afzonderlijke doorlopende correcties. De effecten worden per analyse opnieuw geschat en veranderen de brongegevens niet. |
| Voorspellend vogelmodel met drie brede PQ-maten | Uitgevoerd | Duidelijke verschillen tussen plots, maar geen duidelijke gemiddelde binnen-plotreactie. De tijdsvalidatie verbetert bescheiden; de ruimtelijke winst blijft tussen maten en blokken gemengd. Met deze drie maten is geen bestendige extra voorspellende waarde over zowel nieuwe plots als latere jaren aangetoond. |
| Volledige PQ-samenstelling | Uitgevoerd | Drie assen verklaren samen 27,8%. De ruimtelijke voorspelling verbetert in vier van vijf plotblokken; beide tijdsblokken worden iets slechter. |
| IPI-habitatproxy | Uitgevoerd | Bescheiden ruimtelijke winst in drie van vier geldige plotblokken; geen tijdswinst en geen duidelijke gemiddelde binnen-plotreactie. |
| Landbedekking 2001/2022 | Uitgevoerd; rasterstructuur beschikbaar | Duidelijkste ruimtelijke signaal voor watervogels. Voor andere groepen is de winst gemengd of de numerieke validatie te instabiel. De ontvangen rasters voegen voor 25 plots vlakgrootte, versnippering, randen en landschapsdiversiteit toe; twee kaartmomenten leveren geen algemeen model van vogelverandering. |
| Vegetatiehoogte en gerichte habitatgroepen | Uitgevoerd | AHN2–AHN5 leveren 220 geharmoniseerde structuurregels voor 55 plots en vier momenten, 2008–2023. De tijdstoets is nu uitvoerbaar, maar alleen het boomgroepmodel slaagt numeriek; de winst is 0,0024 logscorepunt en niet robuust voor het weglaten van een soort. AHN1/1997–1998 is wegens sterke methodegevoeligheid alleen experimenteel. Geen model gaat door naar power. |
| Jaarlijkse RGB/CIR-luchtfoto's | Proef uitgevoerd; niet toegelaten | Tien beelden uit 2016, 2020, 2022, 2023 en 2024 zijn voor 53 Natura 2000-plots onderzocht. De onafhankelijke overdracht 2020–2023 behaalt macro-F1 0,420–0,469 en blijft onder 0,60; normalisatie en textuur verbeteren dit niet. De rasters van 2001 en 2022 missen de oorspronkelijke trainings- en validatiereferenties en maken daarvan geen jaarlijkse reeks. |
| Weer | In gerichte modellen verwerkt | Dagweer uit 1958–2025 is samengevat als wintertemperatuur, vorstdagen, voorjaarstemperatuur en voorjaarsneerslag. Dit zijn correcties en mogelijke verklaringen, geen afzonderlijk bewijs van een weereffect. |
| Stikstof en CBS-landgebruik | Uitgevoerd | Stikstof gebruikt 60.127 soort–plot–jaarrijen, 674 plotjaren, 51 plots en 2005–2023; CBS-landgebruik 15.039 rijen, 168 plotjaren, 49 plots en vier kaartjaren uit 2010–2022. Stikstof laat een verschil tussen plots zien, maar geen gemiddelde binnen-plotreactie. Van twaalf volledige modellen zijn er vier geldig; van 36 validaties twaalf. Geen tijdstoets slaagt en geen model gaat door naar power. |
| HYVEG, MODAK en PROBE | Brononderzoek uitgevoerd | MODAK blijkt een haalbaarheidsstudie uit 2003. PROBE is een actuele vegetatiemodellenfamilie, maar de huidige Meijendel-database mist de volledige invoer voor PROBE-1. De PROBE-3-proef voor droog duin gebruikte 30 veldproefvlakken en modelleerde juist voor deze analyse belangrijke processen als begrazing, konijnen en vertraagde respons niet. Geen PROBE-run of poweranalyse uitgevoerd. |
| Niet-lineaire vertraagde PQ–vogelrelaties | Gestart; dekkingsanalyse uitgevoerd | Van 406 gelijktijdig gekoppelde vogelplotjaren in 35 plots blijven er bij 7, 10 en 15 jaar vertraging respectievelijk 285, 233 en 180 over; bij 15 jaar zijn 32 plots vertegenwoordigd. Nog niet bekend is hoeveel onafhankelijke vegetatieveranderingen de vijf ecologische gradiënten opleveren. Er is nog geen effectmodel of poweranalyse uitgevoerd. |
| Poweranalyse | Nog uit te voeren | Er bestaat nog geen formeel powergetal of detectiegrens. |
| Artikel | Nog te schrijven | Alleen doel, structuur en vereiste bewijsroute zijn vastgesteld. |

## Betekenis voor het latere artikel

Het artikel wordt pas inhoudelijk afgerond nadat is besloten welke van de
resterende relaties inhoudelijk sterk genoeg zijn voor een formele
poweranalyse en die poweranalyse is uitgevoerd. Het moet niet alleen melden welke relaties zijn
gevonden, maar ook:

- hoeveel beter het model buiten de schattingsgegevens voorspelt;
- of een relatie vooral verschillen tussen plots of veranderingen binnen
  plots betreft;
- welke soorten of groepen een vergelijkbaar dan wel afwijkend patroon tonen;
- welke veranderingen de meetopzet niet betrouwbaar kon detecteren;
- welke gegevensbeperkingen de interpretatie begrenzen.

Bij het schrijven worden het dan geldende Natuurbeheerplan Zuid-Holland, het
Natura 2000-beheerplan Meijendel & Berkheide en de actuele beheerinvulling van
Dunea opnieuw geraadpleegd. Vastgesteld beleid, beheerambitie, feitelijke
maatregel en ecologische interpretatie blijven onderscheiden.
