/* UITLEG
Deze query is bedoeld voor een view/rapport: per jaar per plot.
*/

-- Stap 1: Leest gegevens uit: `territoria`, `soorten`, `plots`.
SELECT 
    w.jaar,
    p.plot_naam,
    p.plot_nr,
    s.soort_naam,
    s.euring_code,
    w.territoria
FROM territoria w
JOIN soorten s ON w.soort_id = s.id
JOIN plots p ON w.plot_id = p.plot_id
ORDER BY w.jaar DESC, p.plot_naam ASC, s.soort_naam ASC;
