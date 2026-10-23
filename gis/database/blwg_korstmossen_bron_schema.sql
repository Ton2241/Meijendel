-- Primary BLWG source forms, kept distinct from the secondary NDFF observations.
-- Exact geometry and positive records for the protected taxon stay in the secure schema.
CREATE TABLE IF NOT EXISTS Meijendel.korstmossen_bronbestand (
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  bronorganisatie VARCHAR(100) NOT NULL,
  bestandsnaam VARCHAR(255) NOT NULL,
  bronpad VARCHAR(1000) NOT NULL,
  leverdatum DATE NOT NULL,
  plotaantal SMALLINT UNSIGNED NOT NULL,
  formulieraantal SMALLINT UNSIGNED NOT NULL,
  resultaat_aantal SMALLINT UNSIGNED NOT NULL,
  beschermd_resultaat_aantal SMALLINT UNSIGNED NOT NULL,
  importversie VARCHAR(64) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS Meijendel.korstmossen_bron_plot (
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  bron_plot_id INT UNSIGNED NOT NULL,
  ndff_meetlocatie_id SMALLINT UNSIGNED NOT NULL,
  ndff_reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  subgebied VARCHAR(255), provincie VARCHAR(100), routenaam VARCHAR(255),
  bron_x_rd DECIMAL(10,2), bron_y_rd DECIMAL(10,2),
  lengte_m DECIMAL(10,2), breedte_m DECIMAL(10,2), grootte_m2 DECIMAL(12,2),
  aspect TEXT, vegetatie TEXT, beheer TEXT, methode VARCHAR(255),
  begroeiingstype VARCHAR(255), startjaar SMALLINT UNSIGNED, stopjaar SMALLINT UNSIGNED,
  locatie_afscherming ENUM('openbaar','exacte_bronlocatie_beveiligd') NOT NULL,
  PRIMARY KEY (bronbestand_sha256,bron_plot_id),
  UNIQUE KEY uq_blwg_plot_ndff (bronbestand_sha256,ndff_meetlocatie_id),
  CONSTRAINT fk_blwg_plot_bron FOREIGN KEY (bronbestand_sha256)
    REFERENCES Meijendel.korstmossen_bronbestand(bronbestand_sha256),
  CONSTRAINT fk_blwg_plot_ndff FOREIGN KEY (ndff_reconstructieversie,ndff_meetlocatie_id)
    REFERENCES Meijendel.korstmossen_meetlocatie(reconstructieversie,meetlocatie_id),
  CONSTRAINT ck_blwg_plot_locatie CHECK
    ((locatie_afscherming='openbaar' AND bron_x_rd IS NOT NULL AND bron_y_rd IS NOT NULL)
      OR (locatie_afscherming='exacte_bronlocatie_beveiligd' AND bron_x_rd IS NULL AND bron_y_rd IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS Meijendel.korstmossen_bron_formulier (
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  kopid BIGINT UNSIGNED NOT NULL,
  bron_plot_id INT UNSIGNED NOT NULL,
  velddatum DATE NOT NULL,
  rapportagejaar SMALLINT UNSIGNED,
  waarnemer VARCHAR(255), opmerkingen TEXT,
  formulierstatus ENUM('vast_plot_volledige_lijst','eenmalig_aanwezigheid') NOT NULL,
  PRIMARY KEY (bronbestand_sha256,kopid),
  KEY ix_blwg_formulier_plot_datum (bronbestand_sha256,bron_plot_id,velddatum),
  CONSTRAINT fk_blwg_formulier_plot FOREIGN KEY (bronbestand_sha256,bron_plot_id)
    REFERENCES Meijendel.korstmossen_bron_plot(bronbestand_sha256,bron_plot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS Meijendel.korstmossen_bron_resultaat (
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  bronregelnummer SMALLINT UNSIGNED NOT NULL,
  kopid BIGINT UNSIGNED NOT NULL,
  bronnaam VARCHAR(255) NOT NULL,
  hoeveelheidscode SMALLINT UNSIGNED NOT NULL,
  opmerkingen TEXT,
  taxon_bronkoppeling_id BIGINT UNSIGNED NOT NULL,
  ndff_koppelstatus ENUM('direct','groep') NOT NULL,
  ndff_waarneming_id BIGINT UNSIGNED,
  ndff_matchgroep_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  PRIMARY KEY (bronbestand_sha256,bronregelnummer),
  KEY ix_blwg_resultaat_formulier (bronbestand_sha256,kopid),
  KEY ix_blwg_resultaat_taxon (taxon_bronkoppeling_id),
  CONSTRAINT fk_blwg_resultaat_formulier FOREIGN KEY (bronbestand_sha256,kopid)
    REFERENCES Meijendel.korstmossen_bron_formulier(bronbestand_sha256,kopid),
  CONSTRAINT fk_blwg_resultaat_taxon FOREIGN KEY (taxon_bronkoppeling_id)
    REFERENCES Meijendel.taxa_bronkoppeling(koppeling_id),
  CONSTRAINT fk_blwg_resultaat_ndff FOREIGN KEY (ndff_waarneming_id)
    REFERENCES Meijendel.ndff_open_waarneming_register(waarneming_id),
  CONSTRAINT ck_blwg_resultaat_match CHECK
    ((ndff_koppelstatus='direct' AND ndff_waarneming_id IS NOT NULL)
      OR (ndff_koppelstatus='groep' AND ndff_waarneming_id IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS Meijendel.korstmossen_bron_ndff_groeprecord (
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  ndff_matchgroep_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  ndff_waarneming_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (bronbestand_sha256,ndff_waarneming_id),
  KEY ix_blwg_groeprecord_groep (bronbestand_sha256,ndff_matchgroep_sha256),
  CONSTRAINT fk_blwg_groeprecord_bron FOREIGN KEY (bronbestand_sha256)
    REFERENCES Meijendel.korstmossen_bronbestand(bronbestand_sha256),
  CONSTRAINT fk_blwg_groeprecord_ndff FOREIGN KEY (ndff_waarneming_id)
    REFERENCES Meijendel.ndff_open_waarneming_register(waarneming_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS Meijendel.korstmossen_bron_formulier_taxon (
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  kopid BIGINT UNSIGNED NOT NULL,
  taxon_bronkoppeling_id BIGINT UNSIGNED NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  hoeveelheidscode SMALLINT UNSIGNED,
  bronregelnummer SMALLINT UNSIGNED,
  PRIMARY KEY (bronbestand_sha256,kopid,taxon_bronkoppeling_id),
  CONSTRAINT fk_blwg_matrix_formulier FOREIGN KEY (bronbestand_sha256,kopid)
    REFERENCES Meijendel.korstmossen_bron_formulier(bronbestand_sha256,kopid),
  CONSTRAINT fk_blwg_matrix_taxon FOREIGN KEY (taxon_bronkoppeling_id)
    REFERENCES Meijendel.taxa_bronkoppeling(koppeling_id),
  CONSTRAINT fk_blwg_matrix_resultaat FOREIGN KEY (bronbestand_sha256,bronregelnummer)
    REFERENCES Meijendel.korstmossen_bron_resultaat(bronbestand_sha256,bronregelnummer),
  CONSTRAINT ck_blwg_matrix_resultaat CHECK
    ((waarnemingsstatus='waargenomen' AND hoeveelheidscode IS NOT NULL AND bronregelnummer IS NOT NULL)
      OR (waarnemingsstatus='echte_nul' AND hoeveelheidscode=0 AND bronregelnummer IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS Meijendel_ndff_secure.blwg_korstmossen_plot_exact (
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  bron_plot_id INT UNSIGNED NOT NULL,
  bron_x_rd DECIMAL(10,2) NOT NULL, bron_y_rd DECIMAL(10,2) NOT NULL,
  bron_wkt TEXT,
  PRIMARY KEY (bronbestand_sha256,bron_plot_id),
  CONSTRAINT fk_blwg_secure_plot FOREIGN KEY (bronbestand_sha256,bron_plot_id)
    REFERENCES Meijendel.korstmossen_bron_plot(bronbestand_sha256,bron_plot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS Meijendel_ndff_secure.blwg_korstmossen_resultaat (
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  bronregelnummer SMALLINT UNSIGNED NOT NULL,
  kopid BIGINT UNSIGNED NOT NULL,
  bronnaam VARCHAR(255) NOT NULL,
  hoeveelheidscode SMALLINT UNSIGNED NOT NULL,
  opmerkingen TEXT,
  taxon_bronkoppeling_id BIGINT UNSIGNED NOT NULL,
  ndff_koppelstatus ENUM('direct','groep') NOT NULL,
  ndff_waarneming_id BIGINT UNSIGNED,
  ndff_matchgroep_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  PRIMARY KEY (bronbestand_sha256,bronregelnummer),
  KEY ix_blwg_secure_formulier (bronbestand_sha256,kopid),
  CONSTRAINT fk_blwg_secure_formulier FOREIGN KEY (bronbestand_sha256,kopid)
    REFERENCES Meijendel.korstmossen_bron_formulier(bronbestand_sha256,kopid),
  CONSTRAINT fk_blwg_secure_taxon FOREIGN KEY (taxon_bronkoppeling_id)
    REFERENCES Meijendel.taxa_bronkoppeling(koppeling_id),
  CONSTRAINT fk_blwg_secure_ndff FOREIGN KEY (ndff_waarneming_id)
    REFERENCES Meijendel_ndff_secure.ndff_waarneming_register(waarneming_id),
  CONSTRAINT ck_blwg_secure_match CHECK
    ((ndff_koppelstatus='direct' AND ndff_waarneming_id IS NOT NULL)
      OR (ndff_koppelstatus='groep' AND ndff_waarneming_id IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS Meijendel_ndff_secure.blwg_korstmossen_ndff_groeprecord (
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  ndff_matchgroep_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  ndff_waarneming_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (bronbestand_sha256,ndff_waarneming_id),
  KEY ix_blwg_secure_groep (bronbestand_sha256,ndff_matchgroep_sha256),
  CONSTRAINT fk_blwg_secure_groep_bron FOREIGN KEY (bronbestand_sha256)
    REFERENCES Meijendel.korstmossen_bronbestand(bronbestand_sha256),
  CONSTRAINT fk_blwg_secure_groep_ndff FOREIGN KEY (ndff_waarneming_id)
    REFERENCES Meijendel_ndff_secure.ndff_waarneming_register(waarneming_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS Meijendel_ndff_secure.blwg_korstmossen_formulier_taxon (
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  kopid BIGINT UNSIGNED NOT NULL,
  taxon_bronkoppeling_id BIGINT UNSIGNED NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  hoeveelheidscode SMALLINT UNSIGNED,
  bronregelnummer SMALLINT UNSIGNED,
  PRIMARY KEY (bronbestand_sha256,kopid,taxon_bronkoppeling_id),
  CONSTRAINT fk_blwg_secure_matrix_formulier FOREIGN KEY (bronbestand_sha256,kopid)
    REFERENCES Meijendel.korstmossen_bron_formulier(bronbestand_sha256,kopid),
  CONSTRAINT fk_blwg_secure_matrix_taxon FOREIGN KEY (taxon_bronkoppeling_id)
    REFERENCES Meijendel.taxa_bronkoppeling(koppeling_id),
  CONSTRAINT fk_blwg_secure_matrix_resultaat FOREIGN KEY (bronbestand_sha256,bronregelnummer)
    REFERENCES Meijendel_ndff_secure.blwg_korstmossen_resultaat(bronbestand_sha256,bronregelnummer),
  CONSTRAINT ck_blwg_secure_matrix_resultaat CHECK
    ((waarnemingsstatus='waargenomen' AND hoeveelheidscode IS NOT NULL AND bronregelnummer IS NOT NULL)
      OR (waarnemingsstatus='echte_nul' AND hoeveelheidscode=0 AND bronregelnummer IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
