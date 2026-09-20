#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORTER="$REPO_DIR/scripts/export_meijendel_sql.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TEST_DIR/bin"

cat > "$TEST_DIR/bin/ok" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT

cat > "$TEST_DIR/bin/mysqldump" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' 'CREATE TABLE `voorbeeld` (`id` int);' '-- Dump completed on 2026-09-20 22:42:46'
SCRIPT

cat > "$TEST_DIR/bin/mysql" <<'SCRIPT'
#!/usr/bin/env bash
cat >/dev/null || true
SCRIPT

cat > "$TEST_DIR/bin/validator-fail" <<'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT

cat > "$TEST_DIR/bin/validator-ok" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "--write-manifest" ]]
dump="$2"
manifest="$3"
candidate="$4"
[[ -s "$dump" && "$candidate" =~ ^codex_meijendel_export_check_[0-9]+$ ]]
printf 'manifest voor %s\n' "$candidate" > "$manifest"
SCRIPT

chmod +x "$TEST_DIR/bin/"*
dump="$TEST_DIR/Meijendel.sql"
manifest="$TEST_DIR/Meijendel.sql.manifest"
printf 'oude dump\n' > "$dump"
printf 'oud manifest\n' > "$manifest"

if PATH="$TEST_DIR/bin:$PATH" \
  MEIJENDEL_WORKSPACE_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_VERSION_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_BIN="$TEST_DIR/bin/mysql" \
  MEIJENDEL_MYSQLDUMP_BIN="$TEST_DIR/bin/mysqldump" \
  MEIJENDEL_EXPORT_VALIDATOR="$TEST_DIR/bin/validator-fail" \
  "$EXPORTER" "$dump" "$manifest" >/dev/null 2>&1; then
  fail "export met falende proefvalidatie werd geaccepteerd."
fi
[[ "$(cat "$dump")" == "oude dump" ]] || fail "oude dump werd vóór validatie overschreven."
[[ "$(cat "$manifest")" == "oud manifest" ]] || fail "oud manifest werd vóór validatie overschreven."

PATH="$TEST_DIR/bin:$PATH" \
  MEIJENDEL_WORKSPACE_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_VERSION_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_BIN="$TEST_DIR/bin/mysql" \
  MEIJENDEL_MYSQLDUMP_BIN="$TEST_DIR/bin/mysqldump" \
  MEIJENDEL_EXPORT_VALIDATOR="$TEST_DIR/bin/validator-ok" \
  "$EXPORTER" "$dump" "$manifest" >/dev/null

grep -q 'Dump completed' "$dump" || fail "gevalideerde nieuwe dump werd niet geactiveerd."
grep -q 'manifest voor codex_meijendel_export_check_' "$manifest" || fail "nieuw manifest werd niet geactiveerd."
compgen -G "$TEST_DIR/Meijendel.sql.next.*" >/dev/null && fail "tijdelijke dump bleef achter."

printf 'OK: export is atomair en activeert dump plus manifest pas na proefvalidatie.\n'
