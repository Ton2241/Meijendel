# Ontwerp offline QField-project voor afscheidingen in Meijendel

**Datum:** 31 oktober 2026  
**Status:** goedgekeurd; polygonenlaag en keuzelijsten aangevuld op 31 oktober 2026
**Doelapparaat:** iPad met GNS 3000 via iPadOS

## Doel

Een compact QGIS/QField-project waarmee in heel Meijendel zonder internet fysieke afscheidingen, plaatselijke bijzonderheden en gebieden kunnen worden vastgelegd. Het project bevat een vaste luchtfoto, de 55 onderzoekskavels en drie bewerkbare meetlagen. De metingen zijn veldwaarnemingen en geen vaststelling van juridische grenzen.

## Gekozen route

QGIS 3.44.7 op de iMac maakt een lokaal QField-pakket dat per kabel of AirDrop naar de iPad kan. QFieldCloud is hiervoor niet nodig.

Het pakket gebruikt:

- project-CRS **RD New (EPSG:28992)**;
- een vaste PDOK-luchtfoto voor reproduceerbaar offline gebruik;
- een kopie van de 55 onderzoekskavels als alleen-lezen referentielaag;
- een GeoPackage met de bewerkbare lagen `afscheidingen`, `bijzonderheden` en `gebieden`;
- projectrelatieve paden voor gegevens en foto's.

De voorkeur is een landsdekkende RGB-luchtfoto van 25 cm voor het hele onderzoeksgebied. Een volledige 8 cm-luchtfoto maakt het iPad-pakket naar verwachting onnodig groot. Voor gebruik mét internet kan daarnaast een vaste 8 cm-PDOK-laag worden opgenomen. Vóór de bouw wordt via de actuele PDOK GetCapabilities het exacte beschikbare opnamejaar vastgesteld; de laag `Actueel` wordt niet als blijvende bron gebruikt.

Niet gekozen:

- alleen een online WMTS, omdat het project ook zonder internet moet werken;
- een volledige 8 cm-offlinekaart van heel Meijendel, vanwege bestandsgrootte en overdrachtstijd;
- QFieldCloud in de eerste versie, omdat lokale overdracht korter en eenvoudiger is.

## Projectstructuur

Het overdraagbare pakket krijgt één hoofdmap met:

- `meijendel.qgz`;
- `referentie.gpkg`, met een kopie van de 55 onderzoekskavels;
- `veldwerk.gpkg`, met de drie meetlagen;
- een offline luchtfoto;
- `photos/`, voor projectrelatieve foto-opslag.

De oorspronkelijke shapefile `Plots_2025/avimap_252_diversen__gebieden.shp` blijft ongewijzigd. Het projectgebied wordt bepaald door de gezamenlijke kavelgeometrie met circa 100 meter buffer.

## Kaartbeeld

Laagvolgorde van onder naar boven:

1. offline luchtfoto;
2. onderzoekskavels zonder vlakvulling, met heldere begrenzing en kavelnummer als label;
3. `gebieden` met transparante vlakvulling en een gekleurde omtrek per categorie;
4. `afscheidingen` als gekleurde lijn per type;
5. `bijzonderheden` met symbolen per soort.

De kavellabels worden afgeleid van het veld `naam`, bijvoorbeeld `Meijendel k 17a` als `M17a`.

De legenda toont de zes typen afscheiding afzonderlijk. Ieder type krijgt een
eigen kleur en lijnpatroon: hekwerk rood en doorgetrokken; hoge draad oranje
gestreept; lage draad geel gestippeld; wildrooster blauw streep-punt; muur
donkergrijs, dik en doorgetrokken; een poort/doorgang cyaan, dik en
doorgetrokken. Een poort of doorgang wordt als
kort eigen lijnsegment tussen de aansluitende afscheidingssegmenten vastgelegd.

## Meetlaag `afscheidingen`

Geometrie: lijn.

| Veld | Type | Invoer |
|---|---|---|
| `id` | tekst/UUID | automatisch |
| `type` | keuzelijst | hekwerk, hoge draad, lage draad, wildrooster, muur, poort/doorgang |
| `materiaal` | tekst | optioneel |
| `datum_tijd` | datum/tijd | automatisch, aanpasbaar |
| `bron` | keuzelijst | GNSS-track, handmatig meetpunt, luchtfoto |
| `ontvanger` | tekst | standaard `GNS 3000 via iPadOS` |
| `nauwkeurigheid_m` | decimaal | door QField gemelde horizontale nauwkeurigheid |
| `offset_m` | decimaal | geschatte afstand tussen wandelaar en afscheiding |
| `foto` | bijlage | optioneel, relatief pad |
| `opmerking` | lange tekst | optioneel |

