#!/usr/bin/env bash
set -euo pipefail

: "${REMOTE_STAGE:?}"
: "${DOCKERFILE_HASH:?}"
: "${HELPER_HASH:?}"
: "${VALIDATOR_HASH:?}"
: "${EXPECTED_OLD_IMAGE:?}"
: "${NEW_COMMIT:?}"
: "${SHORT_COMMIT:?}"

ACTIVE_CONTAINER="meijendel-mysql"
PREVIOUS_CONTAINER="meijendel-mysql-previous-$SHORT_COMMIT"
CANDIDATE_CONTAINER="meijendel-mysql-candidate-$SHORT_COMMIT"
CANDIDATE_TAG="vwgm-mysql:candidate-$SHORT_COMMIT"
PREVIOUS_TAG="vwgm-mysql:previous-$SHORT_COMMIT"
CANONICAL_TAG="vwgm-mysql:9.7.1"
MYSQL_ENV="/srv/vwgm/meijendel-mysql/mysql.env"
MYSQL_DATA="/srv/vwgm/meijendel-mysql-971-uid1999/data"
BACKUP_DIR="/srv/vwgm/backups/vwg-m-baremetal"
BACKUP_ARCHIVE="$BACKUP_DIR/vwg-m-baremetal-latest.tar.gz"
LOCK="/srv/vwgm/deploy-state/production.lock"
STATE_FILE="/srv/vwgm/deploy-state/Meijendel.commit"
TASK_ROOT="/srv/vwgm/mysql-image-task-$SHORT_COMMIT"
TEST_DATA="$TASK_ROOT/data"
TEST_DUMP="$TASK_ROOT/meijendel.sql.gz"
BUILDER="vwgm-mysql-$SHORT_COMMIT"
CANDIDATE_ID=""
SWITCH_STARTED=0
SUCCESS=0

