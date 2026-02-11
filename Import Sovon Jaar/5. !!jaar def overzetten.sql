-- Kopieer de gegevens van de tijdelijke tabel naar de tabel waarnemingen
INSERT INTO waarnemingen (plot_id, Euring, jaar, territoria)
SELECT plot_id, Euring, jaar, territoria
FROM temp_waarnemingen;

-- EXTRA: Controleer of de totalen in beide tabellen nu gelijk zijn voor het jaar 1988
SELECT 
    (SELECT SUM(territoria) FROM temp_waarnemingen) AS Totaal_Tijdelijk,
    (SELECT SUM(territoria) FROM waarnemingen WHERE jaar = 2025) AS Totaal_Definitief;
