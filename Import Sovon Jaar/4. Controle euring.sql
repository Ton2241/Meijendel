-- Check welke vogels uit je import NIET voorkomen in de tabel 'soorten'
SELECT t.vogelnaam_temp, t.Euring 
FROM temp_waarnemingen t
LEFT JOIN soorten s ON t.Euring = s.Euring
WHERE s.Euring IS NULL;
