SELECT 
    w.jaar,
    p.Plotnaam,
    p.Plotnr,
    s.Soort,
    s.Euring,
    w.territoria
FROM waarnemingen w
JOIN soorten s ON w.soort_id = s.id
JOIN plots p ON w.Plotid = p.Plotid
ORDER BY w.jaar DESC, p.Plotnaam ASC, s.Soort ASC;