# Ontwerp QField-laag paden en wegen

**Datum:** 7 november 2026  
**Status:** goedgekeurd  
**Doelapparaat:** iPad met GNS 3000 via iPadOS

## Doel

Het bestaande offline QField-project `Meijendel` uitbreiden zodat Ton tijdens
wandelen of hardlopen voetpaden, fietspaden en wegen met GNSS-tracking kan
vastleggen. Per lijn wordt uitsluitend de toegankelijkheid als aanvullende
inhoudelijke classificatie geregistreerd.

## Gekozen aanpak

Er komt één bewerkbare lijnlaag `paden_en_wegen` in een afzonderlijk
`routes.gpkg`. Eén laag is eenvoudiger in QField en voorkomt drie vrijwel
gelijke formulieren. Een afzonderlijk GeoPackage voorkomt dat bij de upgrade
van het iPad-project het bestaande `veldwerk.gpkg` met afscheidingen,
bijzonderheden en gebieden hoeft te worden overschreven.

Niet gekozen:

- drie afzonderlijke lagen voor voetpaden, fietspaden en wegen, omdat dit de
  bediening en het beheer onnodig verdrievoudigt;
- opname in `veldwerk.gpkg`, omdat het vervangen daarvan bestaande
  veldwaarnemingen op de iPad kan wissen;
- aanvullende classificaties voor ondergrond, breedte of fysieke toestand,
  omdat die niet voor deze veldronde zijn gevraagd.

## Laag en velden

De laag gebruikt `LineString` in RD New (`EPSG:28992`). De velden zijn:

| Veld | Invoer |
|---|---|
| `id` | automatisch UUID, verplicht en uniek |
| `type` | verplichte keuzelijst: `voetpad`, `fietspad`, `weg` |
| `toegankelijkheid` | verplichte keuzelijst: `openbaar`, `beperkt toegankelijk`, `afgesloten` |
| `naam` | optionele tekst |
| `datum_tijd` | automatisch, aanpasbaar |
| `bron` | keuzelijst: `GNSS-track`, `handmatig`, `luchtfoto` |
| `ontvanger` | standaard `GNS 3000 via iPadOS` |
| `nauwkeurigheid_m` | door QField gemelde horizontale nauwkeurigheid |
| `opmerking` | optionele meerregelige tekst |

`type` bepaalt de kaartkleur. Toegankelijkheid wordt in het formulier
vastgelegd en niet tevens in de lijnstijl gecodeerd, zodat de kaart en legenda
compact blijven.

## Veldgebruik

QField-tracking maakt per gestarte sessie één lijnobject. De begininstelling is
minimaal 2 meter verplaatsing en minimaal 1 seconde tussen opeenvolgende
meetpunten. Ton kiest bij de start `type` en `toegankelijkheid`, loopt of rent
de route en stopt de tracking aan het einde van het betreffende routedeel.

Bij een wijziging van routetype of toegankelijkheid wordt de lopende sessie
gestopt en een nieuw lijnobject gestart. Daarmee heeft ieder object één
eenduidig type en één toegankelijkheidsstatus.

## Veilige iPad-upgrade

De upgrade bevat het bijgewerkte `meijendel.qgz` en het nieuwe `routes.gpkg`.
Het bestaande `veldwerk.gpkg`, de luchtfoto, `referentie.gpkg` en `photos/`
blijven ongewijzigd. Het volledige verse pakket blijft daarnaast beschikbaar
voor een nieuwe installatie.

## Afrondcriteria

1. `routes.gpkg` bevat een lege, bewerkbare lijnlaag `paden_en_wegen` in
   `EPSG:28992` met exact de afgesproken velden en keuzelijsten.
2. `meijendel.qgz` gebruikt relatieve paden en toont alle vier meetlagen.
3. De drie routetypen hebben afzonderlijke, leesbare lijnkleuren.
4. Een bestaande `routes.gpkg` met routeobjecten wordt nooit door de bouwer
   overschreven.
5. Contracttests bewijzen schema, keuzelijsten, renderer, relatieve paden en
   overschrijfbeveiliging.
6. Een volledig pakket en een kleine, gegevensbehoudende iPad-upgrade zijn
   lokaal beschikbaar en inhoudelijk gecontroleerd.
