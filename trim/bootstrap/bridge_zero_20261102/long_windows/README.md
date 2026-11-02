# Langere brugvensters voor 33 onderzochte soorten

Afgerond op 2 november 2026. Historische ontwikkelcache 1958–2025.
Dit is een gezamenlijke gevoeligheidsproef, geen nieuwe bootstrap,
betrouwbaarheidsinterval of vrijgave van een nieuwe standaardmethode.

## Afbakening zonder verwarring over de 33

Deze vergelijking omvat de eerder onderzochte 33 vogelsoorten. Het is
geen groep van 33 probleemsoorten en geen definitieve selectie voor alle
toekomstige bootstrapberekeningen. De soorten zijn hier gelijk gehouden
om het effect van vensterlengte te kunnen vergelijken. De ecologische
groepen bevatten in deze ontwikkelberekening alleen hun deel van deze
33 soorten; zij vertegenwoordigden dus al niet de hele vogelgemeenschap.
Een kleinere rekenkundige selectie is besproken als mogelijkheid, niet
als definitief selectiebesluit.
De bestaande beschrijvende groepsberekening gebruikt ruimere selecties
(135 soorten voor volledig, 93 voor robuust in deze historische run);
de beperking tot 33 betreft de bootstrapontwikkelproef.

De 33 voldeden in de oorspronkelijke fit aan drie voorwaarden: bruikbare
modellen in 1958–1983 en 1984–2025, een primaire brug 1981–1983 naar
1986–1988, en positieve eindige modelindices in alle 68 jaren. Dat laatste
betekent geen waargenomen aanwezigheid in alle jaren en garandeert geen
stabiliteit bij bootstrapherhalingen.

`inventory.csv` maakt dit zichtbaar voor het volledige historische
bestand: 156 soorten, waarvan 93 met twee bruikbare modelperioden, 35
met alleen de latere en zeven met alleen de eerdere periode. De overige
21 kregen destijds de labels te_zeldzaam (16), lokaal_incidenteel (4) of
te_weinig_data (1). Dit zijn historische modelstatussen, geen nieuwe
beoordeling van de levende database en geen definitieve uitsluitlijst.

## Vooraf gekozen vensters en methode

| Lengte per zijde | Voorvenster | Navenster |
|---|---|---|
| 3 jaar, referentie | 1981–1983 | 1986–1988 |
| 5 jaar | 1979–1983 | 1986–1990 |
| 7 jaar | 1977–1983 | 1986–1992 |
| 10 jaar, stresstest | 1974–1983 | 1986–1995 |

Alle soorten kregen dezelfde vensters. Overgangsjaren 1984–1985 blijven
in het tweede hoofdmodel, maar buiten de kalibratie. De hoofdmodellen
blijven gelijk; alleen de kalibratie en haar ankers veranderen. Het
jaarlijkse hulpmodel wordt met ongeronde interne totalen beoordeeld;
deze zijn gecontroleerd tegen de kolomsommen van de imputatiematrix.
De aparte venstermethode schat één niveau per venster. Beide behouden
het bestaande onderscheid tussen echte nullen en onbekende cellen en
gebruiken dezelfde bestaande oppervlaktecorrectie.

Er zijn twee plotvarianten. Bij `baseline_plots` blijven de 33 oorspronkelijke
kalibratieplots gelijk. Het gelijke aantal soorten en plots is toevallig;
het zijn verschillende eenheden. Bij `window_common` wordt de pool opnieuw
uit de vensters afgeleid: respectievelijk 33, 35, 40 en 43 plots. Hiermee
wordt netwerkuitbreiding van het effect van vensterlengte onderscheiden.
De bootstrapkansen blijven berekend voor de oorspronkelijke 52 clusters
(17 historisch, 35 later). Er zijn geen nieuwe trekkingen uitgevoerd.

## Resultaat bij dezelfde oorspronkelijke kalibratieplots

| Vensterlengte | Soorten met schatbare uitgangsbrug, jaarlijks model | Idem, venstermodel | Kans volledig nulvenster Witte Kwikstaart |
|---|---:|---:|---:|
| 3 jaar | 33/33 | 33/33 | 4,318% |
| 5 jaar | 33/33 | 33/33 | 1,519% |
| 7 jaar | 30/33 | 33/33 | 1,519% |
| 10 jaar | 30/33 | 33/33 | 0,517% |

