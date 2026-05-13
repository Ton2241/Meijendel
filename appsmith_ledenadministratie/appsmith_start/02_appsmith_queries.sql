/* Appsmith query's voor de eerste pagina "Leden".
   Maak in Appsmith een MySQL datasource naar database `meijendel`.
*/

-- Naam in Appsmith: q_stats
SELECT label, waarde
FROM appsmith_teller_stats
ORDER BY FIELD(
  label,
  'totaal tellers',
  'actieve gewone leden',
  'aspiranten',
  'oudtellers',
  'zonder email',
  'zonder mobiel',
  'zonder woonplaats'
);

-- Naam in Appsmith: q_tellers
-- Widget: inpZoeken.text
SELECT
  id,
  tellercode,
  naam,
  soort_lid,
  woonplaats,
  email,
  telefoon_mobiel,
  aantal_jaren_geteld,
  aantal_plots,
  eerste_jaar,
  laatste_jaar,
  datakwaliteit
FROM appsmith_teller_lijst
WHERE
  (
    '{{inpZoeken.text || ""}}' = ''
    OR naam LIKE CONCAT('%', '{{inpZoeken.text || ""}}', '%')
    OR tellercode LIKE CONCAT('%', '{{inpZoeken.text || ""}}', '%')
    OR woonplaats LIKE CONCAT('%', '{{inpZoeken.text || ""}}', '%')
  )
ORDER BY achternaam, voornaam, tellercode
LIMIT 500;

-- Naam in Appsmith: q_teller_detail
-- Widget: tblTellers.selectedRow.id
SELECT *
FROM appsmith_teller_detail
WHERE id = {{tblTellers.selectedRow.id || 0}};

-- Naam in Appsmith: q_datakwaliteit
SELECT id, tellercode, naam, soort_lid, aandachtspunt
FROM appsmith_teller_datakwaliteit
ORDER BY soort_lid, naam
LIMIT 500;

-- Naam in Appsmith: q_soort_lid_opties
SELECT '' AS label, '' AS value
UNION ALL
SELECT soort_lid AS label, soort_lid AS value
FROM tellers
GROUP BY soort_lid
ORDER BY label;

-- Naam in Appsmith: q_datakwaliteit_opties
SELECT '' AS label, '' AS value
UNION ALL SELECT 'compleet', 'compleet'
UNION ALL SELECT 'mist email', 'mist email'
UNION ALL SELECT 'mist mobiel', 'mist mobiel'
UNION ALL SELECT 'mist woonplaats', 'mist woonplaats';
