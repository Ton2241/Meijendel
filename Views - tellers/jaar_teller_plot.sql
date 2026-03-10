/* UITLEG
Deze query is bedoeld voor een view/rapport: jaar_teller_plot.
*/

-- Stap 1: Leest gegevens uit: `view_teller_overzicht`.
SELECT * FROM view_teller_overzicht 
WHERE jaar = 1979;
