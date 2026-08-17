# NDFF-protocolaudit per soortgroep

## Besluit

De 810.830 unieke FFV-waarnemingsregels zijn **niet rechtstreeks trendklaar**.
Een gevalideerde waarneming en een geregistreerde protocolnaam bewijzen nog niet
dat de FFV-export alle telbezoeken, inspanning, telobjecten en afleidbare
nulwaarnemingen bevat. De life Meijendel-database blijft daarom ongewijzigd.

Alleen records uit een voor de soortgroep passend doelgericht meetnet zijn
kandidaat voor vervolg. Daarvoor worden eerst de volledige brondata bij de
meetnetbeheerder opgevraagd. NDFF noemt protocollen gestandaardiseerde
telmethoden, maar vermeldt ook dat bruikbare nullen alleen uit sterke
protocollen met goede metadata afleidbaar en beperkt toegankelijk zijn. CBS
beoordeelt NEM-kwaliteit bovendien per meetprogramma en meetdoel; een landelijke
kwaliteitsbeoordeling is geen automatische lokale Meijendeltrend.

## Uitkomst per soortgroep

| Soortgroep | Records | Doelmeetnet | SNL | PQ-risico | Advies |
|---|---:|---:|---:|---:|---|
| Amfibieen | 12.982 | 2.560 (19,72%) | 0 | 0 | Kansrijk na brondata |
| Dagvlinders | 129.238 | 80.442 (62,24%) | 247 | 0 | Kansrijk na brondata |
| Eencelligen | 156 | 0 | 0 | 0 | Niet opnemen voor trends |
| Geleedpotigen (overig) | 247 | 0 | 0 | 0 | Niet opnemen voor trends |
| Insecten (overig) | 1.888 | 0 | 0 | 0 | Niet opnemen voor trends |
| Kevers | 8.079 | 0 | 0 | 0 | Niet opnemen voor trends |
| Korstmossen | 28.643 | 643 (2,24%) | 461 | 3.273 | Voorwaardelijk; PQ-blokkade |
| Kranswieren, wieren en algen | 555 | 0 | 33 | 14 | Voorwaardelijk; PQ-blokkade |
| Kreeftachtigen | 2.052 | 0 | 0 | 0 | Niet opnemen voor trends |
| Libellen | 32.325 | 3.280 (10,15%) | 278 | 0 | Kansrijk na brondata |
| Microvlinders | 22.849 | 0 | 0 | 0 | Niet opnemen voor trends |
| Mossen | 32.353 | 424 (1,31%) | 9 | 11.395 | Voorwaardelijk; PQ-blokkade |
| Nachtvlinders | 72.978 | 596 (0,82%) | 0 | 0 | Kansrijk na brondata |
| Ongewervelden (overig) | 1.760 | 0 | 0 | 0 | Niet opnemen voor trends |
| Reptielen | 3.347 | 957 (28,59%) | 0 | 0 | Kansrijk na brondata |
| Schimmels | 77.670 | 4.734 (6,10%) | 0 | 0 | Kansrijk na brondata |
| Snavelinsecten | 7.819 | 0 | 0 | 0 | Niet opnemen voor trends |
| Spinachtigen | 2.480 | 0 | 0 | 0 | Niet opnemen voor trends |
| Sprinkhanen en krekels | 9.163 | 0 | 1.468 | 0 | Alleen periodieke gebiedstoestand na SNL-brondata |
| Vaatplanten | 277.812 | 10.549 (3,80%) | 3.777 | 82.636 | Voorwaardelijk; PQ-blokkade |
| Vissen | 1.280 | 46 (3,59%) | 0 | 0 | Kansrijk na brondata |
| Vleermuizen | 9.912 | 6.596 (66,55%) | 0 | 0 | Kansrijk na brondata |
| Vliegen en muggen | 10.495 | 0 | 0 | 0 | Niet opnemen voor trends |
| Vliesvleugeligen | 12.365 | 0 | 0 | 0 | Niet opnemen voor trends |
| Weekdieren | 13.043 | 2.772 (21,25%) | 0 | 0 | Kansrijk na brondata |
| Zoogdieren (overig) | 39.339 | 16.465 (41,85%) | 0 | 0 | Kansrijk na brondata |

