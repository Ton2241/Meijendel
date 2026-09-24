# Ruimtelijke lagen van Meijendel

## Drie verschillende begrenzingen

De database gebruikt drie ruimtelijke lagen die niet als onderling
uitwisselbare versies van Meijendel mogen worden behandeld.

1. **Projectgebied.** Dit is de ruime ecologische begrenzing voor toelating tot
   de Meijendel-database. De grens volgt de zee, De Wassenaarse Slag,
   Katwijkseweg, Storm van 's-Gravesandeweg, Jagerslaan, Groot
   Haesebroekseweg, Buurtweg, Landscheidingsweg, Van Alkemadelaan, Zwolsestraat,
   Groningsestraat en Gevers Deynootweg. Bebouwing binnen deze grens hoort bij
   het onderzoekslandschap, ook wanneer zij buiten Natura 2000 ligt.
2. **Natura 2000.** Dit is het Meijendel-deel van de officiële juridische
   begrenzing van gebied 97 Meijendel & Berkheide. De laag is afgeleid als de
   doorsnede van de officiële PDOK-geometrie met het projectgebied. Berkheide,
   ten noorden van De Wassenaarse Slag, valt daardoor buiten deze laag. De laag
   bepaalt niet zelfstandig of een ecologische waarneming tot het project
   behoort.
3. **SOVON-telplots.** Dit zijn geversioneerde onderzoeksgebieden. Zij kunnen
   Natura 2000 en het projectgebied deels overschrijden. De laag beschrijft
   monitoringdekking, niet de buitengrens van Meijendel.

## Toelatingspoort per bronrecord

`meijendel_waarneming_ruimtelijke_status` legt per bronrecord onafhankelijk
vast:

- hoe de locatie bekend is: exact punt, bronpolygoon, plotvlak, benoemde
  locatie of geen geometrie;
- of de geometrie volledig binnen het projectgebied ligt, alleen de grens
  raakt, erbuiten ligt, ongeldig is of ontbreekt;
- of de geometrie binnen Natura 2000 ligt;
- hoeveel SOVON-plots zij raakt en, bij precies één plot, welk plot dat is;
- of het record is toegelaten, ruimtelijk dubbelzinnig is, buiten het gebied
  ligt, geen bruikbare lokalisatie heeft of alleen historische context vormt.

Een punt of polygoon die volledig binnen het projectgebied ligt, passeert de
ruimtelijke toelatingspoort. Een bronpolygoon die het projectgebied alleen
raakt, is **geen bewijs** dat de soort binnen Meijendel is aangetroffen. Zo'n
record krijgt `ruimtelijk_dubbelzinnig` en wordt niet automatisch in lokale
aanwezigheidsanalyses opgenomen.

De bestaande tabel `ndff_open_ruimtelijke_beoordeling` blijft de specifiekere
beoordeling van openbare NDFF-polygonen tegen SOVON-plots. Zij wordt niet
overschreven of hernoemd.

## Bronnen en reproduceerbaarheid

`gis/scripts/build_meijendel_ruimtelijke_lagen.py` haalt de wegassen uit het
Nationaal Wegenbestand, de gemiddelde hoogwaterlijn uit de BRT-zeegebieden en
de officiële Natura 2000-geometrie uit de PDOK-service. Het script begrenst
gebied 97 vervolgens met de projectgrens, zodat alleen Meijendel ten zuiden van
De Wassenaarse Slag resteert. De uitvoer staat in:

`gis/vectors/meijendel_bereik/meijendel_ruimtelijke_lagen.gpkg`

Het manifest naast het GeoPackage bevat de bron- en geometrie-hashes. Alle
geometrieën gebruiken EPSG:28992. Versie `2026-09-24.2` omvat 2.412,044498 ha
projectgebied en 1.862,802455 ha Natura 2000 binnen Meijendel. Het volledige
officiële gebied 97 van 2.878,215078 ha blijft uitsluitend als herkomstmaat in
het manifest staan. De gedocumenteerde aansluitlijnen tussen niet-aansluitende
wegassen blijven als afzonderlijke laag zichtbaar; zij zijn dus niet verstopt
als schijnbaar officiële wegsegmenten.

Officiële bronnen:

- [PDOK Nationaal Wegenbestand](https://www.pdok.nl/ogc-webservices/-/article/nationaal-wegen-bestand-nwb-wegen)
- [PDOK Natura 2000-service](https://www.pdok.nl/-/beschikbaar-bij-pdok-gewijzigde-services-natura-2000-inspire-geharmoniseerd-)
- [Natura 2000-gebied 97: kaart en besluit](https://www.natura2000.nl/gebieden/zuid-holland/meijendel-berkheide/meijendel-berkheide-kaart)
- [PDOK BRT-kustlijn](https://api.pdok.nl/kadaster/brt-zeegebieden/ogc/v1/collections/coastline/items?f=html)
