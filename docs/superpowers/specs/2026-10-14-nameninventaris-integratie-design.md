# Integratie Meijendel-nameninventaris

Stand: 14 oktober 2026.

## Doel

Neem de levering `meijendel_nameninventaris_2026-10-14` gecontroleerd op in de
levende lokale MySQL-database `Meijendel`. De database krijgt een blijvend,
bronvast register voor actuele en historische namen van gebieden, paden, wegen
en wandelroutes, met geometrie waar de bron die verantwoord levert.

De import verandert geen bestaande vogelplot-, projectgrens-, maatregel-,
dashboard-, Shiny- of websitetabel. Productie en VPS blijven ongewijzigd.

## Bronstand en acceptatiebasis

De levering bevat:

- 182 naamobjecten;
- 299 gedateerde vermeldingen uit 1602-2026;
- 8 bronnen;
- 71 objecten met geometrie in EPSG:28992 en EPSG:4326;
- 111 objecten zonder verdedigbare geometrie en met een expliciete bronlacune;
- 47 TOP10NL-features, samengebracht tot 46 naamobjecten;
- 60 OSM-way-ID's, samengebracht tot 25 pad- en wegnamen.

De import accepteert uitsluitend de vastgelegde bestandsset met kloppende
SHA-256-checksums. Herhaalde import van dezelfde leveringsversie moet
idempotent zijn en mag geen extra records opleveren.

## Datamodel

De herkenbare broncollectie krijgt het prefix `nameninventaris_`.

### `nameninventaris_import`

Een reproduceerbare importbatch met versiesleutel, leveringsdatum, bronpad als
logische referentie, archiefhash, regelversie, verwachte aantallen en
importtijdstip. Een unieke versiesleutel voorkomt dubbele import.

### `nameninventaris_bron`

De acht voor deze inventaris gebruikte bronnen. Bewaart broncode, titel,
auteur of beheerder, bronjaar, brontype, URL of logische Zotero-verwijzing,
raadpleegdatum, ruimtelijke grondslag, rechten, kwaliteitsbeoordeling en waar
beschikbaar een Zotero-item-key. Absolute paden naar de Samsung T7 worden niet
opgenomen.

De bronrecords zijn een importsnapshot voor deze gegevenslaag. Zij vervangen
de bredere catalogus in `Meijendel_bronnen` niet.

### `nameninventaris_object`

Een stabiele identiteit voor ieder naamobject. Bewaart de aangeleverde
`object_id`, de gecontroleerde voorkeursnaam, objectklasse en bewijsstatus.
Naam alleen is geen sleutel: dezelfde schrijfwijze mag voor verschillende
objectklassen of werkelijk verschillende objecten voorkomen.

De bewijsstatus beschrijft uitsluitend de geraadpleegde bronnen:
`actueel_bronbewijs`, `historisch_bronbewijs` of `actueel_en_historisch_bronbewijs`.
Zij beweert niet dat een naam officieel is vastgesteld of buiten de acht
bronnen niet meer wordt gebruikt.

### `nameninventaris_vermelding`

Een rij per bronvermelding. Bewaart de letterlijke bronnaam, broncode,
letterlijke periodewaarde, getypeerde jaargrenzen en datumprecisie,
pagina/kaart/bronobject-ID, deelgebied en bewijsnotitie. Voorkeursnaam en
objectklasse worden niet herhaald; die volgen via de foreign key naar het
naamobject.

### `nameninventaris_geometrie`

Een rij per naamobject, bron en geometrieversie. Alleen aanwezige geometrieën
worden opgeslagen; ontbrekende geometrie is afwezigheid van een rij, geen
`NULL`-geometrie. De geometriekolom is `GEOMETRY NOT NULL SRID 28992` met een
spatial index. Daarnaast worden broncode, peildatum, bronobjecttype,
brongetrouwe WKT-hash, nauwkeurigheid in meters, nauwkeurigheidsstatus,
ruimtelijke selectiegrondslag en geometrieopmerking bewaard.

De twee TOP10NL-polygonen voor `Meijendel` worden als een geldige
`MULTIPOLYGON` opgeslagen. Hun afzonderlijke bronidentiteiten blijven in de
koppeltabel behouden.

### `nameninventaris_geometrie_bronobject`

Normaliseert de 47 TOP10NL-feature-ID's en 60 OSM-way-ID's achter de 71
objectgeometrieën. Een geometrie kan daardoor uit meer dan één bronfeature
bestaan zonder komma- of puntkommalijsten.

### `nameninventaris_beoordeling`

De actuele, versieerbare beoordeling van geometriebeschikbaarheid. Voor de 111
objecten zonder geometrie bewaart deze tabel wat ontbreekt, het gevolg voor
gebruik en de kleinste volgende bron. De regelversie maakt latere herbeoordeling
mogelijk zonder historische besluiten te overschrijven.

## Correcties vóór import

De importer voert uitsluitend expliciete, geteste transformaties uit:

1. `Blankenburgh|Buitenplaats` wordt voorkeursnaam `Blankenburgh`, met
   `Buitenplaats` als bronobjecttype.
