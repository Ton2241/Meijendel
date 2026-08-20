#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
REMOTE_BASE="${REMOTE_BASE:-/srv/vwgm}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
VWG_PROJECT="${VWG_PROJECT:-$LOCAL_REPO/../VWG_Project}"
VWG_M="${VWG_M:-$LOCAL_REPO/../VWG_M}"
AUDIT_SCRIPT="$VWG_PROJECT/scripts/vulnerability_audit_vps.sh"
SMOKE_SCRIPT="$VWG_M/website/vwg-m-linux-app/scripts/smoke_vps.sh"
ISOLATION_SCRIPT="$VWG_M/website/vwg-m-linux-app/scripts/check_caddy_mysql_isolation_vps.sh"
VALIDATE_HELPER="$SCRIPT_DIR/validate_mysql_uid_migration_vps_remote.sh"
LOCAL_IMAGE_DIR="$SCRIPT_DIR/mysql_image"
REMOTE_BUILD_DIR="$REMOTE_BASE/meijendel-mysql-image"
MYSQL_ENV="$REMOTE_BASE/meijendel-mysql/mysql.env"
NEW_DATA_ROOT="$REMOTE_BASE/meijendel-mysql-971-uid1999"
NEW_DATA="$NEW_DATA_ROOT/data"
ACTIVE_CONTAINER="meijendel-mysql"
ROLLBACK_CONTAINER="meijendel-mysql-971-uid999-rollback-20260820"
LEGACY_ROLLBACK_CONTAINER="meijendel-mysql-95-rollback-20260813T104315Z"
MYSQL_UID=1999
MYSQL_GID=1999
APPLY=0
YES=0
SUCCESS=0
SWITCH_STARTED=0
CANDIDATE_ID=""
OLD_IMAGE_ID=""
CANDIDATE_TAG=""
CANDIDATE_CONTAINER=""
MIGRATION_DUMP=""

while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help)
      echo "Gebruik: deploy/migrate_mysql_uid_vps.sh [--apply --yes]"
      exit 0
      ;;
    *) echo "Onbekende optie: $1" >&2; exit 2 ;;
  esac
  shift
done

source "$SCRIPT_DIR/production_guard.sh"

rollback_or_cleanup() {
  [[ -n "$CANDIDATE_CONTAINER" ]] || return 0
  ssh -i "$SSH_KEY" "$VPS" \
    "ACTIVE_CONTAINER='$ACTIVE_CONTAINER' ROLLBACK_CONTAINER='$ROLLBACK_CONTAINER' CANDIDATE_CONTAINER='$CANDIDATE_CONTAINER' CANDIDATE_ID='$CANDIDATE_ID' OLD_IMAGE_ID='$OLD_IMAGE_ID' CANDIDATE_TAG='$CANDIDATE_TAG' NEW_DATA_ROOT='$NEW_DATA_ROOT' MIGRATION_DUMP='$MIGRATION_DUMP' SWITCH_STARTED='$SWITCH_STARTED' bash -s" <<'REMOTE'
set -euo pipefail
if [[ "$SWITCH_STARTED" -eq 1 ]] && docker inspect "$ROLLBACK_CONTAINER" >/dev/null 2>&1; then
  docker rm -f "$ACTIVE_CONTAINER" >/dev/null 2>&1 || true
  docker tag "$OLD_IMAGE_ID" vwgm-mysql:9.7.1
  docker rename "$ROLLBACK_CONTAINER" "$ACTIVE_CONTAINER"
  docker start "$ACTIVE_CONTAINER" >/dev/null
  for attempt in $(seq 1 60); do
    if docker exec "$ACTIVE_CONTAINER" sh -c \
        'mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' >/dev/null 2>&1; then
      break
    fi
    [[ "$attempt" -lt 60 ]] || exit 1
    sleep 2
  done
fi
docker rm -f "$CANDIDATE_CONTAINER" >/dev/null 2>&1 || true
if [[ -n "$NEW_DATA_ROOT" && "$NEW_DATA_ROOT" == /srv/vwgm/meijendel-mysql-971-uid1999 ]]; then
  sudo rm -rf -- "$NEW_DATA_ROOT"
fi
[[ -z "$MIGRATION_DUMP" ]] || rm -f -- "$MIGRATION_DUMP"
[[ -z "$CANDIDATE_TAG" ]] || docker image rm "$CANDIDATE_TAG" >/dev/null 2>&1 || true
if [[ -n "$CANDIDATE_ID" ]] && ! docker ps -a --format '{{.Image}}' | grep -Fxq "$CANDIDATE_ID"; then
  docker image rm "$CANDIDATE_ID" >/dev/null 2>&1 || true
fi
REMOTE
}

