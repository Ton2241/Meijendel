#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MYSQL_DATABASE="${MEIJENDEL_MYSQL_DATABASE:-Meijendel}"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_LOGIN_PATH="${MEIJENDEL_MYSQL_LOGIN_PATH:-meijendel_root}"

if [[ -d /usr/local/mysql/bin ]]; then
  PATH="/usr/local/mysql/bin:$PATH"
fi

die() {
  printf 'BLOKKADE: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Gebruik:
  scripts/validate_meijendel_export.sh DUMP MANIFEST
  scripts/validate_meijendel_export.sh --artifact-only DUMP MANIFEST
  scripts/validate_meijendel_export.sh --with-cache DUMP MANIFEST CACHEMAP
  scripts/validate_meijendel_export.sh --write-manifest DUMP MANIFEST KANDIDAATSCHEMA
USAGE
}

manifest_value() {
  local key="$1" file="$2" value count
  count="$(awk -F= -v key="$key" '$1 == key {count++} END {print count+0}' "$file")"
  [[ "$count" -eq 1 ]] || die "manifestveld $key ontbreekt of komt meermaals voor."
  value="$(awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print}' "$file")"
  [[ -n "$value" ]] || die "manifestveld $key is leeg."
  printf '%s\n' "$value"
}

validate_dump_structure() {
  local dump="$1"
  [[ -f "$dump" && ! -L "$dump" && -s "$dump" ]] || die "SQL-dump ontbreekt, is leeg of is een symlink: $dump"
  grep -q -- '-- Dump completed on ' "$dump" || die "SQL-dump mist de eindmarkering."
  grep -q 'CREATE TABLE `pq_vegetatie_pq`' "$dump" || die "SQL-dump mist pq_vegetatie_pq."
  grep -q 'CREATE TABLE `ndff_open_waarneming`' "$dump" || die "SQL-dump mist de openbare NDFF-tabel."
  if LC_ALL=C grep -Eq 'Meijendel_ndff_secure|ndff_open_secure_koppeling|ticket_58679' "$dump"; then
    die "SQL-dump bevat een verwijzing naar beveiligde NDFF-data."
  fi
  if LC_ALL=C grep -Eq '`pwa_[^`]*`' "$dump"; then
    die "SQL-dump bevat een historisch PWA-object; corrigeer de levende database in plaats van de publicatie-export te filteren."
  fi
  LC_ALL=C awk '
    /^CREATE TABLE `tellers`/ { in_tellers = 1; seen = 1 }
    in_tellers && /`id` int/ { has_id = 1 }
    in_tellers && /`tellercode` varchar/ { has_code = 1 }
    in_tellers && /`(voornaam|tussenvoegsel|achternaam|straat|huisnummer|postcode|woonplaats|telefoon_vast|telefoon_mobiel|email|soort_lid|bandnummer)`/ { bad = 1 }
    in_tellers && /ENGINE=InnoDB/ { done = 1; exit }
    END { if (!seen || !done || !has_id || !has_code || bad) exit 1 }
  ' "$dump" || die "tellers ontbreekt of bevat meer dan id en tellercode."
}

