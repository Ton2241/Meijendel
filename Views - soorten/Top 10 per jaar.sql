SELECT 
    s.soort_naam, 
    SUM(w.territoria) AS totaal
FROM waarnemingen w
JOIN soorten s ON w.soort_id = s.id
WHERE w.jaar = 2024
GROUP BY s.soort_naam
ORDER BY totaal DESC
LIMIT 10