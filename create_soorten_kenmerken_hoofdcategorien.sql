CREATE TABLE IF NOT EXISTS soorten_kenmerken_hoofdcategorien (
  code CHAR(1) NOT NULL,
  beschrijving VARCHAR(100) NOT NULL,
  PRIMARY KEY (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO soorten_kenmerken_hoofdcategorien (code, beschrijving) VALUES
  ('F', 'Functionele habitat en foerageerwijze'),
  ('V', 'Voedsel van volwassen vogels'),
  ('J', 'Voedsel voor jongen'),
  ('M', 'Migratie'),
  ('N', 'Nestplaats en nestbouw'),
  ('K', 'Gedrag, ecologie en levenswijze')
ON DUPLICATE KEY UPDATE
  beschrijving = VALUES(beschrijving);
