/* Startviews voor Appsmith ledenadministratie.
   Doel: read-only basis voor zoeken, detailkaart, statistiek en datakwaliteit.
*/

CREATE OR REPLACE VIEW appsmith_teller_lijst AS
SELECT
  t.id,
  t.tellercode,
  TRIM(CONCAT_WS(' ', NULLIF(t.voornaam, ''), NULLIF(t.tussenvoegsel, ''), NULLIF(t.achternaam, ''))) AS naam,
  t.voornaam,
  t.tussenvoegsel,
  t.achternaam,
  t.soort_lid,
  t.woonplaats,
  t.email,
  t.telefoon_mobiel,
  t.bandnummer,
  COUNT(DISTINCT pjt.jaar) AS aantal_jaren_geteld,
  COUNT(DISTINCT pjt.plot_id) AS aantal_plots,
  COUNT(pjt.id) AS aantal_plotjaren,
  MIN(pjt.jaar) AS eerste_jaar,
  MAX(pjt.jaar) AS laatste_jaar,
  CASE
    WHEN COALESCE(t.email, '') = '' THEN 'mist email'
    WHEN COALESCE(t.telefoon_mobiel, '') = '' THEN 'mist mobiel'
    WHEN COALESCE(t.woonplaats, '') = '' THEN 'mist woonplaats'
    ELSE 'compleet'
  END AS datakwaliteit
FROM tellers t
LEFT JOIN plot_jaar_teller pjt ON pjt.teller_id = t.id
GROUP BY
  t.id,
  t.tellercode,
  t.voornaam,
  t.tussenvoegsel,
  t.achternaam,
  t.soort_lid,
  t.woonplaats,
  t.email,
  t.telefoon_mobiel,
  t.bandnummer;

CREATE OR REPLACE VIEW appsmith_teller_detail AS
SELECT
  t.id,
  t.tellercode,
  TRIM(CONCAT_WS(' ', NULLIF(t.voornaam, ''), NULLIF(t.tussenvoegsel, ''), NULLIF(t.achternaam, ''))) AS naam,
  t.voornaam,
  t.tussenvoegsel,
  t.achternaam,
  t.straat,
  t.huisnummer,
  t.postcode,
  t.woonplaats,
  t.telefoon_vast,
  t.telefoon_mobiel,
  t.email,
  t.soort_lid,
  t.bandnummer,
  COUNT(DISTINCT pjt.jaar) AS aantal_jaren_geteld,
  COUNT(DISTINCT pjt.plot_id) AS aantal_plots,
  COUNT(pjt.id) AS aantal_plotjaren,
  MIN(pjt.jaar) AS eerste_jaar,
  MAX(pjt.jaar) AS laatste_jaar,
  GROUP_CONCAT(DISTINCT p.kavel_nummer ORDER BY p.kavel_nummer SEPARATOR ', ') AS kavels
FROM tellers t
LEFT JOIN plot_jaar_teller pjt ON pjt.teller_id = t.id
LEFT JOIN plots p ON p.plot_id = pjt.plot_id
GROUP BY
  t.id,
  t.tellercode,
  t.voornaam,
  t.tussenvoegsel,
  t.achternaam,
  t.straat,
  t.huisnummer,
  t.postcode,
  t.woonplaats,
  t.telefoon_vast,
  t.telefoon_mobiel,
  t.email,
  t.soort_lid,
  t.bandnummer;

CREATE OR REPLACE VIEW appsmith_teller_stats AS
SELECT 'totaal tellers' AS label, COUNT(*) AS waarde FROM tellers
UNION ALL
SELECT 'actieve gewone leden', COUNT(*) FROM tellers WHERE soort_lid = 'gewoon'
UNION ALL
SELECT 'aspiranten', COUNT(*) FROM tellers WHERE soort_lid = 'aspirant'
UNION ALL
SELECT 'oudtellers', COUNT(*) FROM tellers WHERE soort_lid = 'oudteller'
UNION ALL
SELECT 'zonder email', COUNT(*) FROM tellers WHERE COALESCE(email, '') = ''
UNION ALL
SELECT 'zonder mobiel', COUNT(*) FROM tellers WHERE COALESCE(telefoon_mobiel, '') = ''
UNION ALL
SELECT 'zonder woonplaats', COUNT(*) FROM tellers WHERE COALESCE(woonplaats, '') = '';

CREATE OR REPLACE VIEW appsmith_teller_datakwaliteit AS
SELECT
  t.id,
  t.tellercode,
  TRIM(CONCAT_WS(' ', NULLIF(t.voornaam, ''), NULLIF(t.tussenvoegsel, ''), NULLIF(t.achternaam, ''))) AS naam,
  t.soort_lid,
  CONCAT_WS(
    ', ',
    IF(COALESCE(t.email, '') = '', 'email ontbreekt', NULL),
    IF(COALESCE(t.telefoon_mobiel, '') = '', 'mobiel ontbreekt', NULL),
    IF(COALESCE(t.woonplaats, '') = '', 'woonplaats ontbreekt', NULL),
    IF(COALESCE(t.postcode, '') = '', 'postcode ontbreekt', NULL)
  ) AS aandachtspunt
FROM tellers t
WHERE
  COALESCE(t.email, '') = ''
  OR COALESCE(t.telefoon_mobiel, '') = ''
  OR COALESCE(t.woonplaats, '') = ''
  OR COALESCE(t.postcode, '') = '';

CREATE OR REPLACE VIEW appsmith_teller_telhistorie AS
SELECT
  t.id AS teller_id,
  t.tellercode,
  TRIM(CONCAT_WS(' ', NULLIF(t.voornaam, ''), NULLIF(t.tussenvoegsel, ''), NULLIF(t.achternaam, ''))) AS naam,
  pjt.jaar,
  COUNT(DISTINCT pjt.plot_id) AS aantal_plots,
  GROUP_CONCAT(DISTINCT COALESCE(p.kavel_nummer, p.plot_naam, CAST(p.plot_id AS CHAR)) ORDER BY p.kavel_nummer, p.plot_naam SEPARATOR ', ') AS kavels
FROM tellers t
JOIN plot_jaar_teller pjt ON pjt.teller_id = t.id
LEFT JOIN plots p ON p.plot_id = pjt.plot_id
GROUP BY
  t.id,
  t.tellercode,
  t.voornaam,
  t.tussenvoegsel,
  t.achternaam,
  pjt.jaar;

CREATE OR REPLACE VIEW appsmith_actieve_tellers_per_jaar AS
SELECT
  pjt.jaar,
  COUNT(DISTINCT pjt.teller_id) AS actieve_tellers,
  COUNT(DISTINCT pjt.plot_id) AS getelde_plots,
  COUNT(*) AS plotjaren
FROM plot_jaar_teller pjt
GROUP BY pjt.jaar;
