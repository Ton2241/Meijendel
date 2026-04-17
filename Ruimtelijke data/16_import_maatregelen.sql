USE `meijendel`;

LOAD DATA LOCAL INFILE '/Users/ton/Documents/GitHub/Meijendel/Beheer/plot_jaar_maatregel_import.csv'
INTO TABLE `plot_jaar_maatregel`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  plot_id,
  jaar,
  bron,
  maatregel_id,
  intensiteit_code,
  uitvoerder_of_diersoort,
  deel_label,
  dekking_pct,
  opmerking
);

SELECT COUNT(*) AS aantal_records_maatregel
FROM plot_jaar_maatregel;
