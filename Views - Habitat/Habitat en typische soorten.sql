SELECT 
    h.habitat_code, 
    h.habitat_naam,
    GROUP_CONCAT(s.Soort ORDER BY s.Soort SEPARATOR ', ') AS typische_soorten
FROM habitattypen h
JOIN soort_habitat sh ON h.id = sh.habitat_id
JOIN soorten s ON sh.soort_id = s.id
GROUP BY h.habitat_code, h.habitat_naam
ORDER BY h.habitat_code;