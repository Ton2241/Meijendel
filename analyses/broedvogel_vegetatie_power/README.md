# Broedvogels, vegetatie en omgevingsverandering

Deze directory bevat informatie over de analyse van
de broedvogels van Meijendel, hun relatie met vegetatie en andere biotische en
abiotische factoren, de invloed van tellers en de detecteerbaarheid van
veranderingen.

De eerste drie stappen zijn afgerond. Er staat een reproduceerbare
soort–plot–jaarmatrix, de invloed van teller/tellerteam en geregistreerde
ervaring is geschat en de toegevoegde waarde van drie PQ-vegetatiematen is
onderzocht. Die vegetatiematen verbeteren de voorspelling voor andere plots
niet bestendig. Binnen dezelfde plot is evenmin een duidelijke gemiddelde
vogelreactie gevonden nadat soortenrijkdom, Shannon of totale bedekking
verandert. Daarmee is wel een ruimtelijk verschil tussen plots beschreven,
maar nog geen voorspellende relatie tussen vegetatieverandering en
vogelverandering aangetoond.

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

De lokale MySQL-database `Meijendel` op de iMac is de canonieke
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
standaardafwijking: bij een modelverwachting van tien territoria voor een gemiddeld
teller/tellerteam ligt één standaardafwijking grofweg tussen 6,8 en 14,7. Dit is een modelmatige spreiding,
geen bewijs dat een bepaalde teller vogels heeft gemist of dubbel heeft
geteld.

Meer geregistreerde ervaring in dezelfde plot gaf over de volledige periode
geen duidelijk effect. Meer geregistreerde ervaring in andere
Meijendelplots hing wel samen met hogere aantallen: bij één, drie en vijf
eerdere jaren elders waren de verwachte aantallen gemiddeld 4,2%, 8,6% en
11,2% hoger dan bij nul eerdere jaren. Dit verband bleef zichtbaar in de
analyses met alleen één teller en met telinspanning, maar kan nog niet als een
zuiver leereffect worden uitgelegd.

Voor 121 voldoende gedekte soorten veranderde de jaarlijkse trend door opname
van teller/tellerteam en ervaring mediaan met 0,55 procentpunt in absolute zin.
Bij 31 soorten was de verandering groter dan één procentpunt per jaar. De
onzekerheidsintervallen werden mediaan 11% breder. De inhoudelijke conclusie
is daarom: teller en ervaring mogen in het komende vegetatie- en
powermodel niet worden genegeerd, maar hun effecten moeten binnen de dan
gebruikte gegevens opnieuw worden geschat.

Het vegetatiemodel gebruikt voor de gelijktijdige vergelijking 37.362 geldige
soort–plot–jaarrijen uit 406 vogelplotjaren in 35 plots, voor 155 soorten en de
periode 1989–2025. Alleen Muskuseend heeft binnen deze PQ-overlap geen geldige
modelrij. Verschillen tussen plots zijn zichtbaar: bij een één
standaardafwijking hogere plantensoortenrijkdom, Shannon of totale bedekking is
het gemiddelde verwachte territoriumaantal per soort respectievelijk een
factor 0,80, 0,88 en 0,85 lager. Binnen dezelfde plot liggen de overeenkomstige
factoren met 0,99, 0,98 en 1,01 rond één. De varianten met één tot drie jaar
vertraging geven hetzelfde hoofdbeeld. Dit wijst op blijvende verschillen
tussen plots, niet op een aangetoonde vogelreactie nadat de gemeten vegetatie
in een plot verandert.

Bij vijfvoudig achterhouden van volledige plots verbeterde totale bedekking de
gemiddelde negatief-binomiale logscore licht, maar slechts in twee van vijf
blokken. Soortenrijkdom en Shannon verslechterden die score gemiddeld en waren
eveneens slechts in twee blokken beter. In de tijdstoets waren de relatieve
scores iets gunstiger met PQ, maar de absolute voorspelling ontspoorde bij
enkele sterke kolonieverschuivingen: voor Aalscholver werd in een
plot–jaarcombinatie 14.804 verwacht waar nul territoria waren geteld. Die
tijdstoets geldt daarom als modeldiagnose, niet als bewijs van bruikbare
voorspellende kracht.

## Vaste analysescope

Plotgebonden berekeningen gebruiken standaard
`v_meijendel_analyseplot_actueel`. Kavel 66, Haagsche Golf Club, en kavel 91,
Voorlinden, worden niet meegenomen omdat zij geen onderdeel zijn van het
Natura 2000-analysegebied.

Ontbrekende waarden, letterlijke SOVON-nullen, afgeleide jaarverslagnullen en
formeel afgekeurde SOVON-plotjaren behouden hun verschillende betekenis. Een
ontbrekende waarde wordt niet stilzwijgend nul.
