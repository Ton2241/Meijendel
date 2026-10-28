# Resultaten

Deze map bevat de compacte, gecontroleerde uitkomsten waarmee conclusies en
latere figuren kunnen worden herleid. Grote matrices, modelobjecten en
checkpoints staan onder de door Git genegeerde map `runs/`. Een getal gaat pas
naar het hoofddocument of het artikel wanneer selectie, modelstatus en manifest
zijn gecontroleerd.

## Ecologische PQ-gradiënten en veranderingsintervallen

De bestanden `pq_gradient_*_laatste.csv` en het manifest horen bij run
`20261028T145317Z-3691b52aedc8` van 28 oktober 2026. De runner las de lokale
database uitsluitend read-only en gebruikte de officiële SynBioSys-EcoDbase
als ecologische referentie. Van 642 taxa uit 35.672 taxonregels en 1.314 aan
35 vogelplots gekoppelde PQ-opnamen uit 1981–2025 zijn 528 taxa aan ten minste
één van vijf gradiënten gekoppeld. De volledige mapping én alle 114 niet
ingedeelde taxa blijven in de resultaatbestanden zichtbaar.

Een plotjaar geldt alleen als minimaal 80% van de totale geregistreerde
bedekking is ingedeeld. Dit geldt voor 485 van 501 plotjaren. Twee
opeenvolgende, beide geldige PQ-plotjaren leveren 441 veranderingsintervallen:
164 duren één jaar, 159 twee jaar, 69 drie jaar en 44 vier jaar; vier
intervallen duren vijf, zes, zeven of dertien jaar. Jaarlijkse verandering is
de verandering in gradiëntaandeel gedeeld door de werkelijke intervallengte.

Open/pionier, duingrasland/mos/korstmos, struweel/ruigte en bomen/bos veranderen
in alle 441 intervallen en alle 35 plots. Nat/riet verandert in 357 intervallen
en 32 plots. Bij nul, zeven, tien en vijftien jaar na het interval zijn
respectievelijk 366, 249, 196 en 149 intervallen aan een geldig vogelplotjaar
te koppelen; bij vijftien jaar zijn 30 plots vertegenwoordigd. Vijftien jaar
blijft daarmee beschikbaar voor gemeenschap en vogelgroepen, maar deze
dekkingsuitkomst is nog geen aangetoond verband, effectschatting of powergetal.

## PQ-vertragingsdekking 0–15 jaar

`pq_vertragingsdekking_laatste.csv` en het bijbehorende manifest horen bij run
`20261028T142316Z-d6169d52f603` van 28 oktober 2026. De runner las de actuele
lokale database alleen-lezen en schatte geen model. De bron omvat 2.007
PQ-opnamen en 53.122 PQ-taxonregels uit 1981–2025; 1.314 opnamen zijn gekoppeld
aan 35 Natura 2000-vogelplots. De gekoppelde vogelpopulatie bevat, na
uitsluiting van Aalscholver, bij vertraging nul 37.140 soort–plot–jaarrijen uit
406 vogelplotjaren, voor 154 soorten en 1989–2025.

Bij 3, 7, 10 en 15 jaar vertraging blijven respectievelijk 349, 285, 233 en
180 vogelplotjaren beschikbaar. Bij vijftien jaar zijn nog 32 plots en alle
154 soorten vertegenwoordigd; het aantal soort–plot–jaarrijen is dan 16.761.
Dit bestand toont de technische dekking van een PQ-toestand en een later
vogeljaar. Het toont nog niet het aantal onafhankelijke veranderingen tussen
twee PQ-opnamen en is daarom nog geen basis voor een effect- of powergetal.

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

`vegetatiesamenstelling_laatste_hoogtebesluit.csv` adviseerde geen algemene
hoogtecorrectie, maar een gerichte AHN DSM–DTM-proef. Die proef is inmiddels
uitgevoerd en staat in de bestanden `habitatgericht_laatste_*`.

## Oorspronkelijke landbedekkingsrasters

De bestanden `landbedekking_raster_laatste_*` zijn afgeleid uit de op 19
oktober 2026 ontvangen classificatierasters voor 2001 en 2022. Zij omvatten 25
bronplots, zeven klassen en respectievelijk 369.710 en 369.662 geldige pixels.
Alle pixels hebben een bekende klasse en vallen binnen een bronplot.

