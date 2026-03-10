/* UITLEG
Dit bestand bevat een bewerking op data: delete waarnemingen jaarregistraties.
*/

-- Stap 1: Verwijdert rijen uit tabel `territoria`.
DELETE FROM territoria
WHERE jaar = 1980;
