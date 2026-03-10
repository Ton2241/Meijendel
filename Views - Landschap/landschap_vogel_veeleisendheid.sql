/* UITLEG
Deze query is bedoeld voor een view/rapport: landschap_vogel_veeleisendheid.
*/

-- Stap 1: Leest gegevens uit: `evg_vogel_landschapstype`, `soorten`, `evg_landschapstypen`.
SELECT 
    l.beschrijving AS landschap,
    s.soort_naam AS vogelsoort,
    vlt.veeleisendheid
FROM evg_vogel_landschapstype vlt
JOIN soorten s ON vlt.soort_id = s.id
JOIN evg_landschapstypen l ON vlt.landschap_id = l.id
ORDER BY l.beschrijving, s.soort_naam;
