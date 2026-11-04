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

  async function loadReleaseConfig(options={}) {
    const fetchImpl=options.fetchImpl || fetch.bind(globalThis);
    const response=await fetchImpl('release-config.json',{cache:'no-store'});
    if(response.status===404)return null;
    if(!response.ok)throw new Error('Releaseconfiguratie niet beschikbaar');
    const c=await response.json();
    const host=options.hostname || (typeof location!=='undefined'?location.hostname:'');
    if(c.schema!=='meijendel-integral-release-v1'||c.presentation_approved!==true ||
       (c.mode==='local_rehearsal'?!['127.0.0.1','localhost','::1'].includes(host):c.mode!=='production'||c.official_data_validated!==true))throw new Error('Release niet vrijgegeven voor deze weergave');
    if(c.source_hash!==options.sourceManifest.sql_sha256)throw new Error('Bootstrap en dashboard hebben een verschillende bron');
    const metaResponse=await checkedResponse(fetchImpl,'outputs/bootstrap-presentatie-2026/manifest.json');
    const raw=await metaResponse.text(),b=JSON.parse(raw);
    const hash=options.sha256 || (async text=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text)))).map(x=>x.toString(16).padStart(2,'0')).join(''));
    if(await hash(raw)!==c.bootstrap.manifest_sha256 || b.source_hash!==c.source_hash ||
       b.year_from!==c.year_from || b.year_to!==c.year_to || b.html_sha256!==c.bootstrap.html_sha256 ||
       b.schema!=='trim-bootstrap-presentation-v1'||b.publication_status!=='diagnostisch')throw new Error('Bootstrapmanifest past niet bij de actieve release');
    return c;
  }

  return {loadDashboardData, loadReleaseConfig, parseManifest, inflateTables};
});
