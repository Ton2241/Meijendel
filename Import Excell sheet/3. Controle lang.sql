/* UITLEG
Dit bestand hoort bij het importproces: 3. Controle lang.
*/

-- Stap 1: Leest gegevens uit: `import_waarnemingen_lang`, `plot_jaar_oppervlak`, `plots`.
-- Let op: hier bewust GEEN filter op p.in_gebruik = 1.
-- Dit is een importcontrole; ook niet-actieve plots mogen hier nog als koppeling voorkomen.
SELECT DISTINCT t.plot_id, p.plot_naam
FROM import_waarnemingen_lang t
JOIN plots p ON t.plot_id = p.plot_id
WHERE NOT EXISTS (
    SELECT 1 FROM plot_jaar_oppervlak pjo 
    WHERE pjo.plot_id = t.plot_id AND pjo.jaar = t.jaar
);
