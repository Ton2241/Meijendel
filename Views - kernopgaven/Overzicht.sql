SELECT 
    k.code AS Kernopgave_Code,
    k.omschrijving AS Omschrijving,
    GROUP_CONCAT(DISTINCT h.habitat_naam SEPARATOR ', ') AS Gekoppelde_Habitats,
    GROUP_CONCAT(DISTINCT s.Soort SEPARATOR ', ') AS Gekoppelde_Vogelsoorten
FROM kernopgaven k
-- Koppel aan habitats via de koppeltabel
LEFT JOIN kernopgave_habitat kh ON k.id = kh.kernopgave_id
LEFT JOIN habitattypen h ON kh.habitat_id = h.id
-- Koppel aan soorten via de koppeltabel
LEFT JOIN kernopgave_soort ks ON k.id = ks.kernopgave_id
LEFT JOIN soorten s ON ks.soort_id = s.id
GROUP BY k.id;