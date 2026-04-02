USE `meijendel`;

LOAD DATA LOCAL INFILE '/Users/ton/Documents/GitHub/Meijendel/Landgebruik/landgebruik_per_plot_2022.csv'
INTO TABLE `plot_jaar_landgebruik`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  plot_id,
  jaar,
  bron,
  klasse,
  area_m2,
  pct
);

SELECT COUNT(*) AS aantal_records_landgebruik
FROM plot_jaar_landgebruik
WHERE bron = 'CBS_NBBG2022'
  AND jaar = 2022;

SELECT plot_id, jaar, bron, klasse, area_m2, pct
FROM plot_jaar_landgebruik
WHERE bron = 'CBS_NBBG2022'
  AND jaar = 2022
ORDER BY plot_id, klasse
LIMIT 15;
