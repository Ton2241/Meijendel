SELECT DISTINCT
    w.jaar,
    w.plot_id,
    p.Plotnaam
FROM 
    waarnemingen w
JOIN 
    plots p ON w.plot_id = p.plot_id
WHERE 
    w.territoria > 0 -- Alleen plots met daadwerkelijke vogelwaarnemingen
    AND NOT EXISTS (
        SELECT 1 
        FROM plot_jaar_teller pjt 
        WHERE pjt.plot_id = w.plot_id 
        AND pjt.jaar = w.jaar
    )
ORDER BY 
    w.jaar DESC;