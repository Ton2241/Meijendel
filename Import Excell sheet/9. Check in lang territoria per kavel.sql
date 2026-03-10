/* UITLEG
Dit bestand hoort bij het importproces: 9. Check in lang territoria per kavel.
*/

-- Stap 1: Leest gegevens uit: `import_waarnemingen_lang`, `plots`.
SELECT 
    t.plot_id, 
    p.kavel_nummer, 
    SUM(t.territoria) AS totaal_territoria
FROM import_waarnemingen_lang t
JOIN plots p ON t.plot_id = p.plot_id
GROUP BY t.plot_id, p.kavel_nummer;
