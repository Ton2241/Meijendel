#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/meijendel-dashboard-data-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

node "$ROOT/scripts/test_dashboard_browser_data_loader.js"
grep -Fq '<script src="bmp_meijendel_data_loader.js"></script>' "$ROOT/bmp_meijendel_index.html"
if grep -Fq 'sql:["Meijendel.sql","meijendel.sql"]' "$ROOT/bmp_meijendel_index.html"; then
  echo "FOUT: dashboard probeert de volledige SQL-dump nog automatisch te laden." >&2
  exit 1
fi
grep -Fq 'bmp_meijendel_data.json -> $REMOTE_WWW/bmp_meijendel_data.json' "$ROOT/deploy/deploy_meijendel_vps.sh"
grep -Fq 'bmp_meijendel_data_loader.js -> $REMOTE_WWW/bmp_meijendel_data_loader.js' "$ROOT/deploy/deploy_meijendel_vps.sh"

cache="$TMP_ROOT/cache.rds"
cache_manifest="$TMP_ROOT/cache.manifest"
output="$TMP_ROOT/bmp_meijendel_data.json"
output_manifest="$output.manifest"
sql_hash="$(printf 'a%.0s' {1..64})"

Rscript -e '
  args <- commandArgs(TRUE)
  schemas <- list(
    plots=c("plot_id","plot_naam","kavel_nummer","in_gebruik"),
    plot_analyse_scope=c("scope_code","plot_id","in_scope","reden","besluitdatum"),
    soorten=c("id","euring_code","soort_naam","engelse_naam"),
    plot_jaar_oppervlak=c("plot_id","jaar","oppervlakte_km2"),
    plot_jaar_teller=c("teller_id","plot_id","jaar"),
    territoria=c("plot_id","soort_id","jaar","territoria","bron_id"),
    bronnen=c("id","code"), sovon_bmp_plotjaar=c("plot_id","jaar","beoordelingsstatus"),
    evg_vogelgroepen=c("groepsnummer","landschap_groep","beschrijving_landschap_groep"),
    evg_vogel_landschapgroep=c("groepsnummer","vogel_id"),
    functional_group_definition=c("id","group_code","group_version","naam_nl","minimum_exploratief","minimum_hoofdindicator","minimum_robuust","status"),
    functional_group_membership=c("functional_group_definition_id","soort_id","binary_membership","membership_weight","classification"),
    richtlijnen=c("id","naam"), soort_richtlijn=c("soort_id","richtlijn_id"),
    soorten_kenmerken=c("id","soort_id","soortnaam","hoofdcategorie_id","code","waarde"),
    soorten_kenmerken_datadictionary=c("id","veld","betekenis","betekenis_nederlands","parent_code","code_type","status"),
    soorten_kenmerken_hoofdcategorien=c("id","code","beschrijving"),
    soorten_kenmerken_vogeltypering=c("soort_id"), habitattypen=c("id","habitat_code","habitat_naam"),
    plot_jaar_habitat=c("plot_id","jaar","habitat_id","aandeel_m2"),
    plot_jaar_ahn_dtm=c("plot_id","jaar","bron","ahn_mean","ahn_sd"),
    plot_jaar_stikstof=c("plot_id","jaar","bron","stikstof_mean"),
    plot_jaar_infra=c("plot_id","jaar","bron","variabele","waarde"),
    plot_jaar_toegankelijkheid=c("plot_id","jaar","bron","status_code"),
    pq_plot_jaar_vegetatie=c("plot_id","jaar","n_pq","n_opnamen","taxa_aantal","soortenrijkdom_gem","bedekking_som_gem","shannon_gem","dekking_kwaliteit","bronstatus","bronbestand","importversie","taxonlijst_versie"),
    dagwaarnemingen_wv=c("plot_id","soort_id","jaar","maand","dag","aantal"),
    maatregelen=c("id","omschrijving"), plot_jaar_landgebruik=c("plot_id","jaar","bron","klasse","pct"),
    plot_jaar_maatregel=c("plot_id","jaar","maatregel_id"), plot_link=c("plot_id","link_type","label","url"),
    soorten_habitattypen=c("soort_id","habitattype_id","koppelingsterkte"), tellers=c("id","tellercode"),
    trends=c("soort_id","regio","jaar","waarde")
  )
  tables <- lapply(schemas, function(columns) as.data.frame(setNames(replicate(length(columns), logical(), simplify=FALSE), columns)))
  tables$plots <- data.frame(plot_id=1L, plot_naam="Kavel 1", kavel_nummer="1", in_gebruik=1L)
  tables$plot_analyse_scope <- data.frame(scope_code="meijendel_natura2000", plot_id=1L, in_scope=1L, reden="test", besluitdatum="2026-01-01")
  tables$soorten <- data.frame(id=1L, euring_code=1L, soort_naam="Testvogel", engelse_naam="Test bird")
  tables$territoria <- data.frame(plot_id=1L, soort_id=1L, jaar=2025L, territoria=3, bron_id=1L)
  saveRDS(list(
    format="meijendel-shiny-cache-v1",
    identity=list(format="meijendel-shiny-cache-v1", sql_sha256=args[[2]], sql_bytes="1234", parser_version="13"),
    data=tables
  ), args[[1]], version=3)
