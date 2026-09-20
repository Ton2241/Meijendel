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
dagbezoeken_bmp=14455
dagwaarnemingen_bmp=600959
territoria=71155
EOF
}

write_dump
write_manifest
"$VALIDATOR" --artifact-only "$dump" "$manifest" >/dev/null

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

printf 'OK: dumpmanifest blokkeert gewijzigde en beveiligde SQL-artifacts.\n'
