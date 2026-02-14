SELECT 
    w.jaar,
    p.Plotnaam,
    p.plot_nr,
    s.soort_naam,
    s.euring_code,
    w.territoria
FROM waarnemingen w
JOIN soorten s ON w.soort_id = s.id
JOIN plots p ON w.plot_id = p.plot_id
ORDER BY w.jaar DESC, p.Plotnaam ASC, s.soort_naam ASC;