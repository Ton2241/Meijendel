SELECT 
    s.Soort AS vogelsoort,
    w.jaar,
    SUM(w.territoria) AS totaal_territoria,
    GROUP_CONCAT(DISTINCT p.KavelNummer ORDER BY p.KavelNummer SEPARATOR ', ') AS kavels
FROM kernopgave_soort ks
JOIN soorten s ON ks.soort_id = s.id
LEFT JOIN waarnemingen w ON s.id = w.soort_id
LEFT JOIN plots p ON w.Plotid = p.Plotid
GROUP BY 
    s.Soort, 
    w.jaar
ORDER BY 
    w.jaar IS NULL ASC,  -- Houdt de lege records onderaan
    s.Soort ASC, 
    w.jaar DESC;