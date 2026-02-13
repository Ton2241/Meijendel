# 

In deze repository vind je een sql op datum met alle (lege) bestanden en verder mijn queries voor data-analyse, rapportages en databasebeheer van de database Meijendel. 

De database legt ecologische data, specifiek gericht op vogelpopulaties, habitats en andere ‘verstorende’ factoren in het natuurgebied Meijendel vast. De database integreert ecologische, geografische en klimatologische data om trends, dichtheden en habitatrelaties te analyseren.

De database biedt:
- Registratie van broedvogelwaarnemingen per plot, soort en jaar
- Koppeling tussen vogelsoorten en landschapstypen
- Berekening van vogeldichtheden op basis van territoria en oppervlakten
- Beheer van telgegevens en vrijwilligers
- Integratie met Natura 2000 doelstellingen
- Historische referentiedata vanaf 1924
- Klimaatdata voor correlatiestudies

De databasestructuur  

Vogelgegevens
soorten - Vogelsoorten met EURING codes  
euring - Uitgebreide EURING referentietabel met Latijnse en Nederlandse namen  
familie - Taxonomische indeling op familieniveau  
waarnemingen - Kerngegevens: territoria per soort per plot per jaar (116.681 records)  
trends - Populatietrends per soort en jaar voor Zuid-Holland en Nederland  
vogelstand\_1924 - Uitkomst telling van 1924

Ecologische classificatie
evg\_landschapstypen - Landschapstypen (duinen, struweel, grasland, etc.)  
evg\_vogel\_landschapstype - Koppeltabel: welke soorten zijn kenmerkend voor welk landschap  
evg\_vogelgroepen - Ecologische vogelgroepen  
evg\_vogel\_landschapgroep - Koppeltabel met veeleisendheidsscores  
analyse\_ecologie\_kavels - Bezettingspercentages per ecologische groep

Geografische gegevens
plots - Telgebieden met identificatie via plot\_id, plot\_naam en kavel\_nummer  
plot\_jaar\_oppervlak - Oppervlakten in km² per plot per jaar (5.293 records)  
plotkolom\_mapping - Hulptabel voor data-import

Natura 2000 integratie
habitattypen - Natura 2000 habitattypen met codes en doelstellingen  
plot\_jaar\_habitat - Aandeel van elk habitattype per plot  
kernopgaven - Natura 2000 kernopgaven  
maatregelen - Beheermaatregelen met drukfactoren  
plot\_jaar\_maatregel - Uitgevoerde maatregelen per plot  
richtlijnen - Vogelrichtlijn en andere beschermingsregelingen  

Koppeltabellen:
kernopgave\_habitat - Relatie kernopgaven en habitattypen
kernopgave\_soort - Relatie kernopgaven en doelsoorten
maatregel\_habitat - Relatie maatregelen en habitattypen
soort\_habitat - Relatie soorten en habitattypen
soort\_richtlijn - Relatie soorten en beschermingsregelingen
soort\_familie - Relatie soorten en families  

Tellers en monitoring
tellers - Vrijwilligers met contactgegevens en lidmaatschapsstatus  
plot\_jaar\_teller - Registratie wie welk plot in welk jaar telde (2.823 records)

Klimaatgegevens
weer\_historie\_katwijk - Historische weerdata (temperatuur, wind, neerslag)  
weer\_actueel\_voorschoten - Actuele weerdata vanaf 2016  
weer\_legenda - Toelichting bij weervariabelen  
weer\_totaal - View die historische en actuele data combineert (overgang 4 mei 2016)

Import en hulptabellen
import\_waarnemingen\_breed - Staging tabel voor data-import (breed formaat met plotkolommen)  
import\_waarnemingen\_lang - Staging tabel voor data-import (genormaliseerd formaat)  
habitattypen\_doelstelling - Hulptabel voor habitatdata

- Technische kenmerken

Database type: MySQL / MariaDB  
Character set: UTF8MB4  
Engine: InnoDB met referentiële integriteit  
Gegenereerd: TablePlus 6.8.1  
Exportdatum: 13 februari 2026

Datakwaliteit
De database bevat validatieregels via CHECK constraints:
- Jaarbereik 1900-2100
- Oppervlakten altijd positief
- Percentages tussen 0 en 100
- Territoria niet negatief
- Postcode en telefoonnummer formaat validatie
- Email format validatie

Indexering
Strategische indexen op:
- Jaar, soort\_id en plot\_id combinaties
- Naam velden voor zoekacties
- Foreign key relaties
- Unieke combinaties (plot + soort + jaar)

Data omvang
Geschatte omvang op basis van auto\_increment waarden:
- Waarnemingen: 116.681 records
- Plot-jaar combinaties: 5.293 records
- Teller-plot-jaar combinaties: 2.823 records
- Trends: 16.384 records
- Vogelsoorten: 291 stuks
- Families: 66 stuks
- Habitattypen: 28 stuks
- EURING codes: 528 stuks

Contact en gebruik
Voor vragen over de database of toegang tot de data, neem contact op met de databeheerder. Hier vind je de SQL-scripts bij deze database.
SQL Dialect: MySQL  
Tools: GitHub Desktop, TablePlus, Tailscale, Visual Studio Code

Laatste update: februari 2026*