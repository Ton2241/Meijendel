#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SQL_FILE="$REPO_DIR/meijendel.sql"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_DATABASE="${MYSQL_DATABASE:-meijendel}"
WINTER_MYSQL_DATABASE="${MEIJENDEL_MYSQL_DATABASE:-Meijendel}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

need_file() {
  [ -f "$1" ] || {
    printf 'FOUT: bestand ontbreekt: %s\n' "$1" >&2
    exit 1
  }
}

need_dir() {
  [ -d "$1" ] || {
    printf 'FOUT: map ontbreekt: %s\n' "$1" >&2
    exit 1
  }
}

need_dir "$REPO_DIR/R"
need_dir "$REPO_DIR/deploy"
need_file "$REPO_DIR/deploy/deploy_meijendel_vps.sh"

cd "$REPO_DIR"

log "Maak actuele lokale database-dump: $SQL_FILE"
mysqldump --no-defaults \
  --no-tablespaces \
  --complete-insert \
  --single-transaction \
  --set-gtid-purged=OFF \
  --protocol=tcp \
  --host="$MYSQL_HOST" \
  --port="$MYSQL_PORT" \
  -u"$MYSQL_USER" -p \
  --routines \
  --triggers \
  --events \
  --ignore-table="$MYSQL_DATABASE.tellers" \
  "$MYSQL_DATABASE" > "$SQL_FILE"

log "Genereer dashboard-output: output_ecologische_groepen"
Rscript "$REPO_DIR/R/analyse_ecologische_groepen.R" \
  "$SQL_FILE" \
  "$REPO_DIR/output_ecologische_groepen"

log "Genereer TRIM-soorten en TRIM-MSI-output"
Rscript "$REPO_DIR/R/trim_soorten_en_msi_evg.R" \
  "$SQL_FILE" \
  "$REPO_DIR/trim/soorten" \
  "$REPO_DIR/trim_msi_evg"

log "Genereer landelijke MSI-output"
Rscript "$REPO_DIR/R/landelijke_msi_evg.R" \
  "$SQL_FILE" \
  "$REPO_DIR/trim_msi_evg"

log "Genereer dashboardgelijke Groepen-grafieken"
Rscript "$REPO_DIR/R/build_groepen_grafieken_dashboard_csv.R" \
  "$SQL_FILE" \
  "$REPO_DIR/groepen_grafieken"

log "Genereer gevalideerde wintertellingpilot"
Rscript "$REPO_DIR/R/analyse_wintertellingen_pilot.R" \
  "$REPO_DIR/wintertellingen" \
  "${MEIJENDEL_MYSQL_LOGIN_PATH:-meijendel_root}" \
  "$WINTER_MYSQL_DATABASE"
Rscript "$REPO_DIR/R/check_wintertelling_output.R" \
  "$REPO_DIR/wintertellingen"

log "Controleer dashboard/website parity voor Groepen-grafieken"
Rscript "$REPO_DIR/R/check_dashboard_website_parity.R" \
  "$REPO_DIR" \
  "$REPO_DIR/groepen_grafieken"

log "Controleer Shiny/dashboard parity voor MSI-groepen"
Rscript "$REPO_DIR/R/check_shiny_dashboard_parity.R" \
  "$REPO_DIR" \
  "$SQL_FILE" \
  "$REPO_DIR/trim_msi_evg/msi_per_groep_per_jaar.csv" \
  1958 \
  2025

log "Synchroniseer gedeelde Shiny-selectie-CSV"
need_file "$REPO_DIR/R/evg_selctie_T0soort_T0msi.csv"
need_dir "$REPO_DIR/shiny_meijendel"
cp -p "$REPO_DIR/R/evg_selctie_T0soort_T0msi.csv" \
  "$REPO_DIR/shiny_meijendel/evg_selctie_T0soort_T0msi.csv"

log "Generatie en controles zijn klaar. Commit en push de gewijzigde output, merge naar main en voer daarna vanaf schone main uit:"
log "  deploy/deploy_meijendel_vps.sh"
log "  deploy/deploy_meijendel_vps.sh --apply --yes"
