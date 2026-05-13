const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();
const inputNames = ["inpZoeken", "inpLidtype", "inpDatakwaliteit", "inpWoonplaats"];

const tableData = `{{(() => {
  const refreshTick = appsmith.store.ledenFilterRefresh || 0;
  const rows = q_tellers.data || [];
  const textOf = (getter) => {
    try { return String(getter() || '').trim().toLowerCase(); } catch (e) { return ''; }
  };

  const zoek = textOf(() => inpZoeken.text);
  const lidtype = textOf(() => inpLidtype.text);
  const actiefJaar = textOf(() => inpDatakwaliteit.text);
  const woonplaats = textOf(() => inpWoonplaats.text);

  if (!zoek && !lidtype && !actiefJaar && !woonplaats) return [];

  return rows.filter((r) => {
    const zoekTekst = [r.tellercode, r.naam, r.email].filter(Boolean).join(' ').toLowerCase();
    const actieveJaren = String(r.actieve_jaren || '').split(',').map((jaar) => jaar.trim());
    return (!zoek || zoekTekst.includes(zoek))
      && (!lidtype || String(r.soort_lid || '').trim().toLowerCase() === lidtype)
      && (!actiefJaar || actieveJaren.includes(actiefJaar))
      && (!woonplaats || String(r.woonplaats || '').toLowerCase().includes(woonplaats));
  });
})()}}`;

function findWidget(widget, widgetName) {
  if (!widget) return null;
  if (widget.widgetName === widgetName) return widget;
  for (const child of widget.children || []) {
    const found = findWidget(child, widgetName);
    if (found) return found;
  }
  return null;
}

function setRefreshTrigger(input) {
  input.onTextChanged = "{{storeValue('ledenFilterRefresh', Date.now())}}";
  input.onSubmit = "{{storeValue('ledenFilterRefresh', Date.now())}}";
  input.dynamicTriggerPathList = [
    ...((input.dynamicTriggerPathList || []).filter((path) => !["onTextChanged", "onSubmit"].includes(path.key))),
    { key: "onTextChanged" },
    { key: "onSubmit" },
  ];
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor directe tabelverversing na ledenfilter",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const dsl = page[pageKey].layouts[0].dsl;
  const table = findWidget(dsl, "tblTellers");
  if (!table) throw new Error(`tblTellers niet gevonden in ${pageKey}`);

  for (const name of inputNames) {
    const input = findWidget(dsl, name);
    if (!input) throw new Error(`${name} niet gevonden in ${pageKey}`);
    setRefreshTrigger(input);
  }

  table.tableData = tableData;
  table.dynamicBindingPathList = [
    { key: "tableData" },
    ...Object.keys(table.primaryColumns || {}).map((id) => ({ key: `primaryColumns.${id}.computedValue` })),
  ];
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson({
  tableUsesRefreshTick: findWidget(updated, "tblTellers").tableData.includes("ledenFilterRefresh"),
  triggers: Object.fromEntries(inputNames.map((name) => {
    const input = findWidget(updated, name);
    return [name, { onTextChanged: input.onTextChanged, onSubmit: input.onSubmit }];
  })),
});
