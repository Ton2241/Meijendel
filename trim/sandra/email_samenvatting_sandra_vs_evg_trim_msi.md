# Samenvatting voor e-mail: vergelijking Sandra BG-groepen en EVG-TRIM-MSI

Beste allemaal,

Hierbij een samenvatting van de verkenning waarin Sandra Schmidt-Tauschers analyse van de vogelontwikkeling in Meijendel is vergeleken met een nieuwe analyse op basis van ecologische vogelgroepen uit de Meijendel-database.

## Aanleiding

Sandra’s scriptie onderzocht de ontwikkeling van broedvogels in 25 geselecteerde BMP-plots in Meijendel in de periode 1997-2022. Daarbij werden soorten samengevoegd in zeven BG-groepen, gebaseerd op voorkeursbiotoop, en werden veranderingen in aantallen per groep vergeleken met veranderingen in vegetatie.

De vraag was of dezelfde gegevens, over dezelfde plots en dezelfde periode, tot vergelijkbare conclusies leiden wanneer niet Sandra’s BG-groepen worden gebruikt, maar de ecologische vogelgroepen uit de database `Meijendel.sql`.

## Wat is er gedaan

Voor deze vergelijking is eerst een nieuwe, aparte Sandra-variant van de TRIM-analyse gemaakt. De bestaande lange TRIM-reeks voor heel Meijendel is daarbij ongemoeid gelaten.

De nieuwe Sandra-variant:

- gebruikt alleen de 25 Sandra-plots
- gebruikt alleen de jaren 1997-2022
- maakt per soort een volledige matrix van `soort x plot x jaar`
- vult een `0` in als een plot in een jaar wel geteld is maar de soort daar niet is vastgesteld
- vult een lege waarde in als een plot in dat jaar helemaal niet is geteld

Dat onderscheid is belangrijk, omdat een “echte nul” iets anders betekent dan “geen telling”. In gewone taal: afwezigheid van een soort is alleen informatief als er ook echt gekeken is.

Daarna is per soort een TRIM-model geschat. TRIM is een methode om uit onvolledige telreeksen toch een zo goed mogelijke jaarlijkse trend te schatten. Daarbij corrigeert het model voor het feit dat niet elk plot in elk jaar is geteld. In deze toepassing is ook rekening gehouden met verschillen in plotoppervlak per jaar.

Vervolgens zijn de soortuitkomsten samengevoegd tot een Multi-Species Indicator (MSI) per ecologische vogelgroep. Daarbij wordt niet simpelweg het totaal aantal territoria opgeteld, maar wordt per jaar het gemiddelde van soortindices genomen op een manier die ervoor zorgt dat zeer algemene soorten niet automatisch zwaarder wegen dan minder algemene soorten.

## Belangrijk methodisch punt

Aanvankelijk is geprobeerd Sandra’s oorspronkelijke soortenkeuze letterlijk te volgen. Daarbij bleek echter dat de huidige database inmiddels meer soorten bevat die binnen dezelfde plots en jaren aan Sandra’s eigen selectiecriteria voldoen dan in haar oorspronkelijke bestand stonden.

Daarom is de uiteindelijke Sandra-variant niet beperkt tot Sandra’s oorspronkelijke soortenlijst, maar tot alle soorten die in deze 25 plots tussen 1997 en 2022 minstens één keer als territorium zijn geregistreerd. Daarmee wordt voorkomen dat de vergelijking afhangt van een oudere, handmatig beperkte soortenlijst.

Dat betekent:

- 135 soorten kwamen in deze selectie minstens één keer voor
- voor 111 soorten kon een bruikbare TRIM-index worden geschat
- 24 soorten waren daarvoor te zeldzaam

De MSI is dus uiteindelijk gebaseerd op alle soorten waarvoor binnen deze Sandra-selectie een bruikbare soorttrend beschikbaar was.

## Eerst een praktisch punt: reconstructie van Sandra’s selectie

Bij het reconstrueren van Sandra’s analyse bleek dat in de bijlagen enkele plotlabels niet helemaal consequent zijn gebruikt.

De belangrijkste bevindingen waren:

- `10-12-76` komt in sommige Excelbestanden vervormd terug als `10.12.76` of `101276`
- in de vogelbijlagen lijkt `16s` te staan waar op basis van de telgeschiedenis en Sandra’s eigen beschrijving `16` bedoeld moet zijn
- in de landcover-bijlage lijkt `17` qua oppervlak overeen te komen met `17a`

Met de plotkeuze `1a, 1b, 3, 4-5, 6, 7, 8, 10-12-76, 12a, 13, 13s, 14, 15, 16, 17a, 17b, 45, 54a, 62, 71, 72, 73, 74, 75, 83` sluit de database het beste aan op Sandra’s beschrijving van 15 plots zonder telgaten en 10 plots met alleen kleine gaten.

## Hoofdresultaat van de vergelijking

Op hoofdlijnen bevestigt de nieuwe EVG-TRIM-MSI de richting van een deel van Sandra’s bevindingen, maar niet overal de sterkte en ook niet altijd de interpretatie.

### Wat wel overeind blijft

- Rietvogels laten ook in de EVG-analyse een afname zien.
- Struweelvogels laten ook in de EVG-analyse een afname zien.
- Bosvogels laten gemiddeld een stabiel tot licht positief beeld zien.

