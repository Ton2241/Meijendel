#!/usr/bin/env bash
# Prepare and validate only. This helper never replaces production.
set -euo pipefail

fail() { printf 'BLOKKADE|mysql974-kandidaat|%s\n' "$*" >&2; exit 1; }
check_candidate_scan() {
  local report="$1" status="$2" image="$3" tag="$4" short attention
  [[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]] || return 1
  [[ "$status" == 0 || "$status" == 1 ]] || return 1
  short="${image#sha256:}"
  grep -Fxq "SAMENVATTING|kandidaat-${short:0:12}|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0" "$report" || return 1
  ! grep -Eq '^(URGENT|BLOKKADE)\|' "$report" || return 1
  while IFS= read -r attention; do
    [[ "$attention" == "AANDACHT|container-hygiene|onverwachte-imagetag=$tag" ]] || return 1
  done < <(grep '^AANDACHT|container-hygiene|' "$report" || true)
}

prepare_candidate() {
  [[ "$EUID" == 0 && "$#" == 4 ]] || fail 'root, bronmap, broncommit, oude image en datarelease vereist'
  local stage="$1" commit="$2" old_image="$3" data_commit="$4"
  [[ "$stage" =~ ^/var/tmp/vwgm-mysql974-root-[a-zA-Z0-9_]+$ && "$commit" =~ ^[0-9a-f]{40}$ && "$old_image" =~ ^sha256:[0-9a-f]{64}$ && "$data_commit" =~ ^[0-9a-f]{40}$ ]] || fail 'ongeldige argumenten'
  [[ "$(stat -c '%u:%a' "$stage")" == 0:700 ]] || fail 'bronmap moet root0700 zijn'
  local short="${commit:0:12}"
  local task="/srv/vwgm/mysql974-candidate-$short"
  local tag="vwgm-mysql:candidate-974-$short" candidate="meijendel-mysql-974-candidate-$short"
  local state=/srv/vwgm/deploy-state/Meijendel.commit
  local env=/srv/vwgm/meijendel-mysql/mysql.env
  local old_data=/srv/vwgm/meijendel-mysql-971-uid1999/data
  local audit=/usr/local/libexec/vwgm-admin/vulnerability-audit-root
  [[ -d /srv/vwgm/deploy-state/production.lock ]] || fail 'productieslot ontbreekt'
  [[ "$(cat "$state")" == "$data_commit" ]] || fail 'datarelease veranderd'
  [[ -f "$env" && -x "$audit" ]] || fail 'runtime of scanner ontbreekt'
  [[ ! -e "$task" ]] || fail 'taakmap bestaat al; eerst beoordelen'
  ! docker inspect "$candidate" >/dev/null 2>&1 || fail 'kandidaatcontainer bestaat al'
  ! docker image inspect "$tag" >/dev/null 2>&1 || fail 'kandidaatimage bestaat al'
  [[ "$(docker inspect --format '{{.Image}}' meijendel-mysql)" == "$old_image" ]] || fail 'bronimage veranderd'
  [[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Source}}{{end}}{{end}}' meijendel-mysql)" == "$old_data" ]] || fail 'brondatamap veranderd'
  [[ "$(docker exec meijendel-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -NBe "SELECT VERSION()"')" == 9.7.1 ]] || fail 'bronversie is niet9.7.1'
  umask 077
  install -d -m 0700 "$task"
  # A failed preparation retains its exact private artifacts for diagnosis.
  # It never stops, renames, reconfigures or remounts the production container.
  trap 'docker stop "$candidate" >/dev/null 2>&1 || true' EXIT
  docker buildx build --builder default --platform linux/amd64 --pull --no-cache --load \
    --file "$stage/Dockerfile.9.7.4" --tag "$tag" "$stage"
  local image
  image="$(docker image inspect --format '{{.Id}}' "$tag")"
  [[ "$image" =~ ^sha256:[0-9a-f]{64}$ && "$image" != "$old_image" ]] || fail 'ongeldige kandidaatimage'
  docker run --rm --network none --entrypoint sh "$image" -c \
    'test "$(id -u mysql)" -eq 1999 && test "$(id -g mysql)" -eq 1999 && mysql --version | grep -Fq "Ver 9.7.4 " && gosu --version'
  local audit_status=0
  "$audit" --image "$image" > "$task/scan.log" 2>&1 || audit_status=$?
  check_candidate_scan "$task/scan.log" "$audit_status" "$image" "$tag" || fail "exacte kandidaatscan niet groen; besloten bewijs: $task/scan.log"
  echo 'GROEN|mysql974-kandidaatscan|critical=0|high=0'
  docker exec meijendel-mysql sh -c \
    'exec mysqldump --single-transaction --routines --triggers --events --hex-blob --set-gtid-purged=OFF --no-tablespaces -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' \
    | gzip -c > "$task/source.sql.gz"
  gzip -t "$task/source.sql.gz"
  sha256sum "$task/source.sql.gz" > "$task/source.sql.gz.sha256"
  install -d -o 1999 -g 1999 -m 0700 "$task/data"
  docker run -d --name "$candidate" --restart no --network none --memory 1536m --cpus 1 \
    --env-file "$env" -v "$task/data:/var/lib/mysql" "$image" \
    --local-infile=0 --mysqlx=0 --binlog-expire-logs-seconds=259200 --innodb-redo-log-capacity=536870912 >/dev/null
  local attempt version=''
  for attempt in $(seq 1 150); do
    version="$(docker exec "$candidate" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -NBe "SELECT VERSION()"' 2>/dev/null || true)"
    if [[ "$version" == 9.7.4 ]] && docker logs "$candidate" 2>&1 | grep -Fq 'MySQL init process done. Ready for start up.'; then break; fi
    [[ "$attempt" -lt 150 ]] || fail 'kandidaat werd niet gereed'
    sleep 2
  done
  gzip -dc "$task/source.sql.gz" | docker exec -i "$candidate" sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
  local mysql_user mysql_database
  mysql_user="$(docker exec "$candidate" printenv MYSQL_USER)"
  mysql_database="$(docker exec "$candidate" printenv MYSQL_DATABASE)"
  [[ "$mysql_user" =~ ^[A-Za-z0-9_]+$ && "$mysql_database" =~ ^[A-Za-z0-9_]+$ ]] || fail 'ongeldige databasenaam'
  docker exec -i "$candidate" sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' <<SQL
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '$mysql_user'@'%';
GRANT SELECT ON \`$mysql_database\`.* TO '$mysql_user'@'%';
SQL
  bash "$stage/validate_mysql_uid_migration_vps_remote.sh" meijendel-mysql "$candidate" 1999 1999 9.7.1 9.7.4 > "$task/validation.log" 2>&1
  [[ "$(cat "$state")" == "$data_commit" ]] || fail 'datarelease tijdens proef veranderd'
  [[ "$(docker inspect --format '{{.Image}}' meijendel-mysql)" == "$old_image" ]] || fail 'bronimage tijdens proef veranderd'
  [[ "$(docker inspect --format '{{.State.Running}}' meijendel-mysql)" == true ]] || fail 'productie draait niet'
  docker stop "$candidate" >/dev/null
  python3 - "$task/manifest.json" "$image" "$old_image" "$commit" "$data_commit" "$task/data" "$candidate" <<'PY'
import datetime,json,pathlib,sys
pathlib.Path(sys.argv[1]).write_text(json.dumps(dict(
 status='validated-candidate-only',tested_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
 version='9.7.4',source_version='9.7.1',image=sys.argv[2],source_image=sys.argv[3],
 source_commit=sys.argv[4],data_commit=sys.argv[5],data=sys.argv[6],container=sys.argv[7],
 review_before='2026-10-23',purpose='isolated MySQL upgrade candidate; production unchanged'),indent=2)+'\n')
PY
  trap - EXIT
  cat "$task/validation.log"
  printf 'GROEN|mysql974-kandidaat|image=%s|manifest=%s/manifest.json|productie=ongewijzigd\n' "$image" "$task"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then prepare_candidate "$@"; fi
