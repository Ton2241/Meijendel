-- HISTORISCH, NIET UITVOEREN.
-- De voorlopige kavelregistraties uit 2024 zijn op 7 november 2026 volledig
-- vervangen door toegankelijkheidsgebied en toegankelijkheidsgebied_versie.
-- Nieuwe vlakregistraties lopen via gis/scripts/migrate_toegankelijkheidsgebieden.py.
SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = 'Historische kavelimport geblokkeerd; gebruik toegankelijkheidsgebied_versie';
