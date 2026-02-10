SELECT 
    s.Euring, 
    s.Soort AS nederlandse_naam, 
    e.latijnse_naam 
FROM soorten s
LEFT JOIN euring e ON s.Euring = e.euring_code;