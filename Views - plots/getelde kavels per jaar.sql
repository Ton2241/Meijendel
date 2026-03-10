/* UITLEG
Deze query is bedoeld voor een view/rapport: getelde kavels per jaar.
*/

-- Stap 1: Leest gegevens uit: `plots`, `territoria`.
SELECT DISTINCT
    p.plot_id,
    p.plot_naam,
    p.kavel_nummer
FROM 
    plots p
JOIN 
    territoria w ON p.plot_id = w.plot_id
WHERE 
    w.jaar = 1999
ORDER BY 
    p.plot_id;
