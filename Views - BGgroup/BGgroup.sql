/* UITLEG
Deze query is bedoeld voor een view/rapport: BGgroup.
*/

-- Stap 1: Uitvoering van een SQL‑statement.
WITH
SoortenMetBG AS (
    /*
    STAP 1 - Koppel soorten aan een geldige BG-groep
    -------------------------------------------------
    Doel:
    - We willen alleen soorten meenemen die in BGgroup een bruikbare group_code hebben.
    - BGgroup kan in de praktijk meerdere regels per soort bevatten;
-- Stap 2: Uitvoering van een SQL‑statement.
 daarom normaliseren we
      hier naar unieke combinaties (soort_id, group_code).

    Resultaat:
    - Eén regel per soort_id + group_code.
    - Deze set gebruiken we later om territoria per soort op te tellen naar groepsniveau.
    */
    SELECT
        b.id AS soort_id,
        b.group_code
    FROM BGgroup b
    WHERE b.group_code IS NOT NULL
      AND TRIM(b.group_code) <> ''
    GROUP BY b.id, b.group_code
),

ActievePlotsPerJaar AS (
    /*
    STAP 2 - Bepaal welke plots in welk jaar daadwerkelijk zijn geteld
    -------------------------------------------------------------------
    Doel:
    - Alleen plots meenemen waarvoor in dat jaar territoria zijn geregistreerd.
    - Daarmee sluiten we automatisch niet-getelde plots uit, zoals gevraagd.

    Werkwijze:
    - We nemen DISTINCT (jaar, plot_id) uit territoria.
    - Eén plot telt per jaar maar één keer mee in het oppervlak.
    */
    SELECT DISTINCT
        t.jaar,
        t.plot_id
    FROM territoria t
),

GeteldOppervlakPerJaar AS (
    /*
    STAP 3 - Bereken per jaar het totale getelde oppervlak (km2)
    -------------------------------------------------------------
    Doel:
    - Voor elk jaar de noemer bepalen voor dichtheidsberekening.
    - Alleen oppervlak van actief getelde plots (stap 2) wordt opgeteld.

    Werkwijze:
    - Join met plot_jaar_oppervlak op (plot_id, jaar).
    - Som van oppervlakte_km2 per jaar.

    Let op:
    - Deze noemer is jaargebonden en geldt voor alle groepen in dat jaar.
    */
    SELECT
        ap.jaar,
        SUM(pjo.oppervlakte_km2) AS geteld_oppervlak_km2
    FROM ActievePlotsPerJaar ap
    JOIN plot_jaar_oppervlak pjo
      ON pjo.plot_id = ap.plot_id
     AND pjo.jaar = ap.jaar
    GROUP BY ap.jaar
),

TerritoriaPerGroepJaar AS (
    /*
    STAP 4 - Tel territoria op per BG-groep en per jaar
    ---------------------------------------------------
    Doel:
    - Alle soorten binnen dezelfde group_code samenvoegen.
    - Voor elk jaar het totaal aantal territoria per groep berekenen.

    Werkwijze:
    - Join territoria -> SoortenMetBG op soort_id.
    - Som van territoria per (jaar, group_code).
    */
    SELECT
        t.jaar,
        sbg.group_code,
        SUM(t.territoria) AS totaal_territoria
    FROM territoria t
    JOIN SoortenMetBG sbg
      ON sbg.soort_id = t.soort_id
    GROUP BY
        t.jaar,
        sbg.group_code
)

SELECT
    /*
    STAP 5 - Eindresultaat: groepssom + dichtheid per km2
    ------------------------------------------------------
    Doel:
    - Per jaar en per BG-groep tonen:
      1) totaal territoria
      2) geteld oppervlak (km2)
      3) territoriadichtheid (territoria per km2)

    Formule dichtheid:
    - dichtheid = totaal_territoria / geteld_oppervlak_km2

    Veiligheid:
    - NULLIF voorkomt deling door nul.
    */
    tg.jaar,
    tg.group_code,
    tg.totaal_territoria,
    ROUND(go.geteld_oppervlak_km2, 6) AS geteld_oppervlak_km2,
    ROUND(tg.totaal_territoria / NULLIF(go.geteld_oppervlak_km2, 0), 4) AS territoria_per_km2
FROM TerritoriaPerGroepJaar tg
JOIN GeteldOppervlakPerJaar go
  ON go.jaar = tg.jaar
ORDER BY
    tg.jaar DESC,
    tg.group_code ASC;
