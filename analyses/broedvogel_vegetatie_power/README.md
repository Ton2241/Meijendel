# Broedvogels, vegetatie en omgevingsverandering

Deze directory bevat alle blijvende informatie over de integrale analyse van
de broedvogels van Meijendel, hun relatie met vegetatie en andere biotische en
abiotische factoren, de invloed van tellers en de detecteerbaarheid van
veranderingen. Het beoogde eindproduct is een artikel voor *Holland's Duinen*.

De analyse wordt buiten Shiny uitgevoerd. Shiny kan later gevalideerde
uitkomsten presenteren, maar bepaalt geen modelkeuze en voert geen
poweranalyse uit.

## Begin hier

- [Analyse op hoofdlijnen en uitkomsten](ANALYSE_HOOFDLIJNEN_EN_UITKOMSTEN.md)
  is het levende inhoudelijke hoofddocument.
- [Besluiten](BESLUITEN.md) bewaart methodische keuzes die niet bij iedere
  vervolgstap opnieuw moeten worden gemaakt.
- [Ontwerp teller- en ervaringsmodel](ONTWERP_TELLER_EN_ERVARINGSMODEL.md)
  specificeert de goedgekeurde tweede analysestap voordat deze wordt
  geïmplementeerd.
- [Implementatieplan teller- en ervaringsmodel](IMPLEMENTATIEPLAN_TELLER_EN_ERVARINGSMODEL.md)
  vertaalt dat ontwerp in zes testgestuurde uitvoertaken.
- [`scripts/`](scripts/README.md) bevat straks alleen de scripts die specifiek
  voor deze analyse zijn geschreven.
- [`resultaten/`](resultaten/README.md) bevat compacte, controleerbare
  einduitkomsten en uitvoermanifesten.
- [`figuren/`](figuren/README.md) bevat uitsluitend definitieve figuren met een
  herleidbare gegevens- en scriptbasis.
- [`artikel/`](artikel/README.md) bevat later het concept en de definitieve
  kopij voor *Holland's Duinen*.

## Bronnen en gegevensopslag

De levende lokale MySQL-database `Meijendel` op de iMac is de canonieke
gegevensbron. Ruwe vogel-, PQ- en omgevingsgegevens worden niet naar deze
directory gekopieerd. Iedere uitvoering legt wel vast welke databaseversie,
selectie, Git-commit en modelinstellingen zijn gebruikt.

Gedeelde gegevensselectie en nulregels worden niet opnieuw geïmplementeerd,
maar overgenomen uit `R/meijendel_cache_contract.R`. Algemene, ook elders
bruikbare helpers blijven onder `R/`; deze directory bevat alleen de
analyse-specifieke aansturing en documentatie.

Grote tijdelijke modelobjecten, caches en proefuitvoer blijven buiten Git.
Compacte tabellen, figuren en manifesten die nodig zijn om conclusies te
controleren mogen na inhoudelijke beoordeling wel worden opgenomen.

## Vaste analysescope

Plotgebonden berekeningen gebruiken standaard
`v_meijendel_analyseplot_actueel`. M66, Haagsche Golf Club, en M91,
Voorlinden, worden niet meegenomen omdat zij geen onderdeel zijn van het
Natura 2000-analysegebied. Een afwijking hiervan wordt vooraf uitdrukkelijk in
het hoofddocument en het uitvoermanifest vermeld.

Ontbrekende waarden, letterlijke SOVON-nullen, afgeleide jaarverslagnullen en
formeel afgekeurde SOVON-plotjaren behouden hun verschillende betekenis. Een
ontbrekende waarde wordt niet stilzwijgend nul.
