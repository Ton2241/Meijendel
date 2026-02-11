SELECT 
    s.euring_code, 
    s.soort_naam AS nederlandse_naam, 
    e.latijnse_naam 
FROM soorten s
LEFT JOIN euring e ON s.euring_code = e.euring_code;