/* UITLEG
Deze query is bedoeld voor een view/rapport: IBA soorten.
*/

WITH
-- Stap 1: Kies alleen de gevraagde soorten
doelsoorten AS (
    SELECT
        id AS soort_id,
        soort_naam
    FROM soorten
    WHERE LOWER(soort_naam) IN ('boomleeuwerik', 'tafeleend','blauwborst', 'roerdomp', 'slechtvalk', 'grauwe klauwier', 'nachtzwaluw')
),

-- Stap 2: Tel per plot+jaar+soort op, inclusief aparte som voor bron = sovon
territoria_per_plot AS (
    SELECT
        t.jaar,
        t.plot_id,
        t.soort_id,
        SUM(t.territoria) AS territoria_plot_totaal,
        SUM(CASE WHEN b.code = 'sovon' THEN t.territoria ELSE 0 END) AS territoria_plot_sovon
    FROM territoria t
    JOIN doelsoorten d
      ON d.soort_id = t.soort_id
    JOIN bronnen b
      ON b.id = t.bron_id
    GROUP BY
        t.jaar,
        t.plot_id,
        t.soort_id
),

-- Stap 3: Koppel het getelde oppervlak (km2) per plot+jaar
met_oppervlak AS (
    SELECT
        tp.jaar,
        tp.soort_id,
        tp.territoria_plot_totaal,
        tp.territoria_plot_sovon,
        pjo.oppervlakte_km2
    FROM territoria_per_plot tp
    JOIN plot_jaar_oppervlak pjo
      ON pjo.plot_id = tp.plot_id
     AND pjo.jaar = tp.jaar
),

-- Stap 4: Maak totalen per jaar en per soort
per_soort_per_jaar AS (
    SELECT
        m.jaar,
        d.soort_naam AS soort,
        SUM(m.territoria_plot_totaal) AS totaal_territoria,
        SUM(m.territoria_plot_sovon) AS territoria_sovon,
        SUM(m.oppervlakte_km2) AS getelde_km2
    FROM met_oppervlak m
    JOIN doelsoorten d
      ON d.soort_id = m.soort_id
    GROUP BY
        m.jaar,
        d.soort_naam
)

-- Stap 5: Toon resultaat met extra sovon-kolom tussen totaal en km2
SELECT
    jaar,
    soort,
    totaal_territoria,
    territoria_sovon,  -- alleen bron = sovon
    ROUND(getelde_km2, 4) AS getelde_km2,
    ROUND(
        CASE
            WHEN getelde_km2 > 0 THEN totaal_territoria / getelde_km2
            ELSE NULL
        END,
        4
    ) AS vogeldichtheid_per_km2
FROM per_soort_per_jaar
ORDER BY
    jaar,
    soort;
