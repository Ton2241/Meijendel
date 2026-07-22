#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
REMOTE_BASE="${REMOTE_BASE:-/srv/vwgm}"
REMOTE_DATA="$REMOTE_BASE/data"
REMOTE_SHINY="$REMOTE_BASE/shiny"
REMOTE_WWW="$REMOTE_BASE/www"
REMOTE_APP="$REMOTE_BASE/vwg-m-linux-app"
STATE_DIR="${MEIJENDEL_DEPLOY_STATE_DIR:-$REMOTE_BASE/deploy-state}"
STATE_FILE="$STATE_DIR/Meijendel.commit"
GLOBAL_LOCK="$STATE_DIR/production.lock"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
SQL_LOCAL="$LOCAL_REPO/meijendel.sql"
SQL_DEPLOY="${TMPDIR:-/tmp}/meijendel_deploy_$$.sql"
APPLY=0
YES=0
ALLOW_FAILING_CURRENT_SMOKE=0
ALLOW_DELETE=0
INITIALIZE_STATE=""
LOCK_HELD=0
LOCAL_COMMIT=""
DEPLOYED_COMMIT=""
SYNC_MODE="dry"
DELETE_COUNT=0

usage() {
  cat <<'USAGE'
Gebruik:
  deploy/deploy_meijendel_vps.sh
  deploy/deploy_meijendel_vps.sh --apply --yes
  deploy/deploy_meijendel_vps.sh --initialize-state COMMIT --yes

Zonder --apply voert het script alleen preflight, manifest, dry-run en huidige
productiecontroles uit. Productie wordt uitsluitend vanaf schone, actuele main gewijzigd.

Opties:
  --apply                         voer de deploy uit
  --yes                           expliciete niet-interactieve bevestiging
  --allow-failing-current-smoke   alleen voor herstel; vereist --apply --yes
  --allow-delete                  sta beoordeelde verwijderingen toe; vereist --apply --yes
  --initialize-state COMMIT       registreer eenmalig de bekende productiecommit
USAGE
}

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { printf 'BLOKKADE: %s\n' "$*" >&2; exit 1; }
need_file() { [[ -f "$1" ]] || die "bestand ontbreekt: $1"; }
need_dir() { [[ -d "$1" ]] || die "map ontbreekt: $1"; }
remote() { ssh -i "$SSH_KEY" "$VPS" "$@"; }

release_lock() {
  if [[ "$LOCK_HELD" -eq 1 ]]; then
    remote "rmdir '$GLOBAL_LOCK' 2>/dev/null || true" || true
    LOCK_HELD=0
  fi
}
cleanup() { rm -f "$SQL_DEPLOY"; release_lock; }
trap cleanup EXIT INT TERM

while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    --allow-failing-current-smoke) ALLOW_FAILING_CURRENT_SMOKE=1 ;;
    --allow-delete) ALLOW_DELETE=1 ;;
    --initialize-state)
      shift
      [[ $# -gt 0 ]] || die "--initialize-state vereist een commit."
      INITIALIZE_STATE="$1"
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Onbekende optie: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ "$ALLOW_FAILING_CURRENT_SMOKE" -eq 0 || ("$APPLY" -eq 1 && "$YES" -eq 1) ]] || \
  die "--allow-failing-current-smoke vereist --apply --yes."
[[ "$ALLOW_DELETE" -eq 0 || ("$APPLY" -eq 1 && "$YES" -eq 1) ]] || \
  die "--allow-delete vereist --apply --yes."
[[ -z "$INITIALIZE_STATE" || "$APPLY" -eq 0 ]] || die "combineer --initialize-state niet met --apply."

cd "$LOCAL_REPO"
log "Controleer Git-baseline"
[[ -z "$(git status --porcelain)" ]] || die "werkboom is niet schoon."
[[ "$(git branch --show-current)" == "main" ]] || die "productiedeploy mag alleen vanaf main."
git fetch origin --prune
LOCAL_COMMIT="$(git rev-parse HEAD)"
[[ "$LOCAL_COMMIT" == "$(git rev-parse origin/main)" ]] || die "lokale main is niet exact gelijk aan origin/main."
printf 'Main-commit: %s\n' "$LOCAL_COMMIT"

