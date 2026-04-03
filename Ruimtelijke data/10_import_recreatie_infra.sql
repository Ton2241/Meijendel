USE `meijendel`;

LOAD DATA LOCAL INFILE '/Users/ton/Documents/GitHub/Meijendel/Recreatie/plot_jaar_infra_recreatie_import.csv'
INTO TABLE `plot_jaar_infra`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  plot_id,
  jaar,
  bron,
  variabele,
  waarde
);

SELECT COUNT(*) AS aantal_records_recreatie_infra
FROM plot_jaar_infra
WHERE bron IN ('BGT', 'OSM', 'HANDMATIG');

SELECT plot_id, jaar, bron, variabele, waarde
FROM plot_jaar_infra
WHERE bron IN ('BGT', 'OSM', 'HANDMATIG')
ORDER BY jaar, plot_id, variabele
LIMIT 20;
