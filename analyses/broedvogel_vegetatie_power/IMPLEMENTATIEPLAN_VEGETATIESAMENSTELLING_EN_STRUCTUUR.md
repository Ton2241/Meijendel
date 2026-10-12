# Vegetatiesamenstelling en structuur — implementatieplan

**Doel.** Bepalen of de volledige PQ-soortensamenstelling, de brede
IPI-habitatindeling of de onafhankelijke landbedekking van 2001 en 2022 meer
over vogelverandering verklaren en voorspellen dan de reeds getoetste
PQ-soortenrijkdom, Shannon-index en totale bedekking.

**Uitvoering.** Native in deze repository. De levende lokale database
`Meijendel` blijft de primaire bron. Modelschatting en validatie blijven buiten
Shiny en de VPS.

## Vaste uitgangspunten

- De vogelrespons, Natura 2000-plotscope, nulregels en correctie voor
  teller/tellerteam en geregistreerde ervaring blijven gelijk aan de vorige
  analysefase.
- Aalscholver blijft uitsluitend uit deze vogel–vegetatiemodellen verwijderd.
- Iedere vegetatievariabele wordt waar mogelijk gesplitst in verschil tussen
  plots en verandering binnen dezelfde plot.
- Toegevoegde waarde wordt op ongebruikte plots en latere jaren getoetst. Een
  verband in de volledige gegevens is niet voldoende.
- Alle berekende uitkomsten worden bewaard, ook nulbevindingen, onbruikbare
  modellen en ecologisch niet betekenisvolle resultaten.

## Taak 1 — PQ-soortensamenstelling

- Bouw uit 53.122 taxonregels van 2.007 PQ-opnamen uit 1981–2025 een
  herleidbare taxonbedekkingsmatrix.
- Behoud de centrale taxonidentiteit. Controleer dubbele taxonidentiteiten,
  ontbrekende koppelingen, taxonrang, meeteenheid en plotkoppeling.
- Aggregeer naar plotjaar, voer een Hellinger-transformatie uit en vat de
  samenstelling samen met vooraf begrensde compositieassen.
- Leg verklaarde variantie en taxonladingen vast. Toets daarna de extra
  voorspellende waarde met dezelfde geblokkeerde validatie als het brede
  PQ-model.
- Leg voor vertraging nul tot en met drie jaar de feitelijke dekking vast.
  Schat in deze fase alleen het gelijktijdige model. Vertragingen worden pas
  gemodelleerd wanneer dat primaire model buiten de schattingsgegevens waarde
  toevoegt; zo worden geen kostbare lagmodellen op een afwezig signaal gestapeld.

## Taak 2 — IPI als brede habitatproxy

- Breng de zeventien IPI-typen vooraf samen tot open duin, nat/water,
  struweel en bos.
- Bereken per plotjaar het aandeel opnamen per groep. Dit is de verdeling van
  de bemonsterde PQ's, niet het oppervlakteaandeel van de hele vogelplot.
- Toets of deze brede habitatmix boven op het basismodel voorspelt en leg ook
  de stabiliteit van de IPI-verdeling door de tijd vast.

## Taak 3 — onafhankelijke landbedekking 2001/2022

- Gebruik Online Resource 2 van Schmidt-Tauscher, Häger en Van der Hagen
  (2025), DOI `10.1007/s10531-025-03175-x`.
- Koppel exact 25 supplementplots aan de lokale `plot_id`; behandel de in
  Excel als datum gelezen code `10_12_76` expliciet als kavel M10-12-76.
- Gebruik de zeven bronklassen en de twee bronjaren zonder jaarlijkse
  interpolatie. Koppel 2001 aan vogelgemiddelden 1997–2001 en 2022 aan
  vogelgemiddelden 2018–2022.
- Toets vooraf passende vogelgroepen tegenover hun habitatklasse, met dezelfde
  correctie voor teller/tellerteam en ervaring. Rapporteer deze analyse
  afzonderlijk wegens de beperkte dekking van 25 plots en twee momenten.

## Taak 4 — besluit over vegetatiehoogte

- Vergelijk de voorspelwinst en restfouten van brede PQ-maten,
  soortensamenstelling, IPI en landbedekking.
- Beoordeel daarna of een hoogtevariabele een concrete resterende leemte vult.
- Als dat zo is, is de voorkeursbron een reproduceerbaar DSM–DTM-verschil uit
  openbare AHN-cycli, met het werkelijke inwinningsjaar voor Meijendel. Een
  maaiveldmodel alleen geldt niet als vegetatiehoogte.

