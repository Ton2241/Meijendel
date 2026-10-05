#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="$repo/shiny_meijendel/app.R"

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

if grep -Fq 'cache_path <- meijendel_tables_cache_path(path)' "$app"; then
  fail 'de interactieve SQL-lader dwingt nog het oude generieke cachepad af'
fi
if grep -Fq 'load_meijendel_tables_cached(path, cache_path = cache_path)' "$app"; then
  fail 'de interactieve SQL-lader omzeilt nog het actieve cachemanifest'
fi
[[ "$(grep -Fc 'loaded <- load_meijendel_tables_cached(path)' "$app")" -eq 1 ]] ||
  fail 'de interactieve SQL-lader gebruikt niet exact eenmaal de manifestgestuurde cache-ingang'

printf 'OK: interactieve Shiny SQL-lader gebruikt het actieve cachemanifest.\n'
