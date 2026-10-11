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
- De compacte resultaten en manifesten worden in `resultaten/` vastgelegd;
  grote tussenbestanden blijven genegeerd.
- Hoofddocument, besluiten, resultaten-README en bronregister worden inhoudelijk
  bijgewerkt. Bij wijziging van de bronstatus wordt ook de Wordversie van het
  bronregister opnieuw gemaakt, gerenderd en visueel gecontroleerd.
- Afsluiten met de volledige relevante R-tests en de projectbrede preflight.