2. `Voorlinden|Buitenplaats` wordt voorkeursnaam `Voorlinden`, met
   `Buitenplaats` als bronobjecttype.
3. Puntkomma-gescheiden broncodes worden niet overgenomen; relaties worden uit
   `meijendel_vermeldingen.csv` opgebouwd.
4. Komma-gescheiden TOP10NL- en OSM-ID's worden afzonderlijke
   `nameninventaris_geometrie_bronobject`-rijen.
5. Jaarwaarden, jaarbereiken en decennia blijven letterlijk bewaard en worden
   daarnaast vertaald naar `jaar_van`, `jaar_tot` en een precisieklasse.
6. `location_precision_m='bron niet opgegeven'` wordt geen getal maar
   `nauwkeurigheidsstatus='niet_opgegeven'`; numerieke waarden blijven numeriek.
7. `name_status` wordt zonder inhoudelijke verruiming naar de drie
   bewijsstatussen vertaald.
8. Absolute T7-paden worden vervangen door gecontroleerde Zotero-item-keys of
   een logische, niet-apparaatafhankelijke bronverwijzing.

Geen ontbrekend pad of gebied krijgt een gereconstrueerde geometrie. Bunkerpad
en Klippad blijven historische naamobjecten zonder geometrie.

## Relatie tot bestaande tabellen

`plot_gebied`, `plot_gebied_geometrie`, `meijendel_basisgebied` en
`meijendel_natura2000` behouden hun bestaande betekenis en inhoud. De importer
maakt geen automatische koppeling op naam. Eventuele latere relaties naar
Kijfhoek, Bierlap, Voorlinden, Hertenkamp of andere bestaande objecten krijgen
een afzonderlijke, inhoudelijk beoordeelde koppeltabel.

De naamlaag bevat geen soortwaarnemingen. De centrale taxonroute via `taxa`,
`taxa_bronkoppeling` en `taxon_groepen` verandert daarom niet. De
databasebrede taxonaudit wordt na de schemawijziging wel opnieuw uitgevoerd om
onbedoelde neveneffecten uit te sluiten.

## Darwin Core en TDWG TCS

De semantiek sluit aan bij Darwin Core Location: interne object-ID als
`locationID`, voorkeursnaam als `locality`, letterlijke bronnaam als
`verbatimLocality`, geometrie als `footprintWKT` met `footprintSRS=EPSG:28992`,
nauwkeurigheid als `coordinateUncertaintyInMeters` en broninformatie als
`georeferenceSources` en `georeferenceRemarks`.

TDWG TCS is niet inhoudelijk van toepassing omdat de levering geen taxa of
taxonconcepten bevat.

## Import- en herstelketen

1. Valideer bestanden, headers, checksums, sleutels, foreign-keydekking,
   toegestane waarden, perioden en geometrieën zonder databasewijziging.
2. Maak schema, importer en auditscripts en bewijs deze eerst op een
   afzonderlijke testdatabase.
3. Maak vlak vóór live uitvoering een logisch schema- en gegevensback-up van
   de betrokken databaseobjecten en leg de hash vast.
4. Voer schema en import in één gecontroleerde lokale uitvoerketen uit.
5. Controleer aantallen, sleutels, bronfeaturedekking, geometrievaliditeit,
   ruimtelijke SRID, idempotentie en ongewijzigde bestaande tabellen.
6. Voer de bestaande databasebrede taxon- en workspacecontroles uit.
7. Werk Markdown en DOCX van het blijvende bronregister inhoudelijk gelijk bij,
   render de 35 pagina's opnieuw en controleer de gewijzigde pagina's en het
   totale document.

Herstel gebruikt de vlak voor import gemaakte back-up en de bijbehorende
codeversie. Er wordt geen oudere algemene productiedump over de levende lokale
database geplaatst.

## Tests en acceptatie

De geautomatiseerde controles bewijzen minimaal:

- 182 objecten, 299 vermeldingen, 8 bronnen, 71 geometrieën en 111 actuele
  beoordelingen voor ontbrekende geometrie;
- 47 unieke TOP10NL-feature-ID's en 60 unieke OSM-way-ID's zonder verweesde
  koppelingen;
- 0 dubbele primaire sleutels en 0 ontbrekende foreign keys;
- 0 lege of ongeldige geometrieën en uitsluitend SRID 28992;
- exacte overeenkomst tussen GeoJSON en RD-WKT na herprojectie;
- correcte omzetting van de twee samengestelde namen, perioden en onbekende
  nauwkeurigheid;
- ongewijzigde aantallen en inhoudshashes van vooraf geselecteerde bestaande
  referentie- en taxonroutes;
- een tweede import van dezelfde levering verandert geen rijtelling of inhoud.

## Buiten reikwijdte

- geen zware regeneratie van `Meijendel.sql`;
- geen Shiny-cachebouw;
- geen wijziging aan dashboard, website of Shiny;
- geen VPS-publicatie;
- geen nieuwe externe informatievraag;
- geen reconstructie van Bunkerpad, Klippad of andere ontbrekende geometrieën.

Na de lokale databasewijziging wordt Ton afzonderlijk gevraagd of de zware
export- en cacheketen nodig is.
