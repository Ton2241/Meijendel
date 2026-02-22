SELECT 
    t.plot_id, 
    p.kavel_nummer, 
    SUM(t.territoria) AS totaal_territoria
FROM import_waarnemingen_lang t
JOIN plots p ON t.plot_id = p.plot_id
GROUP BY t.plot_id, p.kavel_nummer;