USE `meijendel`;

LOAD DATA LOCAL INFILE '/Users/ton/Documents/GitHub/Meijendel/AHN_DTM_Meijendel/ahn_per_plot_2025.csv'
INTO TABLE `plot_env_continuous`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  plot_id,
  jaar,
  bron,
  ahn_mean,
  ahn_sd,
  stikstof_mean,
  stikstof_median
);

SELECT COUNT(*) AS aantal_records_2025_ahn
FROM plot_env_continuous
WHERE jaar = 2025
  AND bron = 'AHN_DTM';

SELECT plot_id, jaar, bron, ahn_mean, ahn_sd
FROM plot_env_continuous
WHERE jaar = 2025
  AND bron = 'AHN_DTM'
ORDER BY plot_id
LIMIT 10;
