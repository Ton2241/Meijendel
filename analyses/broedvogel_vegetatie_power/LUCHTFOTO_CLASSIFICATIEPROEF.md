# Luchtfoto classificatieproef

## Conclusie

De openbare RGB- en CIR-luchtfoto's zijn in de nu uitgevoerde vorm niet
geschikt om een jaarlijkse vegetatiestructuurreeks voor de vogelmodellen te
bouwen. Zij herkennen vooral ruimtelijke verschillen in houtige bedekking,
maar een in 2020 getrainde indeling wordt in 2023 onvoldoende teruggevonden en
omgekeerd. Jaarlijkse verschillen kunnen daardoor niet betrouwbaar van
verschillen tussen beeldjaren worden gescheiden.

## Gegevens en selectie

De proef gebruikt tien officiële PDOK-WMS-beelden: RGB en CIR voor 2016, 2020,
2022, 2023 en 2024. De beelden zijn per jaar uit vier JPEG-tegels opgebouwd op
hetzelfde RD-rooster als de AHN-analyse: 3.440 bij 3.018 pixels en 2 meter per
pixel. De bronshapefile bevat 55 vogelplots. M66 en M91 liggen buiten het
Natura 2000-analysegebied en zijn uitgesloten, zodat 53 plots zijn onderzocht.
De 25-centimeterlaag ontbreekt voor 2021 in de officiële RGB- en CIR-WMS.

AHN3, AHN4 en AHN5 leveren de referentieklassen voor respectievelijk 2016,
2020 en 2023. Voor 2016 ligt de AHN3-opname omstreeks 2014 en bestaat dus een
tijdsverschil van ongeveer twee jaar. Vier klassen zijn onderzocht: minder dan
0,5 meter, 0,5 tot 2 meter, 2 tot 5 meter en ten minste 5 meter. In de
rapportage heten die klassen open, laag, struweel en boom. De eerste klasse is
een hoogteklasse. Zij mag niet als synoniem voor kaal zand worden gelezen.

## Toetsing

Een Random Forest is eerst op de ruwe RGB- en CIR-banden, NDVI en helderheid
getraind. Per klasse en per toets zijn 40.000 pixels getrokken; iedere
overdrachtstoets omvat daardoor 160.000 testpixels. De vooraf vastgelegde poort
was een macro-F1 van ten minste 0,60 in beide onafhankelijke toetsen 2020 naar
2023 en 2023 naar 2020.

De ruwe kenmerkenset behaalt 0,469 voor 2020 naar 2023 en 0,420 voor 2023 naar
2020. Geen van beide toetsen haalt de poort. Open terrein wordt nog het best
herkend, met F1 0,645 en 0,704. Struweel blijft steken op 0,375 en 0,325. Voor
bomen is de richting sterk afhankelijk van het beeldjaar: F1 0,464 bij 2020
naar 2023 en 0,213 bij 2023 naar 2020.

Daarna is dezelfde proef herhaald met kleurverhoudingen, genormaliseerde
helderheid en lokale RGB- en NIR-textuur. Dat corrigeert voor radiometrische
verschillen tussen beeldjaren, maar verbetert de overdracht niet. De macro-F1
daalt naar 0,419 en 0,326. De nuluitkomst berust dus niet alleen op een
eenvoudig verschil in belichting.

## Onafhankelijke vergelijking en jaarstabiliteit

De voorspelde houtige bedekking in 2022 is vergeleken met de onafhankelijke
landbedekking van Schmidt-Tauscher, Häger en Van der Hagen. Van de 25
gepubliceerde eenheden hebben 24 een afzonderlijke vogelplotpolygoon; de
samengestelde eenheid M17 heeft die niet. Voor de ruwe kenmerken is de
correlatie tussen voorspeld en gepubliceerd houtig aandeel 0,743, de gemiddelde
absolute fout 0,102 en de gemiddelde afwijking -0,039. Voor de genormaliseerde
kenmerken zijn deze waarden 0,869, 0,106 en -0,080. De rangorde van meer en
minder houtige plots is dus redelijk, maar het absolute aandeel wijkt gemiddeld
circa 10 procentpunt af en wordt onderschat.

Ook tussen opeenvolgende beelden blijven verschillen groot. Tussen 2023 en
2024 bedraagt de mediane absolute verandering per plot met de ruwe kenmerken
4,3 procentpunt voor open, 9,6 voor laag, 3,8 voor struweel en 8,5 voor boom.
Met de genormaliseerde kenmerken is dat respectievelijk 3,1, 4,8, 4,5 en 9,1
procentpunt. Zonder onafhankelijke jaarlijkse referentie kan niet worden
vastgesteld welk deel ecologische verandering is. Gezien de zwakke
overdrachtsscores worden deze verschillen niet als echte jaarverandering
gebruikt.

Water en kaal zand waren in deze proef niet afzonderlijk gevalideerd. AHN
onderscheidt beide niet en destijds was alleen de oppervlaktetabel per plot
beschikbaar. Op 19 oktober 2026 zijn de classificatierasters voor 2001 en 2022
ontvangen. Zij bevatten wel pixelklassen voor water en kaal zand, maar niet de
oorspronkelijke trainingspolygonen of de 125 validatiepunten. Het raster van
2022 kan dus als bestaande kaart met het beeld van 2022 worden vergeleken,
maar is geen onafhankelijke waarheid voor datzelfde beeld en valideert geen
overdracht naar andere jaren.

Sandra Schmidt-Tauscher heeft op 20 oktober 2026 bevestigd dat de
oorspronkelijke classificatie in de Semi-Automatic Classification Plugin een
Random Forest gebruikte met 10 beslisbomen en 5.000 trainingspixels. Bij hun
proeven verminderde de nauwkeurigheid wanneer zij meer bomen of trainingspixels
gebruikten. Dit vult de methodebeschrijving aan, maar maakt de classificatie
niet reproduceerbaar: de gebruikte trainingspixels en validatiepunten zijn niet
meer beschikbaar. Het levert evenmin een onafhankelijke referentie voor andere
beeldjaren.

## Besluit en herhaalbaarheid

De vijf beeldjaren worden niet uitgebreid tot een jaarlijkse reeks en gaan
niet naar de levende database, Shiny of de VPS. De grote GeoTIFFs blijven in
de lokale, door Git genegeerde runmap
`20261012T123500Z-luchtfoto-proef-1d09d26`. De compacte validaties, alle
klasse-uitkomsten, alle 53 plotfracties voor vijf jaren en beide
kenmerkensets, de samenvatting en het downloadmanifest staan onder
`resultaten/luchtfoto_proef_laatste_*`.

De oorspronkelijke classificatierasters van 2001 en 2022 zijn inmiddels
beschikbaar en worden gebruikt voor de ruimtelijke inrichting van die twee
jaren. Zij zijn onvoldoende om de jaarlijkse luchtfotoreeks alsnog toe te
laten. Een nieuwe classificatiepoging vraagt onafhankelijke, per pixel
begrensde referenties voor meer beeldjaren en moet op volledig achtergehouden
plots én jaren worden getoetst. Tot die tijd blijven AHN2–AHN5 de bruikbare,
maar slechts viermaal gemeten bron voor verticale vegetatiestructuur.
