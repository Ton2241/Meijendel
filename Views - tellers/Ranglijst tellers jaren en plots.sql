/* UITLEG
Deze query is bedoeld voor een view/rapport: Ranglijst tellers jaren en plots.
*/

-- Stap 1: Leest gegevens uit: `tellers`, `plot_jaar_teller`.

SELECT 
    t.tellercode,
    COUNT(DISTINCT pjt.jaar) AS aantal_jaren,
    COUNT(pjt.plot_id) AS totaal_aantal_plots_geteld
FROM tellers t
JOIN plot_jaar_teller pjt ON t.id = pjt.teller_id
GROUP BY 
    t.id, 
    t.tellercode
ORDER BY aantal_jaren DESC, totaal_aantal_plots_geteld DESC;
