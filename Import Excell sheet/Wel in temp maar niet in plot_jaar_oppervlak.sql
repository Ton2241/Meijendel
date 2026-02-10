SELECT DISTINCT Plotid 
FROM temp_waarnemingen 
WHERE Plotid NOT IN (SELECT Plotid FROM plots);