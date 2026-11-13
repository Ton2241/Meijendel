# Voorbereiding Lansu-modeltoets 2020

## Uitkomst

De lokale modelinvoer is voorbereid voor vijf aaneengesloten buitenduinplots:
M13s, M13, M14, M15 en M16. Het product bevat 25 volledige modeltegels en de
zeven banden uit de gepubliceerde configuratie van Lansu et al.: rood, groen,
blauw, nabij-infrarood, DSM, kroonhoogte en afstand tot zee. De invoer is nog
geen habitatkaart. Classificatie begint pas wanneer de opgevraagde gewichten
zijn ontvangen en het checkpoint de technische controle doorstaat.

De grote bron- en rasterbestanden staan in de geregistreerde T7-werkmap
`/Volumes/T7 Data/Home_Ton/Proefomgevingen/lansu-modelinvoer-2020-2026-11-13`.
Git bevat alleen de reproduceerbare scripts en deze beslisbeschrijving. Er is
niets naar de levende database, Shiny of de VPS geschreven.

## Pilotselectie

De vijf plots zijn ruimtelijk aaneengesloten en beslaan samen de overgang van
open en lage duinvegetatie naar struweel, met in M14-M16 ook water. De
onafhankelijke kaart van Schmidt-Tauscher, Hager en Van der Hagen uit 2022
laat daardoor in een compact gebied alle voor de eerste toets belangrijke
structuren zien. M66 en M91 vallen vanzelfsprekend buiten de selectie.

| Plot | Open zand | Lage vegetatie | Struik | Bomen en bos | Water |
|---|---:|---:|---:|---:|---:|
| M13s | 5,5% | 51,0% | 36,8% | 6,4% | 0,1% |
| M13 | 11,2% | 59,2% | 24,5% | 4,8% | 0,0% |
| M14 | 7,5% | 42,5% | 24,3% | 10,1% | 11,3% |
| M15 | 15,0% | 51,9% | 21,7% | 3,8% | 4,8% |
| M16 | 19,2% | 34,9% | 21,7% | 10,6% | 9,9% |

De percentages zijn uitsluitend gebruikt om de pilot gevarieerd te kiezen.
Zij zijn geen training of validatie van het Lansu-model.

## Bronnen en voorbewerking

De RGB- en CIR-orthofoto's uit 2020 zijn als originele GeoTIFFs van GeoTiles
opgehaald. Voor de pilot zijn kaartbladen `30EZ1` en `30GN1` nodig. Beide zijn
25 centimeter en staan onder CC BY 4.0. Band 1 van CIR levert nabij-infrarood.

AHN4 levert DSM en DTM op 50 centimeter uit de al gecontroleerde historische
AHN-run van 12 oktober 2026. De waarden zijn met nearest-neighbour op het
25-centimeterrooster gezet. Het modelcontract gebruikt DSM en DSM minus DTM
in centimeters. Binnen de vijf plots bevat DSM voor 93,4% bronwaarden; voor
kroonhoogte is zowel DSM als DTM voor 91,9% aanwezig. De resterende pixels,
vooral water, zijn in de modelinvoer nul. Dat is noodzakelijk omdat de
gepubliceerde datalader iedere pixel normaliseert en geen afzonderlijk
nodatamasker toepast. De oorspronkelijke dekkingsfracties blijven in het
manifest staan.

Lansu et al. leidden afstand tot zee en de landelijke uitsluitingsmaskers af
uit LGN2020. LGN2020 is nog niet ontvangen: de open download wordt pas na een
formulier met naam en e-mailadres verstrekt. Voor de gereedstaande
Meijendel-pilot is afstand tot zee daarom reproduceerbaar afgeleid van de
officiële gemiddelde hoogwaterlijn uit de BRT-bronlaag op een rooster van
5 meter en vervolgens nearest-neighbour naar 25 centimeter gebracht. Dit
levert een volledige technische modelband, maar is nog geen bewijs dat de
pixelwaarden exact gelijk zijn aan die van Lansu. Na ontvangst van LGN2020
wordt het verschil gekwantificeerd en wordt ook het uitsluitingsmasker
gereconstrueerd.

## Rastercontract en controle

Het raster `lansu_modelinvoer_2020_m13s_m16.tif` heeft EPSG:28992, een
resolutie van 25 centimeter en 10.240 bij 10.240 pixels. De begrenzing is
uitgelijnd op 25 modeltegels van 2.048 bij 2.048 pixels. Het GeoTIFF is
307 MB en gebruikt de vaste bandvolgorde uit de configuratie. Alle zeven
banden zijn binnen de vijf pilotplots volledig numeriek gevuld. Het manifest
en het afzonderlijke controlerapport bevatten bronpaden, SHA256-hashes,
bandvolgorde, normalisatiewaarden, klassevolgorde en dekking.

De code bewaakt daarnaast het checkpointcontract. Het ontvangen bestand moet
een eerste convolutie met zeven invoerkanalen en een laatste convolutie met
zeven uitvoerklassen bevatten. De klassevolgorde is `Bare_sand`, `Shrubs`,
`Fresh_water`, `Grass`, `Broadl_trees`, `Needl_trees`, `Other`. Een checkpoint
dat hiervan afwijkt wordt niet uitgevoerd.

## Vervolg na ontvangst van de gewichten

Eerst wordt het checkpoint met `controleer_lansu_checkpoint.py` gelezen en
gehasht. De controle stopt wanneer de eerste of laatste convolutie niet zeven
kanalen bevat. Daarna worden ook de modelvariant en sleutelnamen, de vaste
band- en klassevolgorde, de normalisatiewaarden en de verwachte uitvoervorm
van 1.860 bij 1.860 pixels per invoertegel van 2.048 bij 2.048 pixels vergeleken
met de ontvangen modeldocumentatie. Als Eva Lansu een referentievoorspelling of
controlesom meelevert, moet onze lokale uitvoer daarmee overeenkomen. Pas
daarna volgt inferentie op exact deze 25 tegels. De voorspelling wordt
alleen binnen de vijf pilotplots beoordeeld en vergeleken met de kaart van
2022 en de AHN4-hoogteklassen. Omdat 2022 niet onafhankelijk is van het
beeldmateriaal waarmee die kaart is gemaakt, blijft daarnaast een beperkte
handmatige validatieset nodig. Pas wanneer klassefouten en ruimtelijke
patronen aanvaardbaar zijn, wordt besloten over opschaling naar de overige
Natura 2000-plots en andere beeldjaren.
