#!/usr/bin/env bash
set -euo pipefail

STAGES=(preflight apply)
stage="${1:-}"
release_commit="${2:-}"

REMOTE_BASE="/srv/vwgm"
REMOTE_DATA="$REMOTE_BASE/data"
REMOTE_SHINY="$REMOTE_BASE/shiny"
REMOTE_WWW="$REMOTE_BASE/www"
REMOTE_APP="$REMOTE_BASE/vwg-m-linux-app"
STATE_DIR="$REMOTE_BASE/deploy-state"
CANDIDATE_FILE="$STATE_DIR/Meijendel.candidate"
CONTAINER="meijendel-mysql"
SHINY_CONTAINER="shiny_meijendel"
SQL_FILE="$REMOTE_DATA/Meijendel.sql"
BACKUP_DIR="$REMOTE_BASE/backups/meijendel-mysql"
success=0
import_started=0
backup_file=""

die() {
  printf 'BLOKKADE|meijendel-release|%s\n' "$*" >&2
  exit 1
}

[[ " ${STAGES[*]} " == *" $stage "* ]] || die "onbekende fase"
[[ "$release_commit" =~ ^[0-9a-f]{40}$ ]] || die "commit vereist exact 40 hextekens"

restore_backup() {
  [[ -s "$backup_file" ]] || return 1
  printf 'ROLLBACK|meijendel-release|database=%s\n' "$backup_file" >&2
  gzip -dc "$backup_file" | docker exec -i "$CONTAINER" sh -lc \
    'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
}

restart_shiny() {
  mkdir -p "$REMOTE_SHINY/shiny_meijendel/app_cache/sass"
  docker run --rm -v "$REMOTE_SHINY/shiny_meijendel/app_cache:/app_cache" \
    vwgm-shiny:latest chown -R shiny:shiny /app_cache
  cd "$REMOTE_SHINY"
  if ! grep -q '/app_cache:rw' docker-compose.yml; then
    perl -0pi -e 's#(      - /srv/vwgm/shiny/shiny_meijendel:/srv/shiny-server/shiny_meijendel:ro\n)#$1      - /srv/vwgm/shiny/shiny_meijendel/app_cache:/srv/shiny-server/shiny_meijendel/app_cache:rw\n#' docker-compose.yml
  fi
  docker compose up -d --force-recreate shiny >/dev/null
  for attempt in $(seq 1 30); do
    if curl -fsSI http://127.0.0.1:3838/ >/dev/null; then
      printf 'SHINY_STATUS=ready\n'
      return 0
    fi
    sleep 2
  done
  docker logs --tail 120 "$SHINY_CONTAINER" >&2 || true
  return 1
}

