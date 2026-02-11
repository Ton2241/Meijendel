WITH GeselecteerdeGroepen AS (
    -- Stap 1: Kies per soort de numeriek laagste groep_code
    SELECT 
        se.soort_id,
        MIN(evg.groep_code) as gekozen_code
    FROM soort_ecogroep se
    JOIN ecologische_vogelgroepen evg ON se.ecogroep_id = evg.id
    WHERE evg.groep_code % 100 != 0 
    GROUP BY se.soort_id
),
JaarData AS (
    -- Stap 2: Filter op één specifiek plot (pas het nummer hieronder aan)
    SELECT 
        w.jaar,
        w.plot_id,
        w.soort_id,
        w.territoria
    FROM waarnemingen w
    WHERE w.plot_id = 3500 -- VERVANG DIT DOOR HET GEWENSTE plot_id
),
GroepTotalenPerJaar AS (
    -- Stap 3: Bereken totalen per jaar voor dit plot
    SELECT 
        jd.jaar,
        jd.plot_id,
        gg.gekozen_code,
        SUM(jd.territoria) as totaal_groep_territoria,
        SUM(SUM(jd.territoria)) OVER(PARTITION BY jd.jaar) as jaar_totaal
    FROM JaarData jd
    JOIN GeselecteerdeGroepen gg ON jd.soort_id = gg.soort_id
    GROUP BY jd.jaar, gg.gekozen_code
)
-- Stap 4: Finale selectie
SELECT 
    gtj.plot_id AS plot_id,
    gtj.jaar AS jaar,
    gtj.gekozen_code AS groep_code,
    evg.beschrijving AS `Ecologische Groep`,
    ROUND((gtj.totaal_groep_territoria / NULLIF(gtj.jaar_totaal, 0)) * 100, 0) AS `%`
FROM GroepTotalenPerJaar gtj
JOIN ecologische_vogelgroepen evg ON gtj.gekozen_code = evg.groep_code
WHERE ROUND((gtj.totaal_groep_territoria / NULLIF(gtj.jaar_totaal, 0)) * 100, 0) > 0
ORDER BY gtj.jaar DESC, `%` DESC;