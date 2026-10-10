# Ontwerp teller- en ervaringsmodel

**Vastgesteld:** 9 oktober 2026  
**Status:** uitgevoerd en inhoudelijk beoordeeld; formele run
`20261009T171423Z-8888e94f0aab`

## Doel

Deze analysestap bepaalt hoeveel verschillen die samenhangen met
teller/tellerteam en
geregistreerde tellerervaring veranderen aan de geschatte ontwikkeling van de
broedvogelaantallen. Het is een analyse van het waarnemingsproces. Zij bepaalt
niet letterlijk hoeveel vogels een teller heeft gemist en levert nog geen
powergetal op.

De telleranalyse gebruikt territoriumaantallen per soort, plot en jaar. De
TRIM-indices zijn hiervoor niet de respons. De uitkomst bepaalt welke
onderdelen van het waarnemingsproces in het volgende model moeten blijven. Zij
levert geen vaste correctiecoëfficiënten die op de brongegevens worden
toegepast.

## Uitkomst en betekenis voor het vervolg

De uitvoering bevestigt dat teller/tellerteam niet kan worden genegeerd. De
spreiding die daarmee samenhangt bedraagt 0,382 op logschaal, een factor 1,47 per
standaardafwijking. Dit is de overblijvende spreiding die met teller/tellerteam
samenhangt nadat het model onder meer soort, tijd, plot, oppervlakte, bron,
jaar en plotjaar heeft verwerkt. Zij kan ook verschillen in omstandigheden,
inzet en toedeling bevatten en is daarom geen schatting van het percentage
gemiste vogels.

Ervaring in dezelfde plot heeft in de lange reeks geen duidelijk gemiddeld
effect. Ervaring in andere Meijendelplots hangt wel positief samen met het
territoriumaantal: één, drie en vijf eerder geregistreerde jaren elders komen
overeen met gemiddeld 4,2%, 8,6% en 11,2% hogere verwachte aantallen. De
één-telleranalyse en de analyses met bezoekinspanning houden dit hoofdpatroon
in stand. Zij veranderen de samenhang echter niet in bewezen causaliteit.

In volgende primaire modellen wordt teller/tellerteam daarom als random
intercept
opgenomen. De twee ervaringsvariabelen blijven afzonderlijk in het model en
soorten mogen in hun ervaringseffect afwijken. Alle effecten worden opnieuw
geschat binnen de dan gebruikte plots, jaren en soorten. Plotjaren zonder
bekende teller blijven buiten deze primaire correctie en worden desgewenst in
een afzonderlijke gevoeligheidsanalyse onderzocht.

## Actuele gegevensbasis

De reproduceerbare vogelmatrix over 1958–2025 bevat 2.107
territorium-plotjaren in 52 Natura 2000-plots en 156 soorten. Voor de
telleranalyse vervalt M62/2016, omdat dit een afzonderlijke roofvogeltelling
was. Van de resterende 2.106 plotjaren hebben 2.007 een tellerregistratie en 99
niet. De 99 onbekende tellerregistraties worden niet aangevuld of afgeleid.

De 2.007 gekoppelde plotjaren bestaan uit:

- 1.804 plotjaren met één teller;
- 201 plotjaren met twee tellers;
- 2 plotjaren met drie tellers;
- 216 verschillende registraties van teller/tellerteam;
- 1.955 opeenvolgende overgangen tussen bekende tellerjaren binnen een plot,
  waarvan 360 met een andere registratie van teller/tellerteam.

Na selectie op een geldige territoriumwaarde en bekende teller zijn 203.628
soort–plot–jaarcellen beschikbaar. Alle 156 soorten blijven in het gezamenlijke
model. Voor afzonderlijke soortmodellen voldoen bij deze gegevensstand 121
soorten aan de structurele minimumvoorwaarden: minstens 30 geldige cellen,
10 positieve waarden, 3 plots, 3 registraties van teller/tellerteam en 3 jaren.
De andere 35 soorten
blijven in het gezamenlijke model, maar krijgen geen zelfstandige
soortconclusie.

