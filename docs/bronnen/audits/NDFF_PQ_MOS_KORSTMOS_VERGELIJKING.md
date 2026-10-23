# NDFF mossen en korstmossen tegenover de provinciale PQ-reeks

**Stand 23 oktober 2026. Regelversie `pq-mos-korstmos-audit-v1`.** Dit is een vergelijking per positieve taxonregel, geen wijziging van de provinciale PQ-reeks of van de NDFF-bronregistraties. De reproduceerbare selectie staat in `gis/scripts/audit_ndff_pq_mos_korstmos.py`; de uitkomst per NDFF-identiteit in `gis/audit/ndff_pq_mos_korstmos_audit_v1.csv`.

## Uitkomst

De kandidaatselectie omvat 10.903 NDFF-mosregels en 2.998 NDFF-korstmosregels uit 1981–2025. Zij is vergeleken met 2.007 provinciale opnamen en 53.122 provinciale taxonregels uit dezelfde periode. De taxonregel, niet de complete opname, is de basiseenheid van de vergelijking.

| Uitkomst per NDFF-regel | Mossen | Korstmossen | Betekenis |
| --- | ---: | ---: | --- |
| Sterke strikte overeenkomst | 3.020 | 936 | Zelfde datum en centraal taxon, provinciepunt in NDFF-polygoon, verenigbare Braun-Blanquetklasse en één-op-één-koppeling na samenvoegen van identieke NDFF-bronsignaturen. |
| Nabije kandidaat | 199 | 29 | Dezelfde overige kenmerken, maar het provinciepunt ligt buiten de polygoon en maximaal 8 meter ervan af. Geen bewezen 5-metercorrectie. |
| Meervoudige kandidaat | 245 | 47 | Datum, taxon, bedekking en locatie passen, maar meerdere bronregels of provinciale resultaten blijven mogelijk. |
| Nabije locatie met afwijkende bedekking | 8 | 6 | Zelfde datum en taxon, binnen 8 meter, maar de bedekkingsklassen komen niet overeen. |
| Datum en taxon gelijk, locatie niet nabij | 2.577 | 551 | Geen aanwijzing voor dezelfde opname op de getoetste plaats. |
| Geen gelijke datum en taxon | 4.854 | 1.429 | Geen kandidaat in de huidige provinciale reeks. Dit bewijst geen onafhankelijke telling. |

De 3.956 sterke NDFF-regels vertegenwoordigen **3.615 verschillende datum–taxon–geometrie–bedekkingssignaturen**, die één-op-één aansluiten op 3.615 provinciale taxonregels in **770 provinciale opnamen**. Bij 341 van die signaturen staan twee NDFF-identiteiten met dezelfde bronwaarden, één onder protocol `12.007` en één onder `12.202`. Die twee NDFF-regels zijn daarom niet twee onafhankelijke metingen. Bij 417 van de 770 provinciale opnamen komen bovendien alle mossentaxa of alle korstmostaxa van die opname overeen, met minimaal twee taxa in die groep. Dit versterkt de inhoudelijke koppeling, maar zegt niets over de volledigheid van de vaatplantenlijst.

Alle sterke en nabije één-op-één-koppelingen betreffen opnamen uit **1981–2017**. Van de 13.901 NDFF-kandidaten dateren 140 uit 2018–2025; in deze selectie is voor geen daarvan een sterke of nabije één-op-één-koppeling gevonden. De provinciale PQ-tabellen bevatten in 2018–2025 wel 2.465 mos- en 582 korstmostaxonregels. Dit is een vergelijking van de huidige leveringen, geen verklaring voor het verschil.

## Beslisregel

`sterk_strikt` betekent **zeer waarschijnlijk dezelfde positieve PQ-taxonregistratie**, niet een met een oorspronkelijke bron-ID bewezen dubbel. De NDFF-identiteit bevat geen provinciaal opname- of resultaat-ID. Het NDFF-vlak is bovendien een onzekerheidsbuffer. Daarom krijgt geen regel op basis van deze audit de status `exact` en wordt geen regel verwijderd of als nieuwe provinciale PQ-opname toegevoegd. Ook de 228 nabije en 292 meervoudige kandidaten blijven afzonderlijk herkenbaar.

Bij gecombineerde analyse blijven de provinciale PQ-resultaten leidend. Tel de sterke NDFF-overeenkomsten niet ernaast op. Gebruik de overige kandidaatregels evenmin als zelfstandige PQ-trendreeks: een niet gevonden match kan komen door gebiedsselectie, onvolledige NDFF-aanlevering, naam- of locatieverschil of werkelijk een andere opname. De 767 NDFF-mos- en korstmosregels uit 1952–1980 hebben buiten deze vergelijking de bestaande status historische vegetatiecontext; de provinciale reeks begint in 1981.

De vergelijking gebruikt de actuele centrale taxonkoppeling, `DATE(periode_start)` tegenover provinciale `opname_datum`, de aangeleverde Braun-Blanquetklassen en twee ruimtelijke toetsen: provinciaal punt binnen de openbare NDFF-polygoon, of maximaal 8 meter afstand. De tweede toets is uitsluitend een gevoeligheidscontrole rond de door NDFF gemelde coördinaatverschillen. De brongeometrieën zijn niet verplaatst. Regels met gelijke datum en soort maar zonder nabije locatie zijn niet als dubbel aangemerkt. De per-regel-CSV bewaart NDFF-ID, eventuele provinciale opname- en taxonregel-ID, afstand, classificatie en de grootte van de NDFF-bronsignatuur; geen exacte gevoelige geometrie is geëxporteerd.
