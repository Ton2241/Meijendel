# Uitvoering 500 validatie voor alle soorten tot2025

> Uitvoering superpowers:executing-plans. Spec: endpoint_2025_500_20261103/CRITERIA.md.

Bestaande schone analysebranch8ae99e61. Bekende taakvreemde preflightafwijking
VWG_Project/main blijft ongemoeid. Eén worker opiMac; geen2000 ofpublicatie.

- [x] Criteria vooraf, driver/context-hergebruik RED→GREEN, commit voorrunstart.
- [x] Hashgebonden500context uit opgeslagen50context, payload gelijk,
  bestaande batchhelpers, repl1/2controle en500zelfstandig uitvoeren.
- [x] Alle500uitkomsten beoordelen; poorten en250/375/500bandonrust per soort.
- [x] Resultaten/beperkingen/advies2000, registerMD/Word en projectdocs.
- [x] Eén onafhankelijke eindreview en alle 61 Wordpagina's.
Git-afhandeling en eindpreflight volgen aan het taakeinde; feitelijke stand in het eindbericht.

Uitvoeringskeuze: geen identiteitmigratie van50oude resultaten; zelfstandig500
berekenen voorkomt onduidelijke herkomst na gewijzigde code/planidentiteit.
Dit kost extra rekentijd voor de eerste50 maar geeft directe reproduceerbaarheid.

Voorbereiding en start: criteria/driver936915e9 vóór500run gecommit. De oorspronkelijke broncontext blijft behouden, nieuwe planidentiteit500. Replicaties1/2 reproduceren soorten/indices; eerste50draws worden tijdens de run vergeleken. Batches5met atomisch checkpoint.
Geheugen: endpointuitkomsten per replicatie gebundeld in plaats van234468losse eenregelige dataframes; vier50-resultaatCSV’s blijven bytegelijk. Dit beperkt objectoverhead op8GB zonder de maat te veranderen. RED→GREEN voor2000poort; Monte-Carlo-onrust en structurele uitval blijven onderscheiden.

RUNNING: R-execsession3545, PID28094, runroot /Users/ton/Documents/GitHub/Meijendel/outputs/trim-2025-validation-500-20261103; log zelfdepad+.log. Voorbereidingscommit936915e9, analysevoorbereiding75a67164. Batch16–20 meldde101512643bytes systeemswapgroei; memory_pressure32%vrij en R-RSS341712KiB (circa334MiB), dus geen teken van R-geheugentekort. Eén worker blijft actief.
NOG: wacht opVALIDATION_500_COMPLETE; draaiR/assess_trim_500_validation.R REPO RUNROOT RUNROOT/assessment; daarna CSVcontrole/rapport/bronregisterWord/eindreview/commitpush. Niet opnieuw500 starten bij compaction; controleer log/checkpoints en bestaandeprocesstatus.

HALFWAY:254/500berekend, 14:14UTC. Geen batchfouten; R-geheugenmaat circa396,6MB. Nieuwe piek systeembrede swapgroei1,076GB inbatch171–175; controle memory_pressure43%vrij en R-RSS419664KiB (circa410MiB), geen actuele geheugenblokkade. Uitvoering blijft één worker. De actuele voortgang staat altijd in het runlog.

VOORTGANG:375/500, 14:57UTC. Geen batchfouten; R-geheugenmaat396,6MB. Nog125trekkingen. De2000beoordeling is voorbereid in R/assess_trim_500_validation.R; draait pas na VALIDATION_500_COMPLETE.

Verduidelijking modelvoorschrift vóór de500-uitkomstbeoordeling: geen modelherselectie betekent geen nieuwe modelzoekactie of wijziging van de bewaarde engine. De bestaande eerste-werkende-variantvolgorde blijft actief en kan, net als in de50pilot, per trekking een ander model_config opleveren. De code en bron zijn daarop ongewijzigd; geen aanpassing op basis van500uitkomsten.

RUN_COMPLETED:500/500,100batches,0batchfouten; batchtijd11146,64s, R-geheugenmaat396,6MB. Repro1/2 en eerste50draws bevestigd. Beoordeling:28kandidaat2000,9uitval,119geenlangemaat. Laatstegrenscontrole3stabiel; beidecontroles0. Nadereaudit9soort-trekkinggevallen=12jaarregels(1984/85), bronnullenaanwezig maar nulsitefilter verwijdert allemodelcellen. De oorspronkelijke9-jaarregelassertie bleek een eenheidsfout; gecorrigeerdnaar9gevallen/12jaarregels, geen wijziging van statistiek ofpoorten. Geen2kgestart.

Eindreview schoon:100batches/500draws,28/9/119, bronpayload/repro50, bron-/codehashes, 9gevallen/12indexgaten en alle61Wordpagina’s bevestigd. Bestaande BLWG-zinsvolgorde verschilt tussenMD/Word zonder inhoudsverschil; geen nieuwe afwijking. Presentatiecorrectie RED→GREEN: Wulp-puntwaarde werd op2decimalen−100,00% terwijlde eindindexpositiefis. Adaptieveextra decimalen voorkomen die schijnnul; alle156rijen behouden, bronCSV’s ongewijzigd.
