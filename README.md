# 📊 Mijn SQL Query Bibliotheek

Welkom in mijn persoonlijke verzameling SQL-scripts. In deze repository bewaar ik al mijn queries voor data-analyse, rapportages en databasebeheer van de database Meijendel. 

De database Meijendel legt ecologische data, specifiek gericht op vogelpopulaties, habitats en waarnemingen in het natuurgebied Meijendel vast. De structuur ondersteunt langetermijnonderzoek door vogelstandgegevens te koppelen aan specifieke geografische percelen (plots/kavels), tellers en omgevingsfactoren zoals het weer.

1. Kerngegevens: soort_naamen en Taxonomie  

Deze tabellen vormen de basis voor de identificatie van de vogels.
soorten: De centrale tabel met vogelnamen en hun unieke euring_code-codes (een standaard Europese nummering voor vogelsoorten).
familie: Bevat de Nederlandse en wetenschappelijke namen van vogelfamilies.
euring: Een referentietabel die dient als masterlijst voor euring_code-codes en namen.
soort\_familie: Een koppeltabel die soorten linkt aan hun respectievelijke familie.  

2. Geografie en Monitoring: Plots en Oppervlakte  

Monitoring vindt plaats in specifieke gebieden, in de database "plots" genoemd.
plots: Bevat de vaste gegevens van de onderzoeksgebieden, zoals de naam en het kavelnummer.
plot\_jaar\_oppervlak: Cruciaal voor berekeningen; het legt vast hoe groot een plot was in een specifiek jaar (oppervlakte kan immers over tijd veranderen door beheerskeuzes).
plotkolom\_mapping: Een technische tabel die waarschijnlijk helpt bij het importeren van data uit brede Excel-bestanden waar plots als kolommen worden weergegeven.  

3. Waarnemingen en Trends  

Dit is het hart van de database, waar de feitelijke telgegevens worden opgeslagen.
waarnemingen: De belangrijkste data-tabel. Hierin wordt per plot, per soort en per jaar het aantal territoria vastgelegd. Dit is de standaardmaatstaf voor broedvogelmonitoring.
trends: Bevat de trendmatige ontwikkeling van de vogelsoorten voor Zuid-Holland en Nederland.
Vogelstand\_1924: Een historische tabel met beschrijvingen van de vogelstand uit het jaar 1924, wat dient als historisch ijkpunt.  

4. Ecologie en Beleid  

Deze tabellen voegen context toe aan de waarnemingen door soorten te koppelen aan habitat-eisen en beschermingsstatus.
habitattypen: Beschrijft verschillende landschapstypen (bijv. duinen, bos) en de bijbehorende natuurdoelstellingen.
ecologische\_vogelgroepen: Groepeert vogels op basis van hun ecologische rol of gedrag.
richtlijnen: Bevat namen van beschermingsrichtlijnen (zoals de Vogelrichtlijn of Rode Lijst).
Koppeltabellen: soort\_habitat, soort\_ecogroep, soort\_richtlijn en plot\_jaar\_habitat. Hiermee kan men analyseren of specifieke soorten profiteren van bepaalde habitat-ontwikkelingen.
Toe te voegen: In deze categorie zal nog een tabel met beheermaatregelen, zoals benoemd in Natura 2000-beheerplan Meijendel &Berkheide 2026 - 2032 en de jaarverslagen van vogelwerkgroep - worden toegevoegd.   

5. Tellers  

De database houdt bij wie waar heeft geteld.
tellers: Een uitgebreide tabel met contactgegevens van de vrijwilligers, inclusief hun lidmaatschapstype en controles op postcode- en e-mailformaat.
plot\_jaar\_teller: Legt vast welke teller in welk jaar verantwoordelijk was voor welk plot.  

6. Externe Factoren: Weergegevens  

Om fluctuaties in vogelpopulaties te verklaren, zijn weergegevens toegevoegd.
weer\_katwijk: Dagelijkse meteorologische gegevens (temperatuur, neerslag, zonneschijn) van het nabijgelegen station Katwijk.
weer\_legenda: Verklarende lijst voor de meteorologische codes (zoals TG voor daggemiddelde temperatuur).

Belangrijkste Relaties en Integriteit
Referentiële Integriteit: De database maakt uitgebreid gebruik van FOREIGN KEY constraints. Dit zorgt ervoor dat je bijvoorbeeld geen waarneming kunt invoeren voor een plot dat niet bestaat.
Unieke Constraints: Er zijn veel UNIQUE keys op combinaties zoals (plot_id, soort\_id, jaar). Dit voorkomt dubbele tellingen voor dezelfde soort in hetzelfde gebied.

Hier vind je de SQL-scripts bij deze database.
* SQL Dialect: MySQL 
* Tools: GitHub Desktop, TablePlus, Tailscale, Visual Studio Code

Hoe deze scripts te gebruiken  

1. Kloon deze repository naar je eigen machine.
2. Zorg dat je verbinding hebt met de Meijendel omgeving.
3. Let op: vervang in de scripts altijd de placeholders zoals `<datum_vanaf>` door de gewenste waarden.

---
*Laatste update: februari 2026*