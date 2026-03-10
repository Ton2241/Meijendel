/* UITLEG
Dit bestand hoort bij het importproces: 5.
*/

-- Stap 1: Wijzigt bestaande rijen in tabel `import_waarnemingen_lang`.
UPDATE `import_waarnemingen_lang` i
JOIN `soorten` s ON i.`euring_code` = s.`euring_code`
SET i.`soort_id` = s.`id`;
