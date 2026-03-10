/* UITLEG
Deze query is bedoeld voor een view/rapport: view_weer_totaal.
*/

-- Stap 1: Uitvoering van een SQL‑statement.

CREATE OR REPLACE VIEW weer_totaal AS
SELECT datum, temp_gem FROM weer_historie_katwijk WHERE datum < '2016-05-04'
UNION ALL
SELECT datum, temp_gem FROM weer_actueel_voorschoten WHERE datum >= '2016-05-04';
