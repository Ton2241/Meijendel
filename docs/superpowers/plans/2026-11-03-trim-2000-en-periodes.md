# Uitvoering2.000 en eigen periode-/jaarindexbeoordeling

> Uitvoering met superpowers:executing-plans; één onafhankelijke eindreview.

Spec: trim/bootstrap/species_2025_2000_20261103/CRITERIA.md. Bestaande schone taakbranch4aff1abc. Geen database/cache/2026/publicatie. Eén rekenworker.

- [x] Criteria vooraf committen. RED→GREEN voor32contextsubset/drawidentiteit,2000poorten en periode/jaarnormalisatie.
- [x] Driver R/run_trim_2025_2000.R: bewaarde500herkomst en selectie32, engine intact, reproductieoude1/2; checkpointbatches501–2000. Daarna herstel ongebrrugde periodedata uit500 met telling herstelmodelfits, geen andere modelregel.
- [x] R/assess_trim_2025_2000.R: beide identiteiten controleren, lange2000voor32, periode500voor156 en jaar500voor10608posities. Status/banden/stabiliteit apart. Geheugen begrenzen met matrix/batchverwerking; geen miljoenen eenregelige dataframes.
- [x] ResultatenCSV/156soortenMarkdown en beperkingen, allebronhashes/fitcounts; DECISIONS/STATUS/TODO/runbook en bronregisterMD/Word.
- [x] Gerichte regressies, bronbehoud en één onafhankelijke eindreview inclusief alle 62 Wordpagina’s. Git-afhandeling op de analysebranch; geen publicatie.

Reviewfocus: geen eerste500overschrijven ofheretiketteren; geen andere clusters na selectie32; geen brugafhankelijkheid bij eigenperioden; geen bewegend referentiejaar; geen banduit alleen successen/constante referentieverdeling; geen95%-dekking claimen; alle156/312/10608 zichtbaar.

Voorafcriteria gecommit e7f68940, uitbreidingdriver5050b7a8; beide oude draws1/2 reproduceren32soorten/indices. Nieuwe IDs501–2000 lopen, één fitworker; R-execsession96201, PID51604. Root canoniek outputs/trim-2025-species-2000-20261103, logzelfdepad+.log. Eerste500 blijven in parent outputs/trim-2025-validation-500-20261103. Taakvreemde preflightafwijking VWG_Project/main1commitvoororigin blijft ongemoeid.
Naextensie wacht hersteldriver via execsession23279 op PID51604; start alleen bijEXTENSION_2000_COMPLETE. Herstelroot child/period_recovery, logchild/period_recovery.log. Niet opnieuw starten zolang deze processen actief zijn. Ongebrrugde herstelhelper/driver6de1c2e9,software/parentidentiteitschecksdeae13ee. Assessoren gereed; analyse pas na complete markers en hashes.


Afgerond: 300 nieuwe batches, 1.500 nieuwe trekkingen voor 32 soorten en hergebruik van 500. Periodeherstel en beide beoordelingen voltooid. Uitkomst 29 compleet, vier stabiel, drie uitval. Voor de 119: 154 beschikbare periodemodellen, 149 schatbare periodeveranderingen, 73 periodebanden, 4.614 baseline-indexjaren en 2.420 jaarbanden. Alle 156, 312 en 10.608 in het overzicht. Eerste 78.156 primaire ouderregels gecontroleerd tegen het eerdere Git-archief. Afsluitmelding na volledig opgeslagen extensie gedocumenteerd in extension_completion_check.json; geen herberekening.

Uitvoer vanaf de taakcheckout; stel TRIM_REPO in op deze checkout, TRIM_PARENT op de bestaande500-run, TRIM_ROOT op de uitbreidingsmap. De aanroepbestanden worden volledig ingelezen vóór de lange uitvoering.

```sh
Rscript -e 'source("R/run_trim_2025_2000.R"); run_trim_2025_2000()' "$TRIM_REPO" "$TRIM_PARENT" "$TRIM_ROOT"
Rscript -e 'source("R/run_trim_period_recovery.R"); run_trim_period_recovery()' "$TRIM_REPO" "$TRIM_PARENT" "$TRIM_ROOT/period_recovery"
Rscript R/assess_trim_2025_2000.R "$TRIM_REPO" "$TRIM_PARENT" "$TRIM_ROOT" "$TRIM_ROOT/assessment"
Rscript R/assess_trim_period_uncertainty.R "$TRIM_REPO" "$TRIM_PARENT" "$TRIM_ROOT/period_recovery" "$TRIM_ROOT/assessment"
python3 scripts/build_trim_2025_uncertainty_report.py "$TRIM_REPO" "$TRIM_PARENT" "$TRIM_ROOT"
```

Eindreview schoon: alle getelde uitkomsten, 400 batches, oude primaire regels, jaar-/periodebanden en Wordpagina’s bevestigd. De nieuwe registeralinea staat op pagina 9–10. De bekende projectbrede preflightafwijking blijft buiten deze analyse.