validate_artifact() {
  local dump="$1" manifest="$2" expected_hash expected_bytes actual_hash actual_bytes
  [[ -f "$manifest" && ! -L "$manifest" && -s "$manifest" ]] || die "exportmanifest ontbreekt, is leeg of is een symlink: $manifest"
  [[ "$(manifest_value format "$manifest")" == "meijendel-export-v1" ]] || die "onbekend exportmanifestformaat."
  [[ "$(manifest_value source_database "$manifest")" == "Meijendel" ]] || die "manifest wijst niet naar de canonieke database Meijendel."
  expected_hash="$(manifest_value sql_sha256 "$manifest")"
  expected_bytes="$(manifest_value sql_bytes "$manifest")"
  [[ "$expected_hash" =~ ^[0-9a-f]{64}$ ]] || die "ongeldige SQL-SHA-256 in manifest."
  [[ "$expected_bytes" =~ ^[0-9]+$ ]] || die "ongeldige SQL-bestandsgrootte in manifest."
  actual_hash="$(shasum -a 256 "$dump" | awk '{print $1}')"
  actual_bytes="$(stat -f '%z' "$dump")"
  [[ "$actual_hash" == "$expected_hash" ]] || die "SHA-256 van SQL-dump wijkt af van exportmanifest."
  [[ "$actual_bytes" == "$expected_bytes" ]] || die "bestandsgrootte van SQL-dump wijkt af van exportmanifest."
  [[ "$(manifest_value row_counts_sha256 "$manifest")" =~ ^[0-9a-f]{64}$ ]] || die "ongeldige tabelrijtellinghash in manifest."
  [[ "$(manifest_value table_checksums_sha256 "$manifest")" =~ ^[0-9a-f]{64}$ ]] || die "ongeldige tabelinhoudshash in manifest."
  for key in mysql_version base_tables views dagbezoeken_bmp dagwaarnemingen_bmp territoria; do
    manifest_value "$key" "$manifest" >/dev/null
  done
  validate_dump_structure "$dump"
}

