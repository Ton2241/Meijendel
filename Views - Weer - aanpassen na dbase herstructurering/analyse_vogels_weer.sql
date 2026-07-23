/* UITLEG
Deze query is bedoeld voor een view/rapport: analyse_vogels_weer.
*/

-- Stap 1: Uitvoering van een SQL‑statement.
/*
  Analyse territoria Vogelnaam (aanpassen!!!) versus broedseizoentemperatuur

  via een CTE (Common Table Expression).

  Gebruik uitsluitend de genormaliseerde view `weer_analyse`.
  `tg_c` is voor beide stations al uitgedrukt in graden Celsius.
*/

-- Stap 1: Bereken de gemiddelde zomertemperatuur per jaar (21 jun t/m 21 sep)
WITH weer_per_jaar AS (
    SELECT
        YEAR(datum)               AS jaar,
        ROUND(AVG(tg_c), 1)       AS gem_temp_zomer_celsius
    FROM weer_analyse
    WHERE
        tg_c IS NOT NULL
        AND (
            (MONTH(datum) = 6 AND DAY(datum) >= 21)
            OR (MONTH(datum) = 7)
            OR (MONTH(datum) = 8)
            OR (MONTH(datum) = 9 AND DAY(datum) <= 21)
        )
    GROUP BY YEAR(datum)
)

-- Stap 2: Combineer territoriatelling met de zomertemperatuur
SELECT
    t.jaar,
    s.soort_naam,

    -- Tel alle territoria voor de soort per jaar op
    SUM(t.territoria) AS totaal_territoria,

    -- Voeg de temperatuur toe vanuit de CTE
    -- LEFT JOIN zodat jaren zonder weerdata toch verschijnen
    wpj.gem_temp_zomer_celsius

FROM territoria AS t

-- Koppel de soortsnaam
JOIN soorten AS s ON t.soort_id = s.id

-- Koppel het temperatuurgemiddelde uit de CTE
LEFT JOIN weer_per_jaar AS wpj ON t.jaar = wpj.jaar

-- Filter op soort
WHERE s.soort_naam LIKE '%Nachtegaal%'

-- Stap 3: Groepeer zodat de aggregatie per jaar en soort correct werkt
GROUP BY
    t.jaar,
    s.soort_naam,
    wpj.gem_temp_zomer_celsius

ORDER BY t.jaar DESC;
