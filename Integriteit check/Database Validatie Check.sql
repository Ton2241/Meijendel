/* UITLEG
Dit bestand bevat SQL: Database Validatie Check.
*/

-- Stap 1: Uitvoering van een SQL‑statement.
-- ============================================================================
-- DATABASE VALIDATIE SCRIPT - Meijendel
-- Gebruik dit script om de database kwaliteit te controleren
-- ============================================================================

-- Sectie 1: DATA INTEGRITEIT CHECKS
-- ============================================================================

SELECT '=== DATA INTEGRITEIT CHECKS ===' as checkpoint;
-- Stap 2: Uitvoering van een SQL‑statement.


-- Check 1: Orphaned records in evg_vogel_landschapgroep
SELECT 
  'Orphaned evg_vogel_landschapgroep records' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM evg_vogel_landschapgroep vl
LEFT JOIN soorten s ON vl.vogel_id = s.id
WHERE s.id IS NULL;
-- Stap 3: Uitvoering van een SQL‑statement.


-- Check 2: NULL waarden in foreign key kolommen
SELECT 
  'NULL waarden in evg_vogel_landschapgroep FKs' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM evg_vogel_landschapgroep
WHERE groepsnummer IS NULL OR vogel_id IS NULL;
-- Stap 4: Uitvoering van een SQL‑statement.


-- Check 3: Orphaned territoria
-- Let op: hier bewust GEEN filter op p.in_gebruik = 1.
-- Dit is een integriteitscontrole; ook niet-actieve plots moeten nog geldig gekoppeld zijn.
SELECT 
  'Orphaned territoria (geen plot)' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM territoria w
LEFT JOIN plots p ON w.plot_id = p.plot_id
WHERE p.plot_id IS NULL;
-- Stap 5: Uitvoering van een SQL‑statement.


-- Check 4: Waarnemingen met ongeldige soort_id
SELECT 
  'Orphaned territoria (geen soort)' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM territoria w
LEFT JOIN soorten s ON w.soort_id = s.id
WHERE s.id IS NULL;
-- Stap 6: Uitvoering van een SQL‑statement.


-- Check 5: Som habitats m2 wijkt meer dan 1 m2 af van de plotoppervlakte
SELECT 
  'Plots waar som habitat m2 afwijkt van plotoppervlakte' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '⚠️  WAARSCHUWING' END as status,
  -- Stap 4: Toon de afwijkende plots direct als kommalijst, zodat u ze zonder
  -- extra query kunt opzoeken. NULL als er geen problemen zijn.
  GROUP_CONCAT(
      CONCAT(p.plot_naam, ' (', afwijkend.jaar, ', verschil: ', 
             ROUND(afwijkend.verschil_m2), ' m2)')
      ORDER BY afwijkend.jaar, p.plot_naam
      SEPARATOR ' | '
  ) AS afwijkende_plots
FROM (
    -- Stap 1: Bereken per plot en jaar de som van alle habitat-oppervlakten
    -- en vergelijk die met de bekende plotoppervlakte omgerekend naar m2
    SELECT 
        pjh.plot_id,
        pjh.jaar,
        SUM(pjh.aandeel_m2) AS som_habitat_m2,
        pjo.oppervlakte_km2 * 1000000 AS totaal_plot_m2,
        ABS(SUM(pjh.aandeel_m2) - (pjo.oppervlakte_km2 * 1000000)) AS verschil_m2
    FROM plot_jaar_habitat pjh
    -- Stap 2: Koppel de plotoppervlakte op hetzelfde plot en jaar
    JOIN plot_jaar_oppervlak pjo 
        ON pjh.plot_id = pjo.plot_id 
        AND pjh.jaar = pjo.jaar
    GROUP BY pjh.plot_id, pjh.jaar, pjo.oppervlakte_km2
    -- Stap 3: Houd alleen combinaties over waar het verschil groter is dan 1 m2
    HAVING ABS(SUM(pjh.aandeel_m2) - (pjo.oppervlakte_km2 * 1000000)) > 1
) AS afwijkend
-- Stap 4: Koppel de plotnaam voor leesbare uitvoer
-- Let op: hier bewust GEEN filter op p.in_gebruik = 1.
-- Ook niet-actieve plots kunnen een relevante afwijking in habitat/oppervlakte hebben.
JOIN plots p ON afwijkend.plot_id = p.plot_id;
-- Stap 7: Uitvoering van een SQL‑statement.



