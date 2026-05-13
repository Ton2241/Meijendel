const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();
const instructionText = "Vul eerst een zoekterm in een of meer boxen hieronder in. Geef daarna een enter.";
const inputNames = ["inpZoeken", "inpLidtype", "inpDatakwaliteit", "inpWoonplaats"];

const qTellersBody = `SELECT
  l.id,
  l.tellercode,
  l.naam,
  l.soort_lid,
  l.woonplaats,
  l.email,
  l.telefoon_mobiel,
  l.aantal_jaren_geteld,
  l.aantal_plots,
  l.aantal_plotjaren,
  l.eerste_jaar,
  l.laatste_jaar,
  l.datakwaliteit,
  (
    SELECT GROUP_CONCAT(DISTINCT pjt.jaar ORDER BY pjt.jaar SEPARATOR ',')
    FROM plot_jaar_teller pjt
    WHERE pjt.teller_id = l.id
  ) AS actieve_jaren
FROM appsmith_teller_lijst l
ORDER BY l.achternaam, l.voornaam, l.tellercode
LIMIT 500;`;

const tableData = `{{(() => {
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

const exportLedenCsv = `{{(() => {
  const rows = tblTellers.tableData || [];
  const cols = [
    ['Code', 'tellercode'],
    ['Naam', 'naam'],
    ['Lidtype', 'soort_lid'],
    ['Woonplaats', 'woonplaats'],
    ['Email', 'email'],
    ['Mobiel', 'telefoon_mobiel'],
    ['Eerste jaar', 'eerste_jaar'],
    ['Laatste jaar', 'laatste_jaar'],
    ['Jaren', 'aantal_jaren_geteld'],
    ['Plotjaren', 'aantal_plotjaren'],
    ['Unieke plots', 'aantal_plots'],
    ['Datakwaliteit', 'datakwaliteit'],
    ['id', 'id'],
  ];
  const cell = (value) => '"' + String(value ?? '').replace(/"/g, '""') + '"';
  const csv = [
    cols.map(([label]) => cell(label)).join(';'),
    ...rows.map((row) => cols.map(([, key]) => cell(row[key])).join(';')),
  ].join('\\n');
  download(csv, 'leden_informatie.csv', 'text/csv');
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

function setTrigger(input) {
  input.onTextChanged = "";
  input.onSubmit = "";
  input.dynamicTriggerPathList = (input.dynamicTriggerPathList || [])
    .filter((path) => !["onTextChanged", "onSubmit"].includes(path.key));
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

const action = appsmithDb.newAction.findOne({ pageId, name: "q_tellers", deleted: false });
if (!action) throw new Error("q_tellers niet gevonden");

appsmithDb.codexActionBackups.insertOne({
  actionId: action._id,
  pageId,
  name: "q_tellers",
  createdAt: now,
  reason: "Voor stabiele ledenzoekfunctie met client-side filter",
  action,
});
appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor stabiele ledenzoekfunctie met client-side filter",
  page,
});

appsmithDb.newAction.updateOne(
  { _id: action._id },
  {
    $set: {
      "unpublishedAction.actionConfiguration.body": qTellersBody,
      "unpublishedAction.executeOnLoad": true,
      "unpublishedAction.dynamicBindingPathList": [],
      "unpublishedAction.jsonPathKeys": [],
      "publishedAction.actionConfiguration.body": qTellersBody,
      "publishedAction.executeOnLoad": true,
      "publishedAction.dynamicBindingPathList": [],
      "publishedAction.jsonPathKeys": [],
      updatedAt: now,
    },
  },
);

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const dsl = page[pageKey].layouts[0].dsl;
  const instruction = findWidget(dsl, "txtInfoZoekInstructie");
  const table = findWidget(dsl, "tblTellers");
  const exportButton = findWidget(dsl, "btnExportLedenCsv");
  if (!instruction || !table || !exportButton) {
    throw new Error(`Een of meer widgets niet gevonden in ${pageKey}`);
  }

  instruction.text = instructionText;
  instruction.fontStyle = "BOLD";
  instruction.dynamicBindingPathList = [];

  for (const name of inputNames) {
    const input = findWidget(dsl, name);
    if (!input) throw new Error(`${name} niet gevonden in ${pageKey}`);
    setTrigger(input);
  }

  table.tableData = tableData;
  table.dynamicBindingPathList = [
    { key: "tableData" },
    ...Object.keys(table.primaryColumns || {}).map((id) => ({ key: `primaryColumns.${id}.computedValue` })),
  ];

  exportButton.onClick = exportLedenCsv;
  exportButton.dynamicTriggerPathList = [
    ...((exportButton.dynamicTriggerPathList || []).filter((path) => path.key !== "onClick")),
    { key: "onClick" },
  ];
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updatedPage = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
const updatedAction = appsmithDb.newAction.findOne({ pageId, name: "q_tellers", deleted: false });
printjson({
  instruction: findWidget(updatedPage, "txtInfoZoekInstructie").text,
  executeOnLoad: updatedAction.publishedAction.executeOnLoad,
  dynamicBindingPathList: updatedAction.publishedAction.dynamicBindingPathList,
  tableData: findWidget(updatedPage, "tblTellers").tableData,
  triggers: Object.fromEntries(inputNames.map((name) => {
    const input = findWidget(updatedPage, name);
    return [name, { onTextChanged: input.onTextChanged, onSubmit: input.onSubmit }];
  })),
});
