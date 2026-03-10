/* UITLEG
Deze query is bedoeld voor een view/rapport: Kavelbezetting in jaar T T-1 en T+1.
*/

-- Stap 1: Uitvoering van een SQL‑statement.
-- Stap 1: Definieer het basisjaar T. 
-- In een applicatie vervang je '2025' door de input van de gebruiker.
SET @jaar_T = 2025;
-- Stap 2: Leest gegevens uit: `plots`, `territoria`, `om`, `plotkolom_mapping`, `voor`, `plot_jaar_teller`, `tellers`.


SELECT 
    -- Kolom 1: Het geselecteerde jaar
    @jaar_T AS 'Jaar T',
    
    -- Kolom 2 & 3: Plot informatie
    p.kavel_nummer AS 'kavel_nr',
    p.plot_id AS 'plot_id',
    
    -- Kolom 4 & 5: Teller gegevens voor het huidige jaar T
    -- We gebruiken een subquery of join om de naam samen te voegen
    CONCAT_WS(' ', t_curr.voornaam, t_curr.tussenvoegsel, t_curr.achternaam) AS 'Naam teller T',
    t_curr.id AS 'ID teller T',
    
    -- Kolom 7 & 8: Gegevens van het voorgaande jaar (T-1)
    -- We joinen de teller-tabel opnieuw via de koppeltabel voor T-1
    CONCAT_WS(' ', t_prev.voornaam, t_prev.tussenvoegsel, t_prev.achternaam) AS 'Teller T-1',
    t_prev.id AS 'TellerID T-1',
    
    -- Kolom 9 & 10: Gegevens van het volgende jaar (T+1)
    CONCAT_WS(' ', t_next.voornaam, t_next.tussenvoegsel, t_next.achternaam) AS 'Teller T+1',
    t_next.id AS 'TellerID T+1'

FROM plots p
-- Koppel de mapping tabel om de sorteervolgorde van de brede import te kunnen gebruiken
LEFT JOIN plotkolom_mapping m ON p.plot_id = m.plot_id

-- Join voor het huidige jaar T: Alleen plots die data hebben in 'territoria' voor jaar T
INNER JOIN (
    SELECT DISTINCT plot_id 
    FROM territoria 
    WHERE jaar = @jaar_T
) t_data ON p.plot_id = t_data.plot_id

-- Haal de teller op voor Jaar T
LEFT JOIN plot_jaar_teller pjt_curr ON p.plot_id = pjt_curr.plot_id AND pjt_curr.jaar = @jaar_T
LEFT JOIN tellers t_curr ON pjt_curr.teller_id = t_curr.id

-- Haal de teller op voor Jaar T-1
LEFT JOIN plot_jaar_teller pjt_prev ON p.plot_id = pjt_prev.plot_id AND pjt_prev.jaar = (@jaar_T - 1)
LEFT JOIN tellers t_prev ON pjt_prev.teller_id = t_prev.id

-- Haal de teller op voor Jaar T+1
LEFT JOIN plot_jaar_teller pjt_next ON p.plot_id = pjt_next.plot_id AND pjt_next.jaar = (@jaar_T + 1)
LEFT JOIN tellers t_next ON pjt_next.teller_id = t_next.id

-- Sortering op basis van de kolomvolgorde in de import_waarnemingen_breed tabel
-- De kolomnaam in plotkolom_mapping bevat waarden zoals 'p_1A', 'p_1B', 'p_2', etc.
-- Door hierop te sorteren volgen we de logica van de download-bestanden.
ORDER BY 
    CASE 
        WHEN m.kolomnaam LIKE 'p_%' THEN CAST(SUBSTRING_INDEX(SUBSTRING(m.kolomnaam, 3), '_', 1) AS UNSIGNED)
        ELSE 999 
    END, 
    m.kolomnaam;
