SELECT 
    s.Soort AS Vogelnaam,
    IFNULL(f.familienaam_nl, '--- Nog koppelen ---') AS Familie,
    GROUP_CONCAT(DISTINCT r.naam ORDER BY r.naam SEPARATOR ', ') AS Lijsten
FROM soorten s
INNER JOIN waarnemingen w ON s.id = w.soort_id
INNER JOIN soort_richtlijn sr ON s.id = sr.soort_id
INNER JOIN richtlijnen r ON sr.richtlijn_id = r.id
LEFT JOIN soort_familie sf ON s.id = sf.soort_id
LEFT JOIN familie f ON sf.familie_id = f.id
GROUP BY s.id, s.Soort, f.familienaam_nl
ORDER BY s.Soort ASC;