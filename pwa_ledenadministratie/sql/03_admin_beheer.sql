CREATE TABLE IF NOT EXISTS pwa_teller_admin_meta (
  teller_id BIGINT NOT NULL,
  beheer_status ENUM('actief', 'inactief', 'nader_controleren') NOT NULL DEFAULT 'actief',
  opmerking TEXT NULL,
  updated_by_teller_id BIGINT NULL,
  updated_by_email VARCHAR(255) NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (teller_id),
  KEY idx_pwa_teller_admin_meta_status (beheer_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS pwa_member_change_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  teller_id BIGINT NOT NULL,
  actor_teller_id BIGINT NULL,
  actor_email VARCHAR(255) NULL,
  action VARCHAR(80) NOT NULL,
  old_values JSON NOT NULL,
  new_values JSON NOT NULL,
  ip VARBINARY(16) NULL,
  user_agent_hash CHAR(64) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_pwa_member_change_teller_created (teller_id, created_at),
  KEY idx_pwa_member_change_actor_created (actor_teller_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS pwa_history_change_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  plot_jaar_teller_id INT NULL,
  actor_teller_id BIGINT NULL,
  actor_email VARCHAR(255) NULL,
  action ENUM('history_create', 'history_update', 'history_delete') NOT NULL,
  old_values JSON NULL,
  new_values JSON NULL,
  ip VARBINARY(16) NULL,
  user_agent_hash CHAR(64) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_pwa_history_change_entry_created (plot_jaar_teller_id, created_at),
  KEY idx_pwa_history_change_actor_created (actor_teller_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/* Aanbevolen productiegebruiker, wachtwoord zelf invullen en buiten git houden:

CREATE USER 'meijendel_pwa'@'%' IDENTIFIED BY 'sterk-wachtwoord';
GRANT SELECT ON meijendel.pwa_teller_lijst TO 'meijendel_pwa'@'%';
GRANT SELECT ON meijendel.pwa_teller_detail TO 'meijendel_pwa'@'%';
GRANT SELECT ON meijendel.pwa_teller_stats TO 'meijendel_pwa'@'%';
GRANT SELECT ON meijendel.pwa_teller_datakwaliteit TO 'meijendel_pwa'@'%';
GRANT SELECT ON meijendel.pwa_teller_telhistorie TO 'meijendel_pwa'@'%';
GRANT SELECT ON meijendel.pwa_actieve_tellers_per_jaar TO 'meijendel_pwa'@'%';
GRANT SELECT, UPDATE ON meijendel.tellers TO 'meijendel_pwa'@'%';
GRANT SELECT, INSERT, UPDATE ON meijendel.pwa_magic_link_challenges TO 'meijendel_pwa'@'%';
GRANT SELECT, INSERT ON meijendel.pwa_auth_audit_log TO 'meijendel_pwa'@'%';
GRANT SELECT ON meijendel.pwa_auth_whitelist TO 'meijendel_pwa'@'%';
GRANT SELECT, INSERT, UPDATE ON meijendel.pwa_teller_admin_meta TO 'meijendel_pwa'@'%';
GRANT INSERT, SELECT ON meijendel.pwa_member_change_log TO 'meijendel_pwa'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON meijendel.plot_jaar_teller TO 'meijendel_pwa'@'%';
GRANT SELECT ON meijendel.plots TO 'meijendel_pwa'@'%';
GRANT INSERT, SELECT ON meijendel.pwa_history_change_log TO 'meijendel_pwa'@'%';

*/