-- Check 6: Negatieve waardes
SELECT 
  'Waarnemingen met negatieve territoria' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM territoria
WHERE territoria < 0;
-- Stap 8: Uitvoering van een SQL‑statement.


-- Check 7: Ongeldige jaren
SELECT 
  'Waarnemingen met ongeldig jaar' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM territoria
WHERE jaar < 1900 OR jaar > YEAR(CURDATE()) + 1;
-- Stap 9: Uitvoering van een SQL‑statement.


-- Check 8: Dubbele EURING codes
SELECT 
  'Dubbele EURING codes' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM (
  SELECT euring_code, COUNT(*) as cnt
  FROM soorten
  GROUP BY euring_code
  HAVING cnt > 1
) as duplicaten;
-- Stap 10: Uitvoering van een SQL‑statement.


-- Sectie 2: SCHEMA KWALITEIT CHECKS
-- ============================================================================

SELECT '=== SCHEMA KWALITEIT CHECKS ===' as checkpoint;
-- Stap 11: Uitvoering van een SQL‑statement.


-- Check 9: Tabellen zonder Primary Key
SELECT 
  'Tabellen zonder Primary Key' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '⚠️  WAARSCHUWING' END as status
FROM information_schema.tables t
LEFT JOIN information_schema.table_constraints tc 
  ON t.table_schema = tc.table_schema 
  AND t.table_name = tc.table_name 
  AND tc.constraint_type = 'PRIMARY KEY'
WHERE t.table_schema = 'Meijendel'
  AND t.table_type = 'BASE TABLE'
  AND tc.constraint_name IS NULL
  AND t.table_name NOT LIKE 'temp_%';
-- Stap 12: Uitvoering van een SQL‑statement.


-- Check 10: Foreign keys zonder index
SELECT 
  'Foreign key kolommen zonder index' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '⚠️  WAARSCHUWING' END as status
FROM (
  SELECT DISTINCT
    kcu.table_name,
    kcu.column_name
  FROM information_schema.key_column_usage kcu
  WHERE kcu.table_schema = 'Meijendel'
    AND kcu.referenced_table_name IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 
      FROM information_schema.statistics s
      WHERE s.table_schema = kcu.table_schema
        AND s.table_name = kcu.table_name
        AND s.column_name = kcu.column_name
        AND s.seq_in_index = 1
    )
) as missing_indexes;
-- Stap 13: Uitvoering van een SQL‑statement.


-- Sectie 3: PERFORMANCE CHECKS
-- ============================================================================

SELECT '=== PERFORMANCE CHECKS ===' as checkpoint;
-- Stap 14: Uitvoering van een SQL‑statement.


-- Check 11: Tabellen zonder indexen (behalve PK)
SELECT 
  'Tabellen zonder indexen (excl. PK)' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) <= 3 THEN '✓ OK' ELSE '⚠️  WAARSCHUWING' END as status
FROM (
  SELECT t.table_name
  FROM information_schema.tables t
  WHERE t.table_schema = 'Meijendel'
    AND t.table_type = 'BASE TABLE'
    AND t.table_name NOT LIKE 'temp_%'
    AND NOT EXISTS (
      SELECT 1 
      FROM information_schema.statistics s
      WHERE s.table_schema = t.table_schema
        AND s.table_name = t.table_name
        AND s.index_name != 'PRIMARY'
    )
) as no_indexes;
-- Stap 15: Uitvoering van een SQL‑statement.


-- Check 12: Grote tabellen zonder partitionering
SELECT 
  'Tabellen > 100K records zonder partitioning' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE 'ℹ️  INFO' END as status
