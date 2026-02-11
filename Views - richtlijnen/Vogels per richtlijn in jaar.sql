SELECT 
    s.soort_naam AS Vogelnaam,
    SUM(w.territoria) AS Totaal_Territoria
FROM waarnemingen w
JOIN soorten s ON w.soort_id = s.id
JOIN soort_richtlijn sr ON s.id = sr.soort_id
JOIN richtlijnen r ON sr.richtlijn_id = r.id
WHERE r.naam = 'Vogelrichtlijn' 
  AND w.jaar = 2025
  AND w.territoria > 0
GROUP BY s.id, s.soort_naam
ORDER BY Totaal_Territoria DESC;