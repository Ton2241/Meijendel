-- Idempotent herstel van de maatregelenclassificatie.
-- De algemene recreatiekernwoorden horen niet onder de specifieke maatregel
-- strandreservaten. De bestaande plot-jaarregels worden niet gewijzigd.

USE Meijendel;

START TRANSACTION;

UPDATE maatregelen
SET druk_aandachtspunt = 'Overgrassing en\nverstruweling'
WHERE code = 'maaibeheer_aanvullend'
  AND druk_aandachtspunt = 'OVergrassing en\nverstruweling';

INSERT INTO maatregelen
  (code, maatregelgroep_code, omschrijving, druk_aandachtspunt)
VALUES
  ('rust_en_recreatiebeheer', 'rustmaatregel', 'Rust- en recreatiebeheer',
   'Recreatiedruk en onvoldoende rust')
ON DUPLICATE KEY UPDATE
  maatregelgroep_code = VALUES(maatregelgroep_code),
  omschrijving = VALUES(omschrijving),
  druk_aandachtspunt = VALUES(druk_aandachtspunt);

SET @rust_en_recreatiebeheer_id :=
  (SELECT id FROM maatregelen WHERE code = 'rust_en_recreatiebeheer');
SET @strandreservaten_id :=
  (SELECT id FROM maatregelen WHERE code = 'strandreservaten');

UPDATE maatregelen_kernwoorden
SET parent_maatregel_id = @rust_en_recreatiebeheer_id
WHERE code IN ('recreatiezonering', 'honden_aanlijnplicht', 'parkeerreductie', 'routing');

INSERT INTO maatregelen_kernwoorden
  (code, kernwoord, parent_maatregel_id, actief)
VALUES
  ('strandreservaat', 'Strandreservaat', @strandreservaten_id, 1)
ON DUPLICATE KEY UPDATE
  kernwoord = VALUES(kernwoord),
  parent_maatregel_id = VALUES(parent_maatregel_id),
  actief = VALUES(actief);

COMMIT;

-- Controle na uitvoering: deze resultset hoort 11, 26, 144 en 0 te tonen.
SELECT
  (SELECT COUNT(*) FROM maatregelen) AS n_maatregelen,
  (SELECT COUNT(*) FROM maatregelen_kernwoorden) AS n_maatregelen_kernwoorden,
  (SELECT COUNT(*) FROM plot_jaar_maatregel) AS n_plot_jaar_maatregel,
  (SELECT COUNT(*)
   FROM maatregelen_kernwoorden mk
   LEFT JOIN maatregelen m ON m.id = mk.parent_maatregel_id
   WHERE mk.parent_maatregel_id IS NOT NULL AND m.id IS NULL) AS n_verweesde_kernwoorden,
  (SELECT COUNT(*) FROM plot_jaar_toegankelijkheid_deel) AS n_plot_jaar_toegankelijkheid_deel;
