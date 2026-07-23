/*
  Canonieke analyse-interface voor de gemengde ruwe KNMI-reeks in `weer`.

  Gebruik in analyses uitsluitend deze view. De ruwe schaal verschilt:
  - station 210 Valkenburg: TG/TN/TX/RH moeten maal 10;
  - station 215 Voorschoten: TG/TN/TX/RH moeten gedeeld door 10.

  FG, SQ en PG staan bij beide stations in tienden. KNMI-code -1 betekent
  voor SQ en RH een spoorhoeveelheid; de analysewaarde is dan 0 en de
  bijbehorende spoor-kolom blijft 1.
*/
CREATE OR REPLACE SQL SECURITY INVOKER VIEW weer_analyse AS
SELECT
    datum,
    STN AS stn,
    Naam AS station_naam,
    CAST(FG / 10.0 AS DECIMAL(6,1)) AS fg_ms,
    CAST(
        CASE
            WHEN STN = 210 THEN TG * 10.0
            WHEN STN = 215 THEN TG / 10.0
        END AS DECIMAL(6,1)
    ) AS tg_c,
    CAST(
        CASE
            WHEN STN = 210 THEN TN * 10.0
            WHEN STN = 215 THEN TN / 10.0
        END AS DECIMAL(6,1)
    ) AS tn_c,
    CAST(
        CASE
            WHEN STN = 210 THEN TX * 10.0
            WHEN STN = 215 THEN TX / 10.0
        END AS DECIMAL(6,1)
    ) AS tx_c,
    CAST(CASE WHEN SQ = -1 THEN 0.0 ELSE SQ / 10.0 END AS DECIMAL(6,1)) AS sq_uur,
    CASE WHEN SQ = -1 THEN 1 ELSE 0 END AS sq_spoor,
    CAST(
        CASE
            WHEN RH = -1 THEN 0.0
            WHEN STN = 210 THEN RH * 10.0
            WHEN STN = 215 THEN RH / 10.0
        END AS DECIMAL(6,1)
    ) AS rh_mm,
    CASE WHEN RH = -1 THEN 1 ELSE 0 END AS rh_spoor,
    CAST(PG / 10.0 AS DECIMAL(7,1)) AS pg_hpa,
    UG AS ug_pct,
    CASE
        WHEN STN = 210 THEN '210_VALKENBURG_X10'
        WHEN STN = 215 THEN '215_VOORSCHOTEN_DIV10'
        ELSE 'ONBEKEND_STATION'
    END AS eenhedenprofiel
FROM weer;
