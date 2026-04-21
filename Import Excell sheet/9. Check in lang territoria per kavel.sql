/* UITLEG
Dit bestand hoort bij het importproces: 9. Check in lang territoria per kavel.
*/

-- Stap 1: Leest gegevens uit: `import_waarnemingen_lang`, `plots`.
-- Let op: hier bewust GEEN filter op p.in_gebruik = 1.
-- Deze importsom moet alle gekoppelde plots tonen, ook als ze later op niet-actief staan.
SELECT 
    t.plot_id, 
    p.kavel_nummer, 
    SUM(t.territoria) AS totaal_territoria
FROM import_waarnemingen_lang t
JOIN plots p ON t.plot_id = p.plot_id
GROUP BY t.plot_id, p.kavel_nummer;
