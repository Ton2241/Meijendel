# Ontvlechten dubbel afgesloten gebieden

## Intentie

Verwijder de twee geometrische dubbelregistraties tussen afgesloten gebieden zonder een inhoudelijke statuskeuze te maken. Het gezamenlijke afgesloten oppervlak moet gelijk blijven en de nauwkeuriger brongeometrieën moeten ongewijzigd blijven.

## Gekozen aanpak

De actuele geometrieën van `garmin_24999201739_omsloten_gebied` en `harstenhoek_afgesloten_1955` blijven exact behouden. Hun overlap wordt uitsluitend uit `ruygenhoek_afgesloten_1955` gesneden. Ruygenhoek is gebaseerd op de grovere kavelgeometrieën M32 en M33; Garmin en Harstenhoek zijn afzonderlijk ingetekende en visueel goedgekeurde bronvlakken.

Alternatieven zijn verworpen:

- samenvoegen tot één afgesloten gebied wist de drie afzonderlijke identiteiten en herkomstketens;
- snijden in Garmin of Harstenhoek tast de nauwkeuriger, visueel goedgekeurde brongeometrieën aan.

## Invarianten

- alle drie gebieden behouden status `afgesloten`;
- `geldig_vanaf = 1955-01-01` en `geldig_tot = NULL` blijven ongewijzigd;
- Garmin en Harstenhoek behouden geometrie en geometriehash;
- Ruygenhoek overlapt na correctie elk van beide voor minder dan 0,001 m²;
- de geometrische unie van de drie afgesloten gebieden verandert voor minder dan 0,01 m²;
- de zeven overlapparen met verschillende statussen blijven in deze stap onaangeroerd;
- vóór de databasewijziging wordt een herstelkopie gemaakt;
- zware SQL-export, proefimport, volledige Shiny-cachebouw, merge en VPS-publicatie blijven geparkeerd.

## Verantwoording en controle

De migratie krijgt een afzonderlijke technische bronregel voor de topologiecorrectie. De contracttest bewijst eerst de bestaande dubbele overlap en daarna de invarianten. Na toepassing worden de levende database, kavelafleidingen, het Meijendel-bronregister in Markdown en DOCX en een controlekaart bijgewerkt en gecontroleerd.
