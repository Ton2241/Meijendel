/* UITLEG
Deze query is bedoeld voor een view/rapport: Meeuwen.
*/

-- Stap 1: Leest gegevens uit: `territoria`, `soorten`.
SELECT
  t.jaar,
  s.soort_naam AS meeuw,
  SUM(t.territoria) AS totaal_territoria
FROM territoria t
JOIN soorten s
  ON s.id = t.soort_id
WHERE LOWER(s.soort_naam) LIKE '%meeuw%'
GROUP BY
  t.jaar,
  s.soort_naam
HAVING SUM(t.territoria) > 0
ORDER BY
  t.jaar,
  s.soort_naam;