validate_cache_artifacts() {
  local dump="$1" manifest="$2" cache_dir="$3"
  local cache_file cache_manifest cache_path cache_manifest_path
  local sql_hash sql_bytes cache_sql_hash cache_sql_bytes parser_version required_parser
  local filename_sql_hash expected_cache_hash expected_cache_bytes actual_cache_hash actual_cache_bytes source_commit

  validate_artifact "$dump" "$manifest"
  [[ -d "$cache_dir" && ! -L "$cache_dir" ]] || die "cachemap ontbreekt of is een symlink: $cache_dir"
  cache_file="$(manifest_value cache_file "$manifest")"
  cache_manifest="$(manifest_value cache_manifest "$manifest")"
  [[ "$cache_file" != */* && "$cache_file" != *..* && \
     "$cache_file" =~ ^meijendel_tables_cache-p([1-9][0-9]*)-([0-9a-f]{64})\.rds$ ]] || \
    die "cache_file is geen veilige basename."
  parser_version="${BASH_REMATCH[1]}"
  filename_sql_hash="${BASH_REMATCH[2]}"
  [[ "$cache_manifest" == "${cache_file%.rds}.manifest" ]] || \
    die "cache_manifest is geen veilige basename die bij cache_file hoort."

  sql_hash="$(manifest_value sql_sha256 "$manifest")"
  sql_bytes="$(manifest_value sql_bytes "$manifest")"
  [[ "$filename_sql_hash" == "$sql_hash" ]] || die "cachebestandsnaam bevat niet de SQL-hash uit het dumpmanifest."

  cache_path="$cache_dir/$cache_file"
  cache_manifest_path="$cache_dir/$cache_manifest"
  [[ -f "$cache_path" && ! -L "$cache_path" && -s "$cache_path" ]] || \
    die "cachebestand ontbreekt, is leeg of is een symlink: $cache_path"
  [[ -f "$cache_manifest_path" && ! -L "$cache_manifest_path" && -s "$cache_manifest_path" ]] || \
    die "cachemanifest ontbreekt, is leeg of is een symlink: $cache_manifest_path"

  [[ "$(manifest_value format "$cache_manifest_path")" == "meijendel-shiny-cache-manifest-v1" ]] || \
    die "onbekend cachemanifestformaat."
  cache_sql_hash="$(manifest_value sql_sha256 "$cache_manifest_path")"
  cache_sql_bytes="$(manifest_value sql_bytes "$cache_manifest_path")"
  [[ "$cache_sql_hash" == "$sql_hash" ]] || die "SQL-hash in cachemanifest wijkt af van dumpmanifest."
  [[ "$cache_sql_bytes" == "$sql_bytes" ]] || die "SQL-omvang in cachemanifest wijkt af van dumpmanifest."
  [[ "$(manifest_value cache_file "$cache_manifest_path")" == "$cache_file" ]] || \
    die "cachebestand in cachemanifest wijkt af."
  [[ "$(manifest_value serialization_version "$cache_manifest_path")" == "3" ]] || \
    die "cachemanifest gebruikt niet serialisatieversie 3."
  manifest_value r_version "$cache_manifest_path" >/dev/null
  manifest_value created_at "$cache_manifest_path" >/dev/null
  source_commit="$(manifest_value source_commit "$cache_manifest_path")"
  [[ "$source_commit" == "uncommitted" || "$source_commit" =~ ^[0-9a-f]{40}$ ]] || \
    die "ongeldige source_commit in cachemanifest."

  required_parser="$(Rscript - "$REPO_DIR/shiny_meijendel/helpers.R" <<'RSCRIPT'
args <- commandArgs(trailingOnly = TRUE)
source(args[[1L]])
cat(MEIJENDEL_PARSER_CACHE_VERSION)
RSCRIPT
)"
  [[ "$(manifest_value parser_version "$cache_manifest_path")" == "$required_parser" && "$parser_version" == "$required_parser" ]] || \
    die "parser-versie in cacheartefacten wijkt af van de Shiny-parser-versie."

  expected_cache_hash="$(manifest_value cache_sha256 "$cache_manifest_path")"
  expected_cache_bytes="$(manifest_value cache_bytes "$cache_manifest_path")"
  [[ "$expected_cache_hash" =~ ^[0-9a-f]{64}$ ]] || die "ongeldige cachehash in cachemanifest."
  [[ "$expected_cache_bytes" =~ ^[0-9]+$ && "$expected_cache_bytes" -gt 0 ]] || \
    die "ongeldige cacheomvang in cachemanifest."
  actual_cache_hash="$(shasum -a 256 "$cache_path" | awk '{print $1}')"
  actual_cache_bytes="$(stat -f '%z' "$cache_path")"
  [[ "$actual_cache_hash" == "$expected_cache_hash" ]] || die "werkelijke cachehash wijkt af van cachemanifest."
  [[ "$actual_cache_bytes" == "$expected_cache_bytes" ]] || die "werkelijke cacheomvang wijkt af van cachemanifest."
  printf 'CACHE_FILE=%s\nCACHE_MANIFEST=%s\nCACHE_STATUS=ready\n' "$cache_file" "$cache_manifest"
}

mysql_bin="$(command -v mysql 2>/dev/null || true)"
mysqlcheck_bin="$(command -v mysqlcheck 2>/dev/null || true)"
[[ -n "$mysql_bin" ]] || mysql_bin="/usr/local/mysql/bin/mysql"
[[ -n "$mysqlcheck_bin" ]] || mysqlcheck_bin="/usr/local/mysql/bin/mysqlcheck"
mysql_args=(--login-path="$MYSQL_LOGIN_PATH" --protocol=tcp --host="$MYSQL_HOST" --port="$MYSQL_PORT")

query() {
  "$mysql_bin" "${mysql_args[@]}" --batch --raw --skip-column-names -e "$1"
}

write_row_counts() {
  local schema="$1" output="$2" sql_file
  [[ "$schema" =~ ^[A-Za-z0-9_]+$ ]] || die "ongeldige schemanaam: $schema"
  sql_file="${output}.sql"
  query "SELECT CONCAT('SELECT ', QUOTE(table_name), ' AS table_name, COUNT(*) AS row_count FROM ', CHAR(96), '$schema', CHAR(96), '.', CHAR(96), REPLACE(table_name, CHAR(96), CONCAT(CHAR(96),CHAR(96))), CHAR(96)) FROM information_schema.tables WHERE table_schema='$schema' AND table_type='BASE TABLE' ORDER BY table_name" |
    awk 'NR>1 {print "UNION ALL"} {print}' > "$sql_file"
  [[ -s "$sql_file" ]] || die "geen basistabellen gevonden in schema $schema."
  "$mysql_bin" "${mysql_args[@]}" --batch --raw < "$sql_file" | LC_ALL=C sort > "$output"
}

write_table_checksums() {
  local schema="$1" output="$2" sql_file
  [[ "$schema" =~ ^[A-Za-z0-9_]+$ ]] || die "ongeldige schemanaam: $schema"
  sql_file="${output}.sql"
  query "SELECT CONCAT('CHECKSUM TABLE ', CHAR(96), '$schema', CHAR(96), '.', CHAR(96), REPLACE(table_name, CHAR(96), CONCAT(CHAR(96),CHAR(96))), CHAR(96), ';') FROM information_schema.tables WHERE table_schema='$schema' AND table_type='BASE TABLE' ORDER BY table_name" > "$sql_file"
  [[ -s "$sql_file" ]] || die "geen basistabellen gevonden voor inhoudschecksums in schema $schema."
  "$mysql_bin" "${mysql_args[@]}" --batch --raw < "$sql_file" |
    awk -F '\t' '$1 != "Table" {sub(/^[^.]*\./, "", $1); print $1 "\t" $2}' |
    LC_ALL=C sort > "$output"
}

table_count() {
  local schema="$1" table="$2"
  [[ "$schema" =~ ^[A-Za-z0-9_]+$ && "$table" =~ ^[A-Za-z0-9_]+$ ]] || die "ongeldige schema- of tabelnaam."
  query "SELECT COUNT(*) FROM \`$schema\`.\`$table\`;"
}

write_manifest() {
  local dump="$1" manifest="$2" candidate="$3" temp_dir live_counts candidate_counts live_checksums candidate_checksums
  [[ "$candidate" =~ ^codex_meijendel_export_check_[0-9]+$ ]] || die "onveilige kandidaatnaam: $candidate"
  validate_dump_structure "$dump"
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  live_counts="$temp_dir/live.tsv"
  candidate_counts="$temp_dir/candidate.tsv"
  write_row_counts "$MYSQL_DATABASE" "$live_counts"
  write_row_counts "$candidate" "$candidate_counts"
  cmp -s "$live_counts" "$candidate_counts" || die "proefimport wijkt af van de levende database op exacte tabelrijtellingen."
  live_checksums="$temp_dir/live-checksums.tsv"
  candidate_checksums="$temp_dir/candidate-checksums.tsv"
  write_table_checksums "$MYSQL_DATABASE" "$live_checksums"
  write_table_checksums "$candidate" "$candidate_checksums"
  cmp -s "$live_checksums" "$candidate_checksums" || die "proefimport wijkt inhoudelijk af van de levende database."
  "$mysqlcheck_bin" "${mysql_args[@]}" --check "$candidate" > "$temp_dir/mysqlcheck.txt"
  awk '$NF != "OK" && $0 !~ /^[[:alnum:]_]+\.[[:alnum:]_]+$/ {bad=1} END {exit bad}' "$temp_dir/mysqlcheck.txt" || die "mysqlcheck van proefimport is niet volledig groen."

  local live_base candidate_base live_views candidate_views row_hash table_hash temp_manifest
  live_base="$(query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DATABASE' AND table_type='BASE TABLE'")"
  candidate_base="$(query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$candidate' AND table_type='BASE TABLE'")"
  live_views="$(query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DATABASE' AND table_type='VIEW'")"
  candidate_views="$(query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$candidate' AND table_type='VIEW'")"
  [[ "$live_base" == "$candidate_base" && "$live_views" == "$candidate_views" ]] || die "proefimport wijkt af in objectaantallen."
  row_hash="$(shasum -a 256 "$live_counts" | awk '{print $1}')"
  table_hash="$(shasum -a 256 "$live_checksums" | awk '{print $1}')"
  temp_manifest="${manifest}.next.$$"
  {
    printf 'format=meijendel-export-v1\n'
    printf 'source_database=Meijendel\n'
    printf 'mysql_version=%s\n' "$(query 'SELECT VERSION()')"
    printf 'sql_sha256=%s\n' "$(shasum -a 256 "$dump" | awk '{print $1}')"
    printf 'sql_bytes=%s\n' "$(stat -f '%z' "$dump")"
    printf 'base_tables=%s\n' "$live_base"
    printf 'views=%s\n' "$live_views"
    printf 'row_counts_sha256=%s\n' "$row_hash"
    printf 'table_checksums_sha256=%s\n' "$table_hash"
    printf 'dagbezoeken_bmp=%s\n' "$(table_count "$MYSQL_DATABASE" dagbezoeken_bmp)"
    printf 'dagwaarnemingen_bmp=%s\n' "$(table_count "$MYSQL_DATABASE" dagwaarnemingen_bmp)"
    printf 'territoria=%s\n' "$(table_count "$MYSQL_DATABASE" territoria)"
  } > "$temp_manifest"
  chmod 644 "$temp_manifest"
  mv "$temp_manifest" "$manifest"
  validate_artifact "$dump" "$manifest"
  rm -rf "$temp_dir"
  trap - RETURN
  printf 'OK: proefimport en exportmanifest komen exact overeen met de levende database.\n'
}

validate_live() {
  local dump="$1" manifest="$2" temp_dir live_counts live_checksums row_hash table_hash
  "$REPO_DIR/scripts/check_mysql_version.sh" >/dev/null
  validate_artifact "$dump" "$manifest"
  [[ "$(query 'SELECT VERSION()')" == "$(manifest_value mysql_version "$manifest")" ]] || die "MySQL-versie wijkt af van exportmanifest."
  [[ "$(query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DATABASE' AND table_type='BASE TABLE'")" == "$(manifest_value base_tables "$manifest")" ]] || die "aantal basistabellen wijkt af van exportmanifest."
  [[ "$(query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DATABASE' AND table_type='VIEW'")" == "$(manifest_value views "$manifest")" ]] || die "aantal views wijkt af van exportmanifest."
  [[ "$(table_count "$MYSQL_DATABASE" dagbezoeken_bmp)" == "$(manifest_value dagbezoeken_bmp "$manifest")" ]] || die "dagbezoeken_bmp wijzigde sinds export."
  [[ "$(table_count "$MYSQL_DATABASE" dagwaarnemingen_bmp)" == "$(manifest_value dagwaarnemingen_bmp "$manifest")" ]] || die "dagwaarnemingen_bmp wijzigde sinds export."
  [[ "$(table_count "$MYSQL_DATABASE" territoria)" == "$(manifest_value territoria "$manifest")" ]] || die "territoria wijzigde sinds export."
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  live_counts="$temp_dir/live.tsv"
  write_row_counts "$MYSQL_DATABASE" "$live_counts"
  row_hash="$(shasum -a 256 "$live_counts" | awk '{print $1}')"
  [[ "$row_hash" == "$(manifest_value row_counts_sha256 "$manifest")" ]] || die "levende database wijzigde sinds export op een of meer tabelrijtellingen."
  live_checksums="$temp_dir/live-checksums.tsv"
  write_table_checksums "$MYSQL_DATABASE" "$live_checksums"
  table_hash="$(shasum -a 256 "$live_checksums" | awk '{print $1}')"
  [[ "$table_hash" == "$(manifest_value table_checksums_sha256 "$manifest")" ]] || die "levende database wijzigde sinds export inhoudelijk."
  rm -rf "$temp_dir"
  trap - RETURN
  printf 'OK: dump, manifest en levende database komen overeen.\n'
}

mode="live"
case "${1:-}" in
  --artifact-only) mode="artifact"; shift ;;
  --with-cache) mode="cache"; shift ;;
  --write-manifest) mode="write"; shift ;;
esac

case "$mode" in
  artifact)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    validate_artifact "$1" "$2"
    printf 'OK: SQL-dump komt overeen met het exportmanifest.\n'
    ;;
  cache)
    [[ $# -eq 3 ]] || { usage >&2; exit 2; }
    validate_cache_artifacts "$1" "$2" "$3"
    ;;
  write)
    [[ $# -eq 3 ]] || { usage >&2; exit 2; }
    write_manifest "$1" "$2" "$3"
    ;;
  live)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    validate_live "$1" "$2"
    ;;
esac
