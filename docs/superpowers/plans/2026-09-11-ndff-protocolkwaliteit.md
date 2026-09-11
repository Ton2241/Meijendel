# NDFF-protocolkwaliteit implementatieplan

**Doel:** voeg uitsluitend een protocolcatalogus, gebruiksmatrix, ruimtelijke kwaliteitslaag en versieerbare analysebesluiten toe aan de lokale Meijendel-database.

**Architectuur:** de bestaande openbare en beveiligde NDFF-waarnemingen blijven ongewijzigde bronregistraties. Niet-gevoelige kwaliteitsmetadata komt in `Meijendel`; exacte beveiligde geometrie blijft uitsluitend in `Meijendel_ndff_secure`. Iedere afleiding bewaart bron- en regelversie.

**Techniek:** MySQL 9.7.1, Python-standaardbibliotheek, gebundelde `openpyxl`
uitsluitend voor de gecontroleerde Excel-naar-seedgeneratie en de bestaande
MySQL-login-path.

## Afbakening

- Geen survey-, route-, sectie- of bezoekentabellen.
- Geen wijzigingen aan vogel-, PQ-, vangblik- of bestaande NDFF-waarnemingstabellen.
- Geen Shiny-, dashboard- of VPS-wijziging.
- Geen automatische toelating tot trend-, abundantie-, afwezigheids- of beheereffectanalyse.

## Uitvoering

- [x] Leg eerst contracttests vast voor tabellen, sleutels, versievelden, bronhashes en conservatieve analysebesluiten.
- [x] Voeg een idempotent DDL-schema toe voor de vier kwaliteitslagen.
- [x] Maak uit de goedgekeurde Excel-matrix een reproduceerbare seed met 54 protocollen.
- [x] Voeg een importer toe die protocolteksten uit beide NDFF-bronnen koppelt, openbare geometrieën tegen SOVON-plotversie 2025 beoordeelt en conservatieve analysebesluiten vult.
- [x] Voer unit- en contracttests uit.
- [x] Pas de migratie lokaal toe en controleer aantallen, referentiële integriteit, dekking en herhaalbaarheid.
- [x] Werk de NDFF-documentatie bij, commit en push de taakbranch.
