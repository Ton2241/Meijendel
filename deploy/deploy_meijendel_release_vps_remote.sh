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
SQL_MANIFEST_FILE="$REMOTE_DATA/Meijendel.sql.manifest"
SQL_CANDIDATE_FILE="$REMOTE_DATA/Meijendel.sql.candidate-$release_commit"
SQL_MANIFEST_CANDIDATE_FILE="$REMOTE_DATA/Meijendel.sql.manifest.candidate-$release_commit"
APP_CACHE="$REMOTE_SHINY/shiny_meijendel/app_cache"
ACTIVE_CACHE_MANIFEST="$APP_CACHE/meijendel_tables_cache.active.manifest"
BACKUP_DIR="$REMOTE_BASE/backups/meijendel-mysql"
success=0
import_started=0
activation_started=0
backup_file=""
cache_file=""
cache_manifest=""
CACHE_CANDIDATE_FILE=""
CACHE_MANIFEST_CANDIDATE_FILE=""
validation_dir=""
rollback_sql="$REMOTE_DATA/Meijendel.sql.rollback-$release_commit"
rollback_sql_manifest="$REMOTE_DATA/Meijendel.sql.manifest.rollback-$release_commit"
rollback_cache_manifest="$APP_CACHE/meijendel_tables_cache.active.manifest.rollback-$release_commit"
had_sql=0
had_sql_manifest=0
had_cache_manifest=0
previous_cache_file=""
rollback_uses_candidate_cache=0
first_cache_migration=0

die() {
  printf 'BLOKKADE|meijendel-release|%s\n' "$*" >&2
  exit 1
}

manifest_value() {
  local key="$1" file="$2" value count
  count="$(awk -F= -v key="$key" '$1 == key {count++} END {print count+0}' "$file")"
  [[ "$count" -eq 1 ]] || die "manifestveld $key ontbreekt of komt meermaals voor"
  value="$(awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print}' "$file")"
  [[ -n "$value" ]] || die "manifestveld $key is leeg"
  printf '%s\n' "$value"
}

[[ " ${STAGES[*]} " == *" $stage "* ]] || die "onbekende fase"
[[ "$release_commit" =~ ^[0-9a-f]{40}$ ]] || die "commit vereist exact 40 hextekens"

restore_backup() {
  [[ -s "$backup_file" ]] || return 1
  printf 'ROLLBACK|meijendel-release|database=%s\n' "$backup_file" >&2
  gzip -dc "$backup_file" | docker exec -i "$CONTAINER" sh -lc \
    'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
}

ensure_shiny_contract() {
  local compose="$REMOTE_SHINY/docker-compose.yml"
  grep -Fq 'MEIJENDEL_REQUIRE_PREBUILT_CACHE:' "$compose" || perl -0pi -e \
    's#(    restart: unless-stopped\n)#$1    environment:\n      MEIJENDEL_REQUIRE_PREBUILT_CACHE: "1"\n      MEIJENDEL_SQL_MANIFEST_PATH: /srv/shiny-server/Meijendel.sql.manifest\n      MEIJENDEL_CACHE_MANIFEST_PATH: /srv/shiny-server/shiny_meijendel/app_cache/meijendel_tables_cache.active.manifest\n#' "$compose"
  grep -Fq '/srv/shiny-server/Meijendel.sql.manifest:ro' "$compose" || perl -0pi -e \
    's#(      - /srv/vwgm/shiny/Meijendel.sql:/srv/shiny-server/Meijendel.sql:ro\n)#$1      - /srv/vwgm/data/Meijendel.sql.manifest:/srv/shiny-server/Meijendel.sql.manifest:ro\n#' "$compose"
  grep -Fq 'MEIJENDEL_REQUIRE_PREBUILT_CACHE: "1"' "$compose" || die "Compose mist verplichte cachemodus"
  grep -Fq 'MEIJENDEL_SQL_MANIFEST_PATH: /srv/shiny-server/Meijendel.sql.manifest' "$compose" || die "Compose mist SQL-manifestpad"
  grep -Fq 'MEIJENDEL_CACHE_MANIFEST_PATH: /srv/shiny-server/shiny_meijendel/app_cache/meijendel_tables_cache.active.manifest' "$compose" || die "Compose mist cachemanifestpad"
  grep -Fq '/srv/vwgm/data/Meijendel.sql.manifest:/srv/shiny-server/Meijendel.sql.manifest:ro' "$compose" || die "Compose mist read-only SQL-manifestmount"
}

