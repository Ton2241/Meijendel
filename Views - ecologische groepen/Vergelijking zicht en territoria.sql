SELECT 
    IFNULL(k.plot_id, v.plot_id) AS plot_id,
    IFNULL(k.groep_code, v.groep_code) AS Code,
    IFNULL(k.`Ecologische Groep (Beschrijving uit SQL)`, v.`Ecologische Groep (Beschrijving uit SQL)`) AS Beschrijving,
    SUM(IFNULL(k.`%`, 0)) AS Percentage_Kavel,
    SUM(IFNULL(v.`%`, 0)) AS Percentage_Vogels
FROM `analyse_ecologie_kavels` k
LEFT JOIN `analyse ecologie vogelsoorten` v 
    ON k.plot_id = v.plot_id AND k.groep_code = v.groep_code
GROUP BY 1, 2, 3

UNION

SELECT 
    v.plot_id,
    v.groep_code,
    v.`Ecologische Groep (Beschrijving uit SQL)`,
    0 AS Percentage_Kavel,
    SUM(v.`%`) AS Percentage_Vogels
FROM `analyse ecologie vogelsoorten` v
LEFT JOIN `analyse_ecologie_kavels` k 
    ON k.plot_id = v.plot_id AND k.groep_code = v.groep_code
WHERE k.plot_id IS NULL
GROUP BY 1, 2, 3

ORDER BY plot_id ASC, Percentage_Kavel DESC;