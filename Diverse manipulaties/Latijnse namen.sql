-- Stap 1: Selecteer euring_code, Nederlandse naam en Latijnse naam
-- rechtstreeks uit soorten, zonder join naar een externe tabel
SELECT 
    s.euring_code,
    s.soort_naam AS nederlandse_naam,
    s.latijnse_naam
FROM soorten s
ORDER BY s.soort_naam ASC;
-- Stap 2: toon alleen soorten zonder Latijnse naam
WHERE s.latijnse_naam IS NULL OR s.latijnse_naam = ''