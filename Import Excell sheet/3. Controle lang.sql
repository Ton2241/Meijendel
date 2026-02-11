SELECT DISTINCT t.plot_id, p.Plotnaam
FROM temp_waarnemingen_lang t
JOIN plots p ON t.plot_id = p.plot_id
WHERE NOT EXISTS (
    SELECT 1 FROM plot_jaar_oppervlak pjo 
    WHERE pjo.plot_id = t.plot_id AND pjo.jaar = t.jaar
);