# Importbestanden recreatie

## Actieve invoer

De oude CSV- en SQL-invoerroute uit 2024 is verwijderd. De 220 bijbehorende
databaseregels zijn ingetrokken. Actieve infrastructuurinvoer loopt uitsluitend
via `gis/scripts/import_osm_fietspaden.py`.

Toegankelijkheid wordt vanaf 7 november 2026 niet meer per plot geïmporteerd. Nieuwe invoer bestaat uit werkelijk omsloten vlakken:

- `toegankelijkheidsgebied` bewaart de blijvende identiteit en naam;
- `toegankelijkheidsgebied_versie` bewaart status, geometrie, bron en geldigheid;
- `toegankelijkheidsgebied_plot_afleiding` bewaart uitsluitend opnieuw berekenbare doorsnijdingen met plots.

Toegestane statussen zijn `afgesloten`, `toegankelijk` en `toegankelijk_met_toegangskaart`. Voor iedere bestaande en toekomstige gebiedsversie is `geldig_vanaf` standaard 1 januari 1955, op basis van Tons inschatting. `geldig_tot = NULL` betekent actueel totdat een einddatum wordt ingevoerd.

De invoer en herberekening lopen via `gis/scripts/migrate_toegankelijkheidsgebieden.py`. De actuele invoer bevat zes gebieden, zes versies en 46 positieve plotdoorsnijdingen. Een status van een volledige kavel is nooit handmatige invoer: zij wordt uit de oppervlakteaandelen van de geldige gebiedsversies afgeleid.

Voetpaden, fietspaden, wegen en parkeerplaatsen worden vanaf 8 november 2026
afzonderlijk en versieerbaar geïmporteerd. De tabellen scheiden bronmoment,
blijvende OSM-objectidentiteit, geometrische versie en afgeleide
plotdoorsnijding. Een nieuwe snapshot overschrijft oudere versies niet. De
huidige eerste versies hebben op Tons aanwijzing `geldig_vanaf = 1955-01-01`,
grondslag `inschatting` en `geldig_tot = NULL`; het OSM-bronmoment blijft als
herkomst bewaard. De views
`v_infrastructuursegment_actueel` en `v_infrastructuursegment_historie` bieden
respectievelijk de nieuwste lijnstand en alle lijnstanden. Voor parkeerplaatsen
bestaan gelijksoortige voorzieningsviews.

Iedere import bouwt voor het ingangsjaar van de actuele gecombineerde stand
automatisch 165 regels in
`plot_jaar_infra`: `afstand_pad_m`, `padlengte_m_per_ha` en
`afstand_parkeerplaats_m` voor elk van 55 kavels. De eerste twee gebruiken
voet- en fietspaden. Wegen blijven afzonderlijke infrastructuur, maar tellen niet
als pad. De eerste stand begint op 1 januari 1955. Een volgende snapshot voegt
een aggregaatversie toe in haar werkelijke ingangsjaar; herhaling van dezelfde
snapshot vervangt alleen diezelfde versie. `afstand_hoofdtoegang_m` wordt niet
meer gevuld.

## Historische bestanden

`plot_jaar_toegankelijkheid_import.csv`, `plot_jaar_toegankelijkheid_deel_import.csv`, `Ruimtelijke data/11_import_toegankelijkheid.sql` en `Ruimtelijke data/17_import_toegankelijkheid_deel.sql` horen bij de ingetrokken voorlopige kavelregistratie uit 2024. Zij blijven alleen als audit- en herstelmateriaal in Git staan en mogen niet opnieuw als actuele toegankelijkheidsgegevens worden uitgevoerd.

De 55 oude kavelregels, hun 55 herkomstdoelen, de tabel `maatregel_toegankelijkheid_registratie` en de kolom `maatregel_registratie_herkomst.toegang_registratie_id` zijn op 7 november 2026 uit de levende lokale database verwijderd. Bron 101 blijft bestaan voor 139 beheerregistraties uit 1991–1999.

## Controle

Na nieuwe of gewijzigde gebiedsversies controleer je:

1. geldige, niet-lege `MULTIPOLYGON`-geometrie in SRID 28992;
2. precies één toegestane status per versie;
3. geen overlappende geldigheidsperioden voor hetzelfde gebied;
4. opnieuw opgebouwde plotdoorsnijdingen;
5. gezamenlijke statusdekking per plot niet boven 100%;
6. Shiny-contracttests met parser/cacheversie 17.

Na een nieuwe OSM-snapshot controleer je daarnaast bronbestand- en queryhash,
OSM-bronmoment, classificatieverschillen, BGT-dekking, geldigheidsintervallen en
precies drie opnieuw berekende waarden voor elk van 55 kavels.

De zware SQL-export, proefimport, volledige cachebouw en VPS-publicatie volgen pas na afzonderlijke toestemming.
