WITH GeselecteerdeGroepen AS (
    -- Stap 1: Kies per soort uitsluitend de numeriek laagste groep_code
    SELECT 
        se.soort_id,
        MIN(evg.groep_code) as gekozen_code
    FROM soort_ecogroep se
    JOIN ecologische_vogelgroepen evg ON se.ecogroep_id = evg.id
    WHERE evg.groep_code % 100 != 0 -- Filter op specifieke subgroepen
    GROUP BY se.soort_id
),
JaarData AS (
    -- Stap 2: Selecteer territoria voor het jaar 2025 en sluit specifieke plots uit
    SELECT 
        w.plotid,
        w.soort_id,
        w.territoria
    FROM waarnemingen w
    WHERE w.jaar = 2025
      AND w.plotid NOT IN (3503, 3514)
),
GroepTotalenPerPlot AS (
    -- Stap 3: Sommatie per groep en totaal per plot via Window Function
    SELECT 
        jd.plotid,
        gg.gekozen_code,
        SUM(jd.territoria) as totaal_groep_territoria,
        SUM(SUM(jd.territoria)) OVER(PARTITION BY jd.plotid) as plot_totaal
    FROM JaarData jd
    JOIN GeselecteerdeGroepen gg ON jd.soort_id = gg.soort_id
    GROUP BY jd.plotid, gg.gekozen_code
)
-- Stap 4: Finale selectie met percentageberekening en afronding
SELECT 
    gtp.plotid AS Plotid,
    2025 AS jaar,
    gtp.gekozen_code AS groep_code,
    evg.beschrijving AS `Ecologische Groep`,
    ROUND((gtp.totaal_groep_territoria / NULLIF(gtp.plot_totaal, 0)) * 100, 0) AS `%`
FROM GroepTotalenPerPlot gtp
JOIN ecologische_vogelgroepen evg ON gtp.gekozen_code = evg.groep_code
WHERE ROUND((gtp.totaal_groep_territoria / NULLIF(gtp.plot_totaal, 0)) * 100, 0) > 0
ORDER BY gtp.plotid ASC, `%` DESC;