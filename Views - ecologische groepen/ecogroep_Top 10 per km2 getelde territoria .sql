SELECT 
    FLOOR(g.groep_code / 100) * 100 AS hoofdgroep_cluster,
    w.jaar,
    COUNT(DISTINCT w.soort_id) AS aantal_unieke_soorten,
    SUM(w.territoria) AS totaal_territoria
FROM ecologische_vogelgroepen g
JOIN soort_ecogroep seg ON g.id = seg.ecogroep_id
JOIN waarnemingen w ON seg.soort_id = w.soort_id
GROUP BY hoofdgroep_cluster, w.jaar
ORDER BY w.jaar DESC, hoofdgroep_cluster ASC;
