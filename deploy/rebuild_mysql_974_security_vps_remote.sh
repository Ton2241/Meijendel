#!/usr/bin/env bash
set -euo pipefail

ACTIVE_CONTAINER="meijendel-mysql"
CANONICAL_TAG="vwgm-mysql:9.7.4"
MYSQL_ENV="/srv/vwgm/meijendel-mysql/mysql.env"
BACKUP_DIR="/srv/vwgm/backups/vwg-m-baremetal"
BACKUP_ARCHIVE="$BACKUP_DIR/vwg-m-baremetal-latest.tar.gz"
LOCK="/srv/vwgm/deploy-state/production.lock"
STATE_FILE="/srv/vwgm/deploy-state/Meijendel.commit"
MAINT_STATE_FILE="/srv/vwgm/deploy-state/mysql-974-security-rebuild.json"
CANDIDATE_ID=""
EXPECTED_DATA_MOUNT=""
SWITCH_STARTED=0
SUCCESS=0

fail() { printf 'BLOKKADE|mysql-974-security-rebuild|%s\n' "$*" >&2; exit 1; }

version_ge() {
  local actual="${1:?}" minimum="${2:?}" first
  first="$(printf '%s\n%s\n' "$minimum" "$actual" | sort -V | head -n 1)"
  [[ "$first" == "$minimum" ]]
}

require_candidate_packages() {
  local image="${1:?}" package actual minimum
  while IFS='|' read -r package minimum; do
    actual="$(docker run --rm --network none --entrypoint rpm "$image" \
      -q --qf '%{VERSION}-%{RELEASE}\n' "$package")" || fail "pakket ontbreekt in kandidaat: $package"
    version_ge "$actual" "$minimum" ||
      fail "$package is $actual; minimaal vereist is $minimum"
    printf 'GROEN|mysql-974-pakket|%s=%s|minimaal=%s\n' "$package" "$actual" "$minimum"
  done <<'EOF'
libxml2|2.9.13-18.el9_9.1
curl|7.76.1-44.el9_9.1
libcurl|7.76.1-44.el9_9.1
krb5-libs|1.21.1-10.0.1.el9_9.2
EOF
}

audit_candidate_output() {
  local output="${1-}" status="${2:?}" image="${3:?}" tag="${4:?}" short attention
  [[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "ongeldige kandidaatimage voor scan"
  [[ "$status" -eq 0 || "$status" -eq 1 ]] || fail "kandidaatscan faalde technisch met status $status"
  short="${image#sha256:}"
  grep -Fxq "SAMENVATTING|kandidaat-${short:0:12}|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0" <<< "$output" ||
    fail "kandidaat bevat HIGH/CRITICAL of is niet exact gescand"
  ! grep -Eq '^(URGENT|BLOKKADE)\|' <<< "$output" || fail "kandidaatscan is onvolledig"
  while IFS= read -r attention; do
    case "$attention" in
      "AANDACHT|container-hygiene|onverwachte-imagetag=$tag"|AANDACHT\|container-image\|meijendel-mysql\|*|AANDACHT\|container-image\|vwgm-shiny-rollback-* ) ;;
      *) fail "kandidaatscan bevat onverwacht aandachtspunt: $attention" ;;
    esac
  done < <(grep '^AANDACHT|' <<< "$output" || true)
}