`landbedekking_raster_laatste_oppervlaktecontrole.csv` bevat alle 350
vergelijkingen met de eerder gebruikte supplementtabel. Het gemiddelde
absolute verschil is 0,0032 hectare en het maximum 0,030 hectare.
`landbedekking_raster_laatste_landscapemetrics.csv` bevat per plot en jaar
klassenrijkdom, Shannon-diversiteit en totale interne randdichtheid.
`landbedekking_raster_laatste_klassemetrics.csv` bevat per klasse aandeel,
aantal en dichtheid van aaneengesloten vlakken, aandeel van het grootste vlak
en randdichtheid. `landbedekking_raster_laatste_verandering.csv` zet voor
iedere plot en klasse 2001 en 2022 naast elkaar. Het manifest bewaart
bronhashes, rastermetadata, klassecodes en controles.

Dit zijn beschrijvende ruimtelijke maten op twee kaartmomenten. Zij vormen
geen jaarlijkse tijdreeks en zijn nog niet als nieuwe voorspellers in een
vogelmodel geschat.

## Gerichte habitatmodellen met AHN en weer

De bestanden `habitatgericht_laatste_*` horen bij formele run
`20261012T085549Z-3a43bb218f8a`. De voorafgaande bronrun
`20261012T081631Z-ahn-harmonized-3a43bb218f8a` bevat 220 regels voor 55 plots:
AHN2/2008, AHN3/2014, AHN4/2020 en AHN5/2023. De officiële DSM- en DTM-tegels
zijn per cyclus op exact hetzelfde tweemetergrid gemiddeld. Geen van de 220
regels mist een structuurmaat en geen pixel boven 45 meter is als vegetatie
behouden. De compact bijgehouden bestanden `ahn_harmonisatie_laatste_*`
bevatten de structuurlaag, bronbestanden, controles, cyclusgemiddelden en alle
165 gepaarde plotverschillen tussen opeenvolgende cycli.

De tien vooraf bepaalde combinaties gebruiken per model 1.741–11.639
soort–plot–jaarrijen, 15–36 soorten en 22–52 plots. De
landbedekkingsmodellen gebruiken de vensters 1997–2001 en 2018–2022; de
AHN-modellen de jaren 2009–2011, 2014–2016, 2021–2022 en 2023–2025. Naast teller/tellerteam en ervaring zijn
bezoekduur, de beschikbaarheid en waarde van ongunstige
bezoeksomstandigheden, wintertemperatuur, wintervorstdagen,
voorjaarstemperatuur en voorjaarsneerslag opgenomen.

Van twintig volledige basis- en habitatmodellen zijn twaalf geldig en acht
numeriek ongeldig. Van vijftig ruimtelijke validaties zijn 24 geldig en 26
ongeldig. De geldige ruimtelijke blokken verbeteren bij water in drie van
drie, riet in vier van vijf, landbedekking open in één van één,
landbedekking boomgroep in één van één en landbedekking bos in twee van twee
gevallen. Dit is geen robuust rangnummer: de ontbrekende blokken zijn
modeluitval en tellen niet als verbetering.

De landbedekking heeft slechts twee onafhankelijke meetmomenten; de zes
bijbehorende tijdstoetsen blijven `niet_uitvoerbaar`. AHN heeft vier
structuurmomenten en kan daarom op AHN2–AHN3 leren en op AHN4–AHN5 toetsen.
Van die vier tijdstoetsen slaagt alleen het boomgroepmodel numeriek. De
logscore verbetert met 0,0024, maar de minimale verandering na het weglaten van
een soort is −0,0174. De drie andere AHN-tijdstoetsen vallen numeriek uit.
Geen van de tien modellen voldoet aan de vooraf vastgelegde poort naar power.
`habitatgericht_laatste_samenvatting.csv` geeft het besluit per combinatie; de
effect-, validatie- en modeltabellen bewaren ook nulbevindingen en uitval.

De bestanden `ahn1_historisch_laatste_*` bewaren de afzonderlijke
haalbaarheids- en methodegevoeligheidsanalyse van AHN1/1997–1998. Zij omvatten
55 plots, tien gecontroleerde bronbestanden en 12.318.672 punten binnen het
analysevenster. Omdat twee verdedigbare rastermethoden gemiddeld 48,0
procentpunt verschil in open terrein opleveren, is AHN1 niet aan de
AHN2–AHN5-reeks toegevoegd.

