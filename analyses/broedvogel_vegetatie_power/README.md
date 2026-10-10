# Broedvogels, vegetatie en omgevingsverandering

Deze directory bevat alle blijvende informatie over de integrale analyse van
de broedvogels van Meijendel, hun relatie met vegetatie en andere biotische en
abiotische factoren, de invloed van tellers en de detecteerbaarheid van
veranderingen. Het beoogde eindproduct is een artikel voor *Holland's Duinen*.

De analyse wordt buiten Shiny uitgevoerd. Shiny kan later gevalideerde
uitkomsten presenteren, maar bepaalt geen modelkeuze en voert geen
poweranalyse uit.

De eerste twee stappen zijn afgerond. Er staat een reproduceerbare
soort–plot–jaarmatrix en de invloed van teller/tellerteam en geregistreerde
ervaring is geschat. Die tellerfase laat zien dat teller/tellerteam een
wezenlijke bron van verschil is. Zij levert geen vast percentage op waarmee
tellingen achteraf worden verhoogd of verlaagd. In de volgende modellen wordt
teller/tellerteam als variërend modelonderdeel opgenomen; ervaring in dezelfde
plot en ervaring elders blijven als afzonderlijke, doorlopende variabelen in
het model.

## Begin hier

- [Analyse op hoofdlijnen en uitkomsten](ANALYSE_HOOFDLIJNEN_EN_UITKOMSTEN.md)
  is het levende inhoudelijke hoofddocument.
- [Besluiten](BESLUITEN.md) bewaart methodische keuzes die niet bij iedere
  vervolgstap opnieuw moeten worden gemaakt.
- [Ontwerp teller- en ervaringsmodel](ONTWERP_TELLER_EN_ERVARINGSMODEL.md)
  legt de vooraf vastgestelde methode én de gevolgen van de uitgevoerde tweede
  analysestap vast.
- [Implementatieplan teller- en ervaringsmodel](IMPLEMENTATIEPLAN_TELLER_EN_ERVARINGSMODEL.md)
  is het beknopte uitvoerings- en herhaalbaarheidsverslag van die stap.
- [`scripts/`](scripts/README.md) bevat alleen de scripts die specifiek
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

## Wat nu vaststaat

De telleranalyse gebruikt 203.628 geldige soort–plot–jaarrijen uit 2.007
plotjaren met bekend teller/tellerteam, voor 156 soorten en de periode
1958–2025. De geschatte spreiding die samenhangt met teller/tellerteam bedraagt
op de logschaal 0,382. Dat komt overeen met een factor 1,47 per
standaardafwijking:
bij een modelverwachting van tien territoria voor een gemiddeld
teller/tellerteam ligt één
standaardafwijking grofweg tussen 6,8 en 14,7. Dit is een modelmatige spreiding,
geen bewijs dat een bepaalde teller vogels heeft gemist of dubbel heeft
geteld.

Meer geregistreerde ervaring in dezelfde plot gaf over de volledige periode
geen duidelijk gemiddeld effect. Meer geregistreerde ervaring in andere
Meijendelplots hing wel samen met hogere aantallen: bij één, drie en vijf
eerdere jaren elders waren de verwachte aantallen gemiddeld 4,2%, 8,6% en
11,2% hoger dan bij nul eerdere jaren. Dit verband bleef zichtbaar in de
analyses met alleen één teller en met telinspanning, maar kan nog niet als een
zuiver leereffect worden uitgelegd.

Voor 121 voldoende gedekte soorten veranderde de jaarlijkse trend door opname
van teller/tellerteam en ervaring mediaan met 0,55 procentpunt in absolute zin.
Bij 31
soorten was de verandering groter dan één procentpunt per jaar. De
onzekerheidsintervallen werden mediaan 11% breder. De inhoudelijke conclusie
is daarom helder: teller en ervaring mogen in het komende vegetatie- en
powermodel niet worden genegeerd, maar hun effecten moeten binnen de dan
gebruikte gegevens opnieuw worden geschat.

## Vaste analysescope

Plotgebonden berekeningen gebruiken standaard
`v_meijendel_analyseplot_actueel`. M66, Haagsche Golf Club, en M91,
Voorlinden, worden niet meegenomen omdat zij geen onderdeel zijn van het
Natura 2000-analysegebied. Een afwijking hiervan wordt vooraf uitdrukkelijk in
het hoofddocument en het uitvoermanifest vermeld.

Ontbrekende waarden, letterlijke SOVON-nullen, afgeleide jaarverslagnullen en
formeel afgekeurde SOVON-plotjaren behouden hun verschillende betekenis. Een
ontbrekende waarde wordt niet stilzwijgend nul.
