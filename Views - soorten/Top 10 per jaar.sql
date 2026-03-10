/* UITLEG
Deze query is bedoeld voor een view/rapport: Top 10 per jaar.
*/

-- Stap 1: Leest gegevens uit: `territoria`, `soorten`.
SELECT 
    s.soort_naam, 
    SUM(w.territoria) AS totaal
FROM territoria w
JOIN soorten s ON w.soort_id = s.id
WHERE w.jaar = 2024
GROUP BY s.soort_naam
ORDER BY totaal DESC
LIMIT 10
