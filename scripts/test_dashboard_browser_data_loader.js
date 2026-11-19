"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const loader = require(path.join(__dirname, "..", "bmp_meijendel_data_loader.js"));

function response(body) {
  return {
    ok: true,
    text: async () => String(body),
    json: async () => JSON.parse(String(body))
  };
}

async function main() {
  const sqlHash = "a".repeat(64);
  const requested = [];
  const manifest = [
    "format=meijendel-dashboard-data-manifest-v1",
    `sql_sha256=${sqlHash}`,
    "sql_bytes=1234",
    "parser_version=13",
    "dashboard_data_sha256=" + "b".repeat(64),
    "dashboard_data_bytes=456",
    "table_count=2"
  ].join("\n");
  const data = JSON.stringify({
    format: "meijendel-dashboard-data-v1",
    sql_sha256: sqlHash,
    sql_bytes: "1234",
    parser_version: 13,
    tables: {
      plots: {columns: ["plot_id", "plot_naam"], rows: [[1, "Kavel 1"]]},
      territoria: {columns: ["plot_id", "jaar", "territoria"], rows: [[1, 2025, 3]]}
    }
  });
  const fakeFetch = async url => {
    requested.push(url);
    if (url === "bmp_meijendel_data.json.manifest") return response(manifest);
    if (url === "bmp_meijendel_data.json") return response(data);
    throw new Error(`Onverwachte URL: ${url}`);
  };

  const result = await loader.loadDashboardData({fetchImpl: fakeFetch});
  assert.deepEqual(requested, ["bmp_meijendel_data.json.manifest", "bmp_meijendel_data.json"]);
  assert.deepEqual(result.tables.plots.rows, [{plot_id: 1, plot_naam: "Kavel 1"}]);
  assert.deepEqual(result.tables.territoria.rows, [{plot_id: 1, jaar: 2025, territoria: 3}]);
  assert.equal(requested.some(url => /meijendel\.sql/i.test(url)), false);

  const mismatched = JSON.stringify({...JSON.parse(data), sql_sha256: "c".repeat(64)});
  await assert.rejects(
    () => loader.loadDashboardData({
      fetchImpl: async url => response(url.endsWith(".manifest") ? manifest : mismatched)
    }),
    /SQL-hash/
  );
  const hash = value => require("node:crypto").createHash("sha256").update(value).digest("hex");
  const root = "outputs/aantalsindex-preview";
  const shared = "<h1>Aantalsindex</h1>";
  const dashboard = "<h1>Aantalsindex voor dashboard</h1>";
  const groupManifest = JSON.stringify({
    presentation_kind: "ecologische_aantalsindex", publication_status: "diagnostisch",
    source_hash: sqlHash, year_from: 1958, year_to: 2026,
    html_sha256: hash(shared), dashboard_html_sha256: hash(dashboard)
  });
  const config = JSON.stringify({
    schema: "meijendel-integral-release-v1", mode: "production",
    presentation_approved: true, official_data_validated: true,
    source_hash: sqlHash, year_from: 1958, year_to: 2026,
    group_index: {root, manifest_sha256: hash(groupManifest), html_sha256: hash(shared)}
  });
  const serve = dashboardHtml => async url => response({
    "release-config.json": config,
    [root + "/manifest.json"]: groupManifest,
    [root + "/bootstrap.html"]: shared,
    [root + "/dashboard.html?v=" + hash(dashboard)]: dashboardHtml
  }[url]);
  const releaseOptions = {sha256: hash, sourceManifest: {sql_sha256: sqlHash}};
  const release = await loader.loadReleaseConfig({...releaseOptions, fetchImpl: serve(dashboard)});
  assert.equal(release.group_index.dashboard_html_sha256, hash(dashboard));
  await assert.rejects(
    () => loader.loadReleaseConfig({...releaseOptions, fetchImpl: serve("onjuist")}),
    /geen geldige presentatie/
  );
  console.log("Dashboard-browserloadercontract: groen.");
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});

// De echte dashboardfunctie leidt de kavelstatus uitsluitend uit gebiedsaandelen af.
{
  const fs=require('node:fs'),vm=require('node:vm');
  const html=fs.readFileSync(path.join(__dirname,'..','bmp_meijendel_index.html'),'utf8');
  const extract=name=>{const start=html.indexOf(`function ${name}(`);assert.ok(start>=0,name);return html.slice(start,html.indexOf('\nfunction ',start+1));};
  const tables={toegankelijkheidsgebied_plot_afleiding:[{plot_id:1,gebied_versie_id:1,status_code:'afgesloten',aandeel_pct:60,geldig_vanaf:'1955-01-01',geldig_tot:null},{plot_id:1,gebied_versie_id:2,status_code:'toegankelijk_met_toegangskaart',aandeel_pct:20,geldig_vanaf:'1955-01-01',geldig_tot:null},{plot_id:2,gebied_versie_id:3,status_code:'toegankelijk',aandeel_pct:100,geldig_vanaf:'1955-01-01',geldig_tot:null}],maatregel_beheer_jaar:[{plot_id:1,jaar:1999,maatregel_id:3}],maatregelen:[{id:3,omschrijving:'Begrazing'}]};
  const ctx={getTableRows:name=>tables[name]||[],toYear:Number,Object};vm.createContext(ctx);
  vm.runInContext(extract('getSelectedToegankelijkheid')+'\n'+extract('getMaatregelblok'),ctx);
  assert.equal(ctx.getSelectedToegankelijkheid(1,1954).status_code,'onbekend');
  assert.equal(ctx.getSelectedToegankelijkheid(1,2026).status_code,'gemengd');
  assert.equal(ctx.getSelectedToegankelijkheid(1,2026).onbekend,20);
  assert.equal(ctx.getSelectedToegankelijkheid(2,2026).status_code,'toegankelijk');
  assert.equal(ctx.getMaatregelblok(1,2026).items.length,0);
  assert.equal(ctx.getMaatregelblok(1,1999).items[0],'Begrazing');
}
