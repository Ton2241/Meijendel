SELECT DISTINCT t.Plotid, p.Plotnaam
FROM temp_waarnemingen_lang t
JOIN plots p ON t.Plotid = p.Plotid
WHERE NOT EXISTS (
    SELECT 1 FROM plot_jaar_oppervlak pjo 
    WHERE pjo.Plotid = t.Plotid AND pjo.jaar = t.jaar
);