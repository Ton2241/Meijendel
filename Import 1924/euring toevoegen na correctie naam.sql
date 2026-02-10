UPDATE Vogelstand_1924 v
JOIN soorten s ON v.euring = s.Euring
SET v.vogelnaam = s.Soort
WHERE v.euring IS NOT NULL;