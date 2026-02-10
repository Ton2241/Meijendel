SELECT 
    s.Soort, 
    SUM(w.territoria) AS totaal
FROM waarnemingen w
JOIN soorten s ON w.soort_id = s.id
WHERE w.jaar = 2024
GROUP BY s.Soort
ORDER BY totaal DESC
LIMIT 10