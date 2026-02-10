
SELECT 
    w.jaar AS Jaar,
    r.naam AS Richtlijn,
    SUM(w.territoria) AS Totaal_Territoria,
    COUNT(DISTINCT w.soort_id) AS Aantal_Soorten
FROM waarnemingen w
JOIN soort_richtlijn sr ON w.soort_id = sr.soort_id
JOIN richtlijnen r ON sr.richtlijn_id = r.id
GROUP BY w.jaar, r.naam, r.id
ORDER BY w.jaar DESC, r.id ASC;