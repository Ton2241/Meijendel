# Landbedekking 2001 en 2022

Deze map bevat de oorspronkelijke levering van Achim Häger van 19 oktober
2026 voor de studie van Schmidt-Tauscher, Häger en Van der Hagen (2025), DOI
`10.1007/s10531-025-03175-x`.

Onder `bron/` staan twee geclassificeerde GeoTIFFs, de bijbehorende QGIS-stijl
en de shapefile van de 25 onderzochte BMP-plots. De bestanden zijn byte voor
byte uit de levering overgenomen. `SHA256SUMS` maakt die identiteit
controleerbaar.

De rasters bevatten zeven geharmoniseerde klassen: struweel, bos, boomgroepen,
lage vegetatie, riet, kaal zand en water. Zij beschrijven 2001 en 2022 op een
raster van ongeveer 5 bij 5 meter in RD New (`EPSG:28992`). Zij zijn twee
momentopnamen, geen jaarlijkse tijdreeks en geen directe meting van
vegetatiehoogte.

De trainingspolygonen, trainingspixels en de 125 punten uit de oorspronkelijke
nauwkeurigheidsbeoordeling zijn niet meer bij de auteurs aanwezig en maken geen
deel uit van deze levering. Sandra Schmidt-Tauscher heeft bevestigd dat de
classificatie in de Semi-Automatic Classification Plugin is uitgevoerd met een
Random Forest van 10 beslisbomen en 5.000 trainingspixels. Hogere aantallen
bomen en trainingspixels gaven bij hun rasters een minder nauwkeurige
classificatie; dit is een uitkomst van hun eigen proef en geen algemene regel
voor Random Forest-modellen.

Achim Häger en Sandra Schmidt-Tauscher hebben op 20 oktober 2026 beiden
schriftelijk ingestemd met gebruik van de twee classificatierasters voor verder
onderzoek. Daarmee mogen de rasters en de daarvan afgeleide resultaten in deze
analyse worden gebruikt. Een open licentie of toestemming voor openbare
verspreiding van de oorspronkelijke GeoTIFFs is niet vastgelegd; de
bronbestanden worden daarom niet zelfstandig gepubliceerd.

De reproduceerbare controle en afleiding van ruimtelijke structuurmaten staat
in `analyses/broedvogel_vegetatie_power/scripts/schmidt_tauscher_landbedekking.py`.
