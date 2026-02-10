WITH UniekeKoppeling AS (
    -- Zorg dat elke soort slechts aan één groep wordt gekoppeld via de nieuwe soort_id
    SELECT soort_id, MIN(ecogroep_id) as ecogroep_id 
    FROM soort_ecogroep 
    GROUP BY soort_id
),
GecategoriseerdeWaarnemingen AS (
    -- Koppel waarnemingen aan de honderdtallen via de unieke soort_id koppeling
    SELECT 
        w.jaar,
        w.territoria,
        (evg.groep_code DIV 100) * 100 AS groep_honderdtal
    FROM waarnemingen w
    JOIN UniekeKoppeling uk ON w.soort_id = uk.soort_id
    JOIN ecologische_vogelgroepen evg ON uk.ecogroep_id = evg.id
),
JaarTotalen AS (
    -- Bereken het totaal aantal territoria per jaar op basis van de UNIEKE koppeling
    SELECT jaar, SUM(territoria) as totaal_jaar
    FROM GecategoriseerdeWaarnemingen
    GROUP BY jaar
)
SELECT 
    gw.jaar,
    ROUND(SUM(CASE WHEN gw.groep_honderdtal = 100 THEN gw.territoria ELSE 0 END) * 100.0 / jt.totaal_jaar, 2) AS `Groep 100`,
    ROUND(SUM(CASE WHEN gw.groep_honderdtal = 200 THEN gw.territoria ELSE 0 END) * 100.0 / jt.totaal_jaar, 2) AS `Groep 200`,
    ROUND(SUM(CASE WHEN gw.groep_honderdtal = 300 THEN gw.territoria ELSE 0 END) * 100.0 / jt.totaal_jaar, 2) AS `Groep 300`,
    ROUND(SUM(CASE WHEN gw.groep_honderdtal = 400 THEN gw.territoria ELSE 0 END) * 100.0 / jt.totaal_jaar, 2) AS `Groep 400`,
    ROUND(SUM(CASE WHEN gw.groep_honderdtal = 500 THEN gw.territoria ELSE 0 END) * 100.0 / jt.totaal_jaar, 2) AS `Groep 500`,
    ROUND(SUM(CASE WHEN gw.groep_honderdtal = 600 THEN gw.territoria ELSE 0 END) * 100.0 / jt.totaal_jaar, 2) AS `Groep 600`,
    ROUND(SUM(CASE WHEN gw.groep_honderdtal = 700 THEN gw.territoria ELSE 0 END) * 100.0 / jt.totaal_jaar, 2) AS `Groep 700`,
    ROUND(SUM(CASE WHEN gw.groep_honderdtal = 800 THEN gw.territoria ELSE 0 END) * 100.0 / jt.totaal_jaar, 2) AS `Groep 800`,
    ROUND(SUM(CASE WHEN gw.groep_honderdtal = 900 THEN gw.territoria ELSE 0 END) * 100.0 / jt.totaal_jaar, 2) AS `Groep 900`
FROM GecategoriseerdeWaarnemingen gw
JOIN JaarTotalen jt ON gw.jaar = jt.jaar
GROUP BY gw.jaar, jt.totaal_jaar
ORDER BY gw.jaar ASC;