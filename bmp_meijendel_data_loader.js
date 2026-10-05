(function(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.MeijendelDashboardData = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function() {
  "use strict";

  const DATA_FORMAT = "meijendel-dashboard-data-v1";
  const MANIFEST_FORMAT = "meijendel-dashboard-data-manifest-v1";

  function parseManifest(text) {
    const result = {};
    String(text).split(/\r?\n/).forEach(line => {
      if (!line || line.startsWith("#")) return;
      const pos = line.indexOf("=");
      if (pos > 0) result[line.slice(0, pos)] = line.slice(pos + 1);
    });
    return result;
  }

  function inflateTables(compactTables) {
    const tables = {};
    Object.entries(compactTables || {}).forEach(([name, table]) => {
      if (!Array.isArray(table.columns) || !Array.isArray(table.rows)) {
        throw new Error(`Dashboardtabel ${name} heeft een ongeldig formaat.`);
      }
      const columns = table.columns.map(String);
      const rows = table.rows.map(values => {
        if (!Array.isArray(values) || values.length !== columns.length) {
          throw new Error(`Dashboardtabel ${name} bevat een ongeldige rij.`);
        }
        const row = {};
        columns.forEach((column, index) => { row[column] = values[index]; });
        return row;
      });
      tables[name] = {columns, rows};
    });
    return tables;
  }

  async function checkedResponse(fetchImpl, url) {
    const response = await fetchImpl(url, {cache: "no-store"});
    if (!response || response.ok === false) {
      throw new Error(`Dashboardbestand kon niet worden geladen: ${url}`);
    }
    return response;
  }

  async function loadDashboardData(options = {}) {
    const fetchImpl = options.fetchImpl || (typeof fetch === "function" ? fetch.bind(globalThis) : null);
    if (!fetchImpl) throw new Error("Geen fetch-implementatie beschikbaar.");
    const manifestUrl = options.manifestUrl || "bmp_meijendel_data.json.manifest";
    const dataUrl = options.dataUrl || "bmp_meijendel_data.json";
    const manifestResponse = await checkedResponse(fetchImpl, manifestUrl);
    const manifest = parseManifest(await manifestResponse.text());
    if (manifest.format !== MANIFEST_FORMAT) throw new Error("Ongeldig dashboardmanifest.");
    if (!/^[0-9a-f]{64}$/.test(manifest.sql_sha256 || "")) throw new Error("Dashboardmanifest mist een geldige SQL-hash.");

    const dataResponse = await checkedResponse(fetchImpl, dataUrl);
    const compact = await dataResponse.json();
    if (compact.format !== DATA_FORMAT) throw new Error("Ongeldig dashboarddataformaat.");
    if (compact.sql_sha256 !== manifest.sql_sha256) throw new Error("Dashboarddata en manifest hebben een verschillende SQL-hash.");
    if (String(compact.sql_bytes) !== String(manifest.sql_bytes)) throw new Error("Dashboarddata en manifest hebben een verschillende SQL-grootte.");
    if (String(compact.parser_version) !== String(manifest.parser_version)) throw new Error("Dashboarddata en manifest hebben een verschillende parserversie.");
    if (Object.keys(compact.tables || {}).length !== Number(manifest.table_count)) throw new Error("Dashboarddata en manifest hebben een verschillend tabelaantal.");
    return {manifest, tables: inflateTables(compact.tables)};
  }

  return {loadDashboardData, parseManifest, inflateTables};
});
