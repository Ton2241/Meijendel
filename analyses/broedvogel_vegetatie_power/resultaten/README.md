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
`20261011T084206Z-c1136b4ef309` van 11 oktober 2026, uitgevoerd met commit
`c1136b4ef309877ccd086441185e9d3058bc6a02`. De gelijktijdige modelpopulatie
bevat 37.362 geldige soort–plot–jaarrijen uit 406 vogelplotjaren in 35 Natura
2000-plots, voor 155 soorten en 1989–2025. Bij vertraging één, twee en drie
jaar blijven respectievelijk 390, 372 en 349 plotjaren over. Kavel 91 valt via
de analysescope af; tussen PQ-meetjaren is niets geïnterpoleerd.

Alle 24 volledige modellen en 42 validatiemodellen voldeden aan de numerieke
eindcontrole. De volledige modellen vinden voor alle drie PQ-maten een
gemiddeld verschil tussen plots, maar geen duidelijke gemiddelde reactie op
verandering binnen dezelfde plot. Dat patroon blijft bij vertragingen van één
tot drie jaar bestaan. Het is daarom geen bewijs dat een verandering van
plantensoortenrijkdom, Shannon of totale bedekking daarna een verandering van
de vogelstand veroorzaakt of voorspelt.

De ruimtelijk geblokkeerde logscore geeft evenmin een bestendige meerwaarde.
Totale bedekking is gemiddeld licht beter, maar slechts in twee van vijf
plotblokken; soortenrijkdom en Shannon zijn gemiddeld slechter en eveneens in
maar twee blokken beter. De tijdsscores zijn relatief iets gunstiger met PQ,
maar beide modellen extrapoleren bij enkele kolonieverschuivingen onrealistisch.
De meest uitgesproken fout is 14.804 voorspelde Aalscholverterritoria tegenover
nul getelde territoria in één validatiecel. Die relatieve tijdswinst is dus
geen bruikbaar voorspelresultaat.

`vegetatie_model_laatste_dekking.csv` legt de vier modelpopulaties vast.
`vegetatie_model_laatste_modellen.csv` bevat modelstatus en fitmaten;
`vegetatie_model_laatste_effecten.csv` de gemiddelde tussen-plot- en
binnen-plotreacties; `vegetatie_model_laatste_soorten.csv` de soortspecifieke
afwijkingen. De 21 geblokkeerde vergelijkingen en hun samenvatting staan in de
validatie- en samenvattingsbestanden. Het manifest verbindt de uitkomsten met
bronhashes, formules, pakketversies en de uitvoercommit.
