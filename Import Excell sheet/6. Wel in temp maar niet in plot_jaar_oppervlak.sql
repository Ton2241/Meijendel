-- Stap 1: Selecteer alle unieke combinaties van plot en jaar uit de importtabel
-- Stap 2: Controleer welke daarvan ontbreken in plot_jaar_oppervlak
-- Een ontbrekende combinatie blokkeert de INSERT in territoria via de foreign key
SELECT DISTINCT 
    i.plot_id,
    i.jaar,
    p.plot_naam,
    p.kavel_nummer
FROM import_waarnemingen_lang i
-- Stap 3: Koppel de plotnaam voor leesbare uitvoer
JOIN plots p ON i.plot_id = p.plot_id
-- Stap 4: Houd alleen de combinaties over waarvoor geen oppervlakte bekend is
WHERE NOT EXISTS (
    SELECT 1 
    FROM plot_jaar_oppervlak pjo 
    WHERE pjo.plot_id = i.plot_id 
    AND pjo.jaar = i.jaar
)
ORDER BY i.jaar, p.kavel_nummer;