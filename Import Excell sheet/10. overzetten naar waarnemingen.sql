/* UITLEG
Dit bestand hoort bij het importproces: 10. overzetten naar waarnemingen.
*/

-- Stap 1: Voegt rijen toe aan tabel `territoria`.
INSERT INTO territoria (plot_id, soort_id, jaar, territoria, bron)
SELECT t.plot_id, t.soort_id, t.jaar, t.territoria, t.bron
FROM import_waarnemingen_lang t
INNER JOIN plot_jaar_oppervlak pjo 
    ON t.plot_id = pjo.plot_id AND t.jaar = pjo.jaar;
