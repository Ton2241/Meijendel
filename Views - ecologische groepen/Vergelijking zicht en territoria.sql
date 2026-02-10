SELECT 
    IFNULL(k.Plotid, v.Plotid) AS Plotid,
    IFNULL(k.groep_code, v.groep_code) AS Code,
    IFNULL(k.`Ecologische Groep (Beschrijving uit SQL)`, v.`Ecologische Groep (Beschrijving uit SQL)`) AS Beschrijving,
    SUM(IFNULL(k.`%`, 0)) AS Percentage_Kavel,
    SUM(IFNULL(v.`%`, 0)) AS Percentage_Vogels
FROM `Analyse ecologie kavels` k
LEFT JOIN `analyse ecologie vogelsoorten` v 
    ON k.Plotid = v.Plotid AND k.groep_code = v.groep_code
GROUP BY 1, 2, 3

UNION

SELECT 
    v.Plotid,
    v.groep_code,
    v.`Ecologische Groep (Beschrijving uit SQL)`,
    0 AS Percentage_Kavel,
    SUM(v.`%`) AS Percentage_Vogels
FROM `analyse ecologie vogelsoorten` v
LEFT JOIN `Analyse ecologie kavels` k 
    ON k.Plotid = v.Plotid AND k.groep_code = v.groep_code
WHERE k.Plotid IS NULL
GROUP BY 1, 2, 3

ORDER BY Plotid ASC, Percentage_Kavel DESC;