acquire_lock() {
  if ! remote "mkdir -p '$STATE_DIR' && mkdir '$GLOBAL_LOCK'"; then
    die "een andere productie-deploy houdt de globale VPS-lock vast: $GLOBAL_LOCK"
  fi
  LOCK_HELD=1
}

write_state() {
  local commit="$1"
  remote "tmp='$STATE_FILE.tmp.\$\$'; printf '%s\\n' '$commit' > \"\$tmp\"; mv \"\$tmp\" '$STATE_FILE'"
}

production_smoke() {
  remote "bash -s" <<'REMOTE'
set -euo pipefail
curl -fsSI http://127.0.0.1:3838/ >/dev/null
for path in /bmp_meijendel_index.html /Meijendel.sql /shiny_meijendel/; do
  code="$(curl -ksS -o /dev/null -w '%{http_code}' --resolve app.vwg-m.nl:443:127.0.0.1 "https://app.vwg-m.nl$path")"
  if [[ "$code" != "401" ]]; then
    echo "FOUT: verwacht 401 voor $path, kreeg $code" >&2
    exit 1
  fi
done
REMOTE
}

if [[ -n "$INITIALIZE_STATE" ]]; then
  [[ "$YES" -eq 1 ]] || die "--initialize-state vereist --yes en expliciete gebruikersbevestiging."
  git cat-file -e "$INITIALIZE_STATE^{commit}" 2>/dev/null || die "onbekende initialisatiecommit: $INITIALIZE_STATE"
  initial_commit="$(git rev-parse "$INITIALIZE_STATE^{commit}")"
  git merge-base --is-ancestor "$initial_commit" "$LOCAL_COMMIT" || die "initialisatiecommit is geen voorouder van main."
  log "Controleer huidige productie vóór initialisatie"
  production_smoke
  acquire_lock
  existing="$(remote "cat '$STATE_FILE' 2>/dev/null || true")"
  [[ -z "$existing" || "$existing" == "$initial_commit" ]] || die "productiestatus bestaat al met andere commit: $existing"
  write_state "$initial_commit"
  log "Productiecommit geïnitialiseerd op $initial_commit; geen productiebestanden gewijzigd"
  exit 0
fi

DEPLOYED_COMMIT="$(remote "cat '$STATE_FILE' 2>/dev/null || true")"
[[ "$DEPLOYED_COMMIT" =~ ^[0-9a-f]{40}$ ]] || \
  die "geldige productiestatus ontbreekt in $STATE_FILE; initialiseer die eerst bewust."
git cat-file -e "$DEPLOYED_COMMIT^{commit}" 2>/dev/null || die "geregistreerde productiecommit is lokaal onbekend: $DEPLOYED_COMMIT"
git merge-base --is-ancestor "$DEPLOYED_COMMIT" "$LOCAL_COMMIT" || \
  die "productiecommit $DEPLOYED_COMMIT is geen voorouder van main $LOCAL_COMMIT."
printf 'Productiecommit: %s\n' "$DEPLOYED_COMMIT"

need_file "$SQL_LOCAL"
need_file "$LOCAL_REPO/R/check_shiny_dashboard_parity.R"
need_file "$LOCAL_REPO/R/check_wintertelling_output.R"
need_file "$LOCAL_REPO/trim_msi_evg/msi_per_groep_per_jaar.csv"
need_file "$LOCAL_REPO/wintertellingen/winter_jaarindex.csv"
need_file "$LOCAL_REPO/wintertellingen/winter_maandpatroon.csv"
need_file "$LOCAL_REPO/wintertellingen/winter_plotgebruik.csv"
need_file "$LOCAL_REPO/wintertellingen/winter_pilot_besluit.csv"
need_file "$LOCAL_REPO/wintertellingen/winter_soortprotocol.csv"

