SELECT DISTINCT
    w.jaar,
    w.Plotid,
    p.Plotnaam
FROM 
    waarnemingen w
JOIN 
    plots p ON w.Plotid = p.Plotid
WHERE 
    w.territoria > 0 -- Alleen plots met daadwerkelijke vogelwaarnemingen
    AND NOT EXISTS (
        SELECT 1 
        FROM plot_jaar_teller pjt 
        WHERE pjt.Plotid = w.Plotid 
        AND pjt.jaar = w.jaar
    )
ORDER BY 
    w.jaar DESC;