FROM (
  SELECT 
    table_name,
    table_rows
  FROM information_schema.tables
  WHERE table_schema = 'Meijendel'
    AND table_rows > 100000
    AND create_options NOT LIKE '%partitioned%'
) as large_tables;
-- Stap 16: Uitvoering van een SQL‑statement.


-- Check 13: VARCHAR kolommen die te groot zijn
SELECT 
  'VARCHAR(255) kolommen met korte data' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE 'ℹ️  INFO' END as status
FROM information_schema.columns
WHERE table_schema = 'Meijendel'
  AND data_type = 'varchar'
  AND character_maximum_length = 255
  AND column_name NOT LIKE '%omschrijving%'
  AND column_name NOT LIKE '%beschrijving%'
  AND table_name NOT LIKE 'temp_%';
-- Stap 17: Uitvoering van een SQL‑statement.


-- Sectie 4: TEMP TABELLEN CHECK
-- ============================================================================

SELECT '=== TEMP TABELLEN CHECK ===' as checkpoint;
-- Stap 18: Uitvoering van een SQL‑statement.


-- Check 14: Aantal temp tabellen in productie schema
SELECT 
  'Temp tabellen in productie schema' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '⚠️  MOET OPGERUIMD' END as status
FROM information_schema.tables
WHERE table_schema = 'Meijendel'
  AND table_name LIKE 'temp_%';
-- Stap 19: Uitvoering van een SQL‑statement.


-- Check 15: Records in temp tabellen
SELECT 
  table_name,
  table_rows as aantal_records,
  CASE 
    WHEN table_rows = 0 THEN '✓ Leeg - kan verwijderd worden'
    ELSE '⚠️  Bevat data - controleer eerst'
  END as status
FROM information_schema.tables
WHERE table_schema = 'Meijendel'
  AND table_name LIKE 'temp_%'
ORDER BY table_rows DESC;
-- Stap 20: Uitvoering van een SQL‑statement.


-- Sectie 5: INDEX USAGE STATISTICS
-- ============================================================================

SELECT '=== INDEX ANALYSE ===' as checkpoint;
-- Stap 21: Uitvoering van een SQL‑statement.


-- Check 16: Niet gebruikte indexen (na enige tijd draaien)
-- Let op: vereist dat MySQL Performance Schema enabled is
SELECT 
  'Mogelijk ongebruikte indexen' as check_naam,
  COUNT(*) as aantal,
  'ℹ️  INFO - Controleer handmatig' as status
FROM information_schema.statistics s
WHERE s.table_schema = 'Meijendel'
  AND s.index_name != 'PRIMARY'
  AND NOT EXISTS (
    SELECT 1 FROM performance_schema.table_io_waits_summary_by_index_usage iu
    WHERE iu.object_schema = s.table_schema
      AND iu.object_name = s.table_name
      AND iu.index_name = s.index_name
      AND iu.count_star > 0
  )
  LIMIT 1;
-- Stap 22: Uitvoering van een SQL‑statement.


-- Sectie 6: DATA KWALITEIT STATISTIEKEN
-- ============================================================================

SELECT '=== DATA KWALITEIT STATISTIEKEN ===' as checkpoint;
-- Stap 23: Uitvoering van een SQL‑statement.


-- Check 17: NULL percentages in belangrijke kolommen
SELECT 
  'Soorten zonder Latijnse naam' as check_naam,
  COUNT(*) as aantal,
  CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM soorten), 1), '%') as percentage,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '⚠️  PROBLEEM' END as status
FROM soorten
WHERE latijnse_naam IS NULL OR latijnse_naam = '';
-- Stap 24: Leest gegevens uit: `soorten`.


SELECT 
  'Soorten zonder Nederlandse naam' as check_naam,
  COUNT(*) as aantal,
  CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM soorten), 1), '%') as percentage,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '⚠️  PROBLEEM' END as status
FROM soorten
WHERE soort_naam IS NULL OR soort_naam = '';
-- Stap 25: Leest gegevens uit: `tellers`.


SELECT 
  'Tellers zonder tellercode' as check_naam,
  COUNT(*) as aantal,
  CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tellers), 1), '%') as percentage,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '⚠️  PROBLEEM' END as status