finish() {
  status=$?
  trap - EXIT INT TERM
  if [[ "$SUCCESS" -ne 1 ]]; then
    rollback_or_cleanup ||
      printf 'URGENT: automatische MySQL-rollback/opruiming faalde; controleer productie direct.\n' >&2
  fi
  guard_release_lock
  exit "$status"
}
trap finish EXIT INT TERM

[[ -f "$LOCAL_IMAGE_DIR/Dockerfile.9.7.1" ]] || guard_die "MySQL-Dockerfile ontbreekt."
[[ -x "$VALIDATE_HELPER" ]] || guard_die "UID-migratievalidator ontbreekt of is niet uitvoerbaar."
[[ -x "$AUDIT_SCRIPT" ]] || guard_die "kwetsbaarheidsaudit ontbreekt."
[[ -x "$SMOKE_SCRIPT" ]] || guard_die "rooktest ontbreekt."
[[ -x "$ISOLATION_SCRIPT" ]] || guard_die "Caddy/MySQL-isolatiecontrole ontbreekt."

guard_baseline
"$LOCAL_REPO/scripts/test_container_image_definitions.sh"
"$LOCAL_REPO/scripts/test_mysql_uid_migration.sh"

short_commit="${DEPLOY_LOCAL_COMMIT:0:12}"
CANDIDATE_TAG="vwgm-mysql:uid1999-candidate-$short_commit"
CANDIDATE_CONTAINER="meijendel-mysql-uid1999-candidate-$short_commit"
MIGRATION_DUMP="$REMOTE_BASE/backups/meijendel-mysql/uid-migration-$short_commit.sql.gz"

echo "== UID-migratiemanifest en rsync-dry-run =="
printf '%s\n' \
  "deploy/mysql_image/Dockerfile.9.7.1 -> $REMOTE_BUILD_DIR/" \
  "mysql UID:GID 999:999 -> $MYSQL_UID:$MYSQL_GID" \
  "nieuwe logische datamap -> $NEW_DATA" \
  "actieve container -> rollback $ROLLBACK_CONTAINER"
rsync -az --checksum --delay-updates --itemize-changes --dry-run \
  -e "ssh -i $SSH_KEY" "$LOCAL_IMAGE_DIR/" "$VPS:$REMOTE_BUILD_DIR/"

ssh -i "$SSH_KEY" "$VPS" \
  "ACTIVE_CONTAINER='$ACTIVE_CONTAINER' ROLLBACK_CONTAINER='$ROLLBACK_CONTAINER' LEGACY_ROLLBACK_CONTAINER='$LEGACY_ROLLBACK_CONTAINER' NEW_DATA_ROOT='$NEW_DATA_ROOT' MYSQL_UID='$MYSQL_UID' MYSQL_GID='$MYSQL_GID' MYSQL_ENV='$MYSQL_ENV' bash -s" <<'REMOTE'
