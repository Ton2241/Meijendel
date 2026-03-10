/* UITLEG
Dit bestand hoort bij het importproces: euring toevoegen na correctie naam.
*/

-- Stap 1: Wijzigt bestaande rijen in tabel `vogelstand_1924`.
UPDATE vogelstand_1924 v
JOIN soorten s ON v.euring = s.euring_code
SET v.vogelnaam = s.soort_naam
WHERE v.euring IS NOT NULL;
