USE `meijendel`;

LOAD DATA LOCAL INFILE '/Users/ton/Documents/GitHub/Meijendel/Recreatie/plot_jaar_toegankelijkheid_deel_import.csv'
INTO TABLE `plot_jaar_toegankelijkheid_deel`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  plot_id,
  jaar,
  bron,
  deel_label,
  status_code,
  aandeel_pct,
  barriere_type,
  geom_wkt,
  opmerking
);

SELECT COUNT(*) AS aantal_records_toegankelijkheid_deel
FROM plot_jaar_toegankelijkheid_deel;
