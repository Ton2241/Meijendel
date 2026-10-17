# TRIM-bootstrap na ontvangst van broedseizoen 2026

Stand: 17 oktober 2026. Dit draaiboek bereidt de berekening voor; het verleent
geen toestemming voor een nieuwe dump, een 2.000-run of VPS-publicatie.

## Statistisch contract

- Primair: formele TRIM-trends 1958–1983 en 1984–2026 via
  `rtrim::overall(which = "imputed")`.
- Aanvullend: formele gecombineerde trend 1958–2026 via een gestratificeerde
  clusterbootstrap van volledige plotgeschiedenissen.
- Primaire brug: gemeenschappelijke plots, 1981–1983 naar 1986–1988.
- Overgangsjaren 1984–1985: wel in het tweede TRIM-model, niet in de primaire
  brugkalibratie.
- Gevoeligheid: 1987–1989, 1988–1990, strikte zesjaarsset, 1984–1986 als
  historische comparator en een vaste historische-kernvariant.
- Groepen: vaste robuuste soortpopulatie primair; volledige wisselende
  samenstelling uitsluitend als gevoeligheidsvariant.
- De gevoeligheidsenvelop is geen 95%-betrouwbaarheidsinterval.

## Harde volgorde

1. Importeer en valideer eerst alle cijfers over broedseizoen 2026 in de
   levende lokale MySQL-database. Controleer bronstatus, echte nullen, lege
   cellen, formele afkeuringen, plotdekking en soortidentiteit.
2. Vraag afzonderlijk akkoord voor een verse dump en cache uit die levende
   database. Gebruik geen bestaande dump of productieback-up als bron.
3. Draai bron-/uitvoercontract, clusterlineage en brugvensteraudit opnieuw.
   Leg aantallen voor 1958–2026 vast; neem de 2025-aantallen niet over.
4. Bouw vanaf een schone, gereviewde commit één hashgebonden runbundle:

   ```bash
   Rscript R/build_trim_bootstrap_bundle.R \
     --sql /absoluut/pad/meijendel.sql \
     --bundle /absoluut/pad/run/input_bundle \
     --end-year 2026 \
     --planned-replicates 2000 \
     --run-id trim-2026-YYYYMMDDTHHMMSS \
     --run-seed 20260920
   ```

5. Draai eerst twee replicaties en vergelijk ze met dezelfde IDs uit een tweede
   run. Draai daarna met één lokale worker eerst 50 replicaties en vat de
   geldigheid samen. Start 500 alleen als iedere beoogde formele schatter
   minimaal 95% geldig is. Start 2.000 pas als ook de 500-validatie groen is:

   ```bash
   scripts/run_trim_bootstrap_local.sh \
     --replicates 50 --batch-size 5 \
     --sql /absoluut/pad/meijendel.sql \
     --run-root /absoluut/pad/run
   ```

6. Gebruik NAS of productie-VPS alleen na een afzonderlijke read-only
   capaciteitsproef en expliciete toestemming. De voorbeeldconfiguratie houdt
   beide uitgeschakeld. Eén worker maximaal; normale NAS-taken, MySQL, Shiny en
   websitehealth hebben altijd voorrang. Een production lock stopt de VPS-worker
   vóór de volgende replicatie.
7. Merge alleen complete, niet-overlappende batches met gelijke bron-, code-,
   configuratie- en softwarehashes. Voer clusterjackknife, BCa-samenvatting en
   alle structurele gevoeligheidsvergelijkingen uit.
   Leg vóór de intervalberekening ook iedere geldige en ongeldige schatter vast:

   ```bash
   Rscript R/summarise_trim_bootstrap_pilot.R \
     /absoluut/pad/run/pilotdiagnostiek 50 \
     /absoluut/pad/run/batches/batch-??????-??????.rds
   ```

   De vier diagnostiekbestanden rapporteren runtijd, geheugen, batchfouten en
   per soort- en groepsvariant het geldige percentage en de voornaamste
   uitvalreden. Gebruik bij 500 of 2.000 het werkelijk verwachte aantal in
   plaats van `50`. Ze zijn controle-uitvoer en nooit een publicatieproduct.
8. Publiceer een schatter alleen bij minimaal 95% geldige replicaties. Verhoog
   van 2.000 naar maximaal 5.000 alleen wanneer beide intervalgrenzen tussen
   opeenvolgende controles nog minstens 0,10 procentpunt per jaar of 5% van de
   actuele intervalbreedte veranderen.
9. Schrijf de canonieke CSV's atomisch en activeer ze alleen bij eindjaar 2026,
   minimaal 2.000 geplande replicaties en status `publiceerbaar`.
10. Draai alle schema-, dashboard-, website-, Shiny-, bronregister- en
    deploypreflights. Vraag daarna afzonderlijk akkoord voor VPS-publicatie.

## Ontwikkelmeting 1958–2025

De gevalideerde broncache bevat 156 soorten in de statuslaag, 135 soorten met
minimaal één indexreeks, 93 soorten met beide modelperioden en 52 ooit getelde
plots. Daarvan liggen 17 plots in de historische kern, 35 in het latere
netwerk, 33 in de primaire brugset en 20 in de strikte zesjaarsset. Van de 93
soorten met twee perioden hebben 68 een geldige nieuwe formele primaire brug;
33 voldoen daarnaast aan de volledige-jaarvoorwaarde voor de vaste
groepspopulatie.

De lokale 50-pilot met R 4.5.3 en `rtrim` 2.3.1 gebruikte één iMac-worker,
duurde gemeten 2.460,4 seconden en gebruikte maximaal 357,0 MB R-geheugen.
Alle 50 replicaties voltooiden zonder batchfout; swap was nog niet gemeten.
Replicaties 1 en 2 waren bij herhaling exact gelijk. De pilot gebruikte de
voorlopige vaste set van 35 soorten: 5 van 21 primaire vaste groepen haalden
95% geldigheid, tegenover 21 van 21 volledige gevoeligheidsgroepen. Na
correctie naar 33 vaste soorten waren in één rookreplicatie 7 van 21 vaste
groepen geldig. Start de 500-validatie daarom pas na een expliciet methodisch
besluit en een nieuwe groene 50-pilot. Geen validatierun mag canonieke
publicatiebestanden activeren.
