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

De trainingspolygonen en de 125 punten uit de oorspronkelijke
nauwkeurigheidsbeoordeling zijn niet meer bij de auteur aanwezig en maken geen
deel uit van deze levering. De gebruiks- en publicatierechten van de ontvangen
bronbestanden zijn niet afzonderlijk vastgelegd. Gebruik buiten de lokale
projectanalyse of herpublicatie vraagt daarom eerst om een expliciete
rechtencontrole.

De reproduceerbare controle en afleiding van ruimtelijke structuurmaten staat
in `analyses/broedvogel_vegetatie_power/scripts/schmidt_tauscher_landbedekking.py`.
