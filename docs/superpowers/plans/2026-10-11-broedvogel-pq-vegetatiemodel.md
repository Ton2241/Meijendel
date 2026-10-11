# Implementatieplan stap 3: broedvogels en PQ-vegetatie

**Doel:** vaststellen of gemeten PQ-vegetatie op de 35 Natura 2000-plots extra
voorspellende informatie over territoriumaantallen levert boven het reeds
vastgestelde waarnemingsmodel.

**Afbakening:** lokale, zelfstandige analyse. Geen Shiny-wijziging en geen
publicatie naar de VPS. De formele poweranalyse blijft een volgende stap.

## Taak 1 — Exacte PQ-modelpopulaties

Bestanden:

- nieuw: `analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_vegetatie_data.R`
- nieuw: `analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_vegetatie_data.R`

Werk:

1. Lees `pq_plot_jaar_vegetatie` als zelfstandige bronlaag naast de bestaande
   vogelmatrix en tellerlaag.
2. Koppel PQ-meetjaar aan vogeljaar met vooraf vastgelegde vertragingen 0, 1,
   2 en 3 jaar; interpoleer nooit tussen PQ-meetjaren.
3. Beperk elke vergelijking tot exact dezelfde responsrijen met een bekende
   teller/tellerteam en geldige PQ-waarden.
4. Splits iedere PQ-maat in het plotgemiddelde en de afwijking van dat
   gemiddelde in het meetjaar. Standaardiseer daarna beide componenten.
5. Stop bij dubbele plot–jaarrijen, ontbrekende scope of niet-eindige waarden.

## Taak 2 — Basismodel en afzonderlijke vegetatiemodellen

Bestanden:

- nieuw: `analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_vegetatie_fit.R`
- nieuw: `analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_vegetatie_fit.R`

Werk:

1. Neem het uitgevoerde teller- en ervaringsmodel als basis: tijd, bron,
   oppervlakte, teller/tellerteam, ervaring in de plot en ervaring elders,
   met hiërarchische verschillen tussen soorten, plots en jaren.
2. Vergelijk dit basismodel telkens op dezelfde rijen met één uitbreiding voor
   soortenrijkdom, Shannon-index of totale bedekking.
3. Schat verschillen tussen plots en veranderingen binnen plots afzonderlijk,
   met soortspecifieke afwijkingen rond de gemiddelde reactie.
4. Zet de drie sterk samenhangende PQ-maten niet tegelijk in het primaire
   model. Daarmee blijft zichtbaar welke maat informatie levert en wordt
   instabiele verdeling van hetzelfde signaal voorkomen.

## Taak 3 — Voorspellende toets

Bestanden:

- nieuw: `analyses/broedvogel_vegetatie_power/scripts/broedvogel_model_vegetatie_validate.R`
- nieuw: `analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_vegetatie_validate.R`

Werk:

1. Maak reproduceerbare ruimtelijke blokken waarin volledige plots worden
   achtergehouden.
2. Maak temporele blokken waarin latere, volledige vogeljaren worden
   achtergehouden.
3. Bereken voor basis- en PQ-model op exact dezelfde validatierijen de
   negatief-binomiale logscore, gemiddelde absolute fout en wortel uit de
   gemiddelde kwadratische fout.
4. Rapporteer verbetering positief wanneer het PQ-model buiten de
   schattingsgegevens een lagere fout of betere logscore heeft; significantie
   of AIC alleen geldt niet als voorspellend bewijs.

## Taak 4 — Reproduceerbare uitvoering en documentatie

Bestanden:

- nieuw: `analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_vegetatie_model.R`
- nieuw: `analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_vegetatie_model.sh`
- nieuw: `analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_vegetatie_pipeline.R`
- wijzig: analyse-README's, `BESLUITEN.md` en
  `ANALYSE_HOOFDLIJNEN_EN_UITKOMSTEN.md`
- nieuw na geslaagde uitvoering: compacte `vegetatie_model_laatste_*`-uitvoer

Werk:

1. Extraheer de brongegevens read-only uit de lokale MySQL-database.
2. Leg bronhashes, Git-commit, pakketversies, selecties, formules, blokken,
   modeldiagnostiek en resultaatbestanden vast in een manifest.
3. Bewaar grote modelobjecten en volledige tussenbestanden alleen onder de
   genegeerde runmap; volg uitsluitend compacte uitkomsten in Git.
4. Voer alle zuivere tests en daarna de formele analyse uit. Werk de
   hoofddocumentatie uitsluitend bij met uitkomsten die daadwerkelijk zijn
   berekend en gecontroleerd.

## Controle

- alle nieuwe tests slagen;
- bestaande tests voor matrix en tellerlaag blijven slagen;
- basis- en PQ-model hebben per vergelijking dezelfde rijhash;
- kavel 66 en kavel 91 komen niet in de modelpopulaties voor;
- geen afgekeurd SOVON-plotjaar wordt via de SOVON-bron gebruikt;
- eindpreflight: alle drie repositories schoon en gelijk aan hun upstream.
