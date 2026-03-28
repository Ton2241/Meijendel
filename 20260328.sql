-- -------------------------------------------------------------
-- TablePlus 6.8.7(663)
--
-- https://tableplus.com/
--
-- Database: Meijendel
-- Generation Time: 2026-03-28 20:43:13.3650
-- -------------------------------------------------------------


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


CREATE TABLE `BGgroup` (
  `id` int NOT NULL,
  `euring_code` int DEFAULT NULL,
  `soort_naam` varchar(255) NOT NULL,
  `group_code` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`,`soort_naam`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `bronnen` (
  `id` tinyint unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(50) NOT NULL,
  `omschrijving` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bron_code` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

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
  `familie_latijn` varchar(100) DEFAULT NULL,
  `orde_latijn` varchar(100) DEFAULT NULL,
  `orde_nl` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_familienaam` (`familienaam_nl`)
) ENGINE=InnoDB AUTO_INCREMENT=86 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `habitattypen` (
  `id` int NOT NULL AUTO_INCREMENT,
  `habitat_code` varchar(20) NOT NULL,
  `habitat_naam` varchar(255) NOT NULL,
  `beschrijving` varchar(255) DEFAULT NULL,
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
  `jaar` smallint unsigned DEFAULT NULL,
  `bron_id` tinyint unsigned NOT NULL,
  KEY `fk_iwb_bron` (`bron_id`),
  CONSTRAINT `fk_iwb_bron` FOREIGN KEY (`bron_id`) REFERENCES `bronnen` (`id`),
  CONSTRAINT `chk_iwb_jaar` CHECK ((`jaar` between 1900 and 2100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Werktabel voor jaarlijkse importverwerking. Bevat brede SOVON-download met plots als kolommen. Na verwerking leegmaken met TRUNCATE.';

CREATE TABLE `import_waarnemingen_lang` (
  `euring_code` int DEFAULT NULL,
  `soort_id` int DEFAULT NULL,
  `plot_id` int DEFAULT NULL,
  `territoria` int DEFAULT NULL,
  `jaar` smallint unsigned DEFAULT NULL,
  `bron_id` tinyint unsigned NOT NULL,
  KEY `fk_iwl_bron` (`bron_id`),
  CONSTRAINT `fk_iwl_bron` FOREIGN KEY (`bron_id`) REFERENCES `bronnen` (`id`),
  CONSTRAINT `chk_iwl_jaar` CHECK ((`jaar` between 1900 and 2100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Werktabel voor jaarlijkse importverwerking. Bevat lange versie van SOVON-download. Na verwerking leegmaken met TRUNCATE.';

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
  `jaar` smallint unsigned NOT NULL,
  `habitat_id` int NOT NULL,
  `aandeel_m2` decimal(12,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_pjh_habitat` (`habitat_id`),
  KEY `fk_pjh_plot` (`plot_id`),
  CONSTRAINT `fk_pjh_habitat` FOREIGN KEY (`habitat_id`) REFERENCES `habitattypen` (`id`),
  CONSTRAINT `fk_pjh_plot` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`),
  CONSTRAINT `chk_pjh_jaar` CHECK ((`jaar` between 1900 and 2100))
) ENGINE=InnoDB AUTO_INCREMENT=313 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `plot_jaar_maatregel` (
  `id` int NOT NULL AUTO_INCREMENT,
  `plot_id` int NOT NULL,
  `jaar` smallint unsigned NOT NULL,
  `maatregel_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_plot_jaar_maatregel` (`plot_id`,`jaar`,`maatregel_id`),
  KEY `fk_pjm_maatregel` (`maatregel_id`),
  CONSTRAINT `fk_pjm_maatregel` FOREIGN KEY (`maatregel_id`) REFERENCES `maatregelen` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_pjm_plot` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`) ON DELETE CASCADE,
  CONSTRAINT `chk_pjm_jaar` CHECK ((`jaar` between 1900 and 2100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `plot_jaar_oppervlak` (
  `id` int NOT NULL AUTO_INCREMENT,
  `plot_id` int NOT NULL,
  `jaar` int NOT NULL,
  `oppervlakte_km2` decimal(15,8) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_plot_jaar_uniek` (`plot_id`,`jaar`),
  CONSTRAINT `fk_plot_relatie` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`),
  CONSTRAINT `chk_pjo_jaar` CHECK ((`jaar` between 1900 and 2100)),
  CONSTRAINT `chk_pjo_oppervlak_positief` CHECK ((`oppervlakte_km2` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=5298 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `plot_jaar_teller` (
  `id` int NOT NULL AUTO_INCREMENT,
  `teller_id` int NOT NULL,
  `plot_id` int NOT NULL,
  `jaar` smallint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_teller_id_plot_jaar` (`teller_id`,`plot_id`,`jaar`),
  KEY `fk_plot_teller_relatie` (`plot_id`),
  CONSTRAINT `fk_pjt_teller_id` FOREIGN KEY (`teller_id`) REFERENCES `tellers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_plot_teller_relatie` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`),
  CONSTRAINT `chk_pjt_jaar` CHECK ((`jaar` between 1900 and 2100))
) ENGINE=InnoDB AUTO_INCREMENT=3072 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

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
  `engelse_naam` varchar(255) DEFAULT NULL,
  `duitse_naam` varchar(255) DEFAULT NULL,
  `franse_naam` varchar(255) DEFAULT NULL,
  `spaanse_naam` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_euring` (`euring_code`),
  KEY `idx_soort_naam` (`soort_naam`)
) ENGINE=InnoDB AUTO_INCREMENT=625 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Vogelsoorten met EURING codes en classificaties';

