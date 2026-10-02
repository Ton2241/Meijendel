#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo/deploy/rebuild_shiny_image_vps.sh"

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

grep -Fq 'MEIJENDEL_REQUIRE_PREBUILT_CACHE=1' "$script" ||
  fail 'kandidaat gebruikt de verplichte vooraf gebouwde cache niet'
grep -Fq 'MEIJENDEL_SQL_MANIFEST_PATH=/srv/shiny-server/Meijendel.sql.manifest' "$script" ||
  fail 'kandidaat krijgt het SQL-manifest niet'
grep -Fq 'MEIJENDEL_CACHE_MANIFEST_PATH=/srv/shiny-server/shiny_meijendel/app_cache/meijendel_tables_cache.active.manifest' "$script" ||
  fail 'kandidaat krijgt het actieve cachemanifest niet'
grep -Fq 'stopifnot(isTRUE(x[[\"from_cache\"]])' "$script" ||
  fail 'kandidaat bewijst niet dat uitsluitend de vooraf gebouwde cache is gebruikt'
if grep -Fq 'stopifnot(!isTRUE(first[[\"from_cache\"]])' "$script"; then
  fail 'kandidaat probeert het volledige SQL-bestand nog opnieuw te parsen'
fi

printf 'OK: Shiny-kandidaat gebruikt uitsluitend een geisoleerde kopie van de productiecache.\n'
