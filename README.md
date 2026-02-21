\# 

In deze repository vind je een sql op datum met alle (lege) bestanden en verder mijn queries voor data-analyse, rapportages en databasebeheer van de database Meijendel. 

De database is ontworpen voor de analyse van de ontwikkeling van broedvogelterritoria in Meijendel sinds 1958. De gegevens van 1958-1983 zijn afkomstig van de Vogelwerkgroep Meijendel. De gegevens vanaf 1984 zijn gedownload van SOVON.

De database biedt:
- broedvogelterritoria per plot/kavel, soort en jaar
- Koppeling met vogelfamilies, ecologische vogelgroepen, landschapstypen en habitatcodes
- Natura 2000 doelstellingen
- Beheersmatige ingrepen (maatregelen)
- Weerdata sinds 1958

**De databasestructuur**  

_Vogelgegevens_
soorten - Vogelsoorten met EURING codes  
euring - Uitgebreide EURING referentietabel met Latijnse en Nederlandse namen  
familie - Taxonomische indeling op familieniveau  
waarnemingen - Kerngegevens: territoria per soort per plot per jaar (116.681 records)  
trends - Populatietrends per soort en jaar voor Zuid-Holland en Nederland  
vogelstand\_1924 - Uitkomst telling van 1924

_Ecologische classificatie_
evg\_landschapstypen - Landschapstypen (duinen, struweel, grasland, etc.)  
evg\_vogel\_landschapstype - Koppeltabel: welke soorten zijn kenmerkend voor welk landschap  
evg\_vogelgroepen - Ecologische vogelgroepen  
evg\_vogel\_landschapgroep - Koppeltabel met veeleisendheidsscores

_Geografische gegevens_
plots - Telgebieden met identificatie via plot\_id, plot\_naam en kavel\_nummer  
plot\_jaar\_oppervlak - Oppervlakten in km² per plot per jaar (5.293 records)  
plotkolom\_mapping - Hulptabel voor data-import

_Natura 2000 integratie_
habitattypen - Natura 2000 habitattypen met codes en doelstellingen  
plot\_jaar\_habitat - Aandeel van elk habitattype per plot  
kernopgaven - Natura 2000 kernopgaven  
maatregelen - Beheermaatregelen met drukfactoren  
plot\_jaar\_maatregel - Uitgevoerde maatregelen per plot  
richtlijnen - Vogelrichtlijn en andere beschermingsregelingen  

_Koppeltabellen:_
kernopgave\_habitat - Relatie kernopgaven en habitattypen
kernopgave\_soort - Relatie kernopgaven en doelsoorten
maatregel\_habitat - Relatie maatregelen en habitattypen
soort\_habitat - Relatie soorten en habitattypen
soort\_richtlijn - Relatie soorten en beschermingsregelingen
soort\_familie - Relatie soorten en families  

_Tellers en monitoring_
tellers - Vrijwilligers met contactgegevens en lidmaatschapsstatus  
plot\_jaar\_teller - Registratie wie welk plot in welk jaar telde (2.823 records)

_Weergegevens_
weer\_historie\_katwijk - Historische weerdata (temperatuur, wind, neerslag)  
weer\_actueel\_voorschoten - Actuele weerdata vanaf 2016  
weer\_legenda - Toelichting bij weervariabelen  
weer\_totaal - View die historische en actuele data combineert (overgang 4 mei 2016)

**Technische kenmerken**

Database type: MySQL / MariaDB  
Character set: UTF8MB4  
Engine: InnoDB met referentiële integriteit
Tools: GitHub Desktop, Tailscale, Visual Studio Code  
Gegenereerd: TablePlus 6.8.1  
Exportdatum: 18 februari 2026

**Datakwaliteit**
De database bevat validatieregels via CHECK constraints:
- Jaarbereik 1900-2100
- Oppervlakten altijd positief
- Percentages tussen 0 en 100
- Territoria niet negatief
- Postcode en telefoonnummer formaat validatie
- Email format validatie

**Indexering**
Strategische indexen op:
- Jaar, soort\_id en plot\_id combinaties
- Naam velden voor zoekacties
- Foreign key relaties
- Unieke combinaties (plot + soort + jaar)

**Data omvang**
Geschatte omvang op basis van auto\_increment waarden:
- Waarnemingen: 116.681 records
- Plot-jaar combinaties: 5.293 records
- Teller-plot-jaar combinaties: 2.823 records
- Trends: 16.384 records
- Vogelsoorten: 291 stuks
- Families: 66 stuks
- Habitattypen: 28 stuks
- EURING codes: 528 stuks

**Contact en gebruik**
Voor vragen over de database of toegang tot de data, neem contact op met de databeheerder. Hier vind je de SQL-scripts bij deze database.

Laatste update: februari 2026\*