FROM tellers
WHERE tellercode IS NULL OR TRIM(tellercode) = '';
-- Stap 26: Uitvoering van een SQL‑statement.


-- Sectie 7: CONSISTENTIE CHECKS
-- ============================================================================

SELECT '=== CONSISTENTIE CHECKS ===' as checkpoint;
-- Stap 27: Uitvoering van een SQL‑statement.


-- Check 18: Waarnemingen voor plots/jaren die niet bestaan in plot_jaar_oppervlak
SELECT 
  'Waarnemingen zonder plot_jaar_oppervlak record' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM territoria w
LEFT JOIN plot_jaar_oppervlak pjo ON w.plot_id = pjo.plot_id AND w.jaar = pjo.jaar
WHERE pjo.id IS NULL;
-- Stap 28: Uitvoering van een SQL‑statement.


-- Check 19: Plot oppervlaktes van 0 of negatief
SELECT 
  'Plot oppervlaktes <= 0' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM plot_jaar_oppervlak
WHERE oppervlakte_km2 <= 0;
-- Stap 29: Uitvoering van een SQL‑statement.


-- Sectie 8: NAAMGEVING CONVENTIE CHECK
-- ============================================================================

SELECT '=== NAAMGEVING CONVENTIE ===' as checkpoint;
-- Stap 30: Uitvoering van een SQL‑statement.


-- Check 20: Foreign key naming inconsistencies
SELECT 
  'Foreign keys zonder fk_ prefix' as check_naam,
  COUNT(*) as aantal,
  'ℹ️  CONVENTIE' as status
FROM information_schema.table_constraints
WHERE table_schema = 'Meijendel'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name NOT LIKE 'fk_%';
-- Stap 31: Uitvoering van een SQL‑statement.


-- Sectie 9: SAMENVATTING
-- ============================================================================

SELECT '=== ALGEMENE DATABASE STATISTIEKEN ===' as checkpoint;
-- Stap 32: Uitvoering van een SQL‑statement.


-- Totaal overzicht
SELECT 
  (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'Meijendel' AND table_type = 'BASE TABLE') as totaal_tabellen,
  (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'Meijendel' AND table_name LIKE 'temp_%') as temp_tabellen,
  (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'Meijendel') as views,
  (SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_schema = 'Meijendel' AND constraint_type = 'PRIMARY KEY') as primary_keys,
  (SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_schema = 'Meijendel' AND constraint_type = 'FOREIGN KEY') as foreign_keys,
  (SELECT COUNT(DISTINCT index_name) FROM information_schema.statistics WHERE table_schema = 'Meijendel' AND index_name != 'PRIMARY') as indexen;
-- Stap 33: Uitvoering van een SQL‑statement.


-- Record counts voor grote tabellen
SELECT 
  table_name,
  table_rows as geschat_aantal_records,
  ROUND((data_length + index_length) / 1024 / 1024, 2) as grootte_mb
FROM information_schema.tables
WHERE table_schema = 'Meijendel'
  AND table_type = 'BASE TABLE'
ORDER BY table_rows DESC
LIMIT 10;
-- Stap 34: Uitvoering van een SQL‑statement.


-- ============================================================================
-- BASISRAPPORT GENEREREN
-- ============================================================================

SELECT '=== BASISVALIDATIE AFGEROND; TR1-CONTROLES VOLGEN ===' as status;
-- Stap 35: Leest gegevens uit één of meer tabellen.

SELECT 
  'Database validatie uitgevoerd op:' as bericht,
  NOW() as timestamp;
-- Stap 36: Uitvoering van een SQL‑statement.


-- Sectie 10: FUNCTIONELE TRAITLAAG (TR1)
-- ============================================================================

SELECT '=== FUNCTIONELE TRAITLAAG TR1 ===' as checkpoint;