' "$cache" "$sql_hash"

bad_cache="$TMP_ROOT/bad-cache.rds"
bad_manifest="$TMP_ROOT/bad-cache.manifest"
Rscript -e 'x<-readRDS(commandArgs(TRUE)[[1]]); x$data$evg_vogelgroepen$beschrijving_landschap_groep<-NULL; saveRDS(x,commandArgs(TRUE)[[2]],version=3)' "$cache" "$bad_cache"
bad_hash="$(shasum -a 256 "$bad_cache" | awk '{print $1}')"
bad_bytes="$(stat -f '%z' "$bad_cache")"
cat > "$bad_manifest" <<EOF
format=meijendel-shiny-cache-manifest-v1
sql_sha256=$sql_hash
sql_bytes=1234
parser_version=13
cache_sha256=$bad_hash
cache_bytes=$bad_bytes
cache_file=$(basename "$bad_cache")
EOF
if Rscript "$ROOT/R/build_dashboard_browser_data.R" "$bad_cache" "$bad_manifest" "$TMP_ROOT/bad.json" "$TMP_ROOT/bad.json.manifest" >/dev/null 2>&1; then
  echo "FOUT: dashboardgenerator accepteerde een ontbrekende groepsbeschrijving." >&2
  exit 1
fi

cache_sha="$(shasum -a 256 "$cache" | awk '{print $1}')"
cache_bytes="$(stat -f '%z' "$cache")"
cat > "$cache_manifest" <<EOF
format=meijendel-shiny-cache-manifest-v1
sql_sha256=$sql_hash
sql_bytes=1234
parser_version=13
cache_sha256=$cache_sha
cache_bytes=$cache_bytes
cache_file=$(basename "$cache")
EOF

Rscript "$ROOT/R/build_dashboard_browser_data.R" \
  "$cache" "$cache_manifest" "$output" "$output_manifest"

[[ -s "$output" ]] || { echo "FOUT: dashboarddataset ontbreekt." >&2; exit 1; }
[[ -s "$output_manifest" ]] || { echo "FOUT: dashboardmanifest ontbreekt." >&2; exit 1; }
grep -Fqx 'format=meijendel-dashboard-data-manifest-v1' "$output_manifest"
grep -Fqx "sql_sha256=$sql_hash" "$output_manifest"
grep -Fqx 'parser_version=13' "$output_manifest"
grep -Fqx 'table_count=33' "$output_manifest"
expected_hash="$(awk -F= '$1=="dashboard_data_sha256"{print $2}' "$output_manifest")"
[[ "$(shasum -a 256 "$output" | awk '{print $1}')" == "$expected_hash" ]] || {
  echo "FOUT: dashboardhash wijkt af van manifest." >&2
  exit 1
}

node -e '
  const fs=require("node:fs");
  const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  if(data.format!=="meijendel-dashboard-data-v1")throw new Error("verkeerd dataformaat");
  if(data.tables.territoria.rows[0][3]!==3)throw new Error("territoria ontbreekt");
  if(Object.hasOwn(data.tables,"sql_path"))throw new Error("sql_path mag niet worden gepubliceerd");
' "$output"

echo "Dashboard-browserdatacontract: groen."
