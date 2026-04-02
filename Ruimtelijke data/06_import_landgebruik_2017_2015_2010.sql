USE `meijendel`;

/*
Importeer deze CSV-bestanden via TablePlus eerst in een tijdelijke tabel
zonder foreign key, bijvoorbeeld `temp_landgebruik_import`.
Door de foreign key naar `plot_jaar_oppervlak` kunnen ongeldige combinaties
anders de import blokkeren.
*/

/*
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
Na import in temp_landgebruik_import kun je alleen de geldige records
doorzetten naar plot_jaar_landgebruik:

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

SELECT bron, jaar, COUNT(*) AS aantal_records
FROM plot_jaar_landgebruik
WHERE bron IN ('CBS_BBG2017', 'CBS_BBG2015', 'CBS_BBG2010')
GROUP BY bron, jaar
ORDER BY jaar DESC, bron;

SELECT plot_id, jaar, bron, klasse, area_m2, pct
FROM plot_jaar_landgebruik
WHERE bron IN ('CBS_BBG2017', 'CBS_BBG2015', 'CBS_BBG2010')
ORDER BY jaar DESC, plot_id, klasse
LIMIT 30;
