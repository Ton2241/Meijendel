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
  'Tellers zonder email' as check_naam,
  COUNT(*) as aantal,
  CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tellers), 1), '%') as percentage,
  'ℹ️  INFO' as status
FROM tellers
WHERE email IS NULL OR email = '';
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
-- EINDRAPPORT GENEREREN
-- ============================================================================

SELECT '=== VALIDATIE AFGEROND ===' as status;
-- Stap 35: Leest gegevens uit één of meer tabellen.

SELECT 
  'Database validatie uitgevoerd op:' as bericht,
  NOW() as timestamp;
-- Stap 36: Uitvoering van een SQL‑statement.


-- Bewaar dit rapport:
-- mysql -u root -p Meijendel < validatie.sql > validatie_rapport_$(date +%Y%m%d_%H%M%S).txt
