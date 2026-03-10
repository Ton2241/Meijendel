/* UITLEG
Deze query is bedoeld voor een view/rapport: territoria per jaar per richtlijn.
*/

-- Stap 1: Leest gegevens uit: `territoria`, `soort_richtlijn`, `richtlijnen`.

SELECT 
    w.jaar AS Jaar,
    r.naam AS Richtlijn,
    SUM(w.territoria) AS Totaal_Territoria,
    COUNT(DISTINCT w.soort_id) AS Aantal_soort_naamen
FROM territoria w
JOIN soort_richtlijn sr ON w.soort_id = sr.soort_id
JOIN richtlijnen r ON sr.richtlijn_id = r.id
GROUP BY w.jaar, r.naam, r.id
ORDER BY w.jaar DESC, r.id ASC;