set -euo pipefail
docker ps --format '{{.Names}}' | grep -qx "$ACTIVE_CONTAINER"
docker inspect "$LEGACY_ROLLBACK_CONTAINER" >/dev/null
! docker inspect "$ROLLBACK_CONTAINER" >/dev/null 2>&1
test ! -e "$NEW_DATA_ROOT"
test -f "$MYSQL_ENV"
test "$(docker exec "$ACTIVE_CONTAINER" id -u mysql)" -eq 999
test "$(docker exec "$ACTIVE_CONTAINER" id -g mysql)" -eq 999
! getent passwd "$MYSQL_UID" >/dev/null
! getent group "$MYSQL_GID" >/dev/null
test "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Source}}{{end}}{{end}}' "$ACTIVE_CONTAINER")" = "/srv/vwgm/meijendel-mysql-971-cutover-20260813T104315Z/data"
test "$(docker inspect --format '{{.HostConfig.PortBindings}}' "$ACTIVE_CONTAINER")" != "map[]"
docker exec "$ACTIVE_CONTAINER" sh -c 'mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent'
sudo test -f /srv/vwgm/backups/vwg-m-baremetal/vwg-m-baremetal-latest.tar.gz.sha256
cd /srv/vwgm/backups/vwg-m-baremetal
sudo sha256sum -c vwg-m-baremetal-latest.tar.gz.sha256
sudo test ! -e /srv/vwgm/deploy-state/production.lock
REMOTE

"$ISOLATION_SCRIPT"
VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl "$SMOKE_SCRIPT"
"$AUDIT_SCRIPT" --containers-only

if [[ "$APPLY" -ne 1 ]]; then
  echo "Preflight klaar; productie is niet gewijzigd. Gebruik --apply --yes na beoordeling."
  exit 0
fi
[[ "$YES" -eq 1 ]] || guard_die "UID-migratie vereist --apply --yes."
guard_acquire_lock

ssh -i "$SSH_KEY" "$VPS" "mkdir -p '$REMOTE_BUILD_DIR'"
rsync -az --checksum --delay-updates --itemize-changes \
  -e "ssh -i $SSH_KEY" "$LOCAL_IMAGE_DIR/" "$VPS:$REMOTE_BUILD_DIR/"

echo "== Bouw verse MySQL-UID-kandidaat =="
build_output="$(ssh -i "$SSH_KEY" "$VPS" \
  "REMOTE_BUILD_DIR='$REMOTE_BUILD_DIR' CANDIDATE_TAG='$CANDIDATE_TAG' BUILDER_NAME='vwgm-mysql-uid-$short_commit' bash -s" <<'REMOTE'
set -euo pipefail
cd "$REMOTE_BUILD_DIR"
! docker image inspect "$CANDIDATE_TAG" >/dev/null 2>&1
docker buildx create --name "$BUILDER_NAME" --driver docker-container >/dev/null
cleanup_builder() {
  docker buildx rm "$BUILDER_NAME" >/dev/null 2>&1 || true
  docker image rm moby/buildkit:buildx-stable-1 >/dev/null 2>&1 || true
}
trap cleanup_builder EXIT
docker buildx build --builder "$BUILDER_NAME" --platform linux/amd64 \
  --pull --no-cache --load --file Dockerfile.9.7.1 --tag "$CANDIDATE_TAG" .
candidate_id="$(docker image inspect --format '{{.Id}}' "$CANDIDATE_TAG")"
[[ "$candidate_id" =~ ^sha256:[0-9a-f]{64}$ ]]
docker run --rm "$candidate_id" sh -c 'test "$(id -u mysql)" -eq 1999 && test "$(id -g mysql)" -eq 1999 && mysql --version | grep -Fq "Ver 9.7.1 "'
printf 'CANDIDATE_ID=%s\n' "$candidate_id"
REMOTE
)"
printf '%s\n' "$build_output"
CANDIDATE_ID="$(sed -n 's/^CANDIDATE_ID=//p' <<<"$build_output" | tail -n 1)"
[[ "$CANDIDATE_ID" =~ ^sha256:[0-9a-f]{64}$ ]] || guard_die "kandidaat-image-ID ontbreekt."

echo "== Scan exacte kandidaat-image-ID =="
set +e
candidate_audit="$("$AUDIT_SCRIPT" --containers-only --image "$CANDIDATE_ID" 2>&1)"
candidate_audit_status=$?
set -e
printf '%s\n' "$candidate_audit"
candidate_short="${CANDIDATE_ID#sha256:}"
grep -Fq "SAMENVATTING|kandidaat-${candidate_short:0:12}|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0" \
  <<<"$candidate_audit" || guard_die "kandidaat heeft HIGH/CRITICAL-bevindingen of is niet exact gescand."