SELECT
  'TR1-definities en zes groepsdefinities aanwezig' as check_naam,
  CASE
    WHEN (SELECT COUNT(*) FROM trait_definition WHERE trait_version = 'TR1') = 23
     AND (SELECT COUNT(*) FROM trait_definition WHERE trait_version = 'TR1' AND verplicht_v1 = 1) = 15
     AND (SELECT COUNT(*) FROM functional_group_definition WHERE group_version = 'v1') = 6
    THEN 0 ELSE 1
  END as aantal_problemen,
  CASE
    WHEN (SELECT COUNT(*) FROM trait_definition WHERE trait_version = 'TR1') = 23
     AND (SELECT COUNT(*) FROM trait_definition WHERE trait_version = 'TR1' AND verplicht_v1 = 1) = 15
     AND (SELECT COUNT(*) FROM functional_group_definition WHERE group_version = 'v1') = 6
    THEN '✓ OK' ELSE '❌ PROBLEEM'
  END as status;

SELECT
  'Fase-B-scope bevat exact 95 bruikbare trendsoorten' as check_naam,
  ABS(95 - COUNT(*)) as aantal_problemen,
  CASE WHEN COUNT(*) = 95 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM trait_analysis_scope_species tass
JOIN trait_analysis_scope tas ON tas.id = tass.scope_id
WHERE tas.scope_code = 'TRIM_BRUIKBAAR_V1';

SELECT
  'Trait-scope bevat alle 159 territoriumhoudende broedvogels' as check_naam,
  ABS(159 - COUNT(*)) as aantal_problemen,
  CASE WHEN COUNT(*) = 159 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM trait_analysis_scope_species tass
JOIN trait_analysis_scope tas ON tas.id = tass.scope_id
WHERE tas.scope_code = 'BROEDVOGELS_MEIJENDEL_V1';

SELECT
  'Veertien importbatches aanwezig met kloppende aantallen' as check_naam,
  ABS(14 - COUNT(*))
    + SUM(CASE WHEN werkelijk <> geimporteerde_waarden THEN 1 ELSE 0 END) as aantal_problemen,
  CASE
    WHEN COUNT(*) = 14
     AND SUM(CASE WHEN werkelijk <> geimporteerde_waarden THEN 1 ELSE 0 END) = 0
    THEN '✓ OK' ELSE '❌ PROBLEEM'
  END as status
FROM (
  SELECT tib.id, tib.geimporteerde_waarden, COUNT(stv.id) as werkelijk
  FROM trait_import_batch tib
  LEFT JOIN species_trait_value stv ON stv.import_batch_id = tib.id
  GROUP BY tib.id, tib.geimporteerde_waarden
) batches;

SELECT
  'Bronwaarden zonder gekoppelde bron' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM species_trait_value stv
LEFT JOIN species_trait_value_source stvs ON stvs.species_trait_value_id = stv.id
WHERE stv.import_batch_id IS NOT NULL
  AND stvs.species_trait_value_id IS NULL;

SELECT
  'Categorie hoort niet bij de traitdefinitie' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM species_trait_value stv
JOIN trait_category tc ON tc.id = stv.category_id
WHERE tc.trait_id <> stv.trait_id;

SELECT
  'Voorkeurswaarde heeft ongeldige kwaliteitsstatus' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM species_trait_value
WHERE is_preferred = 1
  AND quality_status NOT IN ('approved', 'unknown');

SELECT
  'TR1-gapmatrix mist verplichte soort-traitcombinaties' as check_naam,
  ABS((159 * 15) - COUNT(*)) as aantal_problemen,
  CASE WHEN COUNT(*) = (159 * 15) THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM v_trait_gap_v1;

SELECT
  'Taxonomische koppelingen per soortbron zijn niet volledig' as check_naam,
  ABS(5 - COUNT(*))
    + SUM(ABS(verwacht - gekoppeld)) as aantal_problemen,
  CASE
    WHEN COUNT(*) = 5 AND SUM(ABS(verwacht - gekoppeld)) = 0
    THEN '✓ OK' ELSE '❌ PROBLEEM'
  END as status
