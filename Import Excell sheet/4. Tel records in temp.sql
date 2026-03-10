/* UITLEG
Dit bestand hoort bij het importproces: 4. Tel records in temp.
*/

-- Stap 1: Leest gegevens uit: `import_waarnemingen_lang`.
SELECT SUM(territoria) AS totaal
FROM import_waarnemingen_lang;