if [[ "$candidate_audit_status" -ne 0 ]] && grep -Eq '^(URGENT|BLOKKADE)\|' <<<"$candidate_audit"; then
  guard_die "kandidaataudit bevat een urgente blokkade."
fi

OLD_IMAGE_ID="$(ssh -i "$SSH_KEY" "$VPS" "docker inspect --format '{{.Image}}' '$ACTIVE_CONTAINER'")"
[[ "$OLD_IMAGE_ID" =~ ^sha256:[0-9a-f]{64}$ ]] || guard_die "actieve image-ID ontbreekt."

echo "== Maak logische dump en test de geïsoleerde kandidaat =="
ssh -i "$SSH_KEY" "$VPS" \
  "ACTIVE_CONTAINER='$ACTIVE_CONTAINER' CANDIDATE_CONTAINER='$CANDIDATE_CONTAINER' CANDIDATE_ID='$CANDIDATE_ID' NEW_DATA_ROOT='$NEW_DATA_ROOT' NEW_DATA='$NEW_DATA' MYSQL_ENV='$MYSQL_ENV' MIGRATION_DUMP='$MIGRATION_DUMP' MYSQL_UID='$MYSQL_UID' MYSQL_GID='$MYSQL_GID' bash -s" <<'REMOTE'
set -euo pipefail
test ! -e "$NEW_DATA_ROOT"
test ! -e "$MIGRATION_DUMP"
docker exec "$ACTIVE_CONTAINER" sh -c '
  exec mysqldump --single-transaction --routines --triggers --events --hex-blob \
    --set-gtid-purged=OFF --no-tablespaces -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"
' | gzip -c > "$MIGRATION_DUMP.tmp"
test -s "$MIGRATION_DUMP.tmp"
mv "$MIGRATION_DUMP.tmp" "$MIGRATION_DUMP"
chmod 600 "$MIGRATION_DUMP"
sudo install -d -o "$MYSQL_UID" -g "$MYSQL_GID" -m 0700 "$NEW_DATA"
docker run -d --name "$CANDIDATE_CONTAINER" --restart no \
  --env-file "$MYSQL_ENV" -p 127.0.0.1:3308:3306 \
  -v "$NEW_DATA:/var/lib/mysql" "$CANDIDATE_ID" --local-infile=0 --mysqlx=0 >/dev/null
for attempt in $(seq 1 120); do
  if docker exec "$CANDIDATE_CONTAINER" sh -c \
      'mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' >/dev/null 2>&1; then
    break
  fi
  [[ "$attempt" -lt 120 ]] || { docker logs --tail 160 "$CANDIDATE_CONTAINER" >&2; exit 1; }
  sleep 2
done
gzip -dc "$MIGRATION_DUMP" | docker exec -i "$CANDIDATE_CONTAINER" sh -c \
  'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
