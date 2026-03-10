/* UITLEG
Dit bestand bevat een bewerking op data: kolommen_taalnamen_toevoegen_soorten.
*/

-- Stap 1: Past de structuur van tabel `soorten` aan.
ALTER TABLE `soorten`
  ADD COLUMN IF NOT EXISTS `duitse_naam` varchar(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `franse_naam` varchar(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `spaanse_naam` varchar(255) DEFAULT NULL;
