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
  console.log("Dashboard-browserloadercontract: groen.");
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
