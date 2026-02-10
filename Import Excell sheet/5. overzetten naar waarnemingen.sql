INSERT INTO waarnemingen (Plotid, Euring, jaar, territoria)
SELECT t.Plotid, t.Euring, t.jaar, t.territoria
FROM temp_waarnemingen_lang t
INNER JOIN plot_jaar_oppervlak pjo 
    ON t.Plotid = pjo.Plotid AND t.jaar = pjo.jaar;