finish() {
  status=$?
  trap - EXIT INT TERM
  if [[ "$success" -ne 1 && "$import_started" -eq 1 ]]; then
    if restore_backup; then
      restart_shiny || true
    else
      printf 'URGENT|meijendel-release|automatische databaserollback mislukt\n' >&2
    fi
  fi
  exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

docker inspect --format '{{.State.Status}}' "$CONTAINER" | grep -qx running || \
  die "MySQL-container draait niet"
docker inspect --format '{{.State.Status}}' "$SHINY_CONTAINER" | grep -qx running || \
  die "Shiny-container draait niet"
mysql_version="$(docker exec "$CONTAINER" sh -lc \
  'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -NBe "SELECT VERSION()"')"
printf 'MYSQL_VERSION=%s\n' "$mysql_version"
[[ "$mysql_version" == "9.7.1" ]] || die "MySQL-versie is $mysql_version; vereist 9.7.1"
test -d "$BACKUP_DIR" && test -w "$BACKUP_DIR" || die "back-upmap ontbreekt of is niet schrijfbaar"
df -Pk "$BACKUP_DIR" | awk 'NR == 2 { if ($4 < 1048576) exit 1 }' || \
  die "minder dan 1 GiB vrije back-upruimte"

if [[ "$stage" == "preflight" ]]; then
  success=1
  printf 'PREFLIGHT_STATUS=ready\n'
  exit 0
fi

[[ -f "$CANDIDATE_FILE" ]] || die "kandidaatmarker ontbreekt"
[[ ! -L "$CANDIDATE_FILE" ]] || die "kandidaatmarker mag geen symlink zijn"
[[ "$(stat -c '%U:%a' "$CANDIDATE_FILE")" == "ton:600" ]] || \
  die "kandidaatmarker heeft niet eigenaar ton en modus 600"
[[ "$(tr -d '\r\n' < "$CANDIDATE_FILE")" == "$release_commit" ]] || \
  die "kandidaatmarker wijkt af van releasecommit"
for required in \
  "$SQL_FILE" \
  "$REMOTE_WWW/trim/soorten/soorten_trendoverzicht.csv" \
  "$REMOTE_WWW/trim/sandra/soorten/soorten_trendoverzicht.csv" \
  "$REMOTE_WWW/trim_msi_evg/trendoverzicht_msi_groepen.csv"; do
  test -s "$required" || die "releasebestand ontbreekt of is leeg: $required"
done
grep -q -- '-- Dump completed on ' "$SQL_FILE" || die "SQL-dump mist eindmarkering"
grep -q 'CREATE TABLE `pq_vegetatie_pq`' "$SQL_FILE" || die "SQL-dump mist PQ-tabel"
grep -q 'VIEW `website_plot_vegetatie_jaar`' "$SQL_FILE" || die "SQL-dump mist publieke PQ-view"

backup_file="$BACKUP_DIR/meijendel_before_${release_commit}_$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
docker exec "$CONTAINER" sh -lc '
  exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" \
    --no-tablespaces --single-transaction --set-gtid-purged=OFF \
    --routines --triggers --events --add-drop-database --databases "$MYSQL_DATABASE"
' | gzip -c > "$backup_file.tmp"
test -s "$backup_file.tmp" || die "databaseback-up is leeg"
mv "$backup_file.tmp" "$backup_file"
chmod 600 "$backup_file"
printf 'DATABASE_BACKUP=%s\n' "$backup_file"

import_started=1
docker exec -i "$CONTAINER" sh -lc \
  'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < "$SQL_FILE"

docker exec "$CONTAINER" sh -lc '
  set -eu
  query() { mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -NBe "$1" "$MYSQL_DATABASE"; }
  test "$(query "SELECT COUNT(*) FROM pq_vegetatie_pq")" -eq 254
  test "$(query "SELECT COUNT(*) FROM pq_vegetatie_opname")" -eq 2007
  test "$(query "SELECT COUNT(*) FROM pq_vegetatie_taxon")" -eq 714
  test "$(query "SELECT COUNT(*) FROM pq_vegetatie_waarneming")" -eq 53122
  test "$(query "SELECT COUNT(*) FROM pq_vegetatie_opname_plot")" -eq 1336
  test "$(query "SELECT COUNT(*) FROM pq_plot_jaar_vegetatie")" -eq 513
  test "$(query "SELECT COUNT(*) FROM website_plot_vegetatie_jaar")" -eq 513
  test "$(query "SELECT COUNT(*) FROM pq_vegetatie_import WHERE importstatus = \"voorlopig\"")" -eq 1
  test "$(query "SELECT COUNT(*) FROM pq_vegetatie_taxon WHERE srtnum IS NULL OR taxonlijst_versie = \"\"")" -eq 0
  test "$(query "SELECT COUNT(*) FROM pq_vegetatie_waarneming WHERE plabed_code IS NULL")" -eq 0
  test "$(query "SELECT COUNT(*) FROM (SELECT taxonlijst_versie, srtnum FROM pq_vegetatie_taxon GROUP BY taxonlijst_versie, srtnum HAVING COUNT(*) > 1) d")" -eq 0
  test "$(query "SELECT COUNT(*) FROM pq_vegetatie_opname WHERE bodemtype_status = \"te_bevestigen\"")" -eq 34
  test "$(query "SELECT COUNT(*) FROM website_plot_vegetatie_jaar WHERE bronstatus <> \"voorlopig\" OR taxonlijst_versie = \"\"")" -eq 0
  test "$(query "SELECT COUNT(*) FROM pq_plot_jaar_vegetatie_berekend")" -eq 513
  test "$(query "SELECT COUNT(*) FROM pq_plot_jaar_vegetatie_berekend b JOIN pq_plot_jaar_vegetatie p USING (plot_id, jaar) WHERE ABS(b.soortenrijkdom_gem - p.soortenrijkdom_gem) > 0.0005 OR ABS(b.bedekking_som_gem - p.bedekking_som_gem) > 0.0005 OR ABS(b.shannon_gem - p.shannon_gem) > 0.00011")" -eq 0
  test "$(query "SELECT COUNT(*) FROM pq_vegetatie_opname WHERE ST_SRID(geom) <> 28992 OR YEAR(opname_datum) <> jaar")" -eq 0
  while IFS= read -r table_name; do
    result="$(mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -NBe "CHECK TABLE \`$table_name\` EXTENDED" "$MYSQL_DATABASE")"
    printf "%s\n" "$result" | tail -n 1 | grep -Eq "status[[:space:]]+OK$"
  done <<EOF
$(query "SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = \"BASE TABLE\" ORDER BY TABLE_NAME")
EOF
'

restart_shiny
docker exec "$SHINY_CONTAINER" Rscript -e '
  pkgs <- c("geepack", "glmmTMB", "vegan", "pls", "changepoint", "strucchange", "lavaan", "piecewiseSEM", "indicspecies", "betapart", "unmarked")
  ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  if (!all(ok)) stop("Niet alle analysepackages zijn beschikbaar.")
  if (!nzchar(Sys.which("perl"))) stop("Perl ontbreekt in de Shiny-container.")
'
docker exec -u shiny "$SHINY_CONTAINER" sh -lc \
  'cd /srv/shiny-server/shiny_meijendel && Rscript -e "source(\"helpers.R\"); path <- resolve_meijendel_sql_path(); stopifnot(identical(path, \"/srv/shiny-server/Meijendel.sql\")); x <- load_meijendel_tables_cached(path); cat(sprintf(\"SQL_CACHE=%s\\n\", x[[\"from_cache\"]]))"'
sha256sum "$REMOTE_DATA/Meijendel.sql" "$REMOTE_SHINY/Meijendel.sql" \
  "$REMOTE_WWW/Meijendel.sql" "$REMOTE_APP/data/Meijendel.sql"
docker stats --no-stream "$SHINY_CONTAINER"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

success=1
printf 'RELEASE_STATUS=ready\n'
