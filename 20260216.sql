-- -------------------------------------------------------------
-- TablePlus 6.8.1(655)
--
-- https://tableplus.com/
--
-- Database: Meijendel
-- Generation Time: 2026-02-16 17:46:04.0770
-- -------------------------------------------------------------


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


CREATE TABLE `evg_landschapstypen` (
  `id` int NOT NULL AUTO_INCREMENT,
  `beschrijving` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `evg_vogel_landschapgroep` (
  `groepsnummer` int NOT NULL,
  `vogel_id` int NOT NULL,
  `veeleisendheid_score` int DEFAULT NULL,
  `beschrijving_landschap_vogel` text,
  PRIMARY KEY (`groepsnummer`,`vogel_id`),
  KEY `vogel_id` (`vogel_id`),
  CONSTRAINT `evg_vogel_landschapgroep_ibfk_1` FOREIGN KEY (`groepsnummer`) REFERENCES `evg_vogelgroepen` (`groepsnummer`),
  CONSTRAINT `evg_vogel_landschapgroep_ibfk_2` FOREIGN KEY (`vogel_id`) REFERENCES `soorten` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `evg_vogel_landschapstype` (
  `soort_id` int NOT NULL,
  `landschap_id` int NOT NULL,
  `veeleisendheid` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`soort_id`,`landschap_id`),
  KEY `fk_evl_landschap` (`landschap_id`),
  CONSTRAINT `fk_evl_landschap` FOREIGN KEY (`landschap_id`) REFERENCES `evg_landschapstypen` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_evl_soort` FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `evg_vogelgroepen` (
  `groepsnummer` int NOT NULL,
  `landschap_groep` varchar(255) DEFAULT NULL,
  `beschrijving_landschap_groep` text,
  PRIMARY KEY (`groepsnummer`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `familie` (
  `id` int NOT NULL AUTO_INCREMENT,
  `familienaam_nl` varchar(100) NOT NULL,
  `familienaam_wetenschappelijk` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_familienaam` (`familienaam_nl`)
) ENGINE=InnoDB AUTO_INCREMENT=66 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `habitats_export_2014` (
  `plotid` int DEFAULT NULL,
  `H2130A` int DEFAULT NULL,
  `H2130B` int DEFAULT NULL,
  `H2160` int DEFAULT NULL,
  `H2180Ao` int DEFAULT NULL,
  `H2180B` int DEFAULT NULL,
  `H2180C` int DEFAULT NULL,
  `area_m2` float DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `habitattypen` (
  `id` int NOT NULL AUTO_INCREMENT,
  `habitat_code` varchar(20) NOT NULL,
  `habitat_naam` varchar(255) NOT NULL,
  `habitat_doelstelling` text,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_habitat_code` (`habitat_code`)
) ENGINE=InnoDB AUTO_INCREMENT=31 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Natura 2000 habitattypen met doelstellingen';

CREATE TABLE `habitattypen_doelstelling` (
  `habitat_naam_csv` varchar(255) DEFAULT NULL,
  `habitat_code_csv` varchar(50) DEFAULT NULL,
  `doelstelling_csv` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `import_waarnemingen_breed` (
  `euring_code` int DEFAULT NULL,
  `p_1A` int DEFAULT NULL,
  `p_1B` int DEFAULT NULL,
  `p_2` int DEFAULT NULL,
  `p_3` int DEFAULT NULL,
  `p_4_5` int DEFAULT NULL,
  `p_6` int DEFAULT NULL,
  `p_7` int DEFAULT NULL,
  `p_8` int DEFAULT NULL,
  `p_10_12_76` int DEFAULT NULL,
  `p_12A` int DEFAULT NULL,
  `p_13` int DEFAULT NULL,
  `p_13S` int DEFAULT NULL,
  `p_14` int DEFAULT NULL,
  `p_15` int DEFAULT NULL,
  `p_16plus` int DEFAULT NULL,
  `p_16S` int DEFAULT NULL,
  `p_17A` int DEFAULT NULL,
  `p_17B` int DEFAULT NULL,
  `p_31` int DEFAULT NULL,
  `p_32` int DEFAULT NULL,
  `p_33` int DEFAULT NULL,
  `p_34` int DEFAULT NULL,
  `p_35` int DEFAULT NULL,
  `p_36` int DEFAULT NULL,
  `p_41` int DEFAULT NULL,
  `p_42` int DEFAULT NULL,
  `p_43` int DEFAULT NULL,
  `p_45` int DEFAULT NULL,
  `p_46` int DEFAULT NULL,
  `p_51` int DEFAULT NULL,
  `p_52` int DEFAULT NULL,
  `p_53` int DEFAULT NULL,
  `p_54A` int DEFAULT NULL,
  `p_54B` int DEFAULT NULL,
  `p_55` int DEFAULT NULL,
  `p_61` int DEFAULT NULL,
  `p_62` int DEFAULT NULL,
  `p_63` int DEFAULT NULL,
  `p_64` int DEFAULT NULL,
  `p_65` int DEFAULT NULL,
  `p_66` int DEFAULT NULL,
  `p_71` int DEFAULT NULL,
  `p_72` int DEFAULT NULL,
  `p_73` int DEFAULT NULL,
  `p_74` int DEFAULT NULL,
  `p_75` int DEFAULT NULL,
  `p_75A` int DEFAULT NULL,
  `p_77` int DEFAULT NULL,
  `p_78_79` int DEFAULT NULL,
  `p_83` int DEFAULT NULL,
  `p_84` int DEFAULT NULL,
  `p_85` int DEFAULT NULL,
  `p_91` int DEFAULT NULL,
  `p_105` int DEFAULT NULL,
  `jaar` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `import_waarnemingen_lang` (
  `euring_code` int DEFAULT NULL,
  `plot_id` int DEFAULT NULL,
  `territoria` int DEFAULT NULL,
  `jaar` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `kernopgave_habitat` (
  `kernopgave_id` int NOT NULL,
  `habitat_id` int NOT NULL,
  PRIMARY KEY (`kernopgave_id`,`habitat_id`),
  KEY `fk_kh_habitat` (`habitat_id`),
  CONSTRAINT `fk_kh_habitat` FOREIGN KEY (`habitat_id`) REFERENCES `habitattypen` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_kh_kernopgave` FOREIGN KEY (`kernopgave_id`) REFERENCES `kernopgaven` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `kernopgave_soort` (
  `kernopgave_id` int NOT NULL,
  `soort_id` int NOT NULL,
  PRIMARY KEY (`kernopgave_id`,`soort_id`),
  KEY `fk_ks_soort` (`soort_id`),
  CONSTRAINT `fk_ks_kernopgave` FOREIGN KEY (`kernopgave_id`) REFERENCES `kernopgaven` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ks_soort` FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `kernopgaven` (
  `id` int NOT NULL AUTO_INCREMENT,
  `code` varchar(10) NOT NULL,
  `omschrijving` text,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_kernopgave_code` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `maatregel_habitat` (
  `maatregel_id` int NOT NULL,
  `habitat_id` int NOT NULL,
  PRIMARY KEY (`maatregel_id`,`habitat_id`),
  KEY `fk_mh_habitat` (`habitat_id`),
  CONSTRAINT `fk_mh_habitat` FOREIGN KEY (`habitat_id`) REFERENCES `habitattypen` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_mh_maatregel` FOREIGN KEY (`maatregel_id`) REFERENCES `maatregelen` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `maatregelen` (
  `id` int NOT NULL AUTO_INCREMENT,
  `omschrijving` text NOT NULL,
  `druk_aandachtspunt` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `plot_jaar_habitat` (
  `id` int NOT NULL AUTO_INCREMENT,
  `plot_id` int NOT NULL,
  `jaar` int NOT NULL,
  `habitat_id` int NOT NULL,
  `oppervlakte_m2` decimal(12,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_pjh_habitat` (`habitat_id`),
  KEY `fk_pjh_plot` (`plot_id`),
  CONSTRAINT `fk_pjh_habitat` FOREIGN KEY (`habitat_id`) REFERENCES `habitattypen` (`id`),
  CONSTRAINT `fk_pjh_plot` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `plot_jaar_maatregel` (
  `id` int NOT NULL AUTO_INCREMENT,
  `plot_id` int NOT NULL,
  `jaar` int NOT NULL,
  `maatregel_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_plot_jaar_maatregel` (`plot_id`,`jaar`,`maatregel_id`),
  KEY `fk_pjm_maatregel` (`maatregel_id`),
  CONSTRAINT `fk_pjm_maatregel` FOREIGN KEY (`maatregel_id`) REFERENCES `maatregelen` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_pjm_plot` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `plot_jaar_oppervlak` (
  `id` int NOT NULL AUTO_INCREMENT,
  `plot_id` int NOT NULL,
  `jaar` int NOT NULL,
  `oppervlakte_km2` decimal(10,4) NOT NULL COMMENT 'Oppervlakte van plot in vierkante kilometers',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_plot_jaar_uniek` (`plot_id`,`jaar`),
  CONSTRAINT `fk_plot_relatie` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`),
  CONSTRAINT `chk_pjo_jaar` CHECK ((`jaar` between 1900 and 2100)),
  CONSTRAINT `chk_pjo_oppervlak_positief` CHECK ((`oppervlakte_km2` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=5293 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `plot_jaar_teller` (
  `id` int NOT NULL AUTO_INCREMENT,
  `tellercode` varchar(50) NOT NULL,
  `plot_id` int NOT NULL,
  `jaar` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_teller_plot_jaar` (`tellercode`,`plot_id`,`jaar`),
  KEY `fk_plot_teller_relatie` (`plot_id`),
  CONSTRAINT `fk_plot_teller_relatie` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`),
  CONSTRAINT `fk_teller_relatie` FOREIGN KEY (`tellercode`) REFERENCES `tellers` (`tellercode`)
) ENGINE=InnoDB AUTO_INCREMENT=2823 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `plotkolom_mapping` (
  `kolomnaam` varchar(50) NOT NULL,
  `plot_id` int NOT NULL,
  PRIMARY KEY (`kolomnaam`),
  KEY `idx_plot_id` (`plot_id`),
  CONSTRAINT `plotkolom_mapping_ibfk_1` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `plots` (
  `plot_id` int NOT NULL,
  `plot_nr` int DEFAULT NULL,
  `plot_naam` varchar(255) DEFAULT NULL,
  `kavel_nummer` varchar(255) DEFAULT NULL,
  `geom` geometry /*!80003 SRID 28992 */ DEFAULT NULL,
  PRIMARY KEY (`plot_id`),
  KEY `idx_plot_naam` (`plot_naam`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Geografische telgebieden voor vogelmonitoring';

CREATE TABLE `richtlijnen` (
  `id` int NOT NULL AUTO_INCREMENT,
  `naam` varchar(100) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `soort_familie` (
  `id` int NOT NULL AUTO_INCREMENT,
  `soort_id` int NOT NULL,
  `familie_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_soort_familie` (`soort_id`),
  KEY `fk_familie_link` (`familie_id`),
  CONSTRAINT `fk_soort_familie_familie` FOREIGN KEY (`familie_id`) REFERENCES `familie` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_soort_familie_soort_id` FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=304 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `soort_habitat` (
  `id` int NOT NULL AUTO_INCREMENT,
  `soort_id` int NOT NULL,
  `habitat_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_soort_id_habitat_id` (`soort_id`,`habitat_id`),
  KEY `fk_habitat_soort` (`habitat_id`),
  CONSTRAINT `fk_habitat_soort` FOREIGN KEY (`habitat_id`) REFERENCES `habitattypen` (`id`),
  CONSTRAINT `fk_soort_habitat_soort_id` FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `soort_richtlijn` (
  `id` int NOT NULL AUTO_INCREMENT,
  `soort_id` int NOT NULL,
  `richtlijn_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_soort_richtlijn` (`soort_id`,`richtlijn_id`),
  KEY `fk_richtlijn_type` (`richtlijn_id`),
  CONSTRAINT `fk_richtlijn_type` FOREIGN KEY (`richtlijn_id`) REFERENCES `richtlijnen` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_soort_richtlijn_soort_id` FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=256 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `soorten` (
  `id` int NOT NULL AUTO_INCREMENT,
  `euring_code` int NOT NULL,
  `soort_naam` varchar(100) NOT NULL,
  `latijnse_naam` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `Euring` (`euring_code`),
  UNIQUE KEY `uq_euring` (`euring_code`),
  KEY `idx_soort_naam` (`soort_naam`)
) ENGINE=InnoDB AUTO_INCREMENT=625 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Vogelsoorten met EURING codes en classificaties';

CREATE TABLE `tellers` (
  `tellercode` varchar(50) NOT NULL,
  `voornaam` varchar(100) DEFAULT NULL,
  `tussenvoegsel` varchar(20) DEFAULT NULL,
  `achternaam` varchar(100) DEFAULT NULL,
  `straat` varchar(255) DEFAULT NULL,
  `huisnummer` varchar(20) DEFAULT NULL,
  `postcode` varchar(10) DEFAULT NULL,
  `woonplaats` varchar(100) DEFAULT NULL,
  `telefoon_vast` varchar(20) DEFAULT NULL,
  `telefoon_mobiel` varchar(20) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `soort_lid` enum('aspirant','gewoon','buitengewoon','ondersteunend','donateur','erelid','onbekend','oudteller') DEFAULT 'gewoon',
  `bandnummer` int unsigned DEFAULT NULL,
  PRIMARY KEY (`tellercode`),
  KEY `idx_tellers_email` (`email`),
  CONSTRAINT `chk_email_format` CHECK (((`email` = _utf8mb4'') or (`email` is null) or (`email` like _utf8mb4'%@%'))),
  CONSTRAINT `chk_mobiel_formaat` CHECK (((`telefoon_mobiel` = _utf8mb4'') or (`telefoon_mobiel` is null) or regexp_like(`telefoon_mobiel`,_utf8mb4'^[0-9 +-]+$'))),
  CONSTRAINT `chk_mobiel_vast` CHECK (((`telefoon_vast` = _utf8mb4'') or (`telefoon_vast` is null) or regexp_like(`telefoon_vast`,_utf8mb4'^[0-9 +-]+$'))),
  CONSTRAINT `chk_postcode_formaat_flexibel` CHECK (regexp_like(`postcode`,_utf8mb4'^[0-9]{4} ?[A-Z]{2}$'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `trends` (
  `id` int NOT NULL AUTO_INCREMENT,
  `soort_id` int NOT NULL,
  `regio` varchar(100) DEFAULT NULL,
  `jaar` int NOT NULL,
  `waarde` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_trends_soort_jaar` (`soort_id`,`jaar`),
  KEY `idx_trends_regio_soort_jaar` (`regio`,`soort_id`,`jaar`),
  CONSTRAINT `fk_trends_soort_id` FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `chk_trends_jaar` CHECK ((`jaar` between 1900 and 2100))
) ENGINE=InnoDB AUTO_INCREMENT=16384 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `vogelstand_1924` (
  `id` int NOT NULL AUTO_INCREMENT,
  `soort_id` int DEFAULT NULL,
  `beschrijving` text NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_vogelstand_soort_id` (`soort_id`),
  CONSTRAINT `fk_vogelstand_soort_id` FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=205 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `waarnemingen` (
  `id` int NOT NULL AUTO_INCREMENT,
  `plot_id` int NOT NULL,
  `soort_id` int NOT NULL,
  `jaar` int NOT NULL,
  `territoria` int DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_waarneming_uniek` (`plot_id`,`soort_id`,`jaar`),
  KEY `idx_waarneming_jaar` (`jaar`),
  KEY `idx_soort_jaar` (`jaar`),
  KEY `idx_waarneming_soort_id` (`soort_id`),
  KEY `idx_waarneming_jaar_soort_territoria` (`jaar`,`soort_id`,`territoria`),
  KEY `idx_waarneming_plot_jaar_soort` (`plot_id`,`jaar`,`soort_id`),
  CONSTRAINT `fk_waarneming_jaar_plot` FOREIGN KEY (`plot_id`, `jaar`) REFERENCES `plot_jaar_oppervlak` (`plot_id`, `jaar`),
  CONSTRAINT `fk_waarneming_plot` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`),
  CONSTRAINT `fk_waarneming_soort_id` FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_waarneming_territoria` CHECK ((`territoria` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=116681 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Broedvogel territoria per plot per jaar';

CREATE TABLE `weer_actueel_voorschoten` (
  `datum` date NOT NULL,
  `temp_gem` decimal(5,1) DEFAULT NULL,
  `neerslag_hoeveelheid` decimal(5,1) DEFAULT NULL,
  PRIMARY KEY (`datum`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `weer_historie_katwijk` (
  `windsnelheid_gem` int DEFAULT NULL,
  `temp_gem` decimal(5,1) DEFAULT NULL,
  `temp_min` decimal(5,1) DEFAULT NULL,
  `temp_max` decimal(5,1) DEFAULT NULL,
  `SQ` int DEFAULT NULL,
  `RH` decimal(5,1) DEFAULT NULL,
  `PG` int DEFAULT NULL,
  `UG` int DEFAULT NULL,
  `datum` date NOT NULL,
  PRIMARY KEY (`datum`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `weer_legenda` (
  `variabele` varchar(4) NOT NULL,
  `toelichting` varchar(255) NOT NULL,
  PRIMARY KEY (`variabele`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;



CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `weer_totaal` AS select `weer_historie_katwijk`.`datum` AS `datum`,`weer_historie_katwijk`.`temp_gem` AS `temp_gem` from `weer_historie_katwijk` where (`weer_historie_katwijk`.`datum` < '2016-05-04') union all select `weer_actueel_voorschoten`.`datum` AS `datum`,`weer_actueel_voorschoten`.`temp_gem` AS `temp_gem` from `weer_actueel_voorschoten` where (`weer_actueel_voorschoten`.`datum` >= '2016-05-04');


/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;