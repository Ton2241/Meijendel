/* UITLEG
Deze query is bedoeld voor een view/rapport: m2 per habitat per jaar.
*/

-- Stap 1: Leest gegevens uit: `plot_jaar_habitat`, `plots`, `habitattypen`.
SELECT p.plot_naam, h.habitat_code, pjh.aandeel_m2, pjh.jaar
FROM plot_jaar_habitat pjh
JOIN plots p ON pjh.plot_id = p.plot_id AND p.in_gebruik = 1
JOIN habitattypen h ON pjh.habitat_id = h.id
WHERE pjh.jaar = 2014;