## Luchtfoto classificatieproef

De bestanden `luchtfoto_proef_laatste_*` horen bij lokale run
`20261012T123500Z-luchtfoto-proef-1d09d26`. Het downloadmanifest beschrijft
tien PDOK-WMS-rasters: RGB en CIR voor 2016, 2020, 2022, 2023 en 2024, steeds
3.440 bij 3.018 pixels op 2 meter. De classificatie gebruikt 53 van de 55
bronplots; M66 en M91 zijn uitgesloten.

Beide kenmerkensets bewaren vier overdrachtstoetsen van 160.000 evenwichtig
over de vier klassen getrokken testpixels. De ruwe 2020–2023-toetsen behalen
macro-F1 0,469 en 0,420; de genormaliseerde toetsen 0,419 en 0,326. Geen toets
haalt de vooraf gekozen grens van 0,60. De plotbestanden bewaren daarnaast
alle 1.060 aandelen per kenmerkenset: 53 plots maal vijf jaren maal vier
klassen.

De samenvatting bevat ook de vergelijking met het gepubliceerde houtige
aandeel van 24 afzonderlijk begrensde plots in 2022. De correlatie bedraagt
0,743 voor ruwe en 0,869 voor genormaliseerde kenmerken, maar de gemiddelde
absolute fout blijft respectievelijk 0,102 en 0,106. Water en kaal zand zijn
niet afzonderlijk gevalideerd. De status is daarom
`niet_bruikbaar_voor_jaarlijkse_uitbreiding`.

## Stikstof en CBS-landgebruik

De bestanden `omgeving_laatste_*` horen bij formele run
`20261012T111852Z-d190db5705c6`. Het stikstofmodel bevat 60.127
soort–plot–jaarrijen uit 674 plotjaren in 51 plots, voor 155 soorten en
2005–2023. De vijf CBS-landgebruikmodellen bevatten ieder 15.039 rijen uit 168
plotjaren in 49 plots, voor 155 soorten en de kaartjaren 2010, 2015, 2017 en
2022. De 918 bronregels bevatten daarnaast 1996; die broncodes zijn niet
inhoudelijk aan de latere klassen gekoppeld en blijven daarom buiten deze
modellen.

Voor stikstof zijn basis- en omgevingsmodel beide geldig. Het gemiddelde
verschil tussen plots is een factor 1,157 per standaardafwijking; het
binnen-plotverband is 1,002, met p = 0,924. Van vijf ruimtelijke blokken slaagt
er één en dat blok voorspelt slechter. De tijdstoets op 2019–2023 valt
numeriek uit.

Over alle zes vergelijkingen zijn vier van twaalf volledige modellen geldig;
alleen bij stikstof is het volledige modelpaar geldig. Twaalf van 36
validatievergelijkingen slagen en 24 vallen numeriek uit. Bos verbetert de
logscore in vier van vier geldige ruimtelijke blokken, water in twee van twee.
Deze signalen worden niet als model van verandering gelezen: de volledige
modelparen zijn ongeldig en geen van de zes tijdstoetsen slaagt. Daarom luidt
het besluit voor alle zes combinaties
`geen_bestendige_voorspellende_meerwaarde` en gaat geen combinatie door naar
power.

`omgeving_laatste_samenvatting.csv` geeft dit besluit per combinatie.
`omgeving_laatste_modellen.csv` en `omgeving_laatste_validatie.csv` bewaren
alle modeluitval. De effect-, soort- en groepstabellen bevatten expliciete
statusvelden, zodat een coëfficiënt uit een los geslaagd omgevingsmodel niet
als geldige vergelijking wordt gelezen wanneer het basismodel faalt.
De soorttabel bevat 930 regels en de groepstabel 84 regels. Alleen de veertien
stikstofgroepen hebben `vergelijking_geldig = TRUE`; hun binnen-plotverhouding
ligt tussen 0,985 en 1,012. Omdat de ruimtelijke en temporele validatie voor
stikstof niet slaagt, zijn ook deze groepswaarden geen zelfstandig bewijs van
een ecologisch effect.
