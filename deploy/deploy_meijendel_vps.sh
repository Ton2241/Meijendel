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
GATEWAY="/usr/local/sbin/vwgm-admin"
CANDIDATE_FILE="$STATE_DIR/Meijendel.candidate"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
GATEWAY_RUNNER="${MEIJENDEL_GATEWAY_RUNNER:-$SCRIPT_DIR/run_gateway_job_vps.sh}"
EXPORT_VALIDATOR="${MEIJENDEL_EXPORT_VALIDATOR:-$LOCAL_REPO/scripts/validate_meijendel_export.sh}"
RSYNC_BIN="${MEIJENDEL_RSYNC_BIN:-$(command -v rsync 2>/dev/null || true)}"
SSH_BIN="${MEIJENDEL_SSH_BIN:-$(command -v ssh 2>/dev/null || true)}"
SQL_LOCAL="$LOCAL_REPO/meijendel.sql"
SQL_MANIFEST_LOCAL="$LOCAL_REPO/meijendel.sql.manifest"
SOURCES_SQL_LOCAL="$LOCAL_REPO/meijendel_bronnen.sql"
SQL_DEPLOY="${TMPDIR:-/tmp}/meijendel_deploy_$$.sql"
SOURCES_SQL_DEPLOY="${TMPDIR:-/tmp}/meijendel_bronnen_deploy_$$.sql"
SOURCES_MANIFEST_DEPLOY="${TMPDIR:-/tmp}/meijendel_bronnen_deploy_$$.manifest"
CACHE_FILE=""
CACHE_MANIFEST=""
CACHE_LOCAL=""
CACHE_MANIFEST_LOCAL=""
SQL_CANDIDATE_FILE=""
SQL_MANIFEST_CANDIDATE_FILE=""
CACHE_CANDIDATE_FILE=""
CACHE_MANIFEST_CANDIDATE_FILE=""
SOURCES_SQL_CANDIDATE_FILE=""
SOURCES_MANIFEST_CANDIDATE_FILE=""

if [[ -d /usr/local/mysql/bin ]]; then
  PATH="/usr/local/mysql/bin:$PATH"
fi

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
CANDIDATE_STAGED=0

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
remote() { "$SSH_BIN" -i "$SSH_KEY" "$VPS" "$@"; }

release_lock() {
  if [[ "$LOCK_HELD" -eq 1 ]]; then
    remote "rmdir '$GLOBAL_LOCK' 2>/dev/null || true" || true
    LOCK_HELD=0
  fi
}
cleanup() {
  rm -f "$SQL_DEPLOY" "$SOURCES_SQL_DEPLOY" "$SOURCES_MANIFEST_DEPLOY"
  if [[ "$CANDIDATE_STAGED" -eq 1 ]]; then
    remote "rm -f '$CANDIDATE_FILE' '$SOURCES_SQL_CANDIDATE_FILE' '$SOURCES_MANIFEST_CANDIDATE_FILE'" || true
  fi
  release_lock
}
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
[[ -x "$EXPORT_VALIDATOR" ]] || die "exportvalidator is geen bestaand uitvoerbaar bestand: $EXPORT_VALIDATOR"
[[ -x "$RSYNC_BIN" ]] || die "rsync is geen bestaand uitvoerbaar bestand: $RSYNC_BIN"
[[ -x "$SSH_BIN" ]] || die "SSH-client is geen bestaand uitvoerbaar bestand: $SSH_BIN"
"$LOCAL_REPO/scripts/check_local_workspace.sh"
"$LOCAL_REPO/scripts/check_mysql_version.sh"
REQUIRED_MYSQL_VERSION="$("$LOCAL_REPO/scripts/check_mysql_version.sh" --required-version)"
need_file "$SQL_LOCAL"
need_file "$SQL_MANIFEST_LOCAL"
need_file "$SOURCES_SQL_LOCAL"
log "Controleer Git-baseline"
[[ -z "$(git status --porcelain)" ]] || die "werkboom is niet schoon."
[[ "$(git branch --show-current)" == "main" ]] || die "productiedeploy mag alleen vanaf main."
git fetch origin --prune
LOCAL_COMMIT="$(git rev-parse HEAD)"
[[ "$LOCAL_COMMIT" == "$(git rev-parse origin/main)" ]] || die "lokale main is niet exact gelijk aan origin/main."
printf 'Main-commit: %s\n' "$LOCAL_COMMIT"

