
SELECT 
    CONCAT(t.voornaam, ' ', IFNULL(t.tussenvoegsel, ''), ' ', t.achternaam) AS teller_naam,
    t.soort_lid,
    COUNT(DISTINCT pjt.jaar) AS aantal_jaren,
    COUNT(pjt.Plotid) AS totaal_aantal_plots_geteld
FROM tellers t
JOIN plot_jaar_teller pjt ON t.tellercode = pjt.tellercode
GROUP BY 
    t.tellercode, 
    t.voornaam, 
    t.tussenvoegsel, 
    t.achternaam, 
    t.soort_lid
ORDER BY aantal_jaren DESC, totaal_aantal_plots_geteld DESC;