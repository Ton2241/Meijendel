INSERT INTO waarnemingen (plot_id, euring_code, jaar, territoria)
SELECT t.plot_id, t.euring_code, t.jaar, t.territoria
FROM temp_waarnemingen_lang t
INNER JOIN plot_jaar_oppervlak pjo 
    ON t.plot_id = pjo.plot_id AND t.jaar = pjo.jaar;