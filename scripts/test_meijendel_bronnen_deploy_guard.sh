#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="$REPO_DIR/deploy/Archivering_en_Dump_Meijendel.sh"
UPDATE="$REPO_DIR/deploy/update_en_deploy_meijendel.sh"
DEPLOY="$REPO_DIR/deploy/deploy_meijendel_vps.sh"
REMOTE_HELPER="$REPO_DIR/deploy/deploy_meijendel_release_vps_remote.sh"
SOURCES_DEPLOY="$REPO_DIR/deploy/deploy_meijendel_bronnen_vps.sh"
SOURCES_HELPER="$REPO_DIR/deploy/deploy_meijendel_bronnen_release_vps_remote.sh"

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

for file in "$ARCHIVE" "$UPDATE"; do
  grep -qF 'meijendel_bronnen.sql' "$file" ||
    fail "meijendel_bronnen.sql ontbreekt in $file"
done

[[ -f "$SOURCES_DEPLOY" ]] || fail 'zelfstandig brondeployscript ontbreekt.'
[[ -f "$SOURCES_HELPER" ]] || fail 'zelfstandige bronreleasehelper ontbreekt.'

if grep -qF 'meijendel_bronnen.sql' "$DEPLOY" || grep -qF 'Meijendel_bronnen' "$REMOTE_HELPER"; then
  fail 'ecologische release bevat nog broncataloguslogica.'
fi

grep -qF 'Meijendel_bronnen.sql' "$SOURCES_DEPLOY" ||
  fail 'het release-manifest noemt de afgeschermde bron-dump niet.'
grep -qF 'GRANT SELECT ON \`Meijendel_bronnen\`.\`v_bron_catalogus\`' "$SOURCES_HELPER" ||
  fail 'viewgrant voor v_bron_catalogus ontbreekt.'
grep -qF 'GRANT SELECT ON \`Meijendel_bronnen\`.\`v_literatuur_overzicht\`' "$SOURCES_HELPER" ||
  fail 'viewgrant voor v_literatuur_overzicht ontbreekt.'
grep -qF 'GRANT SELECT ON \`Meijendel_bronnen\`.\`v_contextdataset_overzicht\`' "$SOURCES_HELPER" ||
  fail 'viewgrant voor v_contextdataset_overzicht ontbreekt.'
grep -qF 'information_schema.SCHEMA_PRIVILEGES' "$SOURCES_HELPER" ||
  fail 'controle op brede schemarechten ontbreekt.'
grep -qF 'information_schema.TABLE_PRIVILEGES' "$SOURCES_HELPER" ||
  fail 'controle op uitsluitend drie viewrechten ontbreekt.'
grep -qF '/Meijendel_bronnen.sql' "$SOURCES_DEPLOY" ||
  fail 'publieke 403/404-controle voor de bron-dump ontbreekt.'
grep -qF 'awk '\''{print \$1}'\''' "$SOURCES_DEPLOY" ||
  fail 'remote bronhash gebruikt geen veilig geescape-te awk-veld.'
if grep -qF 'awk '\''{print \\$1}'\''' "$SOURCES_DEPLOY"; then
  fail 'remote bronhash bevat een dubbele escape en leest daardoor lokaal $1.'
fi

if grep -E 'ln -sfn[^\n]*Meijendel_bronnen\.sql' "$SOURCES_DEPLOY" >/dev/null; then
  fail 'de bron-dump mag nergens via een symlink worden gepubliceerd.'
fi
if grep -E 'GRANT SELECT ON [`]?Meijendel_bronnen[`]?\.\*' "$SOURCES_HELPER" >/dev/null; then
  fail 'een brede SELECT-grant op Meijendel_bronnen is verboden.'
fi
if grep -F 'DROP DATABASE IF EXISTS `Meijendel_bronnen`' "$SOURCES_HELPER" >/dev/null; then
  fail 'backticks rond Meijendel_bronnen worden door de remote shell als command substitution uitgevoerd.'
fi

for fragment in \
  'SOURCES_SQL_CANDIDATE_FILE=' \
  'SOURCES_DATABASE="Meijendel_bronnen"' \
  'SOURCES_DATABASE_BACKUP=' \
  'CHECK TABLE' \
  'DROP DATABASE IF EXISTS Meijendel_bronnen' \
  'SOURCES_STATUS=ready'; do
  grep -qF "$fragment" "$SOURCES_HELPER" ||
    fail "gesloten bronimport mist veiligheidscontract: $fragment"
done

if grep -Eq 'remote ".*docker|docker (exec|ps|run|compose|stats)' "$SOURCES_DEPLOY"; then
  fail 'het lokale deployscript mag de bronimport niet buiten de gesloten gateway uitvoeren.'
fi

printf 'OK: Meijendel_bronnen blijft apart, afgeschermd en uitsluitend via drie views leesbaar.\n'
