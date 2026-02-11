UPDATE vogelstand_1924 v
JOIN soorten s ON v.euring = s.euring_code
SET v.vogelnaam = s.soort_naam
WHERE v.euring IS NOT NULL;