Dit zijn schatbaarheidsaantallen op de oorspronkelijke gegevens. Het
zijn geen percentages geldige bootstrapreplicaties. De nulkansen zijn
exacte kansen om alle positieve vensterplots te missen binnen het
bestaande gestratificeerde trekkingsontwerp. Andere modeluitval is niet
in die kansen inbegrepen. Ook een kans onder 2,5% rechtvaardigt niet
het stilzwijgend verwijderen van nulrandtrekkingen.

Het jaarlijkse model valt bij zeven en tien jaar uit voor Kleine
Mantelmeeuw, Veldleeuwerik en Witte Kwikstaart, door afzonderlijke
jaren zonder positieve tellingen. Extra jaren kunnen dus nieuwe
problemen opleveren voor een model met vrije jaareffecten. Met de
grotere plotpool wordt Witte Kwikstaart weer schatbaar; 31/33 blijven
dan schatbaar, tegenover 33/33 bij vijf jaar.

## Waarom langer niet volstaat voor het huidige jaarlijkse hulpmodel

Het jaarlijkse hulpmodel verlangt positieve tellingen in ieder jaar.
Bij Witte Kwikstaart heeft 1986 in de oorspronkelijke kalibratieplots
maar één positieve bronplot. De kans die plot te missen in de bestaande
trekking is `(34/35)^35 = 36,256%`. Dat jaar blijft ook in de langere
vensters zitten. Bij Veldleeuwerik bevat het vijfjaarsvenster in 1989
eveneens maar één positieve bronplot; ook daar is de ondergrens van de
uitvalkans 36,256%. Andere lege jaren of modelproblemen kunnen daar
alleen nog uitval aan toevoegen.

De daling van de kans op een volledig nulvenster van 4,318% naar 1,519%
geldt voor het samen gebruiken van het hele venster, niet voor het
huidige vrije-jaareffectenmodel. Alleen het venster verbreden kan
daarom geen verwachte geldigheid van 95% voor die jaarlijkse
brugschatters opleveren. Een oorspronkelijke fit die slaagt is iets
anders dan een schatter die in bootstrapherhalingen voldoende vaak
kan worden berekend. De ondergrenzen staan afzonderlijk in
`coverage.csv` en `summary.csv`; het zijn geen percentages gemeten
bootstrapuitkomsten.

## Wat vijf jaar verbetert en wat niet

Bij Witte Kwikstaart groeien de positieve plotsets van 7/3 naar 10/4
(voor/na). De berekende kans op volledig verlies van een venster
daalt van 4,318% naar 1,519%. Bij Roodborsttapuit daalt die kans van
1,367% naar 0,0125%. Bij Veldleeuwerik verandert zij weinig:
0,565% naar 0,533%, met nog steeds vijf positieve navensterplots.

Het verschil tussen de modelvormen wordt voor Veldleeuwerik kleiner:
de primaire brugfactoren zijn bij vijf jaar 0,82465 (jaarlijks,
ongerond) en 0,72197 (venstermodel), 12,45% verschil in plaats
van 51,74% bij drie jaar. Bij Witte Kwikstaart worden deze factoren
0,62854 en 0,65721: 4,56% verschil tegenover 8,21% bij drie jaar.

De plotgevoeligheid verdwijnt niet. Bij Veldleeuwerik kan het weglaten
van één plot de vijfjaarsbrugfactor in het jaarlijkse model nog
met 135% veranderen; bij het venstermodel maximaal 53%. De hoogste
imputatiefractie van een kalibratiejaar blijft circa 90%. Bij Witte
Kwikstaart bedragen de grootste veranderingen circa 21% en 40%.
Bij vijf jaar worden bovendien twee van 33 jaarlijkse
weglatingsfits voor Veldleeuwerik onschatbaar en één van 33 voor Witte
Kwikstaart; bij het venstermodel blijven alle 33 voor beide soorten
schatbaar. Daarom is vijf jaar bij de venstermethode een kandidaat
voor de volgende proef, geen bewijs
van een betrouwbare formele brug voor iedere soort. Deze
weglatingscontroles gebruiken uitsluitend `baseline_plots`.

Bij 30 van de 33 soorten verschuift de brugfactor van drie naar vijf
jaar in beide modelvormen minder dan 10%. Veldleeuwerik, Witte
Kwikstaart en Roodborsttapuit veranderen meer. Bij Meerkoet wisselt
een zeer kleine samengestelde puntschatting van teken: jaarlijks
+0,033 naar −0,022% per jaar; venstermodel +0,014 naar −0,053%.
Zonder interval is dit geen bewijs van een echte richtingwisseling.

