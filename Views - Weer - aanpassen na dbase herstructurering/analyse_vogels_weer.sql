/* UITLEG
Deze query is bedoeld voor een view/rapport: analyse_vogels_weer.
*/

-- Stap 1: Uitvoering van een SQL‑statement.
/*
  Analyse territoria Vogelnaam (aanpassen!!!) versus broedseizoentemperatuur

  via een CTE (Common Table Expression).

  Gebruikte weerkolom uit tabel `weer`:
    TG = etmaalgemiddelde temperatuur in 0,1 °C (zie weer_legenda)
    Conversie naar Celsius: TG / 10.0
*/

-- Stap 1: Bereken de gemiddelde zomertemperatuur per jaar (21 jun t/m 21 sep)
-- TG staat in 0,1 °C;
-- Stap 2: Uitvoering van een SQL‑statement.
 delen door 10.0 geeft de waarde in °C
WITH weer_per_jaar AS (
    SELECT
        YEAR(datum)                  AS jaar,
        ROUND(AVG(TG) / 10.0, 1)    AS gem_temp_zomer_celsius
    FROM weer
    WHERE
        TG IS NOT NULL
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
