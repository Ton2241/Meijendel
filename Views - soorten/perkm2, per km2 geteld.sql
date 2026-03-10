/* UITLEG
Deze query is bedoeld voor een view/rapport: perkm2, per km2 geteld.
*/

-- Stap 1: Leest gegevens uit: `plot_jaar_oppervlak`, `territoria`.
SELECT 
    w.jaar AS Jaar,
    SUM(w.territoria) AS Totaal_Aantal_Territoria,
    
    -- Kolom 3: Gemiddelde territoria per km2 (Totaal territoria / Totale oppervlakte van ALLE plots in dat jaar)
    SUM(w.territoria) / (
        SELECT SUM(pjo.oppervlakte_km2) 
        FROM plot_jaar_oppervlak pjo 
        WHERE pjo.jaar = w.jaar
    ) AS Gem_km2,

    -- Kolom 4: Gemiddelde territoria per km2 (Totaal territoria / Alleen oppervlakte van GETELDE plots)
    SUM(w.territoria) / (
        SELECT SUM(pjo2.oppervlakte_km2) 
        FROM plot_jaar_oppervlak pjo2 
        WHERE pjo2.jaar = w.jaar 
        AND pjo2.plot_id IN (SELECT DISTINCT plot_id FROM territoria WHERE jaar = w.jaar)
    ) AS Gem_Getelde_km2

FROM territoria w
GROUP BY w.jaar
ORDER BY w.jaar;