CREATE TABLE `territoria` (
  `id` int NOT NULL AUTO_INCREMENT,
  `plot_id` int NOT NULL,
  `soort_id` int NOT NULL,
  `jaar` int NOT NULL,
  `territoria` int unsigned NOT NULL DEFAULT '0',
  `invoerdatum` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Datum en tijd waarop de waarneming is ingevoerd',
  `bron_id` tinyint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_territoria_bron_uniek` (`plot_id`,`soort_id`,`jaar`),
  KEY `idx_territoria_jaar` (`jaar`),
  KEY `idx_territoria_soort_id` (`soort_id`),
  KEY `idx_territoria_jaar_soort_aantal` (`jaar`,`soort_id`,`territoria`),
  KEY `idx_territoria_plot_jaar_soort` (`plot_id`,`jaar`,`soort_id`),
  KEY `idx_territoria_plot_jaar` (`plot_id`,`jaar`),
  KEY `idx_territoria_soort_jaar` (`soort_id`,`jaar`),
  KEY `fk_territoria_bron` (`bron_id`),
  CONSTRAINT `fk_territoria_bron` FOREIGN KEY (`bron_id`) REFERENCES `bronnen` (`id`),
  CONSTRAINT `fk_territoria_jaar_plot` FOREIGN KEY (`plot_id`, `jaar`) REFERENCES `plot_jaar_oppervlak` (`plot_id`, `jaar`),
  CONSTRAINT `fk_territoria_plot` FOREIGN KEY (`plot_id`) REFERENCES `plots` (`plot_id`),
  CONSTRAINT `fk_territoria_plotjaar` FOREIGN KEY (`plot_id`, `jaar`) REFERENCES `plot_jaar_oppervlak` (`plot_id`, `jaar`) ON UPDATE CASCADE,
  CONSTRAINT `fk_territoria_soort` FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_territoria_soort_id` FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_territoria_aantal` CHECK ((`territoria` >= 0)),
  CONSTRAINT `chk_territoria_waarde` CHECK ((`territoria` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=119402 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Broedvogel territoria per plot per jaar';

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

CREATE TABLE `weer` (
  `STN` int DEFAULT NULL,
  `Naam` varchar(100) DEFAULT NULL,
  `FG` int DEFAULT NULL,
  `TG` decimal(5,1) DEFAULT NULL,
  `TN` decimal(5,1) DEFAULT NULL,
  `TX` decimal(5,1) DEFAULT NULL,
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



/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;