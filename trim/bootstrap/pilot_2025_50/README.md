# TRIM-bootstrap pilot over 1958–2025

Deze map bevat uitsluitend geaggregeerde diagnostiek van 50 lokale
ontwikkelreplicaties. Het is geen formele uitkomst en mag niet worden
gepubliceerd.

De run `pilot50-2025-20261017T192600` gebruikte R 4.5.3, `rtrim` 2.3.1, één
worker op de iMac en bronhash
`15de9245b0d0fbbd0a65990c6c0d618ff8f0298f712775210fe0b1566a917913`.
Alle 50 replicaties en 10 batches zijn voltooid zonder batchfout. De gemeten
rekentijd was 2.460,4 seconden, gemiddeld 49,2 seconden per replicatie; de
hoogste R-geheugenmeting was 357,0 MB. Swap werd in deze run nog niet gemeten.
Replicaties 1 en 2 zijn daarna opnieuw berekend en waren exact gelijk.

De pilot gebruikte de toenmalige vaste populatie van 35 soorten: soorten met
een volledige gebrugde reeks in de bestaande beschrijvende analyse. Zij liet
zien dat deze toelatingsregel niet streng genoeg was voor de nieuwe formele
brug. Van 21 primaire vaste groepsschatters haalden er 5 minimaal 95% geldige
replicaties; 21 van 21 volledige, wisselend samengestelde
gevoeligheidsschatters haalden die grens wel. De 500-validatie is daarom niet
gestart.

Na de pilot is de kandidaatselectie aangescherpt. Een soort moet nu óók door de
bestaande kwaliteitsselectie voor twee bruikbare modelperioden komen en in de
ongetrokken uitgangsdata een geldige formele brug van 1981–1983 naar 1986–1988
hebben. Voor de ontwikkelset 1958–2025 zijn 93 soorten toegelaten voor twee
perioden, 68 daarvan hebben een geldige formele primaire brug en 33 voldoen ook
aan de volledige-jaarvoorwaarde voor de vaste groepspopulatie. Eén rookreplicatie
met deze gecorrigeerde selectie leverde 7 van 21 geldige primaire vaste groepen
en 21 van 21 geldige volledige gevoeligheidsgroepen. Ook dit is geen basis voor
publicatie of een 500-run; de structurele uitval van vaste groepen blijft eerst
een methodisch beslispunt.

De vier CSV-bestanden bevatten respectievelijk run- en bronidentiteit,
soortgeldigheid, groepsgeldigheid en model-/fallbackfrequenties. Ruwe
replicaties, caches en de SQL-bron blijven buiten Git.