fail() { printf 'BLOKKADE|mysql-image-update|%s\n' "$*" >&2; exit 1; }
hash_file() { sha256sum "$1" | awk '{print $1}'; }
wait_mysql() {
  local container="$1" attempt version
  for attempt in $(seq 1 120); do
    version="$(docker exec "$container" sh -c \
      'mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION()"' \
      2>/dev/null || true)"
    if [[ "$version" == "9.7.1" ]]; then
      return 0
    fi
    sleep 2
  done
  docker logs --tail 160 "$container" >&2 || true
  return 1
}
smoke_status() {
  local label="$1" host="$2" path="$3" expected="$4" actual
  actual="$(curl --silent --show-error --insecure --output /dev/null \
    --write-out '%{http_code}' --resolve "$host:443:127.0.0.1" \
    "https://$host$path")"
  [[ "$actual" == "$expected" ]] ||
    fail "rooktest $label verwachtte $expected maar kreeg $actual"
  printf 'GROEN|mysql-image-rooktest|%s|status=%s\n' "$label" "$actual"
}
validate_backup() {
  cd "$BACKUP_DIR"
  sha256sum -c vwg-m-baremetal-latest.tar.gz.sha256
  /srv/vwgm/vwg-m-linux-app/scripts/restore_check_backup.sh "$BACKUP_ARCHIVE"
}
audit_candidate() {
  local output status short attention_count
  set +e
  output="$(/usr/local/libexec/vwgm-admin/vulnerability-audit-root --image "$CANDIDATE_ID" 2>&1)"
  status=$?
  set -e
  printf '%s\n' "$output"
  short="${CANDIDATE_ID#sha256:}"
  grep -Fq "SAMENVATTING|kandidaat-${short:0:12}|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0" \
    <<< "$output" || fail "kandidaat bevat HIGH/CRITICAL of is niet exact gescand"
  grep -Fq 'SAMENVATTING|meijendel-mysql|critical=0|high=2|fix_beschikbaar=2|zonder_fix=0' \
    <<< "$output" || fail "actieve uitgangsimage wijkt af tijdens kandidaatscan"
  grep -Fq 'SAMENVATTING|shiny_meijendel|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' \
    <<< "$output" || fail "Shiny wijkt af tijdens kandidaatscan"
  [[ "$status" -eq 1 ]] || fail "kandidaatscan heeft een onverwachte eindstatus"
  ! grep -Eq '^(URGENT|BLOKKADE)\|' <<< "$output" || fail "kandidaatscan is onvolledig"
  attention_count="$(grep -c '^AANDACHT|' <<< "$output")"
  [[ "$attention_count" -eq 2 ]] || fail "kandidaatscan bevat onverwachte aandachtspunten"
  grep -Fq "AANDACHT|container-hygiene|onverwachte-imagetag=$CANDIDATE_TAG" <<< "$output" || fail "kandidaattag is niet exact verklaard"
  grep -Fq 'AANDACHT|container-image|meijendel-mysql|' <<< "$output" || fail "oude MySQL-baseline ontbreekt"
}
audit_active_with_previous() {
  local output status attention_count
  set +e
  output="$(/usr/local/libexec/vwgm-admin/vulnerability-audit-root 2>&1)"
  status=$?
  set -e
  printf '%s\n' "$output"
  [[ "$status" -eq 1 ]] || fail "actieve tussenscan heeft een onverwachte eindstatus"
  grep -Fq 'SAMENVATTING|meijendel-mysql|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' <<< "$output" || fail "nieuwe actieve MySQL-scan is niet 0/0"
  grep -Fq 'SAMENVATTING|shiny_meijendel|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' <<< "$output" || fail "Shiny-tussenscan wijkt af"
  ! grep -Eq '^(URGENT|BLOKKADE)\|' <<< "$output" || fail "actieve tussenscan is onvolledig"
  attention_count="$(grep -c '^AANDACHT|' <<< "$output")"
  [[ "$attention_count" -eq 3 ]] || fail "actieve tussenscan bevat onverwachte aandachtspunten"
  grep -Fq "AANDACHT|container-hygiene|onverwachte-container=$PREVIOUS_CONTAINER" <<< "$output" || fail "previous-container is niet exact verklaard"
  grep -Fq "AANDACHT|container-hygiene|onverwachte-imagetag=$CANDIDATE_TAG" <<< "$output" || fail "kandidaattag is niet exact verklaard"
  grep -Fq "AANDACHT|container-hygiene|onverwachte-imagetag=$PREVIOUS_TAG" <<< "$output" || fail "previous-tag is niet exact verklaard"
}
rollback_or_cleanup() {
  status=$?
  trap - EXIT INT TERM
  if [[ "$SUCCESS" -ne 1 ]]; then
    if [[ "$SWITCH_STARTED" -eq 1 ]] && docker inspect "$PREVIOUS_CONTAINER" >/dev/null 2>&1; then
      docker rm -f "$ACTIVE_CONTAINER" >/dev/null 2>&1 || true
      docker tag "$EXPECTED_OLD_IMAGE" "$CANONICAL_TAG" >/dev/null 2>&1 || true
      docker rename "$PREVIOUS_CONTAINER" "$ACTIVE_CONTAINER" >/dev/null 2>&1 || true
      docker start "$ACTIVE_CONTAINER" >/dev/null 2>&1 || true
      wait_mysql "$ACTIVE_CONTAINER" || true
    fi
    docker rm -f "$CANDIDATE_CONTAINER" >/dev/null 2>&1 || true
    [[ -z "$CANDIDATE_ID" ]] || docker image rm "$CANDIDATE_TAG" >/dev/null 2>&1 || true
    [[ -z "$CANDIDATE_ID" ]] || {
      if ! docker ps -a --format '{{.Image}}' | grep -Fxq "$CANDIDATE_ID"; then
        docker image rm "$CANDIDATE_ID" >/dev/null 2>&1 || true
      fi
    }
    docker image rm "$PREVIOUS_TAG" >/dev/null 2>&1 || true
    rm -rf -- "$TASK_ROOT"
  fi
  docker buildx rm "$BUILDER" >/dev/null 2>&1 || true
  docker image rm moby/buildkit:buildx-stable-1 >/dev/null 2>&1 || true
  exit "$status"
}
trap rollback_or_cleanup EXIT INT TERM

