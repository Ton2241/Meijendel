# Besluiten

Dit bestand bewaart de inhoudelijke en technische keuzes voor deze analyse.
Nieuwe besluiten worden gedateerd toegevoegd; eerdere besluiten worden niet
stilzwijgend herschreven.

## 9 oktober 2026 — doel en samenhang

- De analyse moet uiteindelijk leiden tot een artikel voor *Holland's
  Duinen*.
- Methode, voortgang en verschillende uitkomsten worden gedurende het werk in
  één leesbaar hoofddocument bijgehouden.
- De analyse omvat soorten, de broedvogelgemeenschap als geheel, functionele
  groepen, ecologische en habitatgebonden groepen en continue functionele
  kenmerken.

## 9 oktober 2026 — opslag en herhaalbaarheid

- Alle blijvende analysespecifieke documentatie, scripts, compacte resultaten,
  figuren en artikelversies worden onder
  `analyses/broedvogel_vegetatie_power/` bijeengehouden.
- De levende lokale MySQL-database `Meijendel` blijft de canonieke bron. Ruwe
  gegevens worden niet gekopieerd naar de analysedirectory.
- Iedere formele uitvoering krijgt een manifest met gegevensselectie,
  aantallen, versies, modelinstellingen, controles en uitkomsten.
- Grote tijdelijke uitvoer, caches en modelobjecten worden niet in Git
  opgenomen.

## 9 oktober 2026 — analysescope en gegevensbetekenis

- Plotgebonden analyses gebruiken standaard
  `v_meijendel_analyseplot_actueel`. M66 en M91 blijven buiten beschouwing.
- De centrale bron-, nul- en afkeurregels uit
  `R/meijendel_cache_contract.R` worden hergebruikt en niet binnen deze analyse
  opnieuw geïnterpreteerd.
- Een groepswaarde wordt alleen berekend wanneer alle samenstellende
  soortcellen geldig zijn; een gedeeltelijke som blijft `NA`.

## 9 oktober 2026 — modelstrategie

- De primaire modelkorrel is soort × plot × jaar.
- Eén hiërarchisch soortmodel is leidend. Groepsuitkomsten worden uit de
  voorspelde soortreacties afgeleid; directe groepsmodellen zijn
  gevoeligheidsanalyses.
- Teller en tellerervaring worden als onderdeel van het waarnemingsproces
  onderzocht. Zij worden niet uitsluitend op grond van niet-significantie
  verwijderd.
- PQ-vegetatie wordt gesplitst in verschillen tussen plots en veranderingen
  binnen dezelfde plot.
- Toegevoegde voorspellende waarde wordt met achtergehouden jaren en plots
  beoordeeld, niet alleen met significantie of AIC.
- De formele poweranalyse volgt pas nadat gegevensmatrix, model en validatie
  zijn vastgesteld. Historische trendonzekerheid wordt niet als power
  aangeduid.

## 9 oktober 2026 — uitvoering en presentatie

- Modelschatting, modelvergelijking, validatie en powerberekening worden buiten
  Shiny uitgevoerd.
- Shiny of het dashboard kan later uitsluitend gevalideerde, reproduceerbare
  uitkomsten presenteren.
- Een statistische relatie wordt niet zonder aanvullend bewijs als een
  causale beheerwerking beschreven.

## 9 oktober 2026 — analysematrix stap 1

- Alleen plotjaren die in `territoria` voorkomen vormen de vogelmeetbasis.
  Een registratie die uitsluitend in `plot_jaar_teller` staat, voegt geen
  analysejaar toe.
- De matrix bevat de volledige kruising van 156 positief vastgestelde soorten
  en 2.107 territorium-plotjaren in de 52 standaardplots. Ontbrekende
  soortregels blijven expliciet `NA`; zij worden niet door de rechthoekige
  matrix impliciet nul.
- Tellerregistraties worden per plotjaar als afzonderlijke dekking en als
  herleidbare tellerteamsleutel toegevoegd. Zij bepalen niet of een plotjaar als
  territoriumtelling bestaat.
- M62/2016 blijft in de algemene vogelmatrix aanwezig. Deze afzonderlijke
  roofvogeltelling wordt pas uit de teller- en tellerervaringsanalyse
  verwijderd, conform het reeds vastgelegde gebruiksbesluit.
- Iedere uitvoering bewaart de bronbestanden alleen tijdelijk, schrijft de
  volledige matrix onder de genegeerde map `resultaten/runs/` en houdt een
  compact samenvattingsbestand en SHA256-manifest in Git bij.

## 9 oktober 2026 — teller- en ervaringsmodel

- Het goedgekeurde ontwerp staat in
  `ONTWERP_TELLER_EN_ERVARINGSMODEL.md` en wordt vóór implementatie als
  methodische specificatie gebruikt.
- Het hoofdmodel is hiërarchisch en negatief-binomiaal. Het vergelijkt op
  exact dezelfde responscellen een basismodel, een model met tellerteam en een
  model met tellerteam plus ervaring. GEE is een afzonderlijke controle.
- Ervaring bestaat uit eerdere geregistreerde teljaren in dezelfde plot en
  eerdere geregistreerde teljaren elders. Beide worden met `log(1 + jaren)`
  gemodelleerd; er komt geen willekeurige grens tussen onervaren en ervaren.
- Bij meertellerteams wordt de gemiddelde getransformeerde ervaring gebruikt.
  Een analyse van uitsluitend één-teller-plotjaren voorkomt dat het resultaat
  geheel van deze teamtoerekening afhankelijk wordt.
- M62/2016 en de 99 plotjaren zonder tellerregistratie worden niet in de
  primaire tellervergelijking gebruikt. Tellergegevens worden niet geïmputeerd.
- Telinspanning wordt alleen in een afzonderlijke analyse over 1984–2025
  opgenomen. Voor 1958–1983 ontbreken BMP-bezoekgegevens.
- Confounders worden niet op grond van niet-significantie verwijderd. Alleen
  niet-identificeerbaarheid of modeluitval kan tot een gedocumenteerde
  vereenvoudiging leiden.
- De uitkomst beschrijft een systematisch effect op territoriumtotalen. Zij
  wordt niet zonder bezoekniveau-tellerkoppeling uitgelegd als het letterlijke
  aantal door een teller gemiste vogels.
