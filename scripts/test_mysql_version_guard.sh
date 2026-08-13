#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$REPO_DIR/scripts/check_mysql_version.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

cat > "$TEST_DIR/mysql" <<'SCRIPT'
#!/usr/bin/env bash
if [[ " $* " == *" --version "* ]]; then
  printf 'mysql  Ver %s for macos15 on arm64\n' "${FAKE_MYSQL_CLIENT_VERSION:-9.7.1}"
else
  printf '%s\n' "${FAKE_MYSQL_SERVER_VERSION:-9.7.1}"
fi
SCRIPT
cat > "$TEST_DIR/mysqldump" <<'SCRIPT'
#!/usr/bin/env bash
printf 'mysqldump  Ver %s for macos15 on arm64\n' "${FAKE_MYSQLDUMP_VERSION:-9.7.1}"
SCRIPT
chmod +x "$TEST_DIR/mysql" "$TEST_DIR/mysqldump"

PATH="$TEST_DIR:$PATH" "$GUARD" >/dev/null || fail "geldige 9.7.1-set werd geblokkeerd."
[[ "$($GUARD --required-version)" == "9.7.1" ]] || fail "vereiste versie is niet 9.7.1."

if output="$(PATH="$TEST_DIR:$PATH" FAKE_MYSQL_CLIENT_VERSION=9.5.0 "$GUARD" 2>&1)"; then
  fail "mysql-client 9.5.0 werd niet geblokkeerd."
fi
[[ "$output" == *"mysql-client is 9.5.0"* ]] || fail "gerichte clientfout ontbreekt."

if output="$(PATH="$TEST_DIR:$PATH" FAKE_MYSQLDUMP_VERSION=9.5.0 "$GUARD" 2>&1)"; then
  fail "mysqldump 9.5.0 werd niet geblokkeerd."
fi
[[ "$output" == *"mysqldump is 9.5.0"* ]] || fail "gerichte mysqldumpfout ontbreekt."

if output="$(PATH="$TEST_DIR:$PATH" FAKE_MYSQL_SERVER_VERSION=9.5.0 "$GUARD" 2>&1)"; then
  fail "MySQL-server 9.5.0 werd niet geblokkeerd."
fi
[[ "$output" == *"lokale MySQL-server is 9.5.0"* ]] || fail "gerichte serverfout ontbreekt."

printf 'OK: MySQL-versieguard accepteert uitsluitend exact 9.7.1.\n'