FROM (
  SELECT ts.source_code, COUNT(*) gekoppeld,
    CASE ts.source_code
      WHEN 'ELTONTRAITS_1' THEN 157
      WHEN 'EU_BIRD_LIFE_HISTORY_2018' THEN 156
      WHEN 'GLOBAL_NEST_TRAITS_V2' THEN 155
      ELSE 159
    END verwacht
  FROM trait_taxon_mapping ttm
  JOIN trait_source ts ON ts.id = ttm.source_id
  WHERE ts.source_code IN (
    'ELTONTRAITS_1',
    'EU_BIRD_LIFE_HISTORY_2018',
    'GLOBAL_NEST_TRAITS_V2',
    'NATURALIS_NSR_VOGELTEKSTEN_2023',
    'VOGELBESCHERMING_VOGELGIDS_2026'
  )
    AND ttm.status = 'approved'
  GROUP BY ts.source_code
) bron;

SELECT
  'Alle 2.385 verplichte doelcellen zijn gereed' as check_naam,
  SUM(CASE WHEN vervolgstatus <> 'gereed' THEN 1 ELSE 0 END)
    + ABS((159 * 15) - COUNT(*)) as aantal_problemen,
  CASE
    WHEN COUNT(*) = (159 * 15)
     AND SUM(CASE WHEN vervolgstatus <> 'gereed' THEN 1 ELSE 0 END) = 0
    THEN '✓ OK' ELSE '❌ PROBLEEM'
  END as status
FROM v_trait_gap_v1;

SELECT
  'Alle 159 soorten hebben exact 15 verplichte traits in de eindbatches' as check_naam,
  ABS(159 - COUNT(*))
    + SUM(CASE WHEN aantal_traits <> 15 THEN 1 ELSE 0 END) as aantal_problemen,
  CASE
    WHEN COUNT(*) = 159 AND MIN(aantal_traits) = 15 AND MAX(aantal_traits) = 15
    THEN '✓ OK' ELSE '❌ PROBLEEM'
  END as status
FROM (
  SELECT stv.soort_id, COUNT(DISTINCT td.trait_code) as aantal_traits
  FROM species_trait_value stv
  JOIN trait_definition td ON td.id = stv.trait_id
  JOIN trait_import_batch tib ON tib.id = stv.import_batch_id
  WHERE tib.batch_code IN ('TR1FINAL_20260718', 'TR1FINAL_ALLBROED_20260720', 'TR1SEED_FINAL_20260720')
    AND td.verplicht_v1 = 1
  GROUP BY stv.soort_id
) eindsoorten;

SELECT
  'Eindwaarden hebben minimaal twee bronkoppelingen' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM (
  SELECT stv.id
  FROM species_trait_value stv
  JOIN trait_import_batch tib ON tib.id = stv.import_batch_id
  LEFT JOIN species_trait_value_source stvs ON stvs.species_trait_value_id = stv.id
  WHERE tib.batch_code IN ('TR1FINAL_20260718', 'TR1FINAL_ALLBROED_20260720', 'TR1SEED_FINAL_20260720')
  GROUP BY stv.id
  HAVING COUNT(DISTINCT stvs.source_id) < 2
) onvoldoende_bronnen;

SELECT
  'Geen geprefereerde doelwaarde is nog unknown' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM species_trait_value stv
JOIN trait_definition td ON td.id = stv.trait_id
WHERE stv.is_preferred = 1
  AND td.verplicht_v1 = 1
  AND stv.value_type = 'unknown';

SELECT
  'Fase C bevat exact 6 × 159 groepsclassificaties' as check_naam,
  ABS((6 * 159) - COUNT(*)) as aantal_problemen,
  CASE WHEN COUNT(*) = (6 * 159) THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM functional_group_membership;

SELECT
  'Iedere fase-C-groep bevat exact 159 soorten' as check_naam,
  ABS(6 - COUNT(*))
    + COALESCE(SUM(ABS(159 - aantal)), 0) as aantal_problemen,
  CASE WHEN COUNT(*) = 6 AND MIN(aantal) = 159 AND MAX(aantal) = 159
    THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM (
  SELECT functional_group_definition_id, COUNT(*) aantal
  FROM functional_group_membership
  GROUP BY functional_group_definition_id
) groepsomvang;

