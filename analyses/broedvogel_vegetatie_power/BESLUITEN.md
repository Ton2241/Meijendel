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
