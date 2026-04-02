USE `meijendel`;

DROP TABLE IF EXISTS `plot_landuse`;
CREATE TABLE `plot_landuse` (
  `plot_id` int NOT NULL,
  `jaar` smallint unsigned NOT NULL,
  `bron` varchar(50) NOT NULL,
  `klasse` varchar(50) NOT NULL,
  `area_m2` double DEFAULT NULL,
  `pct` double DEFAULT NULL,
  PRIMARY KEY (`plot_id`, `jaar`, `bron`, `klasse`),
  CONSTRAINT `fk_plot_landuse_plot_jaar`
    FOREIGN KEY (`plot_id`, `jaar`)
    REFERENCES `plot_jaar_oppervlak` (`plot_id`, `jaar`)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT `chk_plot_landuse_jaar` CHECK ((`jaar` between 1900 and 2100)),
  CONSTRAINT `chk_plot_landuse_area` CHECK ((`area_m2` is null or `area_m2` >= 0)),
  CONSTRAINT `chk_plot_landuse_pct` CHECK ((`pct` is null or (`pct` >= 0 and `pct` <= 100)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Landgebruik per plot en jaar, opgeslagen als oppervlakte en percentage per klasse.';

DROP TABLE IF EXISTS `plot_env_continuous`;
CREATE TABLE `plot_env_continuous` (
  `plot_id` int NOT NULL,
  `jaar` smallint unsigned NOT NULL,
  `bron` varchar(50) NOT NULL,
  `ahn_mean` double DEFAULT NULL,
  `ahn_sd` double DEFAULT NULL,
  `stikstof_mean` double DEFAULT NULL,
  `stikstof_median` double DEFAULT NULL,
  PRIMARY KEY (`plot_id`, `jaar`, `bron`),
  CONSTRAINT `fk_plot_env_continuous_plot_jaar`
    FOREIGN KEY (`plot_id`, `jaar`)
    REFERENCES `plot_jaar_oppervlak` (`plot_id`, `jaar`)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT `chk_plot_env_continuous_jaar` CHECK ((`jaar` between 1900 and 2100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Samengevatte continue omgevingswaarden per plot en jaar.';

/*
Voorbeeldimports vanuit CSV.
Pas het pad aan naar jouw eigen bestand.
*/

/*
LOAD DATA LOCAL INFILE '/pad/naar/ahn_per_plot_2024.csv'
INTO TABLE plot_env_continuous
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
*/

/*
LOAD DATA LOCAL INFILE '/pad/naar/landgebruik_per_plot_2024.csv'
INTO TABLE plot_landuse
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
*/