log "Controleer Shiny/dashboard parity voor MSI-groepen"
Rscript "$LOCAL_REPO/R/check_shiny_dashboard_parity.R" \
  "$LOCAL_REPO" "$SQL_LOCAL" "$LOCAL_REPO/trim_msi_evg/msi_per_groep_per_jaar.csv" 1958 2025
log "Controleer wintertellingoutput voor alle soorten"
Rscript "$LOCAL_REPO/R/check_wintertelling_output.R" "$LOCAL_REPO/wintertellingen"
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || \
  die "lokale validatie wijzigde de werkboom; ruim gegenereerde bestanden op of commit bedoelde wijzigingen vóór deploy."

log "Controleer dat tellers uitsluitend id en tellercode bevat"
LC_ALL=C awk '
  /^CREATE TABLE `tellers`/ { in_tellers = 1; seen = 1 }
  in_tellers && /`id` int/ { has_id = 1 }
  in_tellers && /`tellercode` varchar/ { has_code = 1 }
  in_tellers && /`(voornaam|tussenvoegsel|achternaam|straat|huisnummer|postcode|woonplaats|telefoon_vast|telefoon_mobiel|email|soort_lid|bandnummer)`/ { bad = 1 }
  in_tellers && /ENGINE=InnoDB/ { done = 1; exit }
  END { if (!seen || !done || !has_id || !has_code || bad) exit 1 }
' "$SQL_LOCAL" || die "tellers ontbreekt of bevat meer dan id en tellercode."

