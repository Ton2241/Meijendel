#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$REPO_DIR/scripts/validate_meijendel_export.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

dump="$TEST_DIR/Meijendel.sql"
manifest="$TEST_DIR/Meijendel.sql.manifest"

write_dump() {
  cat > "$dump" <<'SQL'
CREATE TABLE `tellers` (`id` int NOT NULL, `tellercode` varchar(20) NOT NULL) ENGINE=InnoDB;
CREATE TABLE `pq_vegetatie_pq` (`id` int NOT NULL) ENGINE=InnoDB;
CREATE TABLE `ndff_open_waarneming` (`id` bigint NOT NULL) ENGINE=InnoDB;
-- Dump completed on 2026-09-20 22:42:46
SQL
}

write_manifest() {
  local hash bytes
  hash="$(shasum -a 256 "$dump" | awk '{print $1}')"
  bytes="$(stat -f '%z' "$dump")"
  cat > "$manifest" <<EOF
format=meijendel-export-v1
source_database=Meijendel
mysql_version=9.7.1
sql_sha256=$hash
sql_bytes=$bytes
base_tables=236
views=10
row_counts_sha256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
table_checksums_sha256=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
dagbezoeken_bmp=14455
dagwaarnemingen_bmp=600959
territoria=71155
EOF
}

write_dump
write_manifest
"$VALIDATOR" --artifact-only "$dump" "$manifest" >/dev/null

grep -v '^table_checksums_sha256=' "$manifest" > "$manifest.zonder-checksums"
if output=$("$VALIDATOR" --artifact-only "$dump" "$manifest.zonder-checksums" 2>&1); then
  fail "manifest zonder inhoudschecksums werd geaccepteerd."
fi
[[ "$output" == *"table_checksums_sha256"* ]] || fail "gerichte inhoudschecksumfout ontbreekt."

printf '\n-- gewijzigd\n' >> "$dump"
if output=$("$VALIDATOR" --artifact-only "$dump" "$manifest" 2>&1); then
  fail "een na manifestgeneratie gewijzigde dump werd geaccepteerd."
fi
[[ "$output" == *"SHA-256"* ]] || fail "gerichte hashfout ontbreekt."

write_dump
printf 'CREATE TABLE `ticket_58679` (`id` int);\n' >> "$dump"
write_manifest
if output=$("$VALIDATOR" --artifact-only "$dump" "$manifest" 2>&1); then
  fail "beveiligde NDFF-inhoud werd geaccepteerd."
fi
[[ "$output" == *"beveiligde NDFF"* ]] || fail "gerichte beveiligingsfout ontbreekt."

write_dump
printf 'CREATE TABLE `pwa_legacy` (`id` int);\n' >> "$dump"
write_manifest
if output=$("$VALIDATOR" --artifact-only "$dump" "$manifest" 2>&1); then
  fail "historisch PWA-object werd geaccepteerd."
fi
[[ "$output" == *"PWA"* ]] || fail "gerichte PWA-fout ontbreekt."

cache_dir="$TEST_DIR/cache"
mkdir -p "$cache_dir"

write_cache_set() {
  local sql_hash cache_file cache_manifest cache_hash cache_bytes sql_bytes
  write_dump
  write_manifest
  sql_hash="$(awk -F= '$1 == "sql_sha256" {print $2}' "$manifest")"
  sql_bytes="$(awk -F= '$1 == "sql_bytes" {print $2}' "$manifest")"
  cache_file="meijendel_tables_cache-p9-${sql_hash}.rds"
  cache_manifest="${cache_file%.rds}.manifest"
  rm -rf "$cache_dir"
  mkdir -p "$cache_dir"
  printf 'kleine cachefixture\n' > "$cache_dir/$cache_file"
  cache_hash="$(shasum -a 256 "$cache_dir/$cache_file" | awk '{print $1}')"
  cache_bytes="$(stat -f '%z' "$cache_dir/$cache_file")"
  cat > "$cache_dir/$cache_manifest" <<EOF
format=meijendel-shiny-cache-manifest-v1
sql_sha256=$sql_hash
sql_bytes=$sql_bytes
parser_version=9
cache_sha256=$cache_hash
cache_bytes=$cache_bytes
r_version=4.6.1
serialization_version=3
created_at=2026-09-21T12:00:00+0200
source_commit=uncommitted
cache_file=$cache_file
EOF
  printf 'cache_file=%s\ncache_manifest=%s\n' "$cache_file" "$cache_manifest" >> "$manifest"
}

expect_cache_fail() {
  local expected="$1" output
  if output=$("$VALIDATOR" --with-cache "$dump" "$manifest" "$cache_dir" 2>&1); then
    fail "ongeldige cacheset werd geaccepteerd: $expected"
  fi
  [[ "$output" == *"$expected"* ]] || fail "gerichte cachefout ontbreekt: $expected; uitvoer=$output"
}

write_cache_set
"$VALIDATOR" --with-cache "$dump" "$manifest" "$cache_dir" >/dev/null

write_cache_set
sed -i '' 's#^cache_file=.*#cache_file=../escape.rds#' "$manifest"
expect_cache_fail "veilige basename"

write_cache_set
cache_file="$(awk -F= '$1 == "cache_file" {print $2}' "$manifest")"
mv "$cache_dir/$cache_file" "$cache_dir/cache-target.rds"
ln -s cache-target.rds "$cache_dir/$cache_file"
expect_cache_fail "symlink"

write_cache_set
cache_manifest="$(awk -F= '$1 == "cache_manifest" {print $2}' "$manifest")"
sed -i '' "s/^cache_sha256=.*/cache_sha256=$(printf 'b%.0s' {1..64})/" "$cache_dir/$cache_manifest"
expect_cache_fail "cachehash"

write_cache_set
cache_manifest="$(awk -F= '$1 == "cache_manifest" {print $2}' "$manifest")"
sed -i '' "s/^sql_sha256=.*/sql_sha256=$(printf 'c%.0s' {1..64})/" "$cache_dir/$cache_manifest"
expect_cache_fail "SQL-hash"

write_cache_set
cache_manifest="$(awk -F= '$1 == "cache_manifest" {print $2}' "$manifest")"
sed -i '' 's/^parser_version=.*/parser_version=10/' "$cache_dir/$cache_manifest"
expect_cache_fail "parser-versie"

printf 'OK: dumpmanifest blokkeert gewijzigde SQL en ongeldige gekoppelde cacheartefacten.\n'
