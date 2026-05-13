/* UITLEG
Kavelbezetting in jaar T, T-1 en T+1.

Pas @jaar_T aan voor een ander basisjaar.
De tellers worden eerst per plot/jaar samengevoegd, zodat kavels met meerdere
tellers maar een keer in het rapport staan.
*/

SET @jaar_T = 2025;

WITH teller_per_plot_jaar AS (
    SELECT
        pjt.plot_id,
        pjt.jaar,
        GROUP_CONCAT(
            DISTINCT TRIM(CONCAT_WS(
                ' ',
                NULLIF(TRIM(t.voornaam), ''),
                NULLIF(TRIM(t.tussenvoegsel), ''),
                NULLIF(TRIM(t.achternaam), '')
            ))
            ORDER BY t.achternaam, t.voornaam, t.id
            SEPARATOR '; '
        ) AS teller_namen,
        GROUP_CONCAT(
            DISTINCT t.id
            ORDER BY t.id
            SEPARATOR '; '
        ) AS teller_ids
    FROM plot_jaar_teller pjt
    JOIN tellers t ON t.id = pjt.teller_id
    WHERE pjt.jaar BETWEEN @jaar_T - 1 AND @jaar_T + 1
    GROUP BY pjt.plot_id, pjt.jaar
),
getelde_plots AS (
    SELECT DISTINCT plot_id
    FROM territoria
    WHERE jaar = @jaar_T
)
SELECT
    @jaar_T AS 'Jaar T',
    p.kavel_nummer AS 'kavel_nr',
    p.plot_id,
    teller_t.teller_namen AS 'Naam teller T',
    teller_t.teller_ids AS 'ID teller T',
    teller_tm1.teller_namen AS 'Teller T-1',
    teller_tm1.teller_ids AS 'TellerID T-1',
    teller_tp1.teller_namen AS 'Teller T+1',
    teller_tp1.teller_ids AS 'TellerID T+1'
FROM plots p
LEFT JOIN plotkolom_mapping m ON m.plot_id = p.plot_id
JOIN getelde_plots gp ON gp.plot_id = p.plot_id
LEFT JOIN teller_per_plot_jaar teller_t
    ON teller_t.plot_id = p.plot_id
    AND teller_t.jaar = @jaar_T
LEFT JOIN teller_per_plot_jaar teller_tm1
    ON teller_tm1.plot_id = p.plot_id
    AND teller_tm1.jaar = @jaar_T - 1
LEFT JOIN teller_per_plot_jaar teller_tp1
    ON teller_tp1.plot_id = p.plot_id
    AND teller_tp1.jaar = @jaar_T + 1
WHERE p.in_gebruik = 1
ORDER BY
    CASE
        WHEN m.kolomnaam LIKE 'p_%'
            THEN CAST(SUBSTRING_INDEX(SUBSTRING(m.kolomnaam, 3), '_', 1) AS UNSIGNED)
        ELSE 999
    END,
    m.kolomnaam;