SELECT
  'Classificatie, binair lidmaatschap en gewicht zijn consistent' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM functional_group_membership
WHERE (classification = 'primary' AND (binary_membership <> 1 OR membership_weight <> 1.00))
   OR (classification = 'secondary' AND (binary_membership <> 1 OR membership_weight <> 0.50))
   OR (classification = 'excluded' AND (binary_membership <> 0 OR membership_weight <> 0.00))
   OR (classification = 'unknown' AND (binary_membership <> 0 OR membership_weight IS NOT NULL));

SELECT
  'Fase C bevat geen onbekende classificaties' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM functional_group_membership
WHERE classification = 'unknown';

SELECT
  'Fase C gebruikt twee geldige generatiecommits' as check_naam,
  SUM(generation_commit NOT REGEXP '^[0-9a-f]{40}$')
    + ABS(2 - COUNT(DISTINCT generation_commit)) as aantal_problemen,
  CASE
    WHEN SUM(generation_commit NOT REGEXP '^[0-9a-f]{40}$') = 0
     AND COUNT(DISTINCT generation_commit) = 2
    THEN '✓ OK' ELSE '❌ PROBLEEM'
  END as status
FROM functional_group_membership;

SELECT
  'Rationale bevat per gebruikt trait minimaal één bron' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM functional_group_membership fgm
JOIN JSON_TABLE(
  JSON_KEYS(fgm.rationale_json, '$.trait_evidence'),
  '$[*]' COLUMNS(trait_code VARCHAR(96) PATH '$')
) jt
WHERE JSON_LENGTH(JSON_EXTRACT(
  fgm.rationale_json,
  CONCAT('$.trait_evidence.', jt.trait_code, '.sources')
)) = 0;

SELECT
  'Fase-C-baseline en gevoeligheidsaantallen zijn ongewijzigd' as check_naam,
  SUM(
    ABS(v.geselecteerde_soorten - e.baseline)
    + ABS(v.inclusief_geselecteerd - e.inclusief)
    + ABS(v.strikt_geselecteerd - e.strikt)
  ) as aantal_problemen,
  CASE WHEN SUM(
    ABS(v.geselecteerde_soorten - e.baseline)
    + ABS(v.inclusief_geselecteerd - e.inclusief)
    + ABS(v.strikt_geselecteerd - e.strikt)
  ) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM v_functional_group_summary_v1 v
JOIN (
  SELECT 'fg_v1_bodem_insect' group_code, 76 baseline, 77 inclusief, 36 strikt
  UNION ALL SELECT 'fg_v1_lucht', 15, 15, 8
  UNION ALL SELECT 'fg_v1_grondbroed', 69, 69, 62
  UNION ALL SELECT 'fg_v1_holenbroed', 42, 42, 41
  UNION ALL SELECT 'fg_v1_lange_trek', 47, 47, 43
  UNION ALL SELECT 'fg_v1_zaad', 63, 63, 29
) e ON e.group_code = v.group_code;

SELECT
  'Leave-one-species-out verandert geen minimumstatus' as check_naam,
  COUNT(*) as aantal_problemen,
  CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '❌ PROBLEEM' END as status
FROM v_functional_group_summary_v1
WHERE publicatiestatus <> loso_minimumstatus;

SELECT *
FROM v_functional_group_summary_v1
ORDER BY group_code;

SELECT
  vervolgstatus,
  COUNT(*) as aantal_soort_traitcombinaties
FROM v_trait_gap_v1
GROUP BY vervolgstatus
ORDER BY vervolgstatus;

SELECT
  trait_code,
  vervolgstatus,
  COUNT(*) as aantal_soorten
FROM v_trait_gap_v1
GROUP BY trait_code, vervolgstatus
ORDER BY trait_code, vervolgstatus;

SELECT '=== VOLLEDIGE VALIDATIE INCLUSIEF TR1 EN FASE C AFGEROND ===' as status;

-- Bewaar dit rapport:
-- mysql -u root -p Meijendel < validatie.sql > validatie_rapport_$(date +%Y%m%d_%H%M%S).txt
