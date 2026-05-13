#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_FILE="$BASE_DIR/appsmith_start/01_views_ledenbeheer.sql"

MYSQL_DB="${MYSQL_DB:-meijendel}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_SOCKET="${MYSQL_SOCKET:-/tmp/mysql.sock}"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"

cd "$BASE_DIR"

echo "== MySQL views controleren =="
if [[ -n "${MEIJENDEL_MYSQL_PASSWORD:-}" ]]; then
  mysql --no-defaults -u"$MYSQL_USER" -p"$MEIJENDEL_MYSQL_PASSWORD" \
    --protocol=SOCKET --socket="$MYSQL_SOCKET" -D "$MYSQL_DB" < "$SQL_FILE"
else
  echo "MEIJENDEL_MYSQL_PASSWORD is niet gezet; MySQL vraagt nu om het wachtwoord."
  mysql --no-defaults -u"$MYSQL_USER" -p \
    --protocol=SOCKET --socket="$MYSQL_SOCKET" -D "$MYSQL_DB" < "$SQL_FILE"
fi

echo "== Appsmith starten =="
docker compose up -d

echo "== Wachten op MySQL TCP voor Appsmith =="
for i in {1..30}; do
  if docker exec meijendel-appsmith bash -lc "timeout 3 bash -c '</dev/tcp/host.docker.internal/$MYSQL_PORT'" >/dev/null 2>&1; then
    echo "MySQL bereikbaar via host.docker.internal:$MYSQL_PORT"
    break
  fi
  if [[ "$i" == "30" ]]; then
    echo "FOUT: MySQL is niet bereikbaar vanuit Appsmith via host.docker.internal:$MYSQL_PORT"
    exit 1
  fi
  sleep 2
done

echo "== Wachten op Appsmith HTTP =="
for i in {1..60}; do
  if curl -fsS -o /dev/null http://127.0.0.1:8080; then
    echo "Appsmith bereikbaar op http://localhost:8080"
    break
  fi
  sleep 2
done

echo "== Containerstatus =="
docker ps --filter name=meijendel-appsmith --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo "== Wachten op Appsmith Docker-health =="
for i in {1..60}; do
  if docker ps --filter name=meijendel-appsmith --format '{{.Status}}' | grep -q 'healthy'; then
    break
  fi
  sleep 5
done

if docker ps --filter name=meijendel-appsmith --format '{{.Status}}' | grep -q 'healthy'; then
  echo "OK: Appsmith is healthy."
else
  echo "LET OP: Appsmith is niet healthy. Controleer: docker logs --tail 120 meijendel-appsmith"
fi