runtime_cache_check() {
  local output
  output="$(docker exec -u shiny "$SHINY_CONTAINER" sh -lc \
    'cd /srv/shiny-server/shiny_meijendel && Rscript -e "source(\"helpers.R\"); path <- resolve_meijendel_sql_path(); stopifnot(identical(path, \"/srv/shiny-server/Meijendel.sql\")); x <- load_meijendel_tables_cached(path); stopifnot(isTRUE(x[[\"from_cache\"]])); cat(\"SQL_CACHE=TRUE\\n\")"')"
  printf '%s\n' "$output"
  grep -Fqx 'SQL_CACHE=TRUE' <<<"$output"
}

restart_shiny() {
  mkdir -p "$APP_CACHE/sass"
  docker run --rm -v "$APP_CACHE:/app_cache" \
    vwgm-shiny:latest chown -R shiny:shiny /app_cache
  ensure_shiny_contract
  cd "$REMOTE_SHINY"
  docker compose up -d --force-recreate shiny >/dev/null
  for attempt in $(seq 1 30); do
    if curl -fsSI http://127.0.0.1:3838/ >/dev/null; then
      printf 'SHINY_STATUS=ready\n'
      runtime_cache_check
      return 0
    fi
    sleep 2
  done
  docker logs --tail 120 "$SHINY_CONTAINER" >&2 || true
  return 1
}

install_first_migration_artifacts() {
  mkdir -p "$APP_CACHE"
  if [[ -f "$SQL_CANDIDATE_FILE" ]]; then
    rm -f "$SQL_FILE"
    mv "$SQL_CANDIDATE_FILE" "$SQL_FILE"
  fi
  if [[ -f "$SQL_MANIFEST_CANDIDATE_FILE" ]]; then
    rm -f "$SQL_MANIFEST_FILE"
    mv "$SQL_MANIFEST_CANDIDATE_FILE" "$SQL_MANIFEST_FILE"
  fi
  if [[ -f "$CACHE_CANDIDATE_FILE" ]]; then
    rm -f "$APP_CACHE/$cache_file"
    mv "$CACHE_CANDIDATE_FILE" "$APP_CACHE/$cache_file"
  fi
  if [[ -f "$CACHE_MANIFEST_CANDIDATE_FILE" ]]; then
    rm -f "$ACTIVE_CACHE_MANIFEST"
    mv "$CACHE_MANIFEST_CANDIDATE_FILE" "$ACTIVE_CACHE_MANIFEST"
  fi
  chmod 644 "$SQL_FILE" "$SQL_MANIFEST_FILE" "$APP_CACHE/$cache_file" "$ACTIVE_CACHE_MANIFEST"
  ln -sfn "$SQL_FILE" "$REMOTE_SHINY/Meijendel.sql"
  ln -sfn "$SQL_FILE" "$REMOTE_WWW/Meijendel.sql"
  ln -sfn "$SQL_FILE" "$REMOTE_APP/data/Meijendel.sql"
  rm -f "$rollback_sql" "$rollback_sql_manifest" "$rollback_cache_manifest"
  printf 'ROLLBACK_ARTIFACT_STATUS=deterministic-equivalent\n'
}

restore_files() {
  if [[ "$first_cache_migration" -eq 1 ]]; then
    install_first_migration_artifacts
    return 0
  fi
  if [[ "$activation_started" -ne 1 ]]; then
    if [[ "$rollback_uses_candidate_cache" -eq 1 ]]; then
      mkdir -p "$APP_CACHE"
      cp "$CACHE_CANDIDATE_FILE" "$APP_CACHE/$cache_file"
      cp "$CACHE_MANIFEST_CANDIDATE_FILE" "$ACTIVE_CACHE_MANIFEST.next.$$"
      chmod 644 "$APP_CACHE/$cache_file" "$ACTIVE_CACHE_MANIFEST.next.$$"
      mv "$ACTIVE_CACHE_MANIFEST.next.$$" "$ACTIVE_CACHE_MANIFEST"
    fi
    return 0
  fi
  rm -f "$SQL_FILE" "$SQL_MANIFEST_FILE"
  if [[ "$had_cache_manifest" -eq 1 || "$rollback_uses_candidate_cache" -ne 1 ]]; then
    rm -f "$ACTIVE_CACHE_MANIFEST"
  fi
  if [[ "$had_sql" -eq 1 ]]; then mv "$rollback_sql" "$SQL_FILE"; fi
  if [[ "$had_sql_manifest" -eq 1 ]]; then mv "$rollback_sql_manifest" "$SQL_MANIFEST_FILE"; fi
  if [[ "$had_cache_manifest" -eq 1 ]]; then mv "$rollback_cache_manifest" "$ACTIVE_CACHE_MANIFEST"; fi
  if [[ -n "$cache_file" && "$cache_file" != "$previous_cache_file" ]]; then rm -f "$APP_CACHE/$cache_file"; fi
  if [[ -f "$SQL_FILE" ]]; then
    ln -sfn "$SQL_FILE" "$REMOTE_SHINY/Meijendel.sql"
    ln -sfn "$SQL_FILE" "$REMOTE_WWW/Meijendel.sql"
    ln -sfn "$SQL_FILE" "$REMOTE_APP/data/Meijendel.sql"
  fi
}

cleanup_candidates() {
  [[ -z "$validation_dir" ]] || rm -rf "$validation_dir"
  rm -f "$SQL_CANDIDATE_FILE" "$SQL_MANIFEST_CANDIDATE_FILE"
  [[ -z "$CACHE_CANDIDATE_FILE" ]] || rm -f "$CACHE_CANDIDATE_FILE"
  [[ -z "$CACHE_MANIFEST_CANDIDATE_FILE" ]] || rm -f "$CACHE_MANIFEST_CANDIDATE_FILE"
}

finish() {
  status=$?
  trap - EXIT INT TERM
  if [[ "$success" -ne 1 && "$import_started" -eq 1 ]]; then
    rollback_ok=1
    restore_backup || rollback_ok=0
    restore_files || rollback_ok=0
    if [[ "$rollback_ok" -eq 1 ]] && restart_shiny; then
      printf 'ROLLBACK_STATUS=ready\n'
      cleanup_candidates
    else
      printf 'URGENT|meijendel-release|automatische database- of cacherollback mislukt\n' >&2
    fi
  elif [[ "$success" -ne 1 ]]; then
    cleanup_candidates
  elif [[ "$success" -eq 1 ]]; then
    cleanup_candidates
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
for required in "$SQL_CANDIDATE_FILE" "$SQL_MANIFEST_CANDIDATE_FILE"; do
  [[ -f "$required" && ! -L "$required" && -s "$required" ]] || \
    die "SQL-kandidaat ontbreekt, is leeg of is een symlink: $required"
done
cache_file="$(manifest_value cache_file "$SQL_MANIFEST_CANDIDATE_FILE")"
cache_manifest="$(manifest_value cache_manifest "$SQL_MANIFEST_CANDIDATE_FILE")"
[[ "$cache_file" =~ ^meijendel_tables_cache-p[1-9][0-9]*-[0-9a-f]{64}\.rds$ && "$cache_file" != */* ]] || \
  die "cache_file is geen veilige basename"
[[ "$cache_manifest" == "${cache_file%.rds}.manifest" ]] || die "cachemanifest past niet bij cachebestand"
CACHE_CANDIDATE_FILE="$STATE_DIR/${cache_file}.candidate-$release_commit"
CACHE_MANIFEST_CANDIDATE_FILE="$STATE_DIR/${cache_manifest}.candidate-$release_commit"
[[ -f "$CACHE_CANDIDATE_FILE" && -s "$CACHE_CANDIDATE_FILE" ]] || die "cachekandidaat ontbreekt of is leeg"
[[ ! -L "$CACHE_CANDIDATE_FILE" ]] || die "cachekandidaat mag geen symlink zijn"
[[ -f "$CACHE_MANIFEST_CANDIDATE_FILE" && -s "$CACHE_MANIFEST_CANDIDATE_FILE" ]] || die "cachemanifestkandidaat ontbreekt of is leeg"
[[ ! -L "$CACHE_MANIFEST_CANDIDATE_FILE" ]] || die "cachemanifestkandidaat mag geen symlink zijn"

expected_sql_hash="$(manifest_value sql_sha256 "$SQL_MANIFEST_CANDIDATE_FILE")"
expected_sql_bytes="$(manifest_value sql_bytes "$SQL_MANIFEST_CANDIDATE_FILE")"
[[ "$expected_sql_hash" =~ ^[0-9a-f]{64}$ && "$expected_sql_bytes" =~ ^[0-9]+$ ]] || die "ongeldige SQL-identiteit"
[[ "$(sha256sum "$SQL_CANDIDATE_FILE" | awk '{print $1}')" == "$expected_sql_hash" ]] || die "SQL-kandidaathash wijkt af"
[[ "$(stat -c '%s' "$SQL_CANDIDATE_FILE")" == "$expected_sql_bytes" ]] || die "SQL-kandidaatomvang wijkt af"
[[ "$(manifest_value format "$CACHE_MANIFEST_CANDIDATE_FILE")" == "meijendel-shiny-cache-manifest-v1" ]] || die "ongeldig cachemanifestformaat"
[[ "$(manifest_value cache_file "$CACHE_MANIFEST_CANDIDATE_FILE")" == "$cache_file" ]] || die "cachemanifest wijst naar ander bestand"
[[ "$(manifest_value sql_sha256 "$CACHE_MANIFEST_CANDIDATE_FILE")" == "$expected_sql_hash" ]] || die "cachemanifest hoort bij andere SQL"
[[ "$(manifest_value sql_bytes "$CACHE_MANIFEST_CANDIDATE_FILE")" == "$expected_sql_bytes" ]] || die "cachemanifest bevat andere SQL-omvang"
expected_cache_hash="$(manifest_value cache_sha256 "$CACHE_MANIFEST_CANDIDATE_FILE")"
expected_cache_bytes="$(manifest_value cache_bytes "$CACHE_MANIFEST_CANDIDATE_FILE")"
[[ "$expected_cache_hash" =~ ^[0-9a-f]{64}$ && "$expected_cache_bytes" =~ ^[0-9]+$ ]] || die "ongeldige cache-identiteit"
[[ "$(sha256sum "$CACHE_CANDIDATE_FILE" | awk '{print $1}')" == "$expected_cache_hash" ]] || die "cachekandidaathash wijkt af"
[[ "$(stat -c '%s' "$CACHE_CANDIDATE_FILE")" == "$expected_cache_bytes" ]] || die "cachekandidaatomvang wijkt af"
grep -q -- '-- Dump completed on ' "$SQL_CANDIDATE_FILE" || die "SQL-dump mist eindmarkering"
grep -Eq 'CREATE TABLE .pq_vegetatie_pq.' "$SQL_CANDIDATE_FILE" || die "SQL-dump mist PQ-tabel"
grep -Eq 'VIEW .website_plot_vegetatie_jaar.' "$SQL_CANDIDATE_FILE" || die "SQL-dump mist publieke PQ-view"

validation_dir="$STATE_DIR/Meijendel-cache-validation-$release_commit"
rm -rf "$validation_dir"
mkdir "$validation_dir"
ln "$CACHE_CANDIDATE_FILE" "$validation_dir/$cache_file"
ln "$CACHE_MANIFEST_CANDIDATE_FILE" "$validation_dir/$cache_manifest"
candidate_cache_output="$(docker run --rm --network none --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  -e MEIJENDEL_REQUIRE_PREBUILT_CACHE=1 \
  -e MEIJENDEL_SQL_MANIFEST_PATH=/candidate/Meijendel.sql.manifest \
  -e MEIJENDEL_CACHE_MANIFEST_PATH="/candidate-cache/$cache_manifest" \
  --mount type=bind,src="$SQL_CANDIDATE_FILE",dst=/candidate/Meijendel.sql,readonly \
  --mount type=bind,src="$SQL_MANIFEST_CANDIDATE_FILE",dst=/candidate/Meijendel.sql.manifest,readonly \
  --mount type=bind,src="$validation_dir",dst=/candidate-cache,readonly \
  --mount type=bind,src="$REMOTE_SHINY/shiny_meijendel",dst=/srv/shiny-server/shiny_meijendel,readonly \
  --mount type=bind,src="$REMOTE_SHINY/R",dst=/srv/shiny-server/R,readonly \
  --workdir /srv/shiny-server/shiny_meijendel \
  vwgm-shiny:latest Rscript -e \
  'source("helpers.R"); x <- load_meijendel_tables_cached("/candidate/Meijendel.sql"); stopifnot(isTRUE(x[["from_cache"]])); cat("SQL_CACHE=TRUE\n")')"
grep -Fqx 'SQL_CACHE=TRUE' <<<"$candidate_cache_output" || die "kandidaatcache werd niet rechtstreeks geladen"
printf 'CACHE_CANDIDATE_STATUS=ready\n'
rm -rf "$validation_dir"
validation_dir=""

for required in \
  "$REMOTE_WWW/trim/soorten/soorten_trendoverzicht.csv" \
  "$REMOTE_WWW/trim/sandra/soorten/soorten_trendoverzicht.csv" \
  "$REMOTE_WWW/trim_msi_evg/trendoverzicht_msi_groepen.csv"; do
  test -s "$required" || die "releasebestand ontbreekt of is leeg: $required"
done

if [[ -f "$ACTIVE_CACHE_MANIFEST" && ! -L "$ACTIVE_CACHE_MANIFEST" ]]; then
  previous_cache_file="$(manifest_value cache_file "$ACTIVE_CACHE_MANIFEST")"
  [[ "$previous_cache_file" =~ ^meijendel_tables_cache-p[1-9][0-9]*-[0-9a-f]{64}\.rds$ && "$previous_cache_file" != */* ]] || \
    die "vorig actief cachemanifest bevat een onveilige basename"
  previous_cache_path="$APP_CACHE/$previous_cache_file"
  [[ -f "$previous_cache_path" && ! -L "$previous_cache_path" && -s "$previous_cache_path" ]] || \
    die "vorige actieve cache ontbreekt, is leeg of is een symlink"
  [[ "$(sha256sum "$previous_cache_path" | awk '{print $1}')" == "$(manifest_value cache_sha256 "$ACTIVE_CACHE_MANIFEST")" ]] || \
    die "vorige actieve cache wijkt af van zijn manifest"
  [[ "$(sha256sum "$SQL_FILE" | awk '{print $1}')" == "$(manifest_value sql_sha256 "$ACTIVE_CACHE_MANIFEST")" ]] || \
    die "vorige actieve cache hoort niet bij de actieve SQL-dump"
else
  [[ -f "$SQL_FILE" && ! -L "$SQL_FILE" ]] || die "actieve SQL-dump ontbreekt voor rollback"
  [[ -f "$SQL_MANIFEST_FILE" && ! -L "$SQL_MANIFEST_FILE" ]] || \
    die "actief SQL-manifest ontbreekt voor eerste cacheactivering"
  for identity_key in \
    source_database mysql_version base_tables views row_counts_sha256 table_checksums_sha256 \
    dagbezoeken_bmp dagwaarnemingen_bmp territoria; do
    [[ "$(manifest_value "$identity_key" "$SQL_MANIFEST_FILE")" == \
       "$(manifest_value "$identity_key" "$SQL_MANIFEST_CANDIDATE_FILE")" ]] || \
      die "eerste cacheactivering wijzigt database-inhoud volgens manifestveld $identity_key"
  done
  previous_cache_file="$cache_file"
  rollback_uses_candidate_cache=1
  first_cache_migration=1
fi

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
  'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < "$SQL_CANDIDATE_FILE"

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

activation_started=1
if [[ -f "$SQL_FILE" && ! -L "$SQL_FILE" ]]; then mv "$SQL_FILE" "$rollback_sql"; had_sql=1; fi
if [[ -f "$SQL_MANIFEST_FILE" && ! -L "$SQL_MANIFEST_FILE" ]]; then mv "$SQL_MANIFEST_FILE" "$rollback_sql_manifest"; had_sql_manifest=1; fi
if [[ -f "$ACTIVE_CACHE_MANIFEST" && ! -L "$ACTIVE_CACHE_MANIFEST" ]]; then
  mv "$ACTIVE_CACHE_MANIFEST" "$rollback_cache_manifest"
  had_cache_manifest=1
fi
mv "$SQL_CANDIDATE_FILE" "$SQL_FILE"
mv "$SQL_MANIFEST_CANDIDATE_FILE" "$SQL_MANIFEST_FILE"
mkdir -p "$APP_CACHE"
mv "$CACHE_CANDIDATE_FILE" "$APP_CACHE/$cache_file"
cache_manifest_next="$ACTIVE_CACHE_MANIFEST.next.$$"
mv "$CACHE_MANIFEST_CANDIDATE_FILE" "$cache_manifest_next"
chmod 644 "$SQL_FILE" "$SQL_MANIFEST_FILE" "$APP_CACHE/$cache_file" "$cache_manifest_next"
mv "$cache_manifest_next" "$ACTIVE_CACHE_MANIFEST"
ln -sfn "$SQL_FILE" "$REMOTE_SHINY/Meijendel.sql"
ln -sfn "$SQL_FILE" "$REMOTE_WWW/Meijendel.sql"
ln -sfn "$SQL_FILE" "$REMOTE_APP/data/Meijendel.sql"

restart_shiny
docker exec "$SHINY_CONTAINER" Rscript -e '
  pkgs <- c("geepack", "glmmTMB", "vegan", "pls", "changepoint", "strucchange", "lavaan", "piecewiseSEM", "indicspecies", "betapart", "unmarked")
  ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  if (!all(ok)) stop("Niet alle analysepackages zijn beschikbaar.")
  if (!nzchar(Sys.which("perl"))) stop("Perl ontbreekt in de Shiny-container.")
'
sha256sum "$REMOTE_DATA/Meijendel.sql" "$REMOTE_SHINY/Meijendel.sql" \
  "$REMOTE_WWW/Meijendel.sql" "$REMOTE_APP/data/Meijendel.sql"
docker stats --no-stream "$SHINY_CONTAINER"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

for path in "$APP_CACHE"/meijendel_tables_cache-p*.rds; do
  [[ -f "$path" && ! -L "$path" ]] || continue
  basename_path="$(basename "$path")"
  if [[ "$basename_path" != "$cache_file" && "$basename_path" != "$previous_cache_file" ]]; then
    rm -f "$path"
  fi
done
rm -f "$rollback_sql" "$rollback_sql_manifest" "$rollback_cache_manifest"
success=1
printf 'RELEASE_STATUS=ready\n'
