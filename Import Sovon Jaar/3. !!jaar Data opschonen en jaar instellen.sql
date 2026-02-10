-- 1. Verwijder records met territorium 0 of leeg
DELETE FROM temp_waarnemingen 
WHERE territoria = 0 OR territoria IS NULL;

-- 2. Vul het gekozen jaartal in
UPDATE temp_waarnemingen SET jaar = 2025;