De groepsvergelijking gebruikt dezelfde samenstelling: 19 gevulde
schatters en twee lege luchtfoerageerdersvarianten. Van drie naar
vijf jaar wisselt geen gevulde groepspuntschatting van teken. De
grootste verschuiving is circa 0,33 procentpunt per jaar. Dit zijn
beschrijvende oorspronkelijke-dataresultaten, geen groepsbootstrap.

## Afgerond oordeel

Beproef de expliciete venstermethode met vijfjaarsvensters 1979–1983
en 1986–1990 als volgende gezamenlijke kandidaat, met drie jaar en
het ongeronde jaarlijkse model als referenties. Alleen verlenging
binnen het huidige jaarlijkse hulpmodel is geen oplossing. Verleng niet
automatisch naar zeven of tien jaar en kies geen venster per soort
op grond van waar zij toevallig voorkwam. De afstand tussen de
venstermiddenpunten groeit van vijf naar zeven, negen en twaalf
jaar. Een bredere vergelijking omvat daardoor meer echte
ecologische verandering en is geen zuivere meting van methodeverschil.

Er is geen nieuwe primaire methode gekozen, geen kleinere soortselectie
ingevoerd en geen bootstrap gestart. Soorten met onvoldoende
brugonderbouwing blijven zichtbaar, met afzonderlijke periodetrends
waar mogelijk en anders beschrijvende waarnemingen met teldekking.

## Nog nodig voor de bootstrap van alle soorten

1. Kies en toets eerst de brugmodelroute. Het huidige jaarlijkse
   hulpmodel blijft voor sommige soorten structureel kwetsbaar; alleen
   vijf jaar instellen verhelpt dit niet. Rond vervolgens de technische
   route af: ongeronde totalen gebruiken, gekozen
   vensters expliciet configureerbaar maken, reproduceerbaarheid testen
   en nulvensters/ongeschatte bruggen als herkenbare uitkomsten verwerken.
   De grens van 95% geslaagde fits alleen volstaat niet voor randgevallen.
2. Beoordeel het volledige soortenbestand per soort: welke periode en
   welke brug zijn schatbaar, met welke gegevens en reden van uitval?
   De 33 vormen geen toegangspoort voor de soortbootstrap. De bestaande
   engine loopt al over alle soorten in zijn invoermatrix; de beperkte
   33-selectie betrof de vaste groepspopulatie.
3. Voor de afgesproken definitieve run tot en met 2026: valideer/importeer
   eerst de definitieve 2026-bron, inclusief onderbouwde nullen, onbekende
   cellen en goedkeuringsstatussen. Het gebruikersbesluit van 31 oktober
   wacht met import op echte nulgegevens. De afzonderlijke verkennende
   rapportaanname voor een beperkte 2026-selectie vervangt die import niet.
   Maak daarna, na het daarvoor afgesproken afzonderlijke akkoord, een
   verse gevalideerde export/analysecache uit de levende lokale database.
4. Maak één hashgebonden runbasis voor het volledige dan actuele
   soortenbestand en controleer plotgeschiedenissen en dekking. Draai
   eerst een kleine reproduceerbaarheidsproef en 50 ontwikkelreplicaties
   met diagnostiek per soort en resultaatstype; ga daarna via 500 naar
   minimaal 2.000 replicaties als de controles dit ondersteunen. Niet
   iedere soort hoeft een lange trend te krijgen om andere soorten
   verantwoord te kunnen berekenen en rapporteren.

De twee afzonderlijke TRIM-perioden blijven de primaire formele
soortresultaten. De aanvullende lange trend krijgt alleen formele
onzekerheid waar de brug en de behandeling van uitval die dragen.
Publicatie naar de VPS blijft een afzonderlijk besluit.

## Bewijs en herhalen

528 soort/methode/venster/plotpoolcombinaties; 264 dekkingsregels;
528 weglatingscontroles voor twee soorten; 336 groepspuntschattingen
(inclusief ongeldige/lege gevallen). De driejaarsreferenties voor
Veldleeuwerik en Witte Kwikstaart komen binnen 1e−8 overeen met de
eerder gecontroleerde vergelijking. De identiteit en hashes staan
in `manifest.json`; de compacte hoofdresultaten in `summary.csv`.
De overige CSV’s bewaren de controles en historische soorteninventaris.

Herhalen: `Rscript R/audit_trim_bridge_long_windows.R <repository>
<historische-cache.rds> <lokale-uitvoermap>`. De broncachehash wordt
verplicht gecontroleerd; het script maakt geen databaseverbinding.
