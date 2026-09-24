#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="$REPO_DIR/deploy/Archivering_en_Dump_Meijendel.sh"
UPDATE="$REPO_DIR/deploy/update_en_deploy_meijendel.sh"
DEPLOY="$REPO_DIR/deploy/deploy_meijendel_vps.sh"

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

for file in "$ARCHIVE" "$UPDATE" "$DEPLOY"; do
  grep -qF 'meijendel_bronnen.sql' "$file" ||
    fail "meijendel_bronnen.sql ontbreekt in $file"
done

grep -qF 'Meijendel_bronnen.sql -> $REMOTE_DATA/Meijendel_bronnen.sql' "$DEPLOY" ||
  fail 'het release-manifest noemt de afgeschermde bron-dump niet.'
grep -qF 'GRANT SELECT ON \`Meijendel_bronnen\`.\`v_bron_catalogus\`' "$DEPLOY" ||
  fail 'viewgrant voor v_bron_catalogus ontbreekt.'
grep -qF 'GRANT SELECT ON \`Meijendel_bronnen\`.\`v_literatuur_overzicht\`' "$DEPLOY" ||
  fail 'viewgrant voor v_literatuur_overzicht ontbreekt.'
grep -qF 'GRANT SELECT ON \`Meijendel_bronnen\`.\`v_contextdataset_overzicht\`' "$DEPLOY" ||
  fail 'viewgrant voor v_contextdataset_overzicht ontbreekt.'
grep -qF 'information_schema.SCHEMA_PRIVILEGES' "$DEPLOY" ||
  fail 'controle op brede schemarechten ontbreekt.'
grep -qF 'information_schema.TABLE_PRIVILEGES' "$DEPLOY" ||
  fail 'controle op uitsluitend drie viewrechten ontbreekt.'
grep -qF '/Meijendel_bronnen.sql' "$DEPLOY" ||
  fail 'publieke 403/404-controle voor de bron-dump ontbreekt.'

if grep -E 'ln -sfn[^\n]*Meijendel_bronnen\.sql' "$DEPLOY" >/dev/null; then
  fail 'de bron-dump mag nergens via een symlink worden gepubliceerd.'
fi
if grep -E 'GRANT SELECT ON [`]?Meijendel_bronnen[`]?\.\*' "$DEPLOY" >/dev/null; then
  fail 'een brede SELECT-grant op Meijendel_bronnen is verboden.'
fi

printf 'OK: Meijendel_bronnen blijft apart, afgeschermd en uitsluitend via drie views leesbaar.\n'
