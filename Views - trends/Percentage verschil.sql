SELECT 
    s.soort_naam AS vogelnaam,
    -- Zuid-Holland Verschil (bezetting_percentage)
    ROUND(((t2.waarde / t1.waarde) * 100) - 100, 1) AS `ZH_bezetting_percentage`,

    -- Meijendel Verschil (bezetting_percentage)
    ROUND(
        (
            (SELECT COALESCE(SUM(w.territoria), 0) / NULLIF((SELECT SUM(pjo.oppervlakte_km2) FROM plot_jaar_oppervlak pjo WHERE pjo.jaar = 2024), 0)
             FROM waarnemingen w 
             WHERE w.soort_id = s.id AND w.jaar = 2024)
            /
            NULLIF((SELECT COALESCE(SUM(w.territoria), 0) / NULLIF((SELECT SUM(pjo.oppervlakte_km2) FROM plot_jaar_oppervlak pjo WHERE pjo.jaar = 1990), 0)
             FROM waarnemingen w 
             WHERE w.soort_id = s.id AND w.jaar = 1990), 0)
        ) * 100 - 100, 1) AS `Meijendel_bezetting_percentage`,
    
    -- Lokaal Verschil in Procentpunten
    ROUND(
        ((
            (SELECT COALESCE(SUM(w.territoria), 0) / NULLIF((SELECT SUM(pjo.oppervlakte_km2) FROM plot_jaar_oppervlak pjo WHERE pjo.jaar = 2024), 0)
             FROM waarnemingen w 
             WHERE w.soort_id = s.id AND w.jaar = 2024)
            /
            NULLIF((SELECT COALESCE(SUM(w.territoria), 0) / NULLIF((SELECT SUM(pjo.oppervlakte_km2) FROM plot_jaar_oppervlak pjo WHERE pjo.jaar = 1990), 0)
             FROM waarnemingen w 
             WHERE w.soort_id = s.id AND w.jaar = 1990), 0)
        ) * 100 - 100)
        - 
        (((t2.waarde / t1.waarde) * 100) - 100), 1) AS `Lokaal_Verschil_PP`

FROM trends t1
JOIN trends t2 ON t1.soort_id = t2.soort_id AND t1.regio = t2.regio
JOIN soorten s ON t1.soort_id = s.id
WHERE t1.regio = 'Zuid-Holland'
  AND t1.jaar = 1990
  AND t2.jaar = 2024
  AND t1.waarde > 0 
GROUP BY s.soort_naam, s.id, t1.waarde, t2.waarde
HAVING (SELECT SUM(w.territoria) FROM waarnemingen w WHERE w.soort_id = s.id AND w.jaar = 1990) > 0
ORDER BY `Lokaal_Verschil_PP` ASC;