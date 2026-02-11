SELECT 
    s.soort_naam AS Vogelnaam, 
    w.territoria AS Aantal_Territoria,
    w.jaar AS Jaar
FROM waarnemingen w
JOIN soorten s ON w.soort_id = s.id
JOIN soort_richtlijn sr ON s.id = sr.soort_id
JOIN richtlijnen r ON sr.richtlijn_id = r.id
WHERE r.naam = 'RL: Verdwenen' 
  AND w.jaar = 2025
  AND w.territoria > 0;