Het scoped tellerregister bevat 2.339 tellerdeelnames van 186 tellers. Daarvan
vallen 216 deelnames in het eerste bij ons geregistreerde teljaar en 413 in het
eerste geregistreerde jaar van die teller in de betreffende plot. Dit betekent
niet noodzakelijk dat de teller toen werkelijk onervaren was.

Deze aantallen zijn de stand van 9 oktober 2026. Iedere formele uitvoering
berekent ze opnieuw uit de levende database en legt ze in het manifest vast.

## Ervaringsvariabelen

Ervaring wordt uitsluitend afgeleid uit `plot_jaar_teller`, de leidende
tellerregistratie. AVIMAP-waarnemers vervangen of verrijken deze registratie
niet automatisch.

Per tellerdeelname worden vóór het betreffende jaar bepaald:

1. het aantal eerdere geregistreerde teljaren in dezelfde plot;
2. het aantal eerdere geregistreerde teljaren in andere Natura 2000-plots.

De tweede variabele is dus niet het totale aantal eerdere jaren. Daarmee wordt
voorkomen dat ervaring in dezelfde plot dubbel in beide variabelen terechtkomt.
M66, M91 en M62/2016 tellen niet mee in deze ervaringshistorie.

De variabelen worden als `log(1 + eerdere jaren)` opgenomen. Dit legt geen
willekeurige grens tussen onervaren en ervaren, maar laat het grootste verschil
in de eerste geregistreerde jaren vallen en daarna afnemen.

Bij tellerteams is de primaire teamervaring het gemiddelde van de
getransformeerde ervaringswaarden van de teamleden. Een aanvullende analyse
gebruikt uitsluitend de 1.804 één-teller-plotjaren. Daardoor kan een mogelijk
leereffect niet ten onrechte aan één lid van een tellerteam worden toegeschreven.
Minimum- en maximumervaring binnen teams worden alleen als
gevoeligheidscontrole gebruikt.

## Telinspanning en methode

`dagbezoeken_bmp` bevat binnen de standaard Natura 2000-scope 13.903 bezoeken
in 1.361 plotjaren uit 1984–2025. Voor alle 13.903 bezoeken is
`bezoekduur_min` gevuld. Deze tabel bevat geen betrouwbare teller per bezoek;
de teller blijft daarom gekoppeld op plotjaarniveau.

Het lange model over 1958–2025 kan niet voor telinspanning corrigeren, omdat
bezoekgegevens vóór 1984 ontbreken. Een afzonderlijke analyse over 1984–2025
voegt totale bezoekduur per plotjaar toe. Het aantal bezoeken wordt als
gevoeligheidsvariant gebruikt. Beide komen alleen tegelijk in een model als de
collineariteitscontrole dat toelaat.

Er bestaat geen afzonderlijke, volledige databasevariabele
`methodeperiode` voor 1958–2025. Er wordt daarom geen methodegeschiedenis
verzonnen. Het model gebruikt de werkelijk vastgelegde analysebron en vergelijkt
de lange reeks met de beter gedocumenteerde periode 1984–2025. Deze
broncorrectie is geen volledige correctie voor alle historische
methodeveranderingen.

## Modelopbouw

Alle modellen gebruiken exact dezelfde cellen binnen een vergelijking. Zo kan
een verandering tussen modellen niet worden veroorzaakt doordat een ander deel
van de meetreeks is gebruikt.

### Gezamenlijk hiërarchisch model

Het hoofdmodel is negatief-binomiaal met log-link en
`log(oppervlakte_km2)` als offset. Het model bevat:

- een gemiddelde tijdontwikkeling en een per soort afwijkende tijdontwikkeling;
- de vastgelegde analysebron;
- verschillen tussen soorten;
- herhaalde waarnemingen van dezelfde soort binnen dezelfde plot;
- verschillen tussen jaren en plotjaren.

Daarbinnen worden drie vooraf vastgelegde varianten vergeleken:

1. **M0 — basis:** geen teller- of ervaringsvariabele;
2. **M1 — teller/tellerteam:** M0 plus een random effect voor teller/tellerteam;
3. **M2 — teller/tellerteam en ervaring:** M1 plus geregistreerde ervaring in
   dezelfde plot en geregistreerde ervaring elders.

