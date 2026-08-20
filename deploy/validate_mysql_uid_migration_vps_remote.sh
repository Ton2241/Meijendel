#!/usr/bin/env bash
set -euo pipefail

SOURCE_CONTAINER="${1:?broncontainer ontbreekt}"
TARGET_CONTAINER="${2:?doelcontainer ontbreekt}"
EXPECTED_UID="${3:?verwachte UID ontbreekt}"
EXPECTED_GID="${4:?verwachte GID ontbreekt}"

fail() { printf 'FOUT: %s\n' "$*" >&2; exit 1; }
mysql_query() {
  local container="$1" sql="$2"
  docker exec "$container" sh -c \
    'exec mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -e "$1"' \
    sh "$sql"
}

for container in "$SOURCE_CONTAINER" "$TARGET_CONTAINER"; do
  docker inspect "$container" >/dev/null 2>&1 || fail "container ontbreekt: $container"
  docker exec "$container" sh -c \
    'mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' >/dev/null 2>&1 ||
    fail "MySQL is niet gereed: $container"
  [[ "$(docker exec "$container" id -u mysql)" == "$EXPECTED_UID" || "$container" == "$SOURCE_CONTAINER" ]] ||
    fail "mysql-UID wijkt af in $container"
  [[ "$(docker exec "$container" id -g mysql)" == "$EXPECTED_GID" || "$container" == "$SOURCE_CONTAINER" ]] ||
    fail "mysql-GID wijkt af in $container"
  [[ "$(mysql_query "$container" 'SELECT VERSION()')" == "9.7.1" ]] ||
    fail "MySQL-versie wijkt af in $container"
done

tmp_dir="$(mktemp -d /tmp/vwgm-mysql-uid-validate.XXXXXX)"
cleanup() { rm -rf -- "$tmp_dir"; }
trap cleanup EXIT

inventory() {
  local container="$1" prefix="$2" table quoted count
  mysql_query "$container" \
    "SELECT TABLE_NAME, TABLE_TYPE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_NAME" \
    > "$tmp_dir/$prefix.objects"
  : > "$tmp_dir/$prefix.rows"
  while IFS=$'\t' read -r table type; do
    [[ "$type" == "BASE TABLE" ]] || continue
    quoted="${table//\`/\`\`}"
    if ! count="$(mysql_query "$container" "SELECT COUNT(*) FROM \`$quoted\`")"; then
      fail "rijtelling faalde voor $container:$table"
    fi
    printf '%s\t%s\n' "$table" "$count" >> "$tmp_dir/$prefix.rows"
  done < "$tmp_dir/$prefix.objects"
  docker exec "$container" sh -c \
    'exec mysqldump --no-data --skip-comments --skip-dump-date --no-tablespaces --set-gtid-purged=OFF -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' \
    > "$tmp_dir/$prefix.schema.sql"
  mysql_query "$container" \
    'SELECT @@global.time_zone, @@global.sql_mode, @@global.character_set_server, @@global.collation_server' \
    > "$tmp_dir/$prefix.settings"
}

inventory "$SOURCE_CONTAINER" source
inventory "$TARGET_CONTAINER" target
compare() {
  local source="$1" target="$2" label="$3"
  if ! diff -u "$source" "$target" > "$tmp_dir/compare.diff"; then
    sed -n '1,160p' "$tmp_dir/compare.diff" >&2
    fail "$label wijkt af"
  fi
}
compare "$tmp_dir/source.objects" "$tmp_dir/target.objects" objectinventaris
compare "$tmp_dir/source.rows" "$tmp_dir/target.rows" "exacte rijtellingen"
compare "$tmp_dir/source.schema.sql" "$tmp_dir/target.schema.sql" schemastructuur
compare "$tmp_dir/source.settings" "$tmp_dir/target.settings" serverinstellingen

mysql_user="$(docker exec "$TARGET_CONTAINER" printenv MYSQL_USER)"
mysql_database="$(docker exec "$TARGET_CONTAINER" printenv MYSQL_DATABASE)"
[[ "$mysql_user" =~ ^[A-Za-z0-9_]+$ && "$mysql_database" =~ ^[A-Za-z0-9_]+$ ]] ||
  fail "onveilige MySQL-envnaam"
if ! privilege_inventory="$(
  docker exec -i "$TARGET_CONTAINER" sh -c \
    'exec mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD"' <<SQL
SELECT COUNT(*), COALESCE(SUM(PRIVILEGE_TYPE <> 'SELECT'), 0)
FROM information_schema.SCHEMA_PRIVILEGES
WHERE GRANTEE = CONCAT(QUOTE('$mysql_user'), '@', QUOTE('%'))
  AND TABLE_SCHEMA = '$mysql_database';
SQL
)"; then
  fail "rechteninventaris kon niet worden gelezen"
fi
read -r privilege_count unexpected_count <<< "$privilege_inventory"
[[ "$privilege_count" =~ ^[0-9]+$ && "$unexpected_count" =~ ^[0-9]+$ ]] ||
  fail "rechteninventaris heeft een onverwacht formaat"
[[ "$privilege_count" -eq 1 && "$unexpected_count" -eq 0 ]] ||
  fail "leesaccount heeft niet exact één SELECT-schemarecht"
docker exec "$TARGET_CONTAINER" sh -c \
  'mysql --batch --skip-column-names -h127.0.0.1 -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SELECT 1"' |
  grep -qx 1 || fail "leesaccount kan de kandidaatdatabase niet lezen"

check_count=0
while IFS=$'\t' read -r table type; do
  [[ "$type" == "BASE TABLE" ]] || continue
  quoted="${table//\`/\`\`}"
  if ! output="$(mysql_query "$TARGET_CONTAINER" "CHECK TABLE \`$quoted\` EXTENDED")"; then
    fail "CHECK TABLE EXTENDED kon niet worden uitgevoerd voor $table"
  fi
  printf '%s\n' "$output" | awk -F '\t' 'END { exit !($3 == "status" && $4 == "OK") }' ||
    fail "CHECK TABLE EXTENDED faalde voor $table"
  check_count=$((check_count + 1))
done < "$tmp_dir/target.objects"

for object in \
  website_plot_mapping website_plot_mapping_public website_plot_species_totals \
  website_plot_year_totals website_species_mapping website_species_mapping_public \
  website_species_territoria website_species_trends
do
  [[ "$(mysql_query "$TARGET_CONTAINER" "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='$object'")" == "1" ]] ||
    fail "kritiek websiteobject ontbreekt: $object"
done

printf 'GROEN|mysql-uid-migratie|objects=%s|checks=%s|uid=%s|gid=%s\n' \
  "$(wc -l < "$tmp_dir/target.objects" | tr -d ' ')" "$check_count" "$EXPECTED_UID" "$EXPECTED_GID"
