SELECT 
    s.soort_naam AS vogelsoort,
    w.jaar,
    SUM(w.territoria) AS totaal_territoria,
    GROUP_CONCAT(DISTINCT p.kavel_nummer ORDER BY p.kavel_nummer SEPARATOR ', ') AS kavels
FROM kernopgave_soort ks
JOIN soorten s ON ks.soort_id = s.id
LEFT JOIN waarnemingen w ON s.id = w.soort_id
LEFT JOIN plots p ON w.plot_id = p.plot_id
GROUP BY 
    s.soort_naam, 
    w.jaar
ORDER BY 
    w.jaar IS NULL ASC,  -- Houdt de lege records onderaan
    s.soort_naam ASC, 
    w.jaar DESC;