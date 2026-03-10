/* UITLEG
Deze query is bedoeld voor een view/rapport: Soorten per jaar.
*/

-- Stap 1: Leest gegevens uit: `territoria`.
SELECT
  w.jaar,
  COUNT(DISTINCT w.soort_id) AS aantal_getelde_soorten
FROM territoria w
GROUP BY w.jaar
ORDER BY w.jaar;
