#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SQL_FILE="${1:-$REPO_DIR/meijendel.sql}"
MYSQL_LOGIN_PATH="${MEIJENDEL_MYSQL_LOGIN_PATH:-meijendel_root}"
MYSQL_DATABASE="${MEIJENDEL_MYSQL_DATABASE:-Meijendel}"
ANALYSE_DIR="$REPO_DIR/Views - Weer - aanpassen na dbase herstructurering"
VIEW_FILE="$ANALYSE_DIR/view_weer_analyse.sql"

die() {
  printf 'FOUT weercontract: %s\n' "$*" >&2
  exit 1
}

[[ -f "$SQL_FILE" ]] || die "SQL-dump ontbreekt: $SQL_FILE"
[[ -f "$VIEW_FILE" ]] || die "viewdefinitie ontbreekt: $VIEW_FILE"

LC_ALL=C grep -aFq 'Final view structure for view `weer_analyse`' "$SQL_FILE" ||
  die "SQL-dump bevat de definitieve view weer_analyse niet"
LC_ALL=C grep -aFq '210_VALKENBURG_X10' "$SQL_FILE" ||
  die "SQL-dump bevat het profiel voor station 210 niet"
LC_ALL=C grep -aFq '215_VOORSCHOTEN_DIV10' "$SQL_FILE" ||
  die "SQL-dump bevat het profiel voor station 215 niet"

unsafe_files="$(
  rg -l -i \
    --glob '*.sql' \
    --glob '!view_weer_analyse.sql' \
    '\b(FROM|JOIN)[[:space:]]+`?weer`?\b' \
    "$ANALYSE_DIR" || true
)"
[[ -z "$unsafe_files" ]] ||
  die "weeranalyse leest rechtstreeks uit de ruwe tabel: $unsafe_files"

result="$(
  mysql --login-path="$MYSQL_LOGIN_PATH" -D "$MYSQL_DATABASE" -N -B -e "
    SELECT CONCAT_WS(
      ':',
      (SELECT COUNT(*) FROM weer WHERE STN NOT IN (210, 215)),
      ABS((SELECT COUNT(*) FROM weer) - (SELECT COUNT(*) FROM weer_analyse)),
      (
        SELECT SUM(
          CASE
            WHEN datum = '2016-05-02' AND stn = 210 AND tg_c = 11.0
              AND tn_c = 1.0 AND tx_c = 17.0 AND rh_mm = 2.0 THEN 0
            WHEN datum = '2016-05-03' AND stn = 215 AND tg_c = 8.8
              AND tn_c = 2.9 AND tx_c = 11.9 AND rh_mm = 0.5 THEN 0
            ELSE 1
          END
        ) + ABS(2 - COUNT(*))
        FROM weer_analyse
        WHERE datum IN ('2016-05-02', '2016-05-03')
      ),
      (
        SELECT COUNT(*)
        FROM weer_analyse
        WHERE tg_c NOT BETWEEN -40 AND 45
           OR tn_c NOT BETWEEN -40 AND 45
           OR tx_c NOT BETWEEN -40 AND 55
           OR rh_mm < 0
           OR fg_ms < 0
           OR pg_hpa NOT BETWEEN 850 AND 1100
           OR ug_pct NOT BETWEEN 0 AND 100
      ),
      (
        SELECT COUNT(*)
        FROM weer w
        JOIN weer_analyse wa ON wa.datum = w.datum
        WHERE (w.RH = -1 AND (wa.rh_mm <> 0 OR wa.rh_spoor <> 1))
           OR (w.SQ = -1 AND (wa.sq_uur <> 0 OR wa.sq_spoor <> 1))
      )
    );
  "
)" || die "lokale MySQL-controle kon niet worden uitgevoerd"

[[ "$result" == "0:0:0:0:0" ]] ||
  die "controle onbekend_station:korrel:schaal:bereik:spoor gaf $result"

printf 'Weercontract OK: dump, analysequeries en lokale database zijn consistent.\n'
