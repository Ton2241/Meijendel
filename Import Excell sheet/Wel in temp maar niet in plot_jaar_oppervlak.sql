SELECT DISTINCT plot_id 
FROM temp_waarnemingen 
WHERE plot_id NOT IN (SELECT plot_id FROM plots);