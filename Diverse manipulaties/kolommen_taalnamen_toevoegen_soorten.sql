ALTER TABLE `soorten`
  ADD COLUMN IF NOT EXISTS `duitse_naam` varchar(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `franse_naam` varchar(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `spaanse_naam` varchar(255) DEFAULT NULL;