mysql_user="$(docker exec "$CANDIDATE_CONTAINER" printenv MYSQL_USER)"
mysql_database="$(docker exec "$CANDIDATE_CONTAINER" printenv MYSQL_DATABASE)"
[[ "$mysql_user" =~ ^[A-Za-z0-9_]+$ && "$mysql_database" =~ ^[A-Za-z0-9_]+$ ]]
docker exec -i "$CANDIDATE_CONTAINER" sh -c \
  'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' <<SQL
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '$mysql_user'@'%';
GRANT SELECT ON \`$mysql_database\`.* TO '$mysql_user'@'%';
SQL
test -z "$(sudo find "$NEW_DATA" -xdev \( ! -uid "$MYSQL_UID" -o ! -gid "$MYSQL_GID" \) -print -quit)"
REMOTE

ssh -i "$SSH_KEY" "$VPS" \
  "bash -s -- '$ACTIVE_CONTAINER' '$CANDIDATE_CONTAINER' '$MYSQL_UID' '$MYSQL_GID'" \
  < "$VALIDATE_HELPER"

echo "== Activeer kandidaat met automatische rollback =="
SWITCH_STARTED=1
ssh -i "$SSH_KEY" "$VPS" \
  "ACTIVE_CONTAINER='$ACTIVE_CONTAINER' ROLLBACK_CONTAINER='$ROLLBACK_CONTAINER' CANDIDATE_CONTAINER='$CANDIDATE_CONTAINER' CANDIDATE_ID='$CANDIDATE_ID' OLD_IMAGE_ID='$OLD_IMAGE_ID' NEW_DATA='$NEW_DATA' MYSQL_ENV='$MYSQL_ENV' bash -s" <<'REMOTE'
set -euo pipefail
docker stop "$CANDIDATE_CONTAINER" >/dev/null
docker stop "$ACTIVE_CONTAINER" >/dev/null
docker rename "$ACTIVE_CONTAINER" "$ROLLBACK_CONTAINER"
docker rm "$CANDIDATE_CONTAINER" >/dev/null
docker tag "$OLD_IMAGE_ID" vwgm-mysql:9.7.1-uid999-rollback
docker tag "$CANDIDATE_ID" vwgm-mysql:9.7.1
docker run -d --name "$ACTIVE_CONTAINER" --restart unless-stopped \
  --env-file "$MYSQL_ENV" -p 127.0.0.1:3307:3306 \
  -v "$NEW_DATA:/var/lib/mysql" "$CANDIDATE_ID" --local-infile=0 --mysqlx=0 >/dev/null
for attempt in $(seq 1 60); do
  if docker exec "$ACTIVE_CONTAINER" sh -c \
      'mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' >/dev/null 2>&1; then
    break
  fi
  [[ "$attempt" -lt 60 ]] || { docker logs --tail 160 "$ACTIVE_CONTAINER" >&2; exit 1; }
  sleep 2
done
[[ "$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER")" == "$CANDIDATE_ID" ]]
[[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Source}}{{end}}{{end}}' "$ACTIVE_CONTAINER")" == "$NEW_DATA" ]]
REMOTE

ssh -i "$SSH_KEY" "$VPS" \
  "bash -s -- '$ACTIVE_CONTAINER' '$ACTIVE_CONTAINER' '$MYSQL_UID' '$MYSQL_GID'" \
  < "$VALIDATE_HELPER"
"$ISOLATION_SCRIPT"
VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl "$SMOKE_SCRIPT"

echo "== Maak en valideer verse herstelback-up =="
ssh -i "$SSH_KEY" "$VPS" \
  "sudo /usr/local/sbin/vwgm-baremetal-backup >/tmp/vwgm-mysql-uid-backup.json && cd /srv/vwgm/backups/vwg-m-baremetal && sudo sha256sum -c vwg-m-baremetal-latest.tar.gz.sha256 && sudo grep -Fq '$CANDIDATE_ID' vwg-m-baremetal-latest-manifest.json && echo GROEN: nieuwe MySQL-image staat in back-upmanifest"

guard_write_state

echo "== Verwijder uitsluitend tijdelijke taakartefacten =="
SWITCH_STARTED=0
ssh -i "$SSH_KEY" "$VPS" \
  "ACTIVE_CONTAINER='$ACTIVE_CONTAINER' ROLLBACK_CONTAINER='$ROLLBACK_CONTAINER' CANDIDATE_ID='$CANDIDATE_ID' CANDIDATE_TAG='$CANDIDATE_TAG' MIGRATION_DUMP='$MIGRATION_DUMP' bash -s" <<'REMOTE'
set -euo pipefail
[[ "$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER")" == "$CANDIDATE_ID" ]]
docker inspect "$ROLLBACK_CONTAINER" >/dev/null
rm -f -- "$MIGRATION_DUMP"
docker image rm "$CANDIDATE_TAG" >/dev/null
docker image rm moby/buildkit:buildx-stable-1 >/dev/null 2>&1 || true
docker ps -a --no-trunc
docker images --no-trunc
docker system df
REMOTE

SUCCESS=1
echo "MySQL-UID-migratie afgerond; productiecommit geregistreerd: $DEPLOY_LOCAL_COMMIT"
