/* UITLEG
Dit bestand hoort bij het importproces: 6. Wel in temp maar niet in plot_jaar_oppervlak.
*/

-- Stap 1: Uitvoering van een SQL‑statement.
-- Een ontbrekende combinatie blokkeert de INSERT in territoria via de foreign key
SELECT DISTINCT 
    i.plot_id,
    i.jaar,
    p.plot_naam,
    p.kavel_nummer
FROM import_waarnemingen_lang i
JOIN plots p ON i.plot_id = p.plot_id
WHERE NOT EXISTS (
    SELECT 1 
    FROM plot_jaar_oppervlak pjo 
    WHERE pjo.plot_id = i.plot_id 
    AND pjo.jaar = i.jaar
)
ORDER BY i.jaar, p.kavel_nummer;
