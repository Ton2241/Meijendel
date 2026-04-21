/* UITLEG
Deze query is bedoeld voor een view/rapport: Plot met bijbehorende teller.
*/

-- Stap 1: Leest gegevens uit: `plot_jaar_teller`, `plots`, `tellers`.
SELECT 
    p.kavel_nummer,
    pjt.jaar,
    t.tellercode,
    CONCAT_WS(' ', t.voornaam, t.tussenvoegsel, t.achternaam) AS teller_naam
FROM 
    plot_jaar_teller pjt
JOIN 
    plots p ON pjt.plot_id = p.plot_id AND p.in_gebruik = 1
JOIN 
    tellers t ON pjt.teller_id = t.id
WHERE 
    p.kavel_nummer = 'Jouw-Kavel-Nummer' -- Hier vul je het kavelnummer in
ORDER BY 
    pjt.jaar DESC;