`Doelmeetnet` betekent hier uitsluitend: protocol en soortgroep passen bij
elkaar. Het betekent niet dat deze FFV-regels mogen worden geïmporteerd of
geanalyseerd als trend. Een voorbeeld van de soortgroeptoets: 1.535
Vliesvleugeligen zijn geregistreerd binnen het Vlindermeetnet, maar zijn
bijvangst voor die soortgroep en tellen daarom niet als trendmeetnet.

## Toelatingsklassen

1. **Niet opnemen voor trends:** losse waarnemingen, ObsIdentify, iNaturalist,
   collecties, literatuur en atlasgegevens. Bewaar deze alleen in de externe
   staging als verspreidingscontext.
2. **Gestructureerde context:** een inventarisatieprotocol kan aanwezigheid
   ondersteunen, maar zonder volledige bezoeken en inspanning geen afwezigheid,
   detectiekans of populatietrend.
3. **Doelgericht meetnet — brondata opvragen:** vraag volledige telobjecten,
   bezoeken, inspanning, protocolversies, tellingen en nullen op bij de
   beheerder. Controleer daarna lokale dekking en continuiteit.
4. **SNL-gebiedsmonitoring — brondata opvragen:** bruikbaar voor periodieke
   toestand of beheercycli indien de volledige meetronden beschikbaar zijn;
   niet automatisch als jaarlijkse trend.
5. **PQ-overlap eerst uitsluiten:** records uit `12.007 Vegetatieopnamen` en
   `12.202 LMF-M&N` blijven buiten de life-tabellen totdat
   `ndff_pq_koppeling` de bronopname heeft beoordeeld. De bestaande PQ-reeks
   blijft leidend.

## Minimale acceptatietoets voor brondata

Een meetnetdeel wordt pas kandidaat voor een `ndff_<soortgroep>`-tabel als alle
volgende punten controleerbaar zijn:

- stabiel telobject en geversioneerde geometrie;
- datum en afzonderlijk bezoek-/sampling-event-ID;
- protocolnaam én protocolversie;
- vastgelegde duur, route/lengte/oppervlakte, methode en apparatuur waar
  relevant;
- complete soortenlijst of expliciet afleidbare nulwaarnemingen;
- telling/schaal die binnen jaren vergelijkbaar is;
- bronhouder, validatiestatus en bekende kwaliteitsbeperkingen;
- voldoende herhaalde telobjecten binnen Meijendel en de gekozen analysetijd;
- eenduidige relatie met de geversioneerde SOVON-plotlaag;
- geen onbeoordeelde PQ-dubbeling, vervaging of meerplot-toewijzing.

Pas daarna volgt per soort en meetnet een dekkingstabel `plot x jaar`, controle
op methodebreuken en een modelkeuze die bij het protocol hoort. Ontbrekende
tellingen worden nooit automatisch als nul of met machine learning ingevuld.

## Reproduceerbare bestanden

- script: `gis/scripts/analyse_ndff_protocollen.py`;
- rapport: `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/ndff_protocolaudit_1950_2025/ndff_protocolaudit_meijendel_1950_2025.html`;
- soortgroepsamenvatting: dezelfde map, `ndff_protocolaudit_soortgroepen.csv`;
- volledige protocolmatrix: dezelfde map, `ndff_protocolaudit_protocolmatrix.csv`;
- alle berekeningen en bronnen: dezelfde map, `ndff_protocolaudit_resultaten.json`.

## Officiële methodische bronnen

- [NDFF Protocollen](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/)
- [NDFF Bijsluiter](https://ndff.nl/natuurdata/bijsluiter/)
- [NDFF Flora- en Faunaverkenner](https://ndff.nl/natuurdata/afnemen-en-gebruiken/flora-fauna-verkenner/)
- [NDFF Vegetatieopname](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-007-vegetatieopname/)
- [NDFF LMF-M&N](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-202-landelijk-meetnet-flora-milieu-en-natuurkwaliteit/)
- [NDFF LMF-a](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-211-landelijk-meetnet-flora-aandachtssoorten-lmf-a/)
- [CBS Kwaliteitsrapportage NEM 2025](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/meetprogrammas/)
- [CBS methode kwaliteitsbeoordeling](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/kwaliteitsbeoordeling/)
