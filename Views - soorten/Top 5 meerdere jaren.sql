/* UITLEG
Deze query is bedoeld voor een view/rapport: Top 5 meerdere jaren.
*/

-- Stap 1: Leest gegevens uit: `territoria`, `soorten`.
SELECT jaar, soort_naam, totaal
FROM (
    SELECT 
        w.jaar,
        s.soort_naam, 
        SUM(w.territoria) AS totaal,
        RANK() OVER (PARTITION BY w.jaar ORDER BY SUM(w.territoria) DESC) as rang
    FROM territoria w
    JOIN soorten s ON w.soort_id = s.id
    WHERE w.jaar BETWEEN 2008 AND 2010
    GROUP BY w.jaar, s.soort_naam
) AS subquery
WHERE rang <= 5 -- Verander dit getal om de top X per jaar te zien
ORDER BY jaar DESC, rang ASC;