M2 laat soorten via gedeeltelijke pooling van het gemiddelde ervaringspatroon
afwijken. Een random plotjaareffect voorkomt zoveel mogelijk dat een eenmalig
hoog of laag vogeljaar automatisch als tellereffect wordt uitgelegd.

Dit is een inhoudelijk stapsgewijze opbouw. Teller, plot, tijd, bron en
oppervlakte worden niet op grond van niet-significantie verwijderd. Een
vereenvoudiging is alleen toegestaan bij structurele niet-identificeerbaarheid
of modeluitval en wordt per model vastgelegd.

### Afzonderlijke soortmodellen

Voor de 121 structureel voldoende gedekte soorten zijn dezelfde drie
modellen afzonderlijk geschat. Deze modellen laten per soort zien hoeveel de
geschatte tijdontwikkeling en de onzekerheid veranderen wanneer
teller/tellerteam en
ervaring worden toegevoegd. Niet-convergerende modellen leveren geen
soortconclusie op; zij worden niet stilzwijgend weggelaten.

### GEE-controle

Voor dezelfde voldoende gedekte soorten is een GEE-analyse met plot als
cluster uitgevoerd. Zij controleert of de richting van de gemiddelde
ervaringseffecten overeind blijft bij een populatiegemiddelde benadering met
robuuste standaardfouten.

GEE is hier een controle en niet het hoofdmodel. Het kan de variantie die
samenhangt met teller/tellerteam niet op dezelfde manier scheiden en laat
zeldzame soorten geen
informatie delen. Een verschil tussen GEE en het hiërarchische model wordt
gerapporteerd, niet door modelselectie weggewerkt.

## Gerapporteerde uitkomsten

Het resultaat is geen ranglijst van tellers. Tellercodes of teller-ID's worden
niet in het artikel gepubliceerd. De compacte resultaten leggen de geschatte
spreiding die samenhangt met teller/tellerteam, de trendverandering tussen M0
en M2, de verandering van de
intervalbreedte, de ervaringsverhoudingen en alle modeluitval vast. De
één-telleranalyse en de analyse met telinspanning laten zien of de conclusie
afhangt van teamtoerekening of bezoekinspanning. GEE controleert alleen of de
richting bij een andere modelbenadering overeind blijft.

Een statistisch ervaringsverband betekent dat territoriumaantallen
systematisch samenhangen met geregistreerde ervaring, nadat voor de genoemde
structuur is gecorrigeerd. Het bewijst niet dat het verschil uitsluitend door
gemiste vogels wordt veroorzaakt. Daarvoor zijn bezoekniveauwaarnemingen met
betrouwbare tellerkoppeling nodig.

## Technische uitvoering en toetsing

De implementatie staat onder
`analyses/broedvogel_vegetatie_power/scripts/` en bouwt voort op de bestaande
matrix en `R/meijendel_cache_contract.R`. De volledige modelobjecten en
detailuitvoer blijven onder de genegeerde map `resultaten/runs/`. In Git komen
alleen compacte samenvattingen, diagnostiek en een manifest met
databasevingerafdruk, Git-commit, formules, pakketversies en controlesommen.

De tests bewaken dat ervaring alleen uit eerdere jaren wordt afgeleid, dat
ervaring in dezelfde plot niet nogmaals als ervaring elders meetelt en dat de
volgorde van teller-ID's geen nieuwe registratie van teller/tellerteam maakt.
Zij controleren tevens de
Natura 2000-scope, de uitsluiting van M62/2016, het ontbreken van imputatie voor
onbekende tellers, gelijke responsrijen binnen M0–M2 en het zichtbaar blijven
van iedere modeluitval. Daarmee is niet alleen de uitkomst, maar ook de grens
van de uitkomst reproduceerbaar.

Modelschatting en GEE draaien buiten Shiny. Er wordt niets naar dashboard,
Shiny of VPS gepubliceerd zonder een afzonderlijk besluit.
