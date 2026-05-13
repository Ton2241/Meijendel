/* UITLEG
Deze tabel legt functionele kenmerken per soort vast.

Gebruik:
- `soorten` blijft de stamtafel voor vogelsoorten.
- `soort_functies` koppelt een soort aan een functionele code.
- Met `periode` kun je wisselend gedrag vastleggen, bijvoorbeeld ander voedsel
  in de broedperiode dan buiten de broedperiode.
- Samengestelde kenmerken, zoals V-HERB/V-OMN of F-AIR/F-GRD, worden als
  meerdere rijen opgeslagen.
*/

CREATE TABLE IF NOT EXISTS `soort_functies` (
  `id` int NOT NULL AUTO_INCREMENT,
  `soort_id` int NOT NULL,
  `kenmerk_type` enum(
    'voedselgroep',
    'foerageerlaag',
    'migratiegedrag',
    'nesttype',
    'recreatiegevoeligheid',
    'predatiegevoeligheid',
    'kwetsbaarheid'
  ) NOT NULL,
  `code` varchar(20) NOT NULL,
  `periode` enum(
    'broedperiode',
    'niet_broedperiode',
    'jaarrond',
    'onbekend'
  ) NOT NULL DEFAULT 'jaarrond',
  `gewicht` decimal(4,2) DEFAULT NULL,
  `bron` varchar(255) DEFAULT NULL,
  `opmerking` text,
  `aangemaakt_op` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_soort_functie` (`soort_id`, `kenmerk_type`, `code`, `periode`),
  KEY `idx_soort_functies_code` (`code`),
  KEY `idx_soort_functies_type_code` (`kenmerk_type`, `code`),
  KEY `idx_soort_functies_soort_type` (`soort_id`, `kenmerk_type`),
  CONSTRAINT `fk_soort_functies_soort_id`
    FOREIGN KEY (`soort_id`) REFERENCES `soorten` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_soort_functies_code`
    FOREIGN KEY (`code`) REFERENCES `soort_functie_codes` (`code`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_soort_functies_gewicht`
    CHECK ((`gewicht` IS NULL) OR (`gewicht` >= 0 AND `gewicht` <= 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Functionele soortkenmerken met periode/context';

/* Als `soort_functies` al bestond zonder foreign key op `code`,
voer dan deze migratie eenmalig uit.

Let op: dit werkt alleen als alle bestaande codes in `soort_functies`
al aanwezig zijn in `soort_functie_codes`.

ALTER TABLE `soort_functies`
  DROP CHECK `chk_soort_functies_code_prefix`;

ALTER TABLE `soort_functies`
  ADD KEY `idx_soort_functies_code` (`code`);

ALTER TABLE `soort_functies`
  ADD CONSTRAINT `fk_soort_functies_code`
  FOREIGN KEY (`code`) REFERENCES `soort_functie_codes` (`code`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

*/

/* Voorbeelden:

-- Fitis: insecteneter in boomkroon tijdens en buiten broedperiode.
INSERT INTO `soort_functies` (`soort_id`, `kenmerk_type`, `code`, `periode`, `bron`)
SELECT `id`, 'voedselgroep', 'V-INS-K', 'broedperiode', 'Functionele matrix BMP'
FROM `soorten`
WHERE `soort_naam` = 'Fitis';

INSERT INTO `soort_functies` (`soort_id`, `kenmerk_type`, `code`, `periode`, `bron`)
SELECT `id`, 'foerageerlaag', 'F-CAN', 'jaarrond', 'Functionele matrix BMP'
FROM `soorten`
WHERE `soort_naam` = 'Fitis';

-- Vink: insecten in broedperiode, zaden buiten broedperiode.
INSERT INTO `soort_functies` (`soort_id`, `kenmerk_type`, `code`, `periode`, `bron`)
SELECT `id`, 'voedselgroep', 'V-INS-B', 'broedperiode', 'Functionele matrix BMP'
FROM `soorten`
WHERE `soort_naam` = 'Vink';

INSERT INTO `soort_functies` (`soort_id`, `kenmerk_type`, `code`, `periode`, `bron`)
SELECT `id`, 'voedselgroep', 'V-ZAD-B', 'niet_broedperiode', 'Functionele matrix BMP'
FROM `soorten`
WHERE `soort_naam` = 'Vink';

*/
