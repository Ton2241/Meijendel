USE `meijendel`;

LOAD DATA LOCAL INFILE '/Users/ton/Documents/GitHub/Meijendel/Recreatie/plot_jaar_toegankelijkheid_import.csv'
INTO TABLE `plot_jaar_toegankelijkheid`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  plot_id,
  jaar,
  bron,
  status_code,
  opmerking
);

SELECT COUNT(*) AS aantal_records_toegankelijkheid
FROM plot_jaar_toegankelijkheid
WHERE bron IN ('HANDMATIG', 'DUNEA_RAPPORT_2022');

SELECT plot_id, jaar, bron, status_code, opmerking
FROM plot_jaar_toegankelijkheid
WHERE bron IN ('HANDMATIG', 'DUNEA_RAPPORT_2022')
ORDER BY jaar, plot_id
LIMIT 20;
