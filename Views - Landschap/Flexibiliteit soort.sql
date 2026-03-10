/* UITLEG
Deze query is bedoeld voor een view/rapport: Flexibiliteit soort.
*/

-- Stap 1: Leest gegevens uit: `evg_vogel_landschapstype`, `soorten`.
SELECT s.soort_naam, COUNT(*) AS aantal_landschappen
FROM evg_vogel_landschapstype vlt
JOIN soorten s ON vlt.soort_id = s.id
GROUP BY s.id
ORDER BY aantal_landschappen DESC;