log "Maak deploydump zonder historische PWA-objecten"
LC_ALL=C awk '
  function sensitive(line) { return line ~ /`pwa_[^`]*`/ }
  function section_start(line) { return line ~ /^-- (Table structure for table|Dumping data for table|Temporary view structure for view|Final view structure for view) / }
  { if (section_start($0)) skip = sensitive($0); if (!skip) print }
' "$SQL_LOCAL" > "$SQL_DEPLOY"

echo "== Release-/afhankelijkheidsmanifest =="
printf '%s\n' \
  "meijendel.sql -> $REMOTE_DATA/Meijendel.sql" \
  "deploy/shiny_image/ -> $REMOTE_SHINY/" \
  "shiny_meijendel/ -> $REMOTE_SHINY/shiny_meijendel/" \
  "R/ -> $REMOTE_SHINY/R/" \
  "bmp_meijendel_index.html -> $REMOTE_WWW/" \
  "index.html -> $REMOTE_WWW/" \
  "output_ecologische_groepen/ -> $REMOTE_WWW/output_ecologische_groepen/" \
  "trim_msi_evg/ -> $REMOTE_WWW/trim_msi_evg/" \
  "groepen_grafieken/ -> $REMOTE_WWW/groepen_grafieken/" \
  "wintertellingen/ -> $REMOTE_WWW/wintertellingen/" \
  "app-home/index.html -> $REMOTE_BASE/app-home/"

rsync_dry=(rsync -az --checksum --delay-updates --itemize-changes --dry-run -e "ssh -i $SSH_KEY")
rsync_apply=(rsync -az --checksum --delay-updates --itemize-changes -e "ssh -i $SSH_KEY")

run_rsync() {
  if [[ "$SYNC_MODE" == "dry" ]]; then
    local output count
    output="$("${rsync_dry[@]}" "$@")"
    printf '%s\n' "$output"
    count="$(printf '%s\n' "$output" | grep -c '^\*deleting ' || true)"
    DELETE_COUNT=$((DELETE_COUNT + count))
  else
    "${rsync_apply[@]}" "$@"
  fi
}

sync_release() {
  local sql_remote="$REMOTE_DATA/Meijendel.sql.next-$LOCAL_COMMIT"
  if [[ "$SYNC_MODE" == "apply" ]]; then
    remote "mkdir -p '$REMOTE_DATA' '$REMOTE_SHINY' '$REMOTE_WWW' '$REMOTE_APP/data' '$REMOTE_BASE/app-home'"
  fi
  run_rsync "$SQL_DEPLOY" "$VPS:$sql_remote"
  if [[ "$SYNC_MODE" == "apply" ]]; then
    remote "mv '$sql_remote' '$REMOTE_DATA/Meijendel.sql' && ln -sfn '$REMOTE_DATA/Meijendel.sql' '$REMOTE_SHINY/Meijendel.sql' && ln -sfn '$REMOTE_DATA/Meijendel.sql' '$REMOTE_WWW/Meijendel.sql' && ln -sfn '$REMOTE_DATA/Meijendel.sql' '$REMOTE_APP/data/Meijendel.sql'"
  fi
  [[ ! -d "$LOCAL_REPO/deploy/shiny_image" ]] || run_rsync "$LOCAL_REPO/deploy/shiny_image/" "$VPS:$REMOTE_SHINY/"
  [[ ! -d "$LOCAL_REPO/shiny_meijendel" ]] || run_rsync --delete-delay --exclude '.DS_Store' --exclude 'rsconnect/' --exclude 'app_cache/' "$LOCAL_REPO/shiny_meijendel/" "$VPS:$REMOTE_SHINY/shiny_meijendel/"
  [[ ! -d "$LOCAL_REPO/R" ]] || run_rsync --delete-delay --exclude '.DS_Store' "$LOCAL_REPO/R/" "$VPS:$REMOTE_SHINY/R/"
  [[ ! -f "$LOCAL_REPO/bmp_meijendel_index.html" ]] || run_rsync "$LOCAL_REPO/bmp_meijendel_index.html" "$VPS:$REMOTE_WWW/bmp_meijendel_index.html"
  [[ ! -f "$LOCAL_REPO/index.html" ]] || run_rsync "$LOCAL_REPO/index.html" "$VPS:$REMOTE_WWW/index.html"
  [[ ! -d "$LOCAL_REPO/output_ecologische_groepen" ]] || run_rsync --delete-delay --exclude '.DS_Store' "$LOCAL_REPO/output_ecologische_groepen/" "$VPS:$REMOTE_WWW/output_ecologische_groepen/"
  [[ ! -d "$LOCAL_REPO/trim_msi_evg" ]] || run_rsync --delete-delay --exclude '.DS_Store' "$LOCAL_REPO/trim_msi_evg/" "$VPS:$REMOTE_WWW/trim_msi_evg/"
  [[ ! -d "$LOCAL_REPO/groepen_grafieken" ]] || run_rsync --delete-delay --exclude '.DS_Store' "$LOCAL_REPO/groepen_grafieken/" "$VPS:$REMOTE_WWW/groepen_grafieken/"
  [[ ! -d "$LOCAL_REPO/wintertellingen" ]] || run_rsync --delete-delay --exclude '.DS_Store' "$LOCAL_REPO/wintertellingen/" "$VPS:$REMOTE_WWW/wintertellingen/"
  [[ ! -f "$LOCAL_REPO/app-home/index.html" ]] || run_rsync "$LOCAL_REPO/app-home/index.html" "$VPS:$REMOTE_BASE/app-home/index.html"
}

log "Rsync dry-run"
SYNC_MODE="dry"
sync_release
if [[ "$DELETE_COUNT" -gt 0 ]]; then
  echo "WAARSCHUWING: dry-run bevat $DELETE_COUNT verwijdering(en)." >&2
  if [[ "$APPLY" -eq 1 && "$ALLOW_DELETE" -ne 1 ]]; then
    die "deploy met verwijderingen vereist na beoordeling ook --allow-delete."
  fi
fi

log "Controleer huidige productie"
if ! production_smoke; then
  [[ "$ALLOW_FAILING_CURRENT_SMOKE" -eq 1 ]] || exit 1
  echo "WAARSCHUWING: huidige productie faalt; expliciete herstelmodus is actief." >&2
fi

log "Controleer productie-MySQL-deployvoorwaarden"
remote "REMOTE_BASE='$REMOTE_BASE' bash -s" <<'REMOTE'
set -euo pipefail
container="meijendel-mysql"
docker ps --format '{{.Names}}' | grep -qx "$container"
command -v gzip >/dev/null
test -d "$REMOTE_BASE/backups"
test -w "$REMOTE_BASE/backups"
docker exec "$container" sh -lc '
  test -n "$MYSQL_ROOT_PASSWORD"
  test -n "$MYSQL_DATABASE"
  mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -NBe "SELECT 1" "$MYSQL_DATABASE" >/dev/null
'
df -Pk "$REMOTE_BASE/backups" | awk 'NR == 2 { if ($4 < 1048576) exit 1 }'
REMOTE

if [[ "$APPLY" -ne 1 ]]; then
  log "Preflight klaar; productie is niet aangepast. Gebruik --apply --yes na beoordeling."
  exit 0
fi
[[ "$YES" -eq 1 ]] || die "een productiedeploy vereist --apply --yes."

acquire_lock
locked_state="$(remote "cat '$STATE_FILE' 2>/dev/null || true")"
[[ "$locked_state" == "$DEPLOYED_COMMIT" ]] || die "productiestatus veranderde tijdens preflight; begin opnieuw."

log "Voer gecontroleerde release-overdracht uit"
SYNC_MODE="apply"
sync_release

log "Maak productie-MySQL-back-up en importeer de canonieke database"
remote "REMOTE_BASE='$REMOTE_BASE' REMOTE_DATA='$REMOTE_DATA' LOCAL_COMMIT='$LOCAL_COMMIT' bash -s" <<'REMOTE'
set -euo pipefail

container="meijendel-mysql"
backup_dir="$REMOTE_BASE/backups/meijendel-mysql"
backup_file="$backup_dir/meijendel_before_${LOCAL_COMMIT}_$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
sql_file="$REMOTE_DATA/Meijendel.sql"

docker ps --format '{{.Names}}' | grep -qx "$container"
test -s "$sql_file"
grep -q -- '-- Dump completed on ' "$sql_file"
grep -q 'CREATE TABLE `pq_vegetatie_pq`' "$sql_file"
grep -q 'CREATE TABLE `pq_vegetatie_import`' "$sql_file"
grep -q '`srtnum`' "$sql_file"
grep -q '`plabed_code`' "$sql_file"
grep -q 'VIEW `website_plot_vegetatie_jaar`' "$sql_file"
mkdir -p "$backup_dir"

docker exec "$container" sh -lc '
  exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" \
    --no-tablespaces --single-transaction --set-gtid-purged=OFF \
    --routines --triggers --events --add-drop-database --databases "$MYSQL_DATABASE"
' | gzip -c > "$backup_file.tmp"
test -s "$backup_file.tmp"
mv "$backup_file.tmp" "$backup_file"
chmod 600 "$backup_file"
echo "Productie-MySQL-back-up: $backup_file"

restore_backup() {
  echo 'MySQL-import of inhoudscontrole faalde; herstel de zojuist gemaakte productieback-up.' >&2
  gzip -dc "$backup_file" | docker exec -i "$container" sh -lc \
    'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
}

if ! docker exec -i "$container" sh -lc \
  'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < "$sql_file"; then
  restore_backup
  exit 1
fi

if ! docker exec "$container" sh -lc '
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
'; then
  restore_backup
  exit 1
fi

docker exec "$container" sh -lc '
  mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -NBe "
    SELECT CONCAT(\"pq=\", COUNT(*)) FROM pq_vegetatie_pq;
    SELECT CONCAT(\"opnamen=\", COUNT(*)) FROM pq_vegetatie_opname;
    SELECT CONCAT(\"taxa=\", COUNT(*)) FROM pq_vegetatie_taxon;
    SELECT CONCAT(\"waarnemingen=\", COUNT(*)) FROM pq_vegetatie_waarneming;
    SELECT CONCAT(\"taxa_met_srtnum=\", COUNT(*)) FROM pq_vegetatie_taxon WHERE srtnum IS NOT NULL;
    SELECT CONCAT(\"plabed_gevuld=\", COUNT(*)) FROM pq_vegetatie_waarneming WHERE plabed_code IS NOT NULL;
    SELECT CONCAT(\"bodemcodes_te_bevestigen=\", COUNT(*)) FROM pq_vegetatie_opname WHERE bodemtype_status = \"te_bevestigen\";
    SELECT CONCAT(\"publieke_plot_jaren=\", COUNT(*)) FROM website_plot_vegetatie_jaar;
  " "$MYSQL_DATABASE"
'
REMOTE

log "Herstart Shiny en wacht op gereedheid"
remote "REMOTE_SHINY='$REMOTE_SHINY' bash -s" <<'REMOTE'
set -euo pipefail
mkdir -p "$REMOTE_SHINY/shiny_meijendel/app_cache/sass"
docker run --rm -v "$REMOTE_SHINY/shiny_meijendel/app_cache:/app_cache" vwgm-shiny:latest chown -R shiny:shiny /app_cache
cd "$REMOTE_SHINY"
if ! grep -q '/app_cache:rw' docker-compose.yml; then
  perl -0pi -e 's#(      - /srv/vwgm/shiny/shiny_meijendel:/srv/shiny-server/shiny_meijendel:ro\n)#$1      - /srv/vwgm/shiny/shiny_meijendel/app_cache:/srv/shiny-server/shiny_meijendel/app_cache:rw\n#' docker-compose.yml
fi
docker compose up -d --force-recreate shiny >/dev/null
for attempt in $(seq 1 30); do
  if curl -fsSI http://127.0.0.1:3838/ >/dev/null; then
    echo "Shiny gereed na poging $attempt"
    exit 0
  fi
  sleep 2
done
docker ps --filter name=shiny_meijendel
docker logs --tail 120 shiny_meijendel >&2
exit 1
REMOTE

log "Controleer analysepackages, cache, checksums en containers"
remote "REMOTE_BASE='$REMOTE_BASE' REMOTE_DATA='$REMOTE_DATA' REMOTE_SHINY='$REMOTE_SHINY' REMOTE_WWW='$REMOTE_WWW' REMOTE_APP='$REMOTE_APP' bash -s" <<'REMOTE'
set -euo pipefail
docker exec shiny_meijendel Rscript -e '
  pkgs <- c("geepack", "glmmTMB", "vegan", "pls", "changepoint", "strucchange", "lavaan", "piecewiseSEM", "indicspecies", "betapart", "unmarked")
  ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  print(data.frame(package = pkgs, beschikbaar = unname(ok)))
  if (!all(ok)) stop("Niet alle analysepackages zijn beschikbaar.")
  if (!nzchar(Sys.which("perl"))) stop("Perl ontbreekt in de Shiny-container.")
'
docker exec -u shiny shiny_meijendel sh -lc 'cd /srv/shiny-server/shiny_meijendel && Rscript -e "source(\"helpers.R\"); path <- resolve_meijendel_sql_path(); stopifnot(identical(path, \"/srv/shiny-server/Meijendel.sql\")); t <- system.time(x <- load_meijendel_tables_cached(path)); cat(sprintf(\"SQL pad: %s; cache: from_cache=%s elapsed=%.3f cache=%s\\n\", path, x[[\"from_cache\"]], unname(t[[\"elapsed\"]]), x[[\"cache_path\"]]))"'
sha256sum "$REMOTE_DATA/Meijendel.sql" "$REMOTE_SHINY/Meijendel.sql" "$REMOTE_WWW/Meijendel.sql" "$REMOTE_APP/data/Meijendel.sql"
test -s "$REMOTE_WWW/wintertellingen/winter_jaarindex.csv"
test -s "$REMOTE_WWW/wintertellingen/winter_maandpatroon.csv"
test -s "$REMOTE_WWW/wintertellingen/winter_plotgebruik.csv"
test -s "$REMOTE_WWW/wintertellingen/winter_pilot_besluit.csv"
test -s "$REMOTE_WWW/wintertellingen/winter_soortprotocol.csv"
docker stats --no-stream shiny_meijendel
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
REMOTE

log "Volledige productiecontrole na deploy"
production_smoke
write_state "$LOCAL_COMMIT"
log "Productiecommit geregistreerd: $LOCAL_COMMIT"
log "Deploy afgerond"
