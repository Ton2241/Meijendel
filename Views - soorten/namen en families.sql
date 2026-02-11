SELECT 
    s.soort_naam AS Vogelnaam,
    f.familienaam_nl AS Familie,
    GROUP_CONCAT(DISTINCT r.naam ORDER BY r.naam SEPARATOR ', ') AS Lijsten
FROM soorten s
-- Koppeling met waarnemingen (alleen getelde vogels in Meijendel)
INNER JOIN waarnemingen w ON s.id = w.soort_id
-- Koppeling met familie via de nieuwe soort_id
INNER JOIN soort_familie sf ON s.id = sf.soort_id
INNER JOIN familie f ON sf.familie_id = f.id
-- Koppeling met richtlijnen via de nieuwe soort_id
INNER JOIN soort_richtlijn sr ON s.id = sr.soort_id
INNER JOIN richtlijnen r ON sr.richtlijn_id = r.id
GROUP BY s.id, s.soort_naam, f.familienaam_nl
ORDER BY s.soort_naam ASC;