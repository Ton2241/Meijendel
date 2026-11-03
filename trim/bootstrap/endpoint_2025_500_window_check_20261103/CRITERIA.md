# Herbeoordeling 500: relevante indexjaren

Vastgelegd vóór herberekening op 3 november 2026. Aanleiding: door Ton overgenomen advies na de strikte 500-validatie. Bron: dezelfde bewaarde 500 trekkingen voor alle 156 soorten, 1958–2025, 52 kavelclusters. Geen nieuwe tellingen, trekkingen of modelfits.

## Aangepaste controle

- Beide periodemodellen blijven bruikbaar; de bewaarde vijfjaarsbrug moet eindig en positief zijn.
- Voor de primaire begin/eindmaat zijn alle indexjaren 1958–1962, 2021–2025, 1979–1983 en 1986–1990 vereist. Bij gevoeligheidsvensters van drie of zeven jaar veranderen uitsluitend de begin/eindvensters; de brug blijft vijf jaar.
- Ieder vereist jaar staat in de bewaarde modeljaarselectie en komt precies eenmaal voor met een eindige, niet-negatieve index. Een ontbrekend, dubbel of ongeldig vereist jaar blokkeert de maat. Dezelfde regel geldt voor alle 156 soorten.
- Ontbrekende, dubbele of ongeldige indexjaren buiten deze vensters worden afzonderlijk vastgelegd. Zij blokkeren deze maat niet. Jaarindices worden nooit aangevuld, nul gemaakt of verplaatst. De afzonderlijke jaarreeks blijft daar onvolledig.
- Echte nul aan het einde blijft −100%; nulbegin blijft ongedefinieerd. De maat en alle andere poorten blijven gelijk aan het oorspronkelijke 500-contract (936915e9).
- Alleen een eindige baseline en 500/500 geldige, niet-constante uitkomsten maken een soort kandidaat voor 2.000. Uitval wordt niet weggefilterd. De stabiliteitsregel blijft beide grenzen <0,1 procentpunt én <5% van de actuele bandbreedte, bij 250→375 en 375→500. Numerieke onrust wordt gerapporteerd en is geen structurele onschatbaarheid.
- Geen formele 95%-vrijgave; formele CI-kolommen blijven leeg. Venstergevoeligheid, beperkte bronsteun, model-/brugaannamen en onbekende dekking blijven beperkingen.

## Uitvoering en afrondcriteria

1. Schrijf gerichte regressiecontroles; zie deze falen op de oude regel en slagen na de kleinste wijziging.
2. Lees dezelfde honderd gehashte batches; beoordeel 156 soorten × 501 bron/trekkinguitkomsten × drie vensters. Vergelijk alle oude geldige waarden en alle gewijzigde statussen. Bewaar historische strikte resultaten.
3. Leg per soort de oude/nieuwe poort en aantallen, afzonderlijke indexjaarproblemen, herkomst, resultaten en beperkingen vast. Actualiseer besluiten, status, taken, runbook en beide bronregisterversies.
4. Gerichte tests, beschermde uitvoerchecksums, Word-rendercontrole en één onafhankelijke eindreview. Commit en push naar de bestaande taakbranch. Geen 2.000-run of publicatie.
