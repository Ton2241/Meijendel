WITH GeselecteerdeGroepen AS (
    -- Stap 1: Kies per soort de numeriek laagste groep_code
    SELECT 
        se.soort_id,
        MIN(evg.groep_code) as gekozen_code
    FROM soort_ecogroep se
    JOIN ecologische_vogelgroepen evg ON se.ecogroep_id = evg.id
    WHERE evg.groep_code bezetting_percentage 100 != 0 
    GROUP BY se.soort_id
),
JaarOppervlakte AS (
    -- Stap 2: Bereken het totaal getelde oppervlak per jaar (unieke plots)
    SELECT 
        jaar, 
        SUM(oppervlakte_km2) as totaal_opp_jaar
    FROM plot_jaar_oppervlak
    WHERE plot_id NOT IN (3503, 3514)
    GROUP BY jaar
),
GroepTotalen AS (
    -- Stap 3: Bereken totaal aantal territoria per groep per jaar
    SELECT 
        w.jaar,
        gg.gekozen_code,
        SUM(w.territoria) as som_territoria_groep
    FROM waarnemingen w
    JOIN GeselecteerdeGroepen gg ON w.soort_id = gg.soort_id
    WHERE w.plot_id NOT IN (3503, 3514)
    GROUP BY w.jaar, gg.gekozen_code
)
-- Stap 4: Finale berekening waarbij we de oppervlakte-weging toepassen
SELECT 
    gt.jaar AS Jaar,
    gt.gekozen_code AS Groep_code,
    evg.beschrijving AS `ecologische_groep_beschrijving`,
    -- We berekenen de dichtheid (territoria / totaal oppervlak) 
    -- en kijken welk aandeel dat heeft in de totale dichtheid van dat jaar
    ROUND((gt.som_territoria_groep / jo.totaal_opp_jaar) / 
          (SUM(gt.som_territoria_groep / jo.totaal_opp_jaar) OVER(PARTITION BY gt.jaar)) * 100, 1) AS `Gewogen bezetting_percentage`
FROM GroepTotalen gt
JOIN JaarOppervlakte jo ON gt.jaar = jo.jaar
JOIN ecologische_vogelgroepen evg ON gt.gekozen_code = evg.groep_code
WHERE jo.totaal_opp_jaar > 0
ORDER BY gt.jaar DESC, `Gewogen bezetting_percentage` DESC;