Met andere woorden: de achteruitgang van soorten van struweel en riet wordt bevestigd, en ook het beeld dat echte bossoorten niet sterk achteruitgaan.

### Wat duidelijk anders uitvalt

De grootste afwijking zit bij Sandra’s `BgLow`, de groep van soorten van lage vegetatie en open terrein.

In Sandra’s analyse neemt `BgLow` zeer sterk toe:

- van gemiddeld 51,8 territoria in 1997-2001
- naar 122,4 territoria in 2018-2022
- dat is een stijging van 136,3%

In de EVG-TRIM-MSI valt dit beeld veel minder eenduidig uit. De open-landschapsoorten blijken ecologisch niet één samenhangende groep te vormen:

- `Vogels van pionierbegroeiingen` laten slechts een beperkte en statistisch onzekere toename zien
- `Vogels van open heide` laten juist een afname zien
- `Weidevogels` laten eveneens een afname zien

De praktische conclusie is dat Sandra’s sterke stijging van `BgLow` niet gelezen moet worden als “open-landschapsoorten als geheel profiteren”. De nieuwe analyse wijst er eerder op dat binnen de open soorten sommige soorten profiteren, maar andere juist niet.

## De rol van de boomleeuwerik

De boomleeuwerik blijkt hier de sleutelsoort te zijn.

In Sandra’s `BgLow`:

- stijgt de boomleeuwerik van gemiddeld 11,0 territoria in 1997-2001
- naar gemiddeld 85,4 territoria in 2018-2022
- dat is een absolute toename van 74,4 territoria

De hele netto stijging van `BgLow` bedraagt 70,6 territoria. Dat betekent dat de volledige netto toename van deze groep feitelijk door de boomleeuwerik wordt gedragen, en zelfs iets meer dan dat: zonder boomleeuwerik zou `BgLow` als geheel niet stijgen maar dalen.

Ook andere soorten binnen `BgLow` laten dat zien:

- graspieper neemt licht af
- kievit neemt af
- scholekster verdwijnt uit deze selectie

Sandra’s positieve signaal voor `BgLow` is dus in sterke mate een boomleeuwerik-signaal.

## Wat doet de MSI met dat effect

De MSI verandert dat beeld niet doordat de boomleeuwerik “verdwijnt”, maar doordat hij niet langer automatisch het groepsresultaat domineert via zijn hoge aantallen.

Voor EVG-groep `300` (`Vogels van pionierbegroeiingen`) geldt:

- met boomleeuwerik stijgt de gemiddelde MSI tussen de eerste en laatste 5-jaarsperiode met ongeveer 11,6%
- zonder boomleeuwerik daalt dezelfde groep met ongeveer 26,4%

Dat is een belangrijk resultaat. Het betekent dat de boomleeuwerik ook in de EVG-analyse nog steeds een zeer invloedrijke soort is, maar dat de MSI laat zien dat die positieve ontwikkeling niet breed door alle soorten in de groep wordt gedeeld.

De boomleeuwerik zit in deze ecologische indeling bovendien niet alleen in groep `300`, maar ook in groep `700` (`Bosrandvogels`). Ook daar heeft hij een positief effect, maar veel minder dominant dan in groep `300`.

## Wat hieruit inhoudelijk volgt

De vergelijking leidt tot drie hoofdconclusies.

### 1. Sandra’s richting van verandering is deels robuust

Voor riet- en struweelvogels wordt de richting van achteruitgang bevestigd. Ook het relatief gunstige beeld voor bosvogels blijft in grote lijnen overeind.

### 2. De open-terreinconclusie moet worden genuanceerd

Sandra’s analyse suggereert dat vogels van lage vegetatie of open terrein sterk profiteren. De nieuwe analyse laat zien dat dit vooral geldt voor een beperkt aantal soorten, en met name voor de boomleeuwerik. Als groep zijn open-landschapsoorten minder eenduidig positief dan Sandra’s BG-uitkomst doet vermoeden.

### 3. De keuze van groepering maakt ecologisch echt verschil

De BG-groepen zijn begrijpelijk en bruikbaar voor een eerste beschrijving, maar voegen soorten samen op een manier waardoor een paar sterke stijgers of dalers het groepsbeeld sterk kunnen trekken. De EVG-MSI geeft eerder een beeld van de gemiddelde ontwikkeling van soorten binnen een ecologische groep, en is daardoor beter geschikt om te beoordelen of een hele soortengroep echt gezamenlijk vooruit- of achteruitgaat.

## Eindoordeel

De nieuwe EVG-TRIM-MSI ondersteunt dus niet de eenvoudige conclusie dat de verschuiving naar opener terrein de open-landschapsvogels als geheel heeft bevoordeeld. Wat de analyse wél laat zien, is dat bepaalde soorten, vooral de boomleeuwerik, sterk hebben geprofiteerd, terwijl andere open-habitatsoorten gelijk bleven of afnamen.

Juist daardoor is de vergelijking tussen Sandra’s BG-analyse en de EVG-MSI inhoudelijk waardevol: ze laat zien dat de algemene richting van verandering vaak wel klopt, maar dat de ecologische interpretatie wezenlijk verschilt zodra niet de groepssom van aantallen, maar het gemiddelde van soorttrends centraal staat.

Met vriendelijke groet,

Ton
