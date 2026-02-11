SELECT 
    s.id AS soortid,
    s.soort AS vogelnaam,
    se.prioriteit,
    evg.groep_code AS groep_code,
    evg.beschrijving AS ecologische_groep_beschrijving
FROM soort_ecogroep se
JOIN soorten s ON se.soort_id = s.id
JOIN ecologische_vogelgroepen evg ON se.ecogroep_id = evg.id
WHERE se.soort_id IN (
    SELECT se2.soort_id 
    FROM soort_ecogroep se2
    JOIN ecologische_vogelgroepen evg2 ON se2.ecogroep_id = evg2.id
    WHERE evg2.groep_code bezetting_percentage 100 != 0
    GROUP BY se2.soort_id 
    HAVING COUNT(*) > 1
)
AND evg.groep_code bezetting_percentage 100 != 0
ORDER BY s.soort ASC, se.prioriteit ASC, evg.groep_code ASC;