single_rollback_name() {
  local input="${1-}" line matches=()
  while IFS= read -r line; do
    [[ "$line" =~ ^meijendel-mysql-rollback-[0-9a-f]{12}$ ]] || continue
    matches[${#matches[@]}]="$line"
  done <<< "$input"
  [[ "${#matches[@]}" -eq 1 ]] || fail "finalisatie vereist exact één MySQL-rollbackcontainer"
  printf '%s\n' "${matches[0]}"
}

ensure_no_maintenance_artifacts() {
  local names="${1-}" tags="${2-}"
  ! grep -Eq '^meijendel-mysql-(rollback|candidate)-[0-9a-f]{12}$' <<< "$names" ||
    fail "bestaande MySQL-kandidaat of -rollback vereist eerst afzonderlijke beoordeling"
  ! grep -Eq '^vwgm-mysql:(rollback|candidate)-[0-9a-f]{12}$' <<< "$tags" ||
    fail "bestaande MySQL-kandidaat- of rollbacktag vereist eerst afzonderlijke beoordeling"
}

maintenance_state_line() {
  local path="${1:?}" output
  output="$(python3 - "$path" <<'PY'
import json,re,sys
data=json.load(open(sys.argv[1],encoding='utf-8'))
patterns={
 'source_commit':r'[0-9a-f]{40}',
 'data_commit':r'[0-9a-f]{40}',
 'active_image':r'sha256:[0-9a-f]{64}',
 'rollback_container':r'meijendel-mysql-rollback-[0-9a-f]{12}',
 'rollback_image':r'sha256:[0-9a-f]{64}',
 'rollback_tag':r'vwgm-mysql:rollback-[0-9a-f]{12}',
 'data_mount':r'/srv/vwgm/[A-Za-z0-9._/-]+',
}
assert data.get('status') == 'rollback-retained'
values=[]
for key,pattern in patterns.items():
    value=data.get(key,'')
    assert isinstance(value,str) and re.fullmatch(pattern,value), key
    values.append(value)
assert data['rollback_container'].endswith(data['source_commit'][:12])
assert data['rollback_tag'].endswith(data['source_commit'][:12])
print('|'.join(values))
PY
)" || fail "ongeldige of onvolledige MySQL-onderhoudsstatus"
  printf '%s\n' "$output"
}

write_maintenance_state() {
  local tmp="$MAINT_STATE_FILE.tmp.$$"
  python3 - "$tmp" "$SOURCE_COMMIT" "$EXPECTED_DATA_COMMIT" "$CANDIDATE_ID" \
    "$PREVIOUS_CONTAINER" "$EXPECTED_OLD_IMAGE" "$PREVIOUS_TAG" "$EXPECTED_DATA_MOUNT" <<'PY'
import datetime,json,os,pathlib,sys
path=pathlib.Path(sys.argv[1])
payload={
 'status':'rollback-retained',
 'created_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'source_commit':sys.argv[2],
 'data_commit':sys.argv[3],
 'active_image':sys.argv[4],
 'rollback_container':sys.argv[5],
 'rollback_image':sys.argv[6],
 'rollback_tag':sys.argv[7],
 'data_mount':sys.argv[8],
}
path.write_text(json.dumps(payload,indent=2,sort_keys=True)+'\n',encoding='utf-8')
os.chmod(path,0o600)
PY
  mv "$tmp" "$MAINT_STATE_FILE"
  maintenance_state_line "$MAINT_STATE_FILE" >/dev/null
}

wait_mysql() {
  local container="${1:?}" attempt version
  for attempt in $(seq 1 150); do
    version="$(docker exec "$container" sh -c \
      'mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION()"' \
      2>/dev/null || true)"
    [[ "$version" == "9.7.4" ]] && return 0
    sleep 2
  done
  docker logs --tail 160 "$container" >&2 || true
  return 1
}

smoke_status() {
  local label="${1:?}" host="${2:?}" path="${3:?}" expected="${4:?}" actual
  actual="$(curl --silent --show-error --insecure --output /dev/null \
    --write-out '%{http_code}' --resolve "$host:443:127.0.0.1" "https://$host$path")"
  [[ "$actual" == "$expected" ]] || fail "rooktest $label verwachtte $expected maar kreeg $actual"
  printf 'GROEN|mysql-974-rooktest|%s|status=%s\n' "$label" "$actual"
}

validate_backup() {
  (cd "$BACKUP_DIR" && sha256sum -c vwg-m-baremetal-latest.tar.gz.sha256)
  /srv/vwgm/vwg-m-linux-app/scripts/restore_check_backup.sh "$BACKUP_ARCHIVE"
}

validate_image_inventory() {
  local rollback_tag="${1-}" tag mysql_seen=0 shiny_seen=0 rollback_seen=0
  while IFS= read -r tag; do
    case "$tag" in
      "$CANONICAL_TAG") mysql_seen=$((mysql_seen + 1)) ;;
      vwgm-shiny:latest) shiny_seen=$((shiny_seen + 1)) ;;
      "$rollback_tag") rollback_seen=$((rollback_seen + 1)) ;;
      vwgm-shiny:rollback-*|"<none>:<none>") ;;
      *) fail "onverwachte imagetag in eindsituatie: $tag" ;;
    esac
  done < <(docker images --format '{{.Repository}}:{{.Tag}}' | sort)
  [[ "$mysql_seen" -eq 1 && "$shiny_seen" -eq 1 ]] || fail "verplichte actieve imagetags ontbreken of zijn dubbel"
  if [[ -n "$rollback_tag" ]]; then
    [[ "$rollback_seen" -eq 1 ]] || fail "exacte MySQL-rollbacktag ontbreekt"
  else
    [[ "$rollback_seen" -eq 0 ]] || fail "onverwachte MySQL-rollbacktag aanwezig"
  fi
}

scan_candidate() {
  local tag="${1:?}" output status=0
  output="$(/usr/local/libexec/vwgm-admin/vulnerability-audit-root --image "$CANDIDATE_ID" 2>&1)" || status=$?
  printf '%s\n' "$output"
  audit_candidate_output "$output" "$status" "$CANDIDATE_ID" "$tag"
}

scan_active_with_rollback() {
  local rollback_container="${1:?}" output status=0 attention
  output="$(/usr/local/libexec/vwgm-admin/vulnerability-audit-root 2>&1)" || status=$?
  printf '%s\n' "$output"
  [[ "$status" -eq 0 || "$status" -eq 1 ]] || fail "actieve scan faalde technisch met status $status"
  grep -Fxq 'SAMENVATTING|meijendel-mysql|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' <<< "$output" ||
    fail "nieuwe actieve MySQL-image is niet 0 HIGH/0 CRITICAL"
  ! grep -Eq '^(URGENT|BLOKKADE)\|' <<< "$output" || fail "actieve scan is onvolledig"
  grep -Fq "SAMENVATTING|$rollback_container|" <<< "$output" || fail "exacte rollbackscan ontbreekt"
  while IFS= read -r attention; do
    case "$attention" in
      "AANDACHT|container-image|$rollback_container|"*|AANDACHT\|container-image\|vwgm-shiny-rollback-* ) ;;
      *) fail "actieve scan bevat onverwacht aandachtspunt: $attention" ;;
    esac
  done < <(grep '^AANDACHT|' <<< "$output" || true)
}

rollback_or_cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [[ "$SUCCESS" -ne 1 ]]; then
    if [[ "$SWITCH_STARTED" -eq 1 ]] && docker inspect "$PREVIOUS_CONTAINER" >/dev/null 2>&1; then
      docker rm -f "$ACTIVE_CONTAINER" >/dev/null 2>&1 || true
      docker tag "$EXPECTED_OLD_IMAGE" "$CANONICAL_TAG" >/dev/null 2>&1 || true
      docker rename "$PREVIOUS_CONTAINER" "$ACTIVE_CONTAINER" >/dev/null 2>&1 || true
      docker start "$ACTIVE_CONTAINER" >/dev/null 2>&1 || true
      wait_mysql "$ACTIVE_CONTAINER" || true
    elif [[ "$SWITCH_STARTED" -eq 1 ]] && docker inspect "$ACTIVE_CONTAINER" >/dev/null 2>&1; then
      if [[ "$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER" 2>/dev/null || true)" == "$EXPECTED_OLD_IMAGE" ]]; then
        docker start "$ACTIVE_CONTAINER" >/dev/null 2>&1 || true
        wait_mysql "$ACTIVE_CONTAINER" || true
      fi
    fi
    docker rm -f "$CANDIDATE_CONTAINER" >/dev/null 2>&1 || true
    docker image rm "$CANDIDATE_TAG" >/dev/null 2>&1 || true
    docker image rm "$PREVIOUS_TAG" >/dev/null 2>&1 || true
    if [[ -n "$CANDIDATE_ID" ]] && ! docker ps -a --format '{{.Image}}' | grep -Fxq "$CANDIDATE_ID"; then
      docker image rm "$CANDIDATE_ID" >/dev/null 2>&1 || true
    fi
    [[ -z "${TASK_ROOT:-}" ]] || rm -rf -- "$TASK_ROOT"
  fi
  exit "$status"
}

finalize_current() {
  local rollback_container rollback_tag rollback_image output status=0 attention discovered
  [[ "$(docker inspect --format '{{.State.Status}}' "$ACTIVE_CONTAINER")" == "running" ]] || fail "actieve MySQL draait niet"
  [[ "$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER")" == "$EXPECTED_OLD_IMAGE" ]] || fail "actieve eindimage wijkt af"
  [[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/var/lib/mysql\"}}{{.Source}}{{end}}{{end}}' "$ACTIVE_CONTAINER")" == "$EXPECTED_DATA_MOUNT" ]] || fail "actieve datamount wijkt af"
  wait_mysql "$ACTIVE_CONTAINER" || fail "actieve MySQL werd niet gereed"
  discovered="$(single_rollback_name "$(docker ps -a --format '{{.Names}}')")" || return 1
  [[ "$discovered" == "$PREVIOUS_CONTAINER" ]] || fail "aangetroffen rollback wijkt af van de gebonden onderhoudsstatus"
  rollback_container="$PREVIOUS_CONTAINER"
  rollback_tag="$PREVIOUS_TAG"
  rollback_image="$(docker inspect --format '{{.Image}}' "$rollback_container")"
  [[ "$rollback_image" == "$EXPECTED_ROLLBACK_IMAGE" ]] || fail "rollbackimage wijkt af van de gebonden onderhoudsstatus"
  [[ "$(docker inspect --format '{{.State.Status}}' "$rollback_container")" == "exited" ]] || fail "rollbackcontainer is niet gestopt"
  [[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/var/lib/mysql\"}}{{.Source}}{{end}}{{end}}' "$rollback_container")" == "$EXPECTED_DATA_MOUNT" ]] || fail "rollbackcontainermount wijkt af"
  [[ "$(docker image inspect --format '{{.Id}}' "$rollback_tag")" == "$rollback_image" ]] || fail "rollbacktag wijst niet naar rollbackimage"

  docker rm "$rollback_container" >/dev/null
  docker image rm "$rollback_tag" >/dev/null
  if docker image inspect "$rollback_image" >/dev/null 2>&1; then
    docker image rm "$rollback_image" >/dev/null
  fi

  output="$(/usr/local/libexec/vwgm-admin/vulnerability-audit-root 2>&1)" || status=$?
  printf '%s\n' "$output"
  [[ "$status" -eq 0 || "$status" -eq 1 ]] || fail "eindaudit faalde technisch"
  grep -Fxq 'SAMENVATTING|meijendel-mysql|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' <<< "$output" || fail "actieve MySQL-eindscan is niet 0/0"
  ! grep -Eq '^(URGENT|BLOKKADE)\|' <<< "$output" || fail "eindaudit is onvolledig"
  while IFS= read -r attention; do
    case "$attention" in AANDACHT\|container-image\|vwgm-shiny-rollback-* ) ;; *) fail "eindaudit bevat onverwacht aandachtspunt: $attention" ;; esac
  done < <(grep '^AANDACHT|' <<< "$output" || true)
  /usr/local/libexec/vwgm-admin/check-caddy-mysql-isolation
  smoke_status publieke-home www.vwg-m.nl /welkom/index.asp 200
  smoke_status mysql-soortpagina www.vwg-m.nl '/soorten/vogel.asp?id=90' 200
  smoke_status leden-afgeschermd www.vwg-m.nl /leden/member-auth 401
  smoke_status shiny-afgeschermd www.vwg-m.nl /shiny_meijendel/ 401
  /usr/local/sbin/vwgm-baremetal-backup > /tmp/vwgm-mysql974-security-finalize-backup.json
  validate_backup
  grep -Fq "$EXPECTED_OLD_IMAGE" "$BACKUP_DIR/vwg-m-baremetal-latest-manifest.json" || fail "definitieve back-up mist actieve image"
  [[ "$(cat "$STATE_FILE")" == "$EXPECTED_DATA_COMMIT" ]] || fail "Meijendel-datarelease wijzigde tijdens finalisatie"
  rm -f /tmp/vwgm-mysql974-security-finalize-backup.json
  validate_image_inventory ""
  rm -f "$MAINT_STATE_FILE"
  SUCCESS=1
  printf 'GROEN|mysql-974-security-finalisatie|image=%s|mysql=9.7.4|uid=1999|high=0|critical=0|data_commit=%s\n' \
    "$EXPECTED_OLD_IMAGE" "$EXPECTED_DATA_COMMIT"
}