log "Controleer dump, exportmanifest, cache en levende database"
"$EXPORT_VALIDATOR" "$SQL_LOCAL" "$SQL_MANIFEST_LOCAL"
cache_validation="$("$EXPORT_VALIDATOR" --with-cache \
  "$SQL_LOCAL" "$SQL_MANIFEST_LOCAL" "$LOCAL_REPO")"
printf '%s\n' "$cache_validation"
grep -Fqx 'CACHE_STATUS=ready' <<<"$cache_validation" || die "gekoppelde Shiny-cache is niet gereed."
CACHE_FILE="$(sed -n 's/^CACHE_FILE=//p' <<<"$cache_validation")"
CACHE_MANIFEST="$(sed -n 's/^CACHE_MANIFEST=//p' <<<"$cache_validation")"
[[ "$CACHE_FILE" =~ ^meijendel_tables_cache-p[1-9][0-9]*-[0-9a-f]{64}\.rds$ && "$CACHE_FILE" != */* ]] || \
  die "validator gaf geen veilige cachebasename."
[[ "$CACHE_MANIFEST" == "${CACHE_FILE%.rds}.manifest" ]] || \
  die "validator gaf geen passend cachemanifest."
CACHE_LOCAL="$LOCAL_REPO/$CACHE_FILE"
CACHE_MANIFEST_LOCAL="$LOCAL_REPO/$CACHE_MANIFEST"
need_file "$CACHE_LOCAL"
need_file "$CACHE_MANIFEST_LOCAL"
SQL_CANDIDATE_FILE="$REMOTE_DATA/Meijendel.sql.candidate-$LOCAL_COMMIT"
SQL_MANIFEST_CANDIDATE_FILE="$REMOTE_DATA/Meijendel.sql.manifest.candidate-$LOCAL_COMMIT"
CACHE_CANDIDATE_FILE="$STATE_DIR/${CACHE_FILE}.candidate-$LOCAL_COMMIT"
CACHE_MANIFEST_CANDIDATE_FILE="$STATE_DIR/${CACHE_MANIFEST}.candidate-$LOCAL_COMMIT"
SOURCES_SQL_CANDIDATE_FILE="$REMOTE_DATA/Meijendel_bronnen.sql.candidate-$LOCAL_COMMIT"
SOURCES_MANIFEST_CANDIDATE_FILE="$REMOTE_DATA/Meijendel_bronnen.sql.manifest.candidate-$LOCAL_COMMIT"

log "Controleer gesloten Meijendel-beheerroute en VPS-MySQL"
need_file "$GATEWAY_RUNNER"
[[ -x "$GATEWAY_RUNNER" ]] || die "gatewayrunner is niet uitvoerbaar: $GATEWAY_RUNNER"
export VPS SSH_KEY GATEWAY SSH_BIN
set +e
gateway_preflight="$("$GATEWAY_RUNNER" preflight "$LOCAL_COMMIT")"
gateway_preflight_rc=$?
set -e
printf '%s\n' "$gateway_preflight"
[[ "$gateway_preflight_rc" -eq 0 ]] || die "gesloten Meijendel-preflight op de VPS faalde."
REMOTE_MYSQL_VERSION="$(sed -n 's/^MYSQL_VERSION=//p' <<<"$gateway_preflight" | tail -n 1)"
[[ "$REMOTE_MYSQL_VERSION" == "$REQUIRED_MYSQL_VERSION" ]] || \
  die "MySQL op de VPS is $REMOTE_MYSQL_VERSION; vereist is exact $REQUIRED_MYSQL_VERSION."
grep -Fqx 'PREFLIGHT_STATUS=ready' <<<"$gateway_preflight" || \
  die "gesloten Meijendel-preflight gaf geen gereedstatus."

SQL_BYTES="$(awk -F= '$1 == "sql_bytes" {print $2}' "$SQL_MANIFEST_LOCAL")"
[[ "$SQL_BYTES" =~ ^[0-9]+$ ]] || die "exportmanifest bevat geen geldige SQL-bestandsgrootte."
CACHE_BYTES="$(awk -F= '$1 == "cache_bytes" {print $2}' "$CACHE_MANIFEST_LOCAL")"
[[ "$CACHE_BYTES" =~ ^[0-9]+$ && "$CACHE_BYTES" -gt 0 ]] || die "cachemanifest bevat geen geldige cachebestandsgrootte."
SOURCES_SQL_BYTES="$(stat -f '%z' "$SOURCES_SQL_LOCAL")"
[[ "$SOURCES_SQL_BYTES" =~ ^[0-9]+$ && "$SOURCES_SQL_BYTES" -gt 0 ]] || die "bron-dump heeft geen geldige bestandsgrootte."
REQUIRED_FREE_KB=$(( (SQL_BYTES * 4 + CACHE_BYTES * 2 + SOURCES_SQL_BYTES * 4 + 1023) / 1024 + 5 * 1024 * 1024 ))
REMOTE_FREE_KB="$(remote "df -Pk '$REMOTE_BASE' | awk 'NR == 2 {print \$4}'")"
[[ "$REMOTE_FREE_KB" =~ ^[0-9]+$ ]] || die "vrije VPS-schijfruimte kon niet worden bepaald."
[[ "$REMOTE_FREE_KB" -ge "$REQUIRED_FREE_KB" ]] || \
  die "VPS heeft ${REMOTE_FREE_KB} KiB vrij; minimaal ${REQUIRED_FREE_KB} KiB is vereist voor dump, database, back-up en marge."
printf 'VPS_FREE_KB=%s\nREQUIRED_FREE_KB=%s\n' "$REMOTE_FREE_KB" "$REQUIRED_FREE_KB"

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
for path in /bmp_meijendel_index.html /Meijendel.sql /shiny_meijendel/ /trim/soorten/soorten_trendoverzicht.csv; do
  code="$(curl -ksS -o /dev/null -w '%{http_code}' --resolve www.vwg-m.nl:443:127.0.0.1 "https://www.vwg-m.nl$path")"
  if [[ "$code" != "401" ]]; then
    echo "FOUT: verwacht 401 voor https://www.vwg-m.nl$path, kreeg $code" >&2
    exit 1
  fi
  legacy_code="$(curl -ksS -o /dev/null -w '%{http_code}' --resolve app.vwg-m.nl:443:127.0.0.1 "https://app.vwg-m.nl$path")"
  legacy_location="$(curl -ksSI --resolve app.vwg-m.nl:443:127.0.0.1 "https://app.vwg-m.nl$path" | awk 'tolower($1) == "location:" { sub(/\r$/, "", $2); print $2; exit }')"
  if [[ "$legacy_code" != "308" || "$legacy_location" != "https://www.vwg-m.nl$path" ]]; then
    echo "FOUT: verwacht 308 van app naar https://www.vwg-m.nl$path; kreeg code=$legacy_code location=$legacy_location" >&2
    exit 1
  fi
done
sources_code="$(curl -ksS -o /dev/null -w '%{http_code}' --resolve www.vwg-m.nl:443:127.0.0.1 'https://www.vwg-m.nl/Meijendel_bronnen.sql')"
[[ "$sources_code" == "403" || "$sources_code" == "404" ]] || {
  echo "FOUT: verwacht 403 of 404 voor de afgeschermde bron-dump, kreeg $sources_code" >&2
  exit 1
}
REMOTE
}

canonical_data_smoke() {
  remote "bash -s" <<'REMOTE'
set -euo pipefail
body="$(curl -ksS --resolve www.vwg-m.nl:443:127.0.0.1 https://www.vwg-m.nl/soorten/index.asp)"
grep -Fq '<strong>153</strong>' <<<"$body"
for species_id in 3 23 117 199; do
  grep -Fq "href=\"/soorten/vogel.asp?id=$species_id\"" <<<"$body"
done
printf 'CANONICAL_SPECIES_STATUS=ready\n'
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

need_file "$LOCAL_REPO/deploy/check_weer_contract.sh"
need_file "$LOCAL_REPO/R/check_shiny_dashboard_parity.R"
need_file "$LOCAL_REPO/R/check_wintertelling_output.R"
need_file "$LOCAL_REPO/trim/soorten/soorten_modelstatus.csv"
need_file "$LOCAL_REPO/trim/soorten/soortindices_per_jaar.csv"
need_file "$LOCAL_REPO/trim/soorten/soorten_trendoverzicht.csv"
need_file "$LOCAL_REPO/trim/soorten/soorten_brugfactoren.csv"
need_file "$LOCAL_REPO/trim/sandra/soorten/soorten_modelstatus.csv"
need_file "$LOCAL_REPO/trim/sandra/soorten/soortindices_per_jaar.csv"
need_file "$LOCAL_REPO/trim/sandra/soorten/soorten_trendoverzicht.csv"
need_file "$LOCAL_REPO/trim/sandra/trim_msi_evg/trendoverzicht_msi_groepen.csv"
need_file "$LOCAL_REPO/trim_msi_evg/msi_per_groep_per_jaar.csv"
need_file "$LOCAL_REPO/trim_msi_evg/trendoverzicht_msi_groepen.csv"
need_file "$LOCAL_REPO/trim_msi_evg/functionele_trendoverzicht_msi_groepen.csv"
need_file "$LOCAL_REPO/wintertellingen/winter_jaarindex.csv"
need_file "$LOCAL_REPO/wintertellingen/winter_maandpatroon.csv"
need_file "$LOCAL_REPO/wintertellingen/winter_plotgebruik.csv"
need_file "$LOCAL_REPO/wintertellingen/winter_pilot_besluit.csv"
need_file "$LOCAL_REPO/wintertellingen/winter_soortprotocol.csv"

log "Controleer weerdata-eenhedencontract"
"$LOCAL_REPO/deploy/check_weer_contract.sh" "$SQL_LOCAL"

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

log "Maak byte-identieke tijdelijke deploykopie"
cp -p "$SQL_LOCAL" "$SQL_DEPLOY"
"$EXPORT_VALIDATOR" --artifact-only \
  "$SQL_DEPLOY" "$SQL_MANIFEST_LOCAL"

log "Controleer en kopieer afzonderlijke bron-dump"
for required in \
  'CREATE TABLE `bron`' \
  'CREATE TABLE `literatuur`' \
  'VIEW `v_bron_catalogus`' \
  'VIEW `v_literatuur_overzicht`' \
  'VIEW `v_contextdataset_overzicht`'; do
  grep -qF "$required" "$SOURCES_SQL_LOCAL" || die "bron-dump mist vereist object: $required"
done
cp -p "$SOURCES_SQL_LOCAL" "$SOURCES_SQL_DEPLOY"
sources_sha256="$(shasum -a 256 "$SOURCES_SQL_DEPLOY" | awk '{print $1}')"
sources_bytes="$(stat -f '%z' "$SOURCES_SQL_DEPLOY")"
printf 'format=meijendel-bronnen-manifest-v1\nsql_sha256=%s\nsql_bytes=%s\n' \
  "$sources_sha256" "$sources_bytes" > "$SOURCES_MANIFEST_DEPLOY"

echo "== Release-/afhankelijkheidsmanifest =="
printf '%s\n' \
  "meijendel.sql -> $REMOTE_DATA/Meijendel.sql" \
  "meijendel.sql.manifest -> $REMOTE_DATA/Meijendel.sql.manifest" \
  'Meijendel_bronnen.sql -> $REMOTE_DATA/Meijendel_bronnen.sql' \
  "$CACHE_FILE -> $REMOTE_SHINY/shiny_meijendel/app_cache/$CACHE_FILE" \
  "$CACHE_MANIFEST -> $REMOTE_SHINY/shiny_meijendel/app_cache/meijendel_tables_cache.active.manifest" \
  "MEIJENDEL_REQUIRE_PREBUILT_CACHE=1 -> Shiny Compose" \
  "SQL_CACHE=TRUE -> verplichte runtimecontrole" \
  "deploy/shiny_image/ -> $REMOTE_SHINY/" \
  "shiny_meijendel/ -> $REMOTE_SHINY/shiny_meijendel/" \
  "R/ -> $REMOTE_SHINY/R/" \
  "bmp_meijendel_index.html -> $REMOTE_WWW/" \
  "index.html -> $REMOTE_WWW/" \
  "output_ecologische_groepen/ -> $REMOTE_WWW/output_ecologische_groepen/" \
  "trim/soorten/ -> $REMOTE_WWW/trim/soorten/" \
  "trim/sandra/ -> $REMOTE_WWW/trim/sandra/" \
  "trim_msi_evg/ -> $REMOTE_WWW/trim_msi_evg/" \
  "groepen_grafieken/ -> $REMOTE_WWW/groepen_grafieken/" \
  "wintertellingen/ -> $REMOTE_WWW/wintertellingen/" \
  "app-home/index.html -> $REMOTE_BASE/app-home/"

rsync_dry=("$RSYNC_BIN" -az --checksum --delay-updates --itemize-changes --dry-run -e "$SSH_BIN -i $SSH_KEY")
rsync_apply=("$RSYNC_BIN" -az --checksum --delay-updates --itemize-changes -e "$SSH_BIN -i $SSH_KEY")

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
  if [[ "$SYNC_MODE" == "apply" ]]; then
    remote "mkdir -p '$REMOTE_DATA' '$REMOTE_SHINY' '$REMOTE_WWW' '$REMOTE_APP/data' '$REMOTE_BASE/app-home'"
  fi
  run_rsync "$SQL_DEPLOY" "$VPS:$SQL_CANDIDATE_FILE"
  run_rsync "$SQL_MANIFEST_LOCAL" "$VPS:$SQL_MANIFEST_CANDIDATE_FILE"
  run_rsync "$CACHE_LOCAL" "$VPS:$CACHE_CANDIDATE_FILE"
  run_rsync "$CACHE_MANIFEST_LOCAL" "$VPS:$CACHE_MANIFEST_CANDIDATE_FILE"
  run_rsync "$SOURCES_SQL_DEPLOY" "$VPS:$SOURCES_SQL_CANDIDATE_FILE"
  run_rsync "$SOURCES_MANIFEST_DEPLOY" "$VPS:$SOURCES_MANIFEST_CANDIDATE_FILE"
  [[ ! -d "$LOCAL_REPO/deploy/shiny_image" ]] || run_rsync "$LOCAL_REPO/deploy/shiny_image/" "$VPS:$REMOTE_SHINY/"
  [[ ! -d "$LOCAL_REPO/shiny_meijendel" ]] || run_rsync --delete-delay --exclude '.DS_Store' --exclude 'rsconnect/' --exclude 'app_cache/' "$LOCAL_REPO/shiny_meijendel/" "$VPS:$REMOTE_SHINY/shiny_meijendel/"
  [[ ! -d "$LOCAL_REPO/R" ]] || run_rsync --delete-delay --exclude '.DS_Store' "$LOCAL_REPO/R/" "$VPS:$REMOTE_SHINY/R/"
  [[ ! -f "$LOCAL_REPO/bmp_meijendel_index.html" ]] || run_rsync "$LOCAL_REPO/bmp_meijendel_index.html" "$VPS:$REMOTE_WWW/bmp_meijendel_index.html"
  [[ ! -f "$LOCAL_REPO/index.html" ]] || run_rsync "$LOCAL_REPO/index.html" "$VPS:$REMOTE_WWW/index.html"
  [[ ! -d "$LOCAL_REPO/output_ecologische_groepen" ]] || run_rsync --delete-delay --exclude '.DS_Store' "$LOCAL_REPO/output_ecologische_groepen/" "$VPS:$REMOTE_WWW/output_ecologische_groepen/"
  [[ ! -d "$LOCAL_REPO/trim" ]] || run_rsync --delete-delay --exclude '.DS_Store' "$LOCAL_REPO/trim/" "$VPS:$REMOTE_WWW/trim/"
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

EXPECTED_SQL_SHA256="$(awk -F= '$1 == "sql_sha256" {print $2}' "$SQL_MANIFEST_LOCAL")"
REMOTE_SQL_SHA256="$(remote "sha256sum '$SQL_CANDIDATE_FILE' | awk '{print \$1}'")"
REMOTE_MANIFEST_SHA256="$(remote "sha256sum '$SQL_MANIFEST_CANDIDATE_FILE' | awk '{print \$1}'")"
LOCAL_MANIFEST_SHA256="$(shasum -a 256 "$SQL_MANIFEST_LOCAL" | awk '{print $1}')"
EXPECTED_CACHE_SHA256="$(awk -F= '$1 == "cache_sha256" {print $2}' "$CACHE_MANIFEST_LOCAL")"
REMOTE_CACHE_SHA256="$(remote "sha256sum '$CACHE_CANDIDATE_FILE' | awk '{print \$1}'")"
REMOTE_CACHE_MANIFEST_SHA256="$(remote "sha256sum '$CACHE_MANIFEST_CANDIDATE_FILE' | awk '{print \$1}'")"
LOCAL_CACHE_MANIFEST_SHA256="$(shasum -a 256 "$CACHE_MANIFEST_LOCAL" | awk '{print $1}')"
REMOTE_SOURCES_SHA256="$(remote "sha256sum '$SOURCES_SQL_CANDIDATE_FILE' | awk '{print \$1}'")"
REMOTE_SOURCES_MANIFEST_SHA256="$(remote "sha256sum '$SOURCES_MANIFEST_CANDIDATE_FILE' | awk '{print \$1}'")"
LOCAL_SOURCES_MANIFEST_SHA256="$(shasum -a 256 "$SOURCES_MANIFEST_DEPLOY" | awk '{print $1}')"
[[ "$REMOTE_SQL_SHA256" == "$EXPECTED_SQL_SHA256" ]] || die "remote SQL-hash wijkt af van exportmanifest."
[[ "$REMOTE_MANIFEST_SHA256" == "$LOCAL_MANIFEST_SHA256" ]] || die "remote exportmanifest wijkt af van lokaal manifest."
[[ "$REMOTE_CACHE_SHA256" == "$EXPECTED_CACHE_SHA256" ]] || die "remote cachehash wijkt af van cachemanifest."
[[ "$REMOTE_CACHE_MANIFEST_SHA256" == "$LOCAL_CACHE_MANIFEST_SHA256" ]] || die "remote cachemanifest wijkt af van lokaal manifest."
[[ "$REMOTE_SOURCES_SHA256" == "$sources_sha256" ]] || die "remote bron-dump wijkt af van lokaal bestand."
[[ "$REMOTE_SOURCES_MANIFEST_SHA256" == "$LOCAL_SOURCES_MANIFEST_SHA256" ]] || die "remote bronmanifest wijkt af van lokaal manifest."
printf 'REMOTE_SQL_SHA256=%s\nREMOTE_CACHE_SHA256=%s\nREMOTE_SOURCES_SHA256=%s\n' \
  "$REMOTE_SQL_SHA256" "$REMOTE_CACHE_SHA256" "$REMOTE_SOURCES_SHA256"

log "Leg exacte kandidaatcommit vast voor de gesloten releasehelper"
remote "mkdir -p '$STATE_DIR'; umask 077; tmp='$CANDIDATE_FILE.tmp.\$\$'; printf '%s\n' '$LOCAL_COMMIT' > \"\$tmp\"; mv \"\$tmp\" '$CANDIDATE_FILE'"
CANDIDATE_STAGED=1

log "Maak back-up, importeer MySQL, herstart Shiny en controleer de release via de gesloten gateway"
set +e
gateway_apply="$("$GATEWAY_RUNNER" apply "$LOCAL_COMMIT")"
gateway_apply_rc=$?
set -e
printf '%s\n' "$gateway_apply"
[[ "$gateway_apply_rc" -eq 0 ]] || \
  die "gesloten Meijendel-releaseactie faalde; controleer rollbackmelding en productie."
grep -Fq 'DATABASE_BACKUP=' <<<"$gateway_apply" || die "releaseactie meldde geen databaseback-up."
grep -Fq 'SOURCES_DATABASE_BACKUP=' <<<"$gateway_apply" || die "releaseactie meldde geen status van de bronback-up."
grep -Fqx 'SOURCES_STATUS=ready' <<<"$gateway_apply" || die "releaseactie meldde de bron-database niet gereed."
grep -Fqx 'CACHE_CANDIDATE_STATUS=ready' <<<"$gateway_apply" || die "releaseactie bewees de kandidaatcache niet."
grep -Fqx 'SQL_CACHE=TRUE' <<<"$gateway_apply" || die "releaseactie gebruikte niet aantoonbaar de vooraf gebouwde cache."
grep -Fqx 'SHINY_STATUS=ready' <<<"$gateway_apply" || die "releaseactie meldde Shiny niet gereed."
grep -Fqx 'RELEASE_STATUS=ready' <<<"$gateway_apply" || die "releaseactie gaf geen gereedstatus."

log "Controleer canonieke publieke soortselectie"
canonical_data_smoke

log "Volledige productiecontrole na deploy"
production_smoke
write_state "$LOCAL_COMMIT"
log "Productiecommit geregistreerd: $LOCAL_COMMIT"
log "Deploy afgerond"
