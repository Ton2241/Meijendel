/* UITLEG
Dit bestand bevat een bewerking op data: Latijnse namen.
*/

-- Stap 1: Uitvoering van een SQL‑statement.
-- rechtstreeks uit soorten, zonder join naar een externe tabel
SELECT 
    s.euring_code,
    s.soort_naam AS nederlandse_naam,
    s.latijnse_naam
FROM soorten s
ORDER BY s.soort_naam ASC;
-- Stap 2: Uitvoering van een SQL‑statement.


WHERE s.latijnse_naam IS NULL OR s.latijnse_naam = ''
