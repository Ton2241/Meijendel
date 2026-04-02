USE `meijendel`;

/*
1. Maak of hergebruik eerst een tijdelijke tabel zonder foreign key:

DROP TABLE IF EXISTS temp_landgebruik_import;

CREATE TABLE temp_landgebruik_import (
  plot_id INT,
  jaar INT,
  bron VARCHAR(50),
  klasse VARCHAR(50),
  area_m2 DOUBLE,
  pct DOUBLE
);
*/

/*
2. Importeer daarna via TablePlus:
/Users/ton/Documents/GitHub/Meijendel/Landgebruik/landgebruik_per_plot_1996.csv
in temp_landgebruik_import.
*/

/*
3. Controleer welke combinaties ontbreken in plot_jaar_oppervlak:

SELECT t.plot_id, t.jaar, COUNT(*) AS n
FROM temp_landgebruik_import t
LEFT JOIN plot_jaar_oppervlak p
  ON p.plot_id = t.plot_id
 AND p.jaar = t.jaar
WHERE p.plot_id IS NULL
GROUP BY t.plot_id, t.jaar
ORDER BY t.jaar, t.plot_id;
*/

/*
4. Zet alleen geldige records door:

INSERT INTO plot_jaar_landgebruik (
  plot_id,
  jaar,
  bron,
  klasse,
  area_m2,
  pct
)
SELECT
  t.plot_id,
  t.jaar,
  t.bron,
  t.klasse,
  t.area_m2,
  t.pct
FROM temp_landgebruik_import t
INNER JOIN plot_jaar_oppervlak p
  ON p.plot_id = t.plot_id
 AND p.jaar = t.jaar;
*/

SELECT COUNT(*) AS aantal_records_1996
FROM plot_jaar_landgebruik
WHERE bron = 'CBS_BBG1996'
  AND jaar = 1996;

SELECT plot_id, jaar, bron, klasse, area_m2, pct
FROM plot_jaar_landgebruik
WHERE bron = 'CBS_BBG1996'
  AND jaar = 1996
ORDER BY plot_id, klasse
LIMIT 20;