## Controle en afronding

- Iedere nieuwe functie krijgt eerst een falende regressietest.
- De `glmmTMB`-validatiemodellen worden op de 8GB-iMac sequentieel uitgevoerd.
  Een proef met twee gevorkte R-processen veroorzaakte op 11 oktober 2026 een
  niet-afvangbare fout in de onderliggende numerieke bibliotheek; dat is een
  technisch uitvoeringsresultaat en geen ecologische modeluitkomst.
- De compacte resultaten en manifesten worden in `resultaten/` vastgelegd;
  grote tussenbestanden blijven genegeerd.
- Hoofddocument, besluiten, resultaten-README en bronregister worden inhoudelijk
  bijgewerkt. Bij wijziging van de bronstatus wordt ook de Wordversie van het
  bronregister opnieuw gemaakt, gerenderd en visueel gecontroleerd.
- Afsluiten met de volledige relevante R-tests en de projectbrede preflight.

## Uitvoering 11 oktober 2026

De formele run `20261011T130319Z-bb63b78a716f` heeft alle vier taken
uitgevoerd. De modellen zijn geschat met commit `bb63b78`; de definitieve
rapportagelaag met expliciete uitvalredenen en geldigheidsvlaggen is opgebouwd
met commit `a1a2293`.

De drie compositieassen verklaren samen 27,8% en verbeteren de ruimtelijke
logscore in vier van vijf plotblokken, maar niet in twee tijdsblokken. IPI
verbetert drie van vier geldige ruimtelijke blokken en evenmin de tijdsblokken.
De landbedekking geeft het duidelijkste ruimtelijke signaal bij watervogels;
voor open-duin-, boomgroep- en bosvogels is de numerieke validatie te
instabiel. Van vijftig geblokkeerde vergelijkingen over alle drie blokken zijn
31 geldig en 19 ongeldig. Alle uitvalredenen zijn bewaard.

Taak 4 leidt daarom niet tot algemene opname van vegetatiehoogte. Het besluit
is een gerichte AHN DSM–DTM-proef voor bos-, boomgroep- en struweelvogels,
gekoppeld aan werkelijke inwinningsjaren en opnieuw beoordeeld op voorspelling
buiten de schattingsgegevens.

## Vervolguitvoering 12 oktober 2026

De AHN-bronbewerking is uitgevoerd in run
`20261012T081631Z-ahn-harmonized-3a43bb218f8a`. AHN2/2008, AHN3/2014,
AHN4/2020 en AHN5/2023 leveren 220 vergelijkbare plot–cyclusregels voor 55
plots. De definitieve modelrun is
`20261012T085549Z-3a43bb218f8a`. De analyse gebruikt tien vooraf bepaalde
combinaties van structuurbron en vogelgroep en voegt vier seizoensmaten uit
het dagelijkse weer toe. De gebruikte modelpopulaties omvatten per combinatie
1.741–11.639 soort–plot–jaarrijen, 15–36 soorten en 22–52 plots. De
landbedekkingsmodellen omvatten tien vogeljaren; de AHN-modellen elf jaren uit
de vaste vensters 2009–2011, 2014–2016, 2021–2022 en 2023–2025.

Twaalf van twintig volledige modellen en 24 van vijftig ruimtelijke
validaties zijn numeriek geldig. De overige uitkomsten blijven met hun
convergentiereden bewaard. De zes landbedekkingstijdstoetsen blijven door hun
twee kaartmomenten `niet_uitvoerbaar`. De vier AHN-tijdstoetsen zijn nu wel
inhoudelijk uitvoerbaar. Eén slaagt numeriek: bij boomgroepvogels bedraagt de
verbetering van de gemiddelde logscore 0,0024, maar de minimale verandering na
weglaten van een soort is −0,0174. De andere drie AHN-tijdstoetsen vallen
numeriek uit. Geen gericht model gaat door naar power.

AHN1/1997–1998 is daarnaast apart gereconstrueerd voor 55 plots. De
haalbaarheidsanalyse gebruikt 12.318.672 punten binnen het analysevenster.
Twee verdedigbare 5-meterrastermethoden verschillen gemiddeld 48,0
procentpunt in open terrein, 14,0 procentpunt in bomen en 4,81 meter in de 95e
hoogtepercentiel. Daarom blijft AHN1 buiten de geharmoniseerde hoofdreeks.
