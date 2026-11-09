# Toegankelijkheidsgebieden — ontwerp

## Doel

Vervang de 55 voorlopige, handmatig per kavel vastgelegde
toegankelijkheidsregistraties door bronvaste polygonen. De toestand van een
kavel is uitsluitend een ruimtelijke afleiding uit die polygonen en wordt niet
meer als zelfstandig bronfeit opgeslagen.

## Gebiedsstatussen

Een gebiedsversie heeft exact een van deze statussen:

- `afgesloten`
- `toegankelijk`
- `toegankelijk_met_toegangskaart`

`geldig_vanaf` is voorlopig verplicht en heeft standaardwaarde `1955-01-01`.
Deze datum is een inschatting van Ton en geen uit een externe bron vastgestelde
ingangsdatum. `geldig_tot` is standaard `NULL`; dit betekent dat de versie
actueel is totdat een einddatum wordt ingevoerd.

## Model

`toegankelijkheidsgebied` bewaart de vaste identiteit van een vlak.
`toegankelijkheidsgebied_versie` bewaart status, geldigheidsperiode, native
geometrie in EPSG:28992, bron, geometriehash en inwinningsinformatie. Per gebied
mag hoogstens één versie een open einddatum hebben.

`toegankelijkheidsgebied_plot_afleiding` is uitsluitend een reproduceerbare
cache van de doorsnijding met `plots.geom`. Zij bevat oppervlakte en aandeel per
gebiedsversie en kavel, maar geen handmatig kavelkenmerk. Een kavel met meerdere
statussen of ongedekte ruimte blijft in de presentatie samengesteld; er wordt
geen fictieve enkelvoudige status opgeslagen.

## Eerste gebied

Importeer het door Ton bevestigde afgesloten vlak uit laag `gebieden` in
`veldwerk.gpkg`, object-id `2b3ae5c9-1ef6-4d82-9247-470fcc8054f6`. De
registratiedatum is 7 november 2026. De bronregistratie vermeldt de Garmin-route,
het sluiten van de begin-eindopening van 40,3 meter en het verwijderen van
zestien kleine GPS-artefacten.

## Vervanging

Verwijder uit de levende database alle 55 regels uit
`maatregel_toegankelijkheid_registratie`, hun 55 doelkoppelingen uit
`maatregel_registratie_herkomst`, de foreign key en doelkolom
`toegang_registratie_id`, en daarna de volledige registratietabel. Behoud bron
101 omdat 139 beheerregistraties die bron eveneens gebruiken.

De oude CSV- en migratiebestanden blijven alleen als historisch auditmateriaal
herkenbaar en mogen niet langer een actieve import- of leesroute vormen.

## Afnemers

Shiny en het browserdashboard lezen de gebiedsversies en de ruimtelijk
afgeleide kavelpercentages. De statistische analysetabel krijgt aandelen voor
`afgesloten`, `toegankelijk`, `toegankelijk_met_toegangskaart` en `onbekend`.
Een categoriale kavelstatus mag alleen worden getoond wanneer één status het
volledige kavel dekt; anders is de presentatie `gemengd` of deels `onbekend`.

De zware `meijendel.sql`-export, proefimport, volledige Shiny-cachebouw en
VPS-publicatie vallen buiten deze uitvoering en vereisen afzonderlijk akkoord.

## Correctie zuidgrens Bierlap-Kijfhoek op 9 november 2026

Het gebied `bierlap_kijfhoek_dagkaart_1955` krijgt één samengestelde
zuidgrens. Het landdeel volgt het door Ton aangewezen deel van Garmin-activiteit
25020262638, vanaf de groene marker bij de waaiervormige parkeerplaats tot de
wit-zwarte marker aan de plas. Bij die marker stopt het Garmin-spoor als grens.

Vanaf de marker loopt een afzonderlijk gedigitaliseerd sluitsegment door het
water, ten noorden van de zuidoever. Het segment kruist uitsluitend het korte
landstuk uit Tons vierde controlescreenshot en eindigt bij de knik waar de grens
van M6 de oever verlaat en landinwaarts gaat. Vanaf die knik sluiten de bestaande
kavelgrenzen het dagkaartvlak. Het landdeel bestaat uit de volledige
Garmin-puntreeks 0–396; het verdere Garmin-spoor heeft voor deze grens een
andere betekenis en wordt niet aan dit vlak toegekend.

De bronregistratie bewaart de puntselectie van het Garmin-deel, de vloeiende
lijn en het door Ton goedgekeurde GeoPackage-vlak. Voor iedere levende wijziging wordt eerst een
T7-herstelkopie gemaakt. De vervangende geometrie wordt vóór invoer als kaart
gecontroleerd en moet één geldig vlak zonder interne ringen opleveren.

### Herbouw als expliciete buitenring

De eerdere afleiding door een unie van kavelpolygonen wordt voor
`bierlap_kijfhoek_dagkaart_1955` niet meer gebruikt. Die methode nam de
aangewezen grenslijnen grotendeels binnen het vlak op: van de waterlijn lag
0 meter en van de Garminlijn 852,935 van 3.166,543 meter op de opgeslagen
buitencontour.

De vervangende geometrie wordt daarom rechtstreeks uit één gesloten ring
opgebouwd. De ring volgt achtereenvolgens:

1. Garmin-punten 0–396, vanaf de marker bij de waaiervormige parkeerplaats tot
   de wit-zwarte marker;
2. de afzonderlijke vloeiende lijn door het water tot de oeverknik van M6;
3. uitsluitend het buitenste noordelijke en oostelijke randdeel van de
   gezamenlijke geselecteerde kavelgeometrie terug naar het Garmin-beginpunt.

De twee mogelijke richtingen langs de kavelcontour zijn in de proef geometrisch
opgebouwd. Ton heeft het resulterende vlak visueel goedgekeurd. Dat GeoPackage-vlak
is vanaf dat moment de vaste geometriebron: runtime-herbouw uit overlappende
kavelpolygonen is niet toegestaan. Contracttests eisen de vastgelegde oppervlakte,
geometriehash, veertien volledig gedekte kavels, 96,539888% van M62 en
31,502056% van M4-5.

De controlekaart toont de volledige buitengrens in hetzelfde blauw. Na Tons
visuele akkoord vervangt het akkoordvlak alle eerdere lokale versies van
`bierlap_kijfhoek_dagkaart_1955`; precies één versie blijft over. SQL-export,
cachebouw, merge naar `main` en VPS-publicatie blijven buiten deze correctiestap.