[[ "$(hash_file "$REMOTE_STAGE/Dockerfile.9.7.1")" == "$DOCKERFILE_HASH" ]] || fail "Dockerfilehash wijkt af"
[[ "$(hash_file "$REMOTE_STAGE/rebuild-mysql")" == "$HELPER_HASH" ]] || fail "helperhash wijkt af"
[[ "$(hash_file "$REMOTE_STAGE/validate-mysql")" == "$VALIDATOR_HASH" ]] || fail "validatorhash wijkt af"
[[ "$EXPECTED_OLD_IMAGE" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "oude image-ID is ongeldig"
[[ "$NEW_COMMIT" =~ ^[0-9a-f]{40}$ && "$SHORT_COMMIT" == "${NEW_COMMIT:0:12}" ]] || fail "commitbinding wijkt af"
[[ -d "$LOCK" ]] || fail "gedeelde productielock ontbreekt"
[[ ! -e "$TASK_ROOT" ]] || fail "taakmap bestaat al"
! docker inspect "$PREVIOUS_CONTAINER" >/dev/null 2>&1 || fail "previous-container bestaat al"
! docker inspect "$CANDIDATE_CONTAINER" >/dev/null 2>&1 || fail "kandidaatcontainer bestaat al"
! docker image inspect "$CANDIDATE_TAG" >/dev/null 2>&1 || fail "kandidaattag bestaat al"
[[ -f "$MYSQL_ENV" && -d "$MYSQL_DATA" ]] || fail "MySQL-env of datamap ontbreekt"
[[ "$(docker inspect --format '{{.State.Status}}' "$ACTIVE_CONTAINER")" == "running" ]] || fail "actieve MySQL draait niet"
[[ "$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER")" == "$EXPECTED_OLD_IMAGE" ]] || fail "actieve image veranderde"
[[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Source}}{{end}}{{end}}' "$ACTIVE_CONTAINER")" == "$MYSQL_DATA" ]] || fail "actieve datamount wijkt af"
[[ "$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$ACTIVE_CONTAINER")" == "unless-stopped" ]] || fail "restartbeleid wijkt af"
docker port "$ACTIVE_CONTAINER" 3306/tcp | grep -Fxq '127.0.0.1:3307' || fail "poortbinding wijkt af"
[[ "$(docker exec "$ACTIVE_CONTAINER" id -u mysql)" == 1999 && "$(docker exec "$ACTIVE_CONTAINER" id -g mysql)" == 1999 ]] || fail "MySQL UID/GID wijkt af"
[[ "$(docker exec "$ACTIVE_CONTAINER" sh -c 'mysql -NBe "select version()" -uroot -p"$MYSQL_ROOT_PASSWORD"')" == 9.7.1 ]] || fail "MySQL-versie wijkt af"

mkdir -m 0700 "$TASK_ROOT"
echo "== Verse herstelback-up vóór imagewisseling =="
/usr/local/sbin/vwgm-baremetal-backup > "$TASK_ROOT/pre-backup.json"
validate_backup
grep -Fq "$EXPECTED_OLD_IMAGE" "$BACKUP_DIR/vwg-m-baremetal-latest-manifest.json" || fail "oude actieve image ontbreekt in back-upmanifest"

echo "== Verse no-cache MySQL-kandidaat =="
docker buildx create --name "$BUILDER" --driver docker-container >/dev/null
docker buildx build --builder "$BUILDER" --platform linux/amd64 \
  --pull --no-cache --load --file "$REMOTE_STAGE/Dockerfile.9.7.1" \
  --tag "$CANDIDATE_TAG" "$REMOTE_STAGE"
CANDIDATE_ID="$(docker image inspect --format '{{.Id}}' "$CANDIDATE_TAG")"
[[ "$CANDIDATE_ID" =~ ^sha256:[0-9a-f]{64}$ && "$CANDIDATE_ID" != "$EXPECTED_OLD_IMAGE" ]] || fail "kandidaat-ID ontbreekt of is niet nieuw"
docker buildx rm "$BUILDER" >/dev/null
docker image rm moby/buildkit:buildx-stable-1 >/dev/null 2>&1 || true
docker run --rm "$CANDIDATE_ID" sh -c \
  'test "$(id -u mysql)" -eq 1999 && test "$(id -g mysql)" -eq 1999 && mysql --version | grep -Fq "Ver 9.7.1 "'
printf 'KANDIDAAT|mysql-image|image=%s\n' "$CANDIDATE_ID"
audit_candidate

echo "== Logische proefimport en volledige databasevalidatie =="
docker exec "$ACTIVE_CONTAINER" sh -c '
  exec mysqldump --single-transaction --routines --triggers --events --hex-blob \
    --set-gtid-purged=OFF --no-tablespaces -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"
' | gzip -c > "$TEST_DUMP"
[[ -s "$TEST_DUMP" ]] || fail "logische proefdumpt is leeg"
install -d -o 1999 -g 1999 -m 0700 "$TEST_DATA"
docker run -d --name "$CANDIDATE_CONTAINER" --restart no \
  --env-file "$MYSQL_ENV" -p 127.0.0.1:3308:3306 \
  -v "$TEST_DATA:/var/lib/mysql" "$CANDIDATE_ID" --local-infile=0 --mysqlx=0 >/dev/null
wait_mysql "$CANDIDATE_CONTAINER" || fail "proefcontainer werd niet gereed"
gzip -dc "$TEST_DUMP" | docker exec -i "$CANDIDATE_CONTAINER" sh -c \
  'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
mysql_user="$(docker exec "$CANDIDATE_CONTAINER" printenv MYSQL_USER)"
mysql_database="$(docker exec "$CANDIDATE_CONTAINER" printenv MYSQL_DATABASE)"
[[ "$mysql_user" =~ ^[A-Za-z0-9_]+$ && "$mysql_database" =~ ^[A-Za-z0-9_]+$ ]] || fail "onveilige envnaam"
docker exec -i "$CANDIDATE_CONTAINER" sh -c \
  'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' <<SQL
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '$mysql_user'@'%';
GRANT SELECT ON \`$mysql_database\`.* TO '$mysql_user'@'%';
SQL
bash "$REMOTE_STAGE/validate-mysql" "$ACTIVE_CONTAINER" "$CANDIDATE_CONTAINER" 1999 1999
docker rm -f "$CANDIDATE_CONTAINER" >/dev/null
rm -rf -- "$TEST_DATA" "$TEST_DUMP"

echo "== Gecontroleerde imagewisseling met automatische rollback =="
SWITCH_STARTED=1
docker stop "$ACTIVE_CONTAINER" >/dev/null
docker rename "$ACTIVE_CONTAINER" "$PREVIOUS_CONTAINER"
docker tag "$EXPECTED_OLD_IMAGE" "$PREVIOUS_TAG"
docker tag "$CANDIDATE_ID" "$CANONICAL_TAG"
docker run -d --name "$ACTIVE_CONTAINER" --restart unless-stopped \
  --env-file "$MYSQL_ENV" -p 127.0.0.1:3307:3306 \
  -v "$MYSQL_DATA:/var/lib/mysql" "$CANDIDATE_ID" --local-infile=0 --mysqlx=0 >/dev/null
wait_mysql "$ACTIVE_CONTAINER" || fail "nieuwe actieve MySQL werd niet gereed"
[[ "$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER")" == "$CANDIDATE_ID" ]] || fail "actieve image wijkt af"
[[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Source}}{{end}}{{end}}' "$ACTIVE_CONTAINER")" == "$MYSQL_DATA" ]] || fail "actieve datamount wijkt af"
bash "$REMOTE_STAGE/validate-mysql" "$ACTIVE_CONTAINER" "$ACTIVE_CONTAINER" 1999 1999
/usr/local/libexec/vwgm-admin/check-caddy-mysql-isolation
smoke_status publieke-home www.vwg-m.nl /welkom/index.asp 200
smoke_status mysql-soortpagina www.vwg-m.nl '/soorten/vogel.asp?id=90' 200
smoke_status leden-afgeschermd www.vwg-m.nl /leden/member-auth 401
smoke_status shiny-afgeschermd www.vwg-m.nl /shiny_meijendel/ 401
smoke_status app-redirect app.vwg-m.nl '/welkom/index.asp?bron=app' 308
smoke_status hoofddomein-redirect vwg-m.nl /welkom/index.asp 301

echo "== Exacte actieve scan en herstelbewijs vóór opruiming =="
audit_active_with_previous
/usr/local/sbin/vwgm-baremetal-backup > "$TASK_ROOT/post-switch-backup.json"
validate_backup
grep -Fq "$CANDIDATE_ID" "$BACKUP_DIR/vwg-m-baremetal-latest-manifest.json" || fail "nieuwe image ontbreekt in back-upmanifest"

echo "== Verwijder uitsluitend exacte taakartefacten en oude image =="
[[ "$(docker inspect --format '{{.State.Status}}' "$PREVIOUS_CONTAINER")" == "exited" ]] || fail "vorige container is niet gestopt"
[[ "$(docker inspect --format '{{.Image}}' "$PREVIOUS_CONTAINER")" == "$EXPECTED_OLD_IMAGE" ]] || fail "vorige containerimage wijkt af"
[[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Source}}{{end}}{{end}}' "$PREVIOUS_CONTAINER")" == "$MYSQL_DATA" ]] || fail "vorige containermount wijkt af"
docker rm "$PREVIOUS_CONTAINER" >/dev/null
docker image rm "$CANDIDATE_TAG" >/dev/null
docker image rm "$PREVIOUS_TAG" >/dev/null
docker image rm "$EXPECTED_OLD_IMAGE" >/dev/null
SWITCH_STARTED=0

final_audit="$(/usr/local/libexec/vwgm-admin/vulnerability-audit-root)"
printf '%s\n' "$final_audit"
grep -Fq 'SAMENVATTING|meijendel-mysql|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' <<< "$final_audit" || fail "actieve MySQL-eindscan is niet 0/0"
grep -Fq 'SAMENVATTING|shiny_meijendel|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' <<< "$final_audit" || fail "Shiny-eindscan wijkt af"
! grep -Eq '^(URGENT|BLOKKADE|AANDACHT)\|' <<< "$final_audit" || fail "eindaudit bevat een afwijking"

echo "== Definitieve herstelback-up van schone eindsituatie =="
/usr/local/sbin/vwgm-baremetal-backup > "$TASK_ROOT/final-backup.json"
validate_backup
grep -Fq "$CANDIDATE_ID" "$BACKUP_DIR/vwg-m-baremetal-latest-manifest.json" || fail "definitieve back-up mist nieuwe image"
! grep -Fq "$EXPECTED_OLD_IMAGE" "$BACKUP_DIR/vwg-m-baremetal-latest-manifest.json" || fail "definitieve back-up noemt oude image nog"

[[ "$(docker ps -a --format '{{.Names}}' | sort | tr '\n' ' ')" == "meijendel-mysql shiny_meijendel " ]] || fail "containereindsituatie wijkt af"
[[ "$(docker images --format '{{.Repository}}:{{.Tag}}' | sort | tr '\n' ' ')" == "vwgm-mysql:9.7.1 vwgm-shiny:latest " ]] || fail "image-eindsituatie wijkt af"
tmp_state="$STATE_FILE.tmp.$$"
printf '%s\n' "$NEW_COMMIT" > "$tmp_state"
mv "$tmp_state" "$STATE_FILE"
rm -rf -- "$TASK_ROOT"
docker ps -a --no-trunc
docker images --no-trunc
docker system df

SUCCESS=1
printf 'GROEN|mysql-image-update|image=%s|mysql=9.7.1|uid=1999|high=0|critical=0|commit=%s\n' \
  "$CANDIDATE_ID" "$NEW_COMMIT"
