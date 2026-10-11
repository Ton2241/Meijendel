# Resultaten

Deze map bevat de compacte, gecontroleerde uitkomsten waarmee conclusies en
latere figuren kunnen worden herleid. Grote matrices, modelobjecten en
checkpoints staan onder de door Git genegeerde map `runs/`. Een getal gaat pas
naar het hoofddocument of het artikel wanneer selectie, modelstatus en manifest
zijn gecontroleerd.

## Analysematrix

`analysematrix_laatste_samenvatting.csv` beschrijft de actuele
soort–plot–jaarmatrix. `analysematrix_laatste_manifest.json` legt de gebruikte
bronregels, selectie en SHA256-controlesommen vast. De volledige matrix blijft
in de runmap die in het manifest is genoemd.

De matrix maakt het onderscheid tussen een positief territorium, een
letterlijke SOVON-nul, een afgeleide jaarverslagnul, een ontbrekende waarde en
een formeel afgekeurd SOVON-resultaat zichtbaar. Daarmee voorkomt zij dat een
ontbrekende soortregel stilzwijgend als afwezigheid wordt geïnterpreteerd.

## Telleranalyse

De vijf bestanden `teller_model_laatste_*` horen bij de formele run
`20261009T171423Z-8888e94f0aab` van 9 oktober 2026, uitgevoerd met commit
`8888e94f0aab0ecff6c9245bc3a7bcf31443987e`. De analyse omvat 52 Natura
2000-plots, 2.106 voor deze stap geldige plotjaren uit 1958–2025 en 156
soorten. Voor 2.007 plotjaren is teller/tellerteam bekend; de 99 overige
plotjaren zijn niet geïmputeerd. De primaire modelpopulatie bevat 203.628
geldige soort–plot–jaarrijen.

De kernuitkomst is dat teller/tellerteam een betekenisvolle bron van spreiding
blijft nadat de overige modelstructuur is verwerkt. De geschatte standaardafwijking
is 0,382 op logschaal, een factor 1,47 per standaardafwijking. Dit is geen
schatting van door individuele tellers gemiste vogels. Het is de reden om
teller/tellerteam in volgende ecologische modellen als random effect op te
nemen.

Meer geregistreerde ervaring in dezelfde plot had over 1958–2025 geen
duidelijk gemiddeld effect. Eén, drie en vijf eerdere geregistreerde jaren in
andere Meijendelplots hingen samen met gemiddeld 4,2%, 8,6% en 11,2% hogere
verwachte aantallen. Hetzelfde hoofdpatroon bleef zichtbaar wanneer alleen de
1.804 één-teller-plotjaren werden gebruikt en wanneer voor bezoekduur of aantal
bezoeken over 1984–2025 werd gecorrigeerd. Dat maakt het verband robuuster,
maar nog niet causaal.

Alle 121 vooraf toegelaten soorten leverden in het hiërarchische hoofdmodel een
bruikbare uitkomst. Negentig M2-modellen waren negatief-binomiaal; 31 gebruikten
na gedocumenteerde NB-uitval de vooraf toegestane Poisson-terugval. De mediane
absolute verandering van de jaarlijkse trend was 0,545 procentpunt. Bij 67
soorten was zij groter dan 0,5 procentpunt en bij 31 groter dan één
procentpunt. De mediane intervalbreedte nam 11% toe. De tellercorrectie heeft
dus gemiddeld een beperkte invloed op de puntschatting, maar kan voor
afzonderlijke soorten relevant zijn en maakt de onzekerheid minder stellig.

De GEE gaf voor 105 van de 121 soorten een technisch geldig controleresultaat.
Acht fits bereikten de grens van zestig seconden; acht andere leverden geen
geldige numerieke oplossing. Hun hiërarchische hoofdmodel bleef wel bruikbaar.
Bij de geldige GEE-uitkomsten kwam de richting van het ervaringseffect in
dezelfde plot voor 78,1% en elders voor 80,0% overeen met het hoofdmodel. De
GEE ondersteunt daarmee de algemene richting, maar vervangt het hoofdmodel
niet en rechtvaardigt geen stellige ervaringsconclusie per soort.

## Betekenis van de bestanden

`teller_model_laatste_dekking.csv` legt de gebruikte populatie vast.
`teller_model_laatste_samenvatting.csv` bevat de kernmaten over alle soorten.
`teller_model_laatste_soorten.csv` toont per soort hoe trend, interval en
ervaringseffect veranderen, inclusief modeluitval. De gezamenlijke
modelkwaliteit en rijgelijkheid staan in
`teller_model_laatste_diagnostiek.csv`. Het manifest verbindt dit alles met
data, formules, pakketversies, checkpoints en controlesommen.

Deze resultaten zijn de correctielaag voor de volgende analysefase. De
factor 1,47 en de ervaringspercentages worden niet rechtstreeks op tellingen
toegepast. Teller/tellerteam en de twee ervaringsvariabelen worden binnen ieder
volgend model opnieuw geschat op de exacte daar gebruikte gegevens.

## PQ-vegetatiemodel

De bestanden `vegetatie_model_laatste_*` horen bij de formele run
`20261011T101029Z-cf9b4e61c455` van 11 oktober 2026, uitgevoerd met commit
`cf9b4e61c45558c11553a11cb1b48ce48cf70ffd`. De gelijktijdige modelpopulatie
bevat 37.140 geldige soort–plot–jaarrijen uit 406 vogelplotjaren in 35 Natura
2000-plots, voor 154 soorten en 1989–2025. Bij vertraging één, twee en drie
jaar blijven respectievelijk 390, 372 en 349 plotjaren over. Kavel 91 valt via
de analysescope af; tussen PQ-meetjaren is niets geïnterpoleerd. Muskuseend
heeft geen geldige PQ-modelrij. Aalscholver is alleen uit dit model verwijderd,
omdat de nestelplaats niet door de gebruikte PQ-maten wordt gemeten.

