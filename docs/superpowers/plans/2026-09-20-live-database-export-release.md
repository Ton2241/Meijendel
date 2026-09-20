# Levende database naar productie Implementation Plan

**Goal:** Publiceer uitsluitend een verse, volledig beproefde `Meijendel.sql`
uit de levende lokale database en blokkeer toekomstige deploys van een
verouderde of gewijzigde dump.

**Authority:** De levende lokale MySQL-database `Meijendel` is de canonieke
schrijfbron. Dump, productie-MySQL, Shiny en website zijn afgeleiden.

## Task 1 - Exportcontract

- Voeg eerst falende gedragstests toe voor een dumpmanifest.
- Genereer de dump atomair via een tijdelijk bestand.
- Proefimporteer haar in een tijdelijke lokale database.
- Vergelijk alle basistabellen op exacte rijtelling en voer `mysqlcheck` uit.
- Schrijf daarna een manifest met dump-hash, bytes, MySQL-versie,
  objectaantallen, kernrijtellingen en een hash over alle tabelaantallen.

## Task 2 - Deploygate

- Laat de Meijendel-deploy lokaal blokkeren wanneer dump, manifest en levende
  database niet meer overeenkomen.
- Synchroniseer het manifest samen met de dump en verifieer de remote hash
  voordat de gesloten importhelper wordt gestart.
- Controleer na import de actuele publieke soortselectie.

## Task 3 - Publieke selectie

- Wijzig de VWG_M-rooktest van 149 naar 153 overige soorten.
- Controleer afzonderlijk Kuifduiker, Indische Gans, Noordse Stern en
  Iberische Tjiftjaf.

## Task 4 - Release

- Draai alle lokale tests en beide preflights.
- Merge schone taakbranches naar `main` en push.
- Maak een productieback-up, publiceer via de bestaande gesloten releaseketen
  en voer alle nacontroles uit.
- Registreer een nieuwe release in `VWG_Project/RELEASE_MANIFEST.yml`; wijzig
  release `2026-09-20.1` niet.

## Review focus

- Geen beveiligde ticket-58679-data in dump, Git of VPS.
- Geen import wanneer de levende database sinds export is gewijzigd.
- Geen productiebelasting vóór alle lokale proefimportcontroles groen zijn.
- Rollback herstelt alleen een technisch mislukte release en bepaalt nooit de
  inhoudelijke waarheid.
