/* UITLEG
Identificeert soorten waarvan de trend in Meijendel sterk afwijkt van zowel
Zuid-Holland als Landelijk.

Methode:
- Meijendel wordt berekend uit territoria per soort per jaar.
- Zuid-Holland en Landelijk komen uit trends.
- Alleen jaren waarin alle drie reeksen aanwezig zijn worden vergeleken.
- De trend is een log-lineaire helling, omgerekend naar procent per jaar.
- afwijking_score = de kleinste afwijking van Meijendel t.o.v. Zuid-Holland
  en Landelijk. Hoog betekent: Meijendel wijkt sterk af van beide referenties.
*/

WITH jaarreeksen AS (
  SELECT
    m.soort_id,
    m.jaar,
    m.meijendel_waarde,
    zh.waarde AS zh_waarde,
    nl.waarde AS nl_waarde
  FROM (
    SELECT
      soort_id,
      jaar,
      SUM(territoria) AS meijendel_waarde
    FROM territoria
    WHERE jaar BETWEEN 1990 AND 2024
    GROUP BY soort_id, jaar
  ) m
  JOIN trends zh
    ON zh.soort_id = m.soort_id
   AND zh.jaar = m.jaar
   AND zh.regio = 'Zuid-Holland'
   AND zh.waarde > 0
  JOIN trends nl
    ON nl.soort_id = m.soort_id
   AND nl.jaar = m.jaar
   AND nl.regio = 'Landelijk'
   AND nl.waarde > 0
),
stats AS (
  SELECT
    soort_id,
    COUNT(*) AS n_jaren,
    MIN(jaar) AS eerste_jaar,
    MAX(jaar) AS laatste_jaar,
    AVG(jaar) AS avg_jaar,
    AVG(LN(meijendel_waarde + 1)) AS avg_meijendel,
    AVG(LN(zh_waarde)) AS avg_zh,
    AVG(LN(nl_waarde)) AS avg_nl
  FROM jaarreeksen
  GROUP BY soort_id
  HAVING COUNT(*) >= 10
),
slopes AS (
  SELECT
    j.soort_id,
    s.n_jaren,
    s.eerste_jaar,
    s.laatste_jaar,
    100 * (EXP(
      SUM((j.jaar - s.avg_jaar) * (LN(j.meijendel_waarde + 1) - s.avg_meijendel))
      / NULLIF(SUM(POW(j.jaar - s.avg_jaar, 2)), 0)
    ) - 1) AS meijendel_pct_jr,
    100 * (EXP(
      SUM((j.jaar - s.avg_jaar) * (LN(j.zh_waarde) - s.avg_zh))
      / NULLIF(SUM(POW(j.jaar - s.avg_jaar, 2)), 0)
    ) - 1) AS zh_pct_jr,
    100 * (EXP(
      SUM((j.jaar - s.avg_jaar) * (LN(j.nl_waarde) - s.avg_nl))
      / NULLIF(SUM(POW(j.jaar - s.avg_jaar, 2)), 0)
    ) - 1) AS nl_pct_jr
  FROM jaarreeksen j
  JOIN stats s ON s.soort_id = j.soort_id
  GROUP BY j.soort_id, s.n_jaren, s.eerste_jaar, s.laatste_jaar
)
SELECT
  so.soort_naam,
  eerste_jaar,
  laatste_jaar,
  n_jaren,
  ROUND(meijendel_pct_jr, 2) AS meijendel_pct_jr,
  ROUND(zh_pct_jr, 2) AS zuid_holland_pct_jr,
  ROUND(nl_pct_jr, 2) AS landelijk_pct_jr,
  ROUND(ABS(meijendel_pct_jr - zh_pct_jr), 2) AS afwijking_vs_zh,
  ROUND(ABS(meijendel_pct_jr - nl_pct_jr), 2) AS afwijking_vs_landelijk,
  ROUND(
    LEAST(
      ABS(meijendel_pct_jr - zh_pct_jr),
      ABS(meijendel_pct_jr - nl_pct_jr)
    ),
    2
  ) AS afwijking_score
FROM slopes sl
JOIN soorten so ON so.id = sl.soort_id
ORDER BY
  afwijking_score DESC,
  GREATEST(
    ABS(meijendel_pct_jr - zh_pct_jr),
    ABS(meijendel_pct_jr - nl_pct_jr)
  ) DESC;
