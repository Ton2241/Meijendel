INSERT INTO waarnemingen (plot_id, Euring, jaar, territoria)
SELECT t.plot_id, t.Euring, t.jaar, t.territoria
FROM temp_waarnemingen_lang t
INNER JOIN plot_jaar_oppervlak pjo 
    ON t.plot_id = pjo.plot_id AND t.jaar = pjo.jaar;