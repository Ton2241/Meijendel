SELECT 
    t.Plotid, 
    p.KavelNummer, 
    SUM(t.territoria) AS totaal_territoria
FROM temp_waarnemingen_lang t
JOIN plots p ON t.Plotid = p.Plotid
GROUP BY t.Plotid, p.KavelNummer;