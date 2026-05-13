const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const exportButtonNames = new Set(["btnExportLedenCsv", "btnExportTelhistorieCsv"]);

const exportLedenCsv = `{{(() => {
  const textOf = (getter) => {
    try { return String(getter() || '').trim().toLowerCase(); } catch (e) { return ''; }
  };
  const zoek = textOf(() => inpZoeken.text);
  const lidtype = textOf(() => inpLidtype.text);
  const datakwaliteit = textOf(() => inpDatakwaliteit.text);
  const woonplaats = textOf(() => inpWoonplaats.text);
  const rows = (q_tellers.data || []).filter((r) => {
    const zoekTekst = [r.tellercode, r.naam, r.email].filter(Boolean).join(' ').toLowerCase();
    return (!zoek || zoekTekst.includes(zoek))
      && (!lidtype || String(r.soort_lid || '').trim().toLowerCase() === lidtype)
      && (!datakwaliteit || String(r.datakwaliteit || '').toLowerCase().includes(datakwaliteit))
      && (!woonplaats || String(r.woonplaats || '').toLowerCase().includes(woonplaats));
  });
  const cols = [
    ['Code', 'tellercode'],
    ['Naam', 'naam'],
    ['Lidtype', 'soort_lid'],
    ['Woonplaats', 'woonplaats'],
    ['Jaren', 'aantal_jaren_geteld'],
    ['Plotjaren', 'aantal_plotjaren'],
    ['Unieke plots', 'aantal_plots'],
    ['Email', 'email'],
    ['Mobiel', 'telefoon_mobiel'],
    ['Datakwaliteit', 'datakwaliteit'],
  ];
  const cell = (value) => '"' + String(value ?? '').replace(/"/g, '""') + '"';
  const csv = [
    cols.map(([label]) => cell(label)).join(';'),
    ...rows.map((row) => cols.map(([, key]) => cell(row[key])).join(';')),
  ].join('\\n');
  download(csv, 'leden_informatie.csv', 'text/csv');
})()}}`;

const exportTelhistorieCsv = `{{(() => {
  const jaar = String(inpTelhistorieJaar.text || '').trim();
  const rows = (q_teller_telhistorie.data || []).filter((r) => !jaar || String(r.jaar || '').trim() === jaar);
  const cols = [
    ['Code', 'tellercode'],
    ['Naam', 'naam'],
    ['Jaar', 'jaar'],
    ['Plots in jaar', 'aantal_plots'],
    ['Kavels', 'kavels'],
  ];
  const cell = (value) => '"' + String(value ?? '').replace(/"/g, '""') + '"';
  const csv = [
    cols.map(([label]) => cell(label)).join(';'),
    ...rows.map((row) => cols.map(([, key]) => cell(row[key])).join(';')),
  ].join('\\n');
  download(csv, jaar ? 'telhistorie_' + jaar + '.csv' : 'telhistorie_alle_tellers.csv', 'text/csv');
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

function removeWidgetsByName(widget, names) {
  if (!widget.children) return;
  widget.children = widget.children.filter((child) => !names.has(child.widgetName));
  for (const child of widget.children) removeWidgetsByName(child, names);
}

function allWidgetNames(widget, names = []) {
  names.push(widget.widgetName);
  for (const child of widget.children || []) allWidgetNames(child, names);
  return names;
}

function buttonWidget({ name, id, parentId, top, bottom, left, right, text, onClick }) {
  return {
    widgetName: name,
    widgetId: id,
    type: "BUTTON_WIDGET",
    version: 1,
    parentId,
    renderMode: "CANVAS",
    isVisible: true,
    isDisabled: false,
    topRow: top,
    bottomRow: bottom,
    leftColumn: left,
    rightColumn: right,
    text,
    buttonStyle: "PRIMARY_BUTTON",
    placement: "CENTER",
    dynamicBindingPathList: [],
    dynamicTriggerPathList: [{ key: "onClick" }],
    onClick,
  };
}

function applyExports(dsl) {
  removeWidgetsByName(dsl, exportButtonNames);

  const infoCanvas = findWidget(dsl, "canInfoPerLid");
  const telCanvas = findWidget(dsl, "canTelhistorie");
  if (!infoCanvas) throw new Error("canInfoPerLid niet gevonden");
  if (!telCanvas) throw new Error("canTelhistorie niet gevonden");

  const tellersTable = findWidget(dsl, "tblTellers");
  if (tellersTable) {
    tellersTable.topRow = 17;
    tellersTable.bottomRow = 78;
  }

  infoCanvas.children = infoCanvas.children || [];
  telCanvas.children = telCanvas.children || [];
  infoCanvas.children.push(buttonWidget({
    name: "btnExportLedenCsv",
    id: "expleden",
    parentId: infoCanvas.widgetId,
    top: 10,
    bottom: 15,
    left: 31,
    right: 41,
    text: "Export CSV",
    onClick: exportLedenCsv,
  }));
  telCanvas.children.push(buttonWidget({
    name: "btnExportTelhistorieCsv",
    id: "exptelh1",
    parentId: telCanvas.widgetId,
    top: 7,
    bottom: 14,
    left: 10,
    right: 20,
    text: "Export CSV",
    onClick: exportTelhistorieCsv,
  }));
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor CSV exportknoppen",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  applyExports(layout.dsl);
  layout.widgetNames = allWidgetNames(layout.dsl);
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson(["btnExportLedenCsv", "btnExportTelhistorieCsv"].map((name) => {
  const widget = findWidget(updated, name);
  return { name, top: widget.topRow, bottom: widget.bottomRow, left: widget.leftColumn, right: widget.rightColumn, type: widget.type };
}));
