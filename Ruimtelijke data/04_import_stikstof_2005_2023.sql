USE `meijendel`;

LOAD DATA LOCAL INFILE '/Users/ton/Documents/GitHub/Meijendel/Stikstof_AERIUS/stikstof_per_plot_2005_2023.csv'
INTO TABLE `plot_jaar_stikstof`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  plot_id,
  jaar,
  bron,
  stikstof_mean,
  stikstof_median
);

SELECT COUNT(*) AS aantal_records_stikstof
FROM plot_jaar_stikstof
WHERE bron = 'RIVM_HIST_STIKSTOF';

SELECT MIN(jaar) AS min_jaar, MAX(jaar) AS max_jaar
FROM plot_jaar_stikstof
WHERE bron = 'RIVM_HIST_STIKSTOF';

SELECT plot_id, jaar, bron, stikstof_mean, stikstof_median
FROM plot_jaar_stikstof
WHERE bron = 'RIVM_HIST_STIKSTOF'
ORDER BY jaar, plot_id
LIMIT 10;