Er komt geen vast kavelveld in deze laag. Eén lijn kan meerdere kavels doorsnijden; de bijbehorende kavels worden later reproduceerbaar met een ruimtelijke doorsnijding bepaald.

## Meetlaag `bijzonderheden`

Geometrie: punt.

| Veld | Type | Invoer |
|---|---|---|
| `id` | tekst/UUID | automatisch |
| `afscheiding_id` | tekst/UUID | optionele verwijzing naar een lijn |
| `soort` | keuzelijst | hoek, onderbreking, typewijziging, bord, schade, foto, anders, dierenverzamelplek |
| `datum_tijd` | datum/tijd | automatisch, aanpasbaar |
| `bron` | keuzelijst | GNSS, handmatig, luchtfoto |
| `ontvanger` | tekst | standaard `GNS 3000 via iPadOS` |
| `nauwkeurigheid_m` | decimaal | door QField gemelde horizontale nauwkeurigheid |
| `offset_m` | decimaal | geschatte afstand tot het object |
| `foto` | bijlage | projectrelatief pad |
| `opmerking` | lange tekst | optioneel |

De QGIS-formulieren groeperen automatische gegevens, waarneming en toelichting. Keuzevelden worden als eenvoudige keuzelijsten ingericht; foto's worden in `photos/` opgeslagen. De puntsymbolen hebben een diameter van 10 kaartmeter, begrensd op 1,2–4,2 mm op het scherm. Ze worden daardoor kleiner bij uitzoomen, maar blijven zichtbaar.

## Meetlaag `gebieden`

Geometrie: polygoon. Afzonderlijke polygonen mogen elkaar overlappen en geheel
binnen elkaar liggen; zij blijven zelfstandige objecten.

| Veld | Type | Invoer |
|---|---|---|
| `id` | tekst/UUID | automatisch |
| `categorie` | keuzelijst | inclosure, exclosure, openbaar, beperkt toegankelijk, afgesloten, bedrijventerrein |
| `datum_tijd` | datum/tijd | automatisch, aanpasbaar |
| `bron` | keuzelijst | GNSS, handmatig, luchtfoto |
| `ontvanger` | tekst | standaard `GNS 3000 via iPadOS` |
| `nauwkeurigheid_m` | decimaal | door QField gemelde horizontale nauwkeurigheid |
| `offset_m` | decimaal | geschatte afstand tot de gebiedsgrens |
| `foto` | bijlage | projectrelatief pad |
| `opmerking` | lange tekst | optioneel |

De categorieën krijgen een lichte transparante vlakvulling en een duidelijke
omtrek. Daardoor blijven luchtfoto, kavels en eventueel onderliggende grotere
gebieden zichtbaar bij geneste polygonen.

## GNS 3000 en positiekwaliteit

De GNS 3000 wordt in iPadOS gekoppeld en door QField als systeemlocatie gebruikt. Het project registreert daarom de horizontale nauwkeurigheid die QField/iPadOS rapporteert, plus de vaste ontvangervermelding. Rechtstreekse toegang tot alle ruwe NMEA-kwaliteitsvelden is via deze route niet gegarandeerd.

Voor ingebruikname volgt één proef:

1. GNS 3000 koppelen en buiten een stabiele positie laten verkrijgen;
2. controleren of QField positie en horizontale nauwkeurigheid toont;
3. enkele minuten stationair registreren;
4. een bekend hek over enkele honderden meters volgen;
5. een punt, lijn en foto opslaan terwijl de iPad geen internetverbinding heeft;
6. de lijn in QGIS vergelijken met de luchtfoto en de geregistreerde `offset_m`.

Pas op basis van deze proef worden de definitieve instellingen voor tijd- of afstandsinterval van lijnregistratie gekozen.

## Afrondcriteria

Het project is gereed wanneer:

1. het in QGIS opent met de offline luchtfoto en alle 55 onderzoekskavels;
2. alle drie meetlagen met hun formulieren bewerkbaar zijn;
3. foto's projectrelatief worden opgeslagen;
4. het QField-pakket lokaal naar de iPad kan worden overgezet en zonder internet opent;
5. met de GNS 3000 een punt, lijn, polygoon en foto kunnen worden opgeslagen;
6. de uitkomsten en gekozen trackinstellingen van de proef kort zijn vastgelegd.