main() {
  [[ "$EUID" -eq 0 && "$#" -eq 5 ]] || fail "root, bronmap, broncommit, actieve image, datarelease en modus vereist"
  local stage="$1" source_commit="$2" old_image="$3" data_commit="$4" finalize_only="$5"
  [[ "$stage" =~ ^/var/tmp/vwgm-mysql974-security-root-[A-Za-z0-9_]+$ ]] || fail "ongeldige root-bronmap"
  [[ "$(stat -c '%u:%a' "$stage")" == "0:700" ]] || fail "root-bronmap moet 0700 zijn"
  [[ "$source_commit" =~ ^[0-9a-f]{40}$ && "$old_image" =~ ^sha256:[0-9a-f]{64}$ && "$data_commit" =~ ^[0-9a-f]{40}$ ]] || fail "ongeldige bronbinding"
  [[ "$finalize_only" == 0 || "$finalize_only" == 1 ]] || fail "ongeldige finalisatiemodus"

  SOURCE_COMMIT="$source_commit"
  EXPECTED_OLD_IMAGE="$old_image"
  EXPECTED_DATA_COMMIT="$data_commit"
  SHORT_COMMIT="${source_commit:0:12}"
  PREVIOUS_CONTAINER="meijendel-mysql-rollback-$SHORT_COMMIT"
  CANDIDATE_CONTAINER="meijendel-mysql-candidate-$SHORT_COMMIT"
  CANDIDATE_TAG="vwgm-mysql:candidate-$SHORT_COMMIT"
  PREVIOUS_TAG="vwgm-mysql:rollback-$SHORT_COMMIT"
  TASK_ROOT="/srv/vwgm/mysql-974-security-task-$SHORT_COMMIT"
  TEST_DATA="$TASK_ROOT/data"
  TEST_DUMP="$TASK_ROOT/meijendel.sql.gz"

  [[ -d "$LOCK" ]] || fail "gedeelde productielock ontbreekt"
  [[ -f "$MYSQL_ENV" ]] || fail "MySQL-env ontbreekt"
  [[ "$(cat "$STATE_FILE")" == "$EXPECTED_DATA_COMMIT" ]] || fail "Meijendel-datarelease wijzigde vóór onderhoud"
  [[ "$(docker inspect --format '{{.State.Status}}' "$ACTIVE_CONTAINER")" == "running" ]] || fail "actieve MySQL draait niet"
  [[ "$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER")" == "$EXPECTED_OLD_IMAGE" ]] || fail "actieve image veranderde"
  EXPECTED_DATA_MOUNT="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/var/lib/mysql\"}}{{.Source}}{{end}}{{end}}' "$ACTIVE_CONTAINER")"
  [[ -n "$EXPECTED_DATA_MOUNT" && -d "$EXPECTED_DATA_MOUNT" ]] || fail "actieve datamount ontbreekt"
  [[ "$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$ACTIVE_CONTAINER")" == "unless-stopped" ]] || fail "restartbeleid wijkt af"
  docker port "$ACTIVE_CONTAINER" 3306/tcp | grep -Fxq '127.0.0.1:3307' || fail "poortbinding wijkt af"
  [[ "$(docker exec "$ACTIVE_CONTAINER" id -u mysql)" == 1999 && "$(docker exec "$ACTIVE_CONTAINER" id -g mysql)" == 1999 ]] || fail "MySQL UID/GID wijkt af"
  wait_mysql "$ACTIVE_CONTAINER" || fail "actieve MySQL werd niet gereed"

  trap rollback_or_cleanup EXIT INT TERM
  if [[ "$finalize_only" == 1 ]]; then
    [[ -f "$MAINT_STATE_FILE" ]] || fail "gebonden MySQL-onderhoudsstatus ontbreekt"
    local state_line state_source state_data state_active state_rollback_container state_rollback_image state_rollback_tag state_mount
    state_line="$(maintenance_state_line "$MAINT_STATE_FILE")"
    IFS='|' read -r state_source state_data state_active state_rollback_container state_rollback_image state_rollback_tag state_mount <<< "$state_line"
    [[ "$state_data" == "$EXPECTED_DATA_COMMIT" ]] || fail "onderhoudsstatus hoort bij een andere datarelease"
    [[ "$state_active" == "$EXPECTED_OLD_IMAGE" ]] || fail "onderhoudsstatus hoort bij een andere actieve image"
    [[ "$state_mount" == "$EXPECTED_DATA_MOUNT" ]] || fail "onderhoudsstatus hoort bij een andere datamount"
    SOURCE_COMMIT="$state_source"
    PREVIOUS_CONTAINER="$state_rollback_container"
    EXPECTED_ROLLBACK_IMAGE="$state_rollback_image"
    PREVIOUS_TAG="$state_rollback_tag"
    finalize_current
    return 0
  fi

  [[ ! -e "$MAINT_STATE_FILE" ]] || fail "eerdere MySQL-onderhoudsstatus vereist eerst finalisatie of beoordeling"
  ensure_no_maintenance_artifacts \
    "$(docker ps -a --format '{{.Names}}')" \
    "$(docker images --format '{{.Repository}}:{{.Tag}}')"
  [[ ! -e "$TASK_ROOT" ]] || fail "taakmap bestaat al"
  ! docker inspect "$PREVIOUS_CONTAINER" >/dev/null 2>&1 || fail "rollbackcontainer bestaat al"
  ! docker inspect "$CANDIDATE_CONTAINER" >/dev/null 2>&1 || fail "kandidaatcontainer bestaat al"
  ! docker image inspect "$CANDIDATE_TAG" >/dev/null 2>&1 || fail "kandidaattag bestaat al"

  umask 077
  install -d -m 0700 "$TASK_ROOT"
  echo "== Verse herstelback-up vóór imagewisseling =="
  /usr/local/sbin/vwgm-baremetal-backup > "$TASK_ROOT/pre-backup.json"
  validate_backup
  grep -Fq "$EXPECTED_OLD_IMAGE" "$BACKUP_DIR/vwg-m-baremetal-latest-manifest.json" || fail "oude actieve image ontbreekt in back-upmanifest"

  echo "== Verse no-cache MySQL 9.7.4-kandidaat =="
  docker buildx build --builder default --platform linux/amd64 --pull --no-cache --load \
    --file "$stage/Dockerfile.9.7.4" --tag "$CANDIDATE_TAG" "$stage"
  CANDIDATE_ID="$(docker image inspect --format '{{.Id}}' "$CANDIDATE_TAG")"
  [[ "$CANDIDATE_ID" =~ ^sha256:[0-9a-f]{64}$ && "$CANDIDATE_ID" != "$EXPECTED_OLD_IMAGE" ]] || fail "kandidaat-ID ontbreekt of is niet nieuw"
  docker run --rm --network none --entrypoint sh "$CANDIDATE_ID" -c \
    'test "$(id -u mysql)" -eq 1999 && test "$(id -g mysql)" -eq 1999 && mysql --version | grep -Fq "Ver 9.7.4 " && gosu --version'
  require_candidate_packages "$CANDIDATE_ID"
  scan_candidate "$CANDIDATE_TAG"

  echo "== Logische proefimport en volledige 9.7.4→9.7.4-validatie =="
  docker exec "$ACTIVE_CONTAINER" sh -c \
    'exec mysqldump --single-transaction --routines --triggers --events --hex-blob --set-gtid-purged=OFF --no-tablespaces -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' \
    | gzip -c > "$TEST_DUMP"
  gzip -t "$TEST_DUMP"
  install -d -o 1999 -g 1999 -m 0700 "$TEST_DATA"
  docker run -d --name "$CANDIDATE_CONTAINER" --restart no --network none --memory 1536m --cpus 1 \
    --env-file "$MYSQL_ENV" -v "$TEST_DATA:/var/lib/mysql" "$CANDIDATE_ID" \
    --local-infile=0 --mysqlx=0 --binlog-expire-logs-seconds=259200 --innodb-redo-log-capacity=536870912 >/dev/null
  wait_mysql "$CANDIDATE_CONTAINER" || fail "proefcontainer werd niet gereed"
  gzip -dc "$TEST_DUMP" | docker exec -i "$CANDIDATE_CONTAINER" sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
  local mysql_user mysql_database
  mysql_user="$(docker exec "$CANDIDATE_CONTAINER" printenv MYSQL_USER)"
  mysql_database="$(docker exec "$CANDIDATE_CONTAINER" printenv MYSQL_DATABASE)"
  [[ "$mysql_user" =~ ^[A-Za-z0-9_]+$ && "$mysql_database" =~ ^[A-Za-z0-9_]+$ ]] || fail "onveilige MySQL-envnaam"
  docker exec -i "$CANDIDATE_CONTAINER" sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' <<SQL
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '$mysql_user'@'%';
GRANT SELECT ON \`$mysql_database\`.* TO '$mysql_user'@'%';
SQL
  bash "$stage/validate-mysql" "$ACTIVE_CONTAINER" "$CANDIDATE_CONTAINER" 1999 1999 9.7.4 9.7.4
  docker rm -f "$CANDIDATE_CONTAINER" >/dev/null
  rm -rf -- "$TEST_DATA" "$TEST_DUMP"

  echo "== Gecontroleerde imagewisseling met automatische rollback =="
  SWITCH_STARTED=1
  docker stop "$ACTIVE_CONTAINER" >/dev/null
  docker rename "$ACTIVE_CONTAINER" "$PREVIOUS_CONTAINER"
  docker tag "$EXPECTED_OLD_IMAGE" "$PREVIOUS_TAG"
  docker tag "$CANDIDATE_ID" "$CANONICAL_TAG"
  docker image rm "$CANDIDATE_TAG" >/dev/null
  docker run -d --name "$ACTIVE_CONTAINER" --restart unless-stopped \
    --env-file "$MYSQL_ENV" -p 127.0.0.1:3307:3306 \
    -v "$EXPECTED_DATA_MOUNT:/var/lib/mysql" "$CANDIDATE_ID" \
    --local-infile=0 --mysqlx=0 --binlog-expire-logs-seconds=259200 --innodb-redo-log-capacity=536870912 >/dev/null
  wait_mysql "$ACTIVE_CONTAINER" || fail "nieuwe actieve MySQL werd niet gereed"
  [[ "$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER")" == "$CANDIDATE_ID" ]] || fail "actieve image wijkt af"
  [[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/var/lib/mysql\"}}{{.Source}}{{end}}{{end}}' "$ACTIVE_CONTAINER")" == "$EXPECTED_DATA_MOUNT" ]] || fail "actieve datamount wijkt af"
  /usr/local/libexec/vwgm-admin/check-caddy-mysql-isolation
  smoke_status publieke-home www.vwg-m.nl /welkom/index.asp 200
  smoke_status mysql-soortpagina www.vwg-m.nl '/soorten/vogel.asp?id=90' 200
  smoke_status leden-afgeschermd www.vwg-m.nl /leden/member-auth 401
  smoke_status shiny-afgeschermd www.vwg-m.nl /shiny_meijendel/ 401
  smoke_status app-redirect app.vwg-m.nl '/welkom/index.asp?bron=app' 308
  smoke_status hoofddomein-redirect vwg-m.nl /welkom/index.asp 301

  scan_active_with_rollback "$PREVIOUS_CONTAINER"
  /usr/local/sbin/vwgm-baremetal-backup > "$TASK_ROOT/post-backup.json"
  validate_backup
  grep -Fq "$CANDIDATE_ID" "$BACKUP_DIR/vwg-m-baremetal-latest-manifest.json" || fail "definitieve back-up mist nieuwe image"
  grep -Fq "$EXPECTED_OLD_IMAGE" "$BACKUP_DIR/vwg-m-baremetal-latest-manifest.json" || fail "definitieve back-up mist rollbackimage"
  [[ "$(cat "$STATE_FILE")" == "$EXPECTED_DATA_COMMIT" ]] || fail "Meijendel-datarelease wijzigde tijdens onderhoud"
  validate_image_inventory "$PREVIOUS_TAG"
  rm -rf -- "$TASK_ROOT"
  write_maintenance_state
  SUCCESS=1
  printf 'GROEN|mysql-974-security-rebuild|rollback=behouden|image=%s|rollback_image=%s|mysql=9.7.4|uid=1999|high=0|critical=0|data_commit=%s\n' \
    "$CANDIDATE_ID" "$EXPECTED_OLD_IMAGE" "$EXPECTED_DATA_COMMIT"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