Alle 24 volledige modellen en 42 validatiemodellen voldeden aan de numerieke
eindcontrole. De volledige modellen vinden voor alle drie PQ-maten een
gemiddeld verschil tussen plots, maar geen duidelijke gemiddelde reactie op
verandering binnen dezelfde plot. Dat patroon blijft bij vertragingen van één
tot drie jaar bestaan. Het is daarom geen bewijs dat een verandering van
plantensoortenrijkdom, Shannon of totale bedekking daarna een verandering van
de vogelstand veroorzaakt of voorspelt.

De ruimtelijk geblokkeerde uitkomst is gemengd. Totale bedekking verbetert de
gemiddelde logscore licht en is in drie van vijf plotblokken beter.
Soortenrijkdom is in vier van vijf blokken beter, maar door één slechter blok
gemiddeld vrijwel gelijk; Shannon is gemiddeld slechter en in twee blokken
beter. In beide tijdsblokken verbeteren logscore, MAE en RMSE voor alle drie
maten bescheiden. De eerdere extreme Aalscholverextrapolatie verdwijnt; het
hoogste modelgemiddelde is 133 voorspelde Vinken tegenover 11 getelde in
M55/2025. De absolute tijdvoorspelling is dus sterk verbeterd maar nog niet
volledig goed gekalibreerd. Met deze drie brede PQ-maten is geen bestendige
extra voorspellende waarde over zowel nieuwe plots als latere jaren aangetoond.
Dit bewijst niet dat de PQ-veranderingen te klein waren; daarvoor is nog geen
poweranalyse uitgevoerd.

`vegetatie_model_laatste_dekking.csv` legt de vier modelpopulaties vast.
`vegetatie_model_laatste_modellen.csv` bevat modelstatus en fitmaten;
`vegetatie_model_laatste_effecten.csv` de gemiddelde tussen-plot- en
binnen-plotreacties; `vegetatie_model_laatste_soorten.csv` de soortspecifieke
afwijkingen. De 21 geblokkeerde vergelijkingen en hun samenvatting staan in de
validatie- en samenvattingsbestanden. Het manifest verbindt de uitkomsten met
bronhashes, formules, pakketversies en de uitvoercommit.

## PQ-samenstelling, IPI en landbedekking

De bestanden `vegetatiesamenstelling_laatste_*` horen bij formele run
`20261011T130319Z-bb63b78a716f`. De modellen zijn geschat met commit
`bb63b78a716ff5f91a01b07e3ba9d1ba56cee249`; de compacte rapportage is na
verbetering van de uitvalredenen en geldigheidsvlaggen opgebouwd met commit
`a1a2293dde48e7100920cb21552a2d2204a4be0d`. Beide staan in het manifest.

De samenstellings- en IPI-modellen bevatten 37.140 geldige
soort–plot–jaarrijen uit 406 vogelplotjaren, 35 plots en 154 soorten over
1989–2025. De vegetatiebasis bestaat uit 1.314 gekoppelde PQ-opnamen, 501
PQ-plotjaren en 642 taxa uit 1981–2025. De eerste drie compositieassen verklaren
12,1%, 9,1% en 6,6%, samen 27,8%.

Alle zeven compositievalidaties zijn geldig. De ruimtelijke logscore verbetert
gemiddeld 0,093 en in vier van vijf blokken; beide tijdsscores verslechteren
licht. Van de zeven IPI-validaties zijn er zes geldig. Ruimtelijk verbetert de
logscore gemiddeld 0,036 en in drie van vier geldige blokken; beide
tijdsblokken verslechteren licht. De bestanden bewaren alle afzonderlijke
scores, niet alleen deze gemiddelden.

De landbedekkingstabel bevat zeven klassen voor 25 plots en 2001 en 2022. M17
heeft geen territoriumplotjaar in de huidige vogelmatrix; afhankelijk van de
vogelgroep gebruiken de modellen 22–24 plots, 209–228 plotjaren en 15–36
soorten over 1997–2022. M71 heeft in beide bronjaren 47,89 geclassificeerde
hectare tegenover 48,46 hectare plotoppervlak. Dit verschil van 0,57 hectare
blijft expliciet in het resultaatbestand staan.

Van de twaalf volledige landbedekkingsmodellen zijn negen geldig. Het
vegetatiemodel voor pionier/open-duinvogels en boomgroepvogels en het
basismodel voor bosvogels hebben een niet-positief-definiete Hessiaan. Over de
volledige validatie zijn 31 van 50 vergelijkingen geldig en 19 ongeldig. Voor
water- en struweelvogels slagen vijf van zes validatieblokken, voor rietvogels
vier, voor pionier/open-duinvogels twee en voor boomgroep- en bosvogels ieder
één. Een effect in `vegetatiesamenstelling_laatste_effecten.csv` heeft daarom
de expliciete kolom `vergelijking_geldig`; een coëfficiënt uit een los geslaagd
vegetatiemodel geldt niet als geldige vergelijking wanneer het basismodel
faalt.

`vegetatiesamenstelling_laatste_hoogtebesluit.csv` adviseert geen algemene
hoogtecorrectie, maar een gerichte AHN DSM–DTM-proef voor bos-, boomgroep- en
struweelvogels. De hoogteproxy is nog niet afgeleid en niet in de database
opgenomen.
