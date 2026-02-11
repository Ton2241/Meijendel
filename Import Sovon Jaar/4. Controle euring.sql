-- Check welke vogels uit je import NIET voorkomen in de tabel 'soorten'
SELECT t.vogelnaam_temp, t.euring_code 
FROM temp_waarnemingen t
LEFT JOIN soorten s ON t.euring_code = s.euring_code
WHERE s.euring_code IS NULL;
