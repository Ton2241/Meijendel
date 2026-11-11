-- HISTORISCH, NIET UITVOEREN.
-- Deelregistraties per kavel zijn op 7 november 2026 volledig vervangen door
-- werkelijke vlakgeometrie en ruimtelijk afgeleide kaveldoorsnijdingen.
-- Nieuwe vlakregistraties lopen via gis/scripts/migrate_toegankelijkheidsgebieden.py.
SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = 'Historische deelimport geblokkeerd; gebruik toegankelijkheidsgebied_versie';
