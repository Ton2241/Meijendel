CREATE TABLE IF NOT EXISTS pwa_magic_link_challenges (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  teller_id BIGINT NOT NULL,
  email VARCHAR(255) NOT NULL,
  selector CHAR(32) NOT NULL,
  token_hash CHAR(64) NOT NULL,
  code_hash VARCHAR(255) NULL,
  code_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  max_code_attempts TINYINT UNSIGNED NOT NULL DEFAULT 5,
  requested_ip VARBINARY(16) NULL,
  requested_country_code CHAR(2) NULL,
  requested_user_agent_family VARCHAR(80) NULL,
  requested_user_agent_hash CHAR(64) NULL,
  expires_at DATETIME NOT NULL,
  consumed_at DATETIME NULL,
  soft_mismatch_reason VARCHAR(255) NULL,
  confirmation_required TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_pwa_magic_selector (selector),
  KEY idx_pwa_magic_user_active (teller_id, expires_at, consumed_at),
  KEY idx_pwa_magic_email_active (email, expires_at, consumed_at),
  CONSTRAINT chk_pwa_magic_attempts CHECK (code_attempts <= max_code_attempts),
  CONSTRAINT chk_pwa_magic_max_attempts CHECK (max_code_attempts BETWEEN 1 AND 10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS pwa_auth_whitelist (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  teller_id BIGINT NULL,
  email VARCHAR(255) NULL,
  ip_cidr VARCHAR(64) NULL,
  country_code CHAR(2) NULL,
  user_agent_family VARCHAR(80) NULL,
  note VARCHAR(255) NOT NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(120) NULL,
  PRIMARY KEY (id),
  KEY idx_pwa_auth_whitelist_active (active),
  KEY idx_pwa_auth_whitelist_teller (teller_id),
  CONSTRAINT chk_pwa_auth_whitelist_criterion CHECK (
    teller_id IS NOT NULL
    OR email IS NOT NULL
    OR ip_cidr IS NOT NULL
    OR country_code IS NOT NULL
    OR user_agent_family IS NOT NULL
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS pwa_auth_audit_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  teller_id BIGINT NULL,
  email VARCHAR(255) NULL,
  event_type ENUM(
    'magic_link_requested',
    'magic_link_sent',
    'magic_link_verified',
    'magic_code_verified',
    'soft_check_mismatch',
    'extra_confirmation_required',
    'whitelist_match',
    'auth_failed',
    'logout'
  ) NOT NULL,
  result ENUM('success', 'denied', 'pending', 'expired', 'consumed') NOT NULL,
  ip VARBINARY(16) NULL,
  country_code CHAR(2) NULL,
  user_agent_family VARCHAR(80) NULL,
  user_agent_hash CHAR(64) NULL,
  challenge_id BIGINT UNSIGNED NULL,
  details JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_pwa_auth_audit_teller_created (teller_id, created_at),
  KEY idx_pwa_auth_audit_event_created (event_type, created_at),
  CONSTRAINT fk_pwa_auth_audit_challenge
    FOREIGN KEY (challenge_id) REFERENCES pwa_magic_link_challenges(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
