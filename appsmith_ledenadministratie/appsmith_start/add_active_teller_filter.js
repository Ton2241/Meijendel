const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();
const instructionName = "txtInfoZoekInstructie";

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

const filteredTableData = `{{(() => {
  const rows = q_tellers.data || [];
  const textOf = (getter) => {
    try {
      return String(getter() || '').trim().toLowerCase();
    } catch (e) {
      return '';
    }
  };

  const zoek = textOf(() => inpZoeken.text);
  const lidtype = textOf(() => inpLidtype.text);
  const actiefJaar = textOf(() => inpDatakwaliteit.text);
  const woonplaats = textOf(() => inpWoonplaats.text);

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
  const textOf = (getter) => {
    try { return String(getter() || '').trim().toLowerCase(); } catch (e) { return ''; }
  };
  const zoek = textOf(() => inpZoeken.text);
  const lidtype = textOf(() => inpLidtype.text);
  const actiefJaar = textOf(() => inpDatakwaliteit.text);
  const woonplaats = textOf(() => inpWoonplaats.text);
  const rows = (q_tellers.data || []).filter((r) => {
    const zoekTekst = [r.tellercode, r.naam, r.email].filter(Boolean).join(' ').toLowerCase();
    const actieveJaren = String(r.actieve_jaren || '').split(',').map((jaar) => jaar.trim());
    return (!zoek || zoekTekst.includes(zoek))
      && (!lidtype || String(r.soort_lid || '').trim().toLowerCase() === lidtype)
      && (!actiefJaar || actieveJaren.includes(actiefJaar))
      && (!woonplaats || String(r.woonplaats || '').toLowerCase().includes(woonplaats));
  });
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

function instructionWidget(parentId) {
  return {
    widgetName: instructionName,
    widgetId: "infzoek1",
    type: "TEXT_WIDGET",
    version: 1,
    parentId,
    renderMode: "CANVAS",
    isVisible: true,
    topRow: 1,
    bottomRow: 4,
    leftColumn: 0,
    rightColumn: 60,
    text: "Vul eerst een of meer zoektermen in de boxen hieronder in. Geef daarna een enter.",
    fontSize: "0.875rem",
    fontStyle: "BOLD",
    textAlign: "LEFT",
    textColor: "#1F2937",
    dynamicBindingPathList: [],
    dynamicTriggerPathList: [],
  };
}

function setPosition(widget, top, bottom, left, right) {
  widget.topRow = top;
  widget.bottomRow = bottom;
  widget.leftColumn = left;
  widget.rightColumn = right;
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
  reason: "Voor actieve teller filter",
  action,
});
appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor actieve teller filter en zoekinstructie",
  page,
});

appsmithDb.newAction.updateOne(
  { _id: action._id },
  {
    $set: {
      "unpublishedAction.actionConfiguration.body": qTellersBody,
      "unpublishedAction.dynamicBindingPathList": [],
      "unpublishedAction.jsonPathKeys": [],
      "publishedAction.actionConfiguration.body": qTellersBody,
      "publishedAction.dynamicBindingPathList": [],
      "publishedAction.jsonPathKeys": [],
      updatedAt: now,
    },
  },
);

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  const dsl = layout.dsl;
  const canvas = findWidget(dsl, "canInfoPerLid");
  if (!canvas) throw new Error(`canInfoPerLid niet gevonden in ${pageKey}`);

  removeWidgetsByName(dsl, new Set([instructionName]));
  canvas.children = canvas.children || [];
  canvas.children.push(instructionWidget(canvas.widgetId));

  const zoek = findWidget(dsl, "inpZoeken");
  const lidtype = findWidget(dsl, "inpLidtype");
  const actief = findWidget(dsl, "inpDatakwaliteit");
  const woonplaats = findWidget(dsl, "inpWoonplaats");
  const exportButton = findWidget(dsl, "btnExportLedenCsv");
  const table = findWidget(dsl, "tblTellers");
  if (!zoek || !lidtype || !actief || !woonplaats || !exportButton || !table) {
    throw new Error(`Een of meer widgets niet gevonden in ${pageKey}`);
  }

  setPosition(zoek, 5, 12, 0, 15);
  zoek.label = "Naam, code of email";
  zoek.placeholderText = "bijv. lansink";

  setPosition(lidtype, 5, 12, 16, 28);

  setPosition(actief, 5, 12, 29, 43);
  actief.label = "Actieve tellers";
  actief.placeholderText = "jaartal, bijv. 2025";
  actief.labelPosition = "Top";
  actief.inputType = "NUMBER";

  setPosition(woonplaats, 5, 12, 44, 60);

  setPosition(exportButton, 14, 19, 31, 41);

  table.tableData = filteredTableData;
  table.topRow = 21;
  table.dynamicBindingPathList = [
    { key: "tableData" },
    ...Object.keys(table.primaryColumns || {}).map((id) => ({ key: `primaryColumns.${id}.computedValue` })),
  ];

  const title = findWidget(dsl, "txtDetailTitel");
  const detailWidgets = [
    "txtDetailTitel",
    "txtDetail",
    "txtDetailMetaValues",
    "txtDetailContactTitel",
    "txtDetailContactLabels",
    "txtDetailContactValues",
    "txtDetailTellingTitel",
    "txtDetailTellingLabels",
    "txtDetailTellingValues",
    "txtDetailStatusLabel",
    "txtDetailStatusValue",
  ];
  if (title && title.topRow < 14) {
    for (const widgetName of detailWidgets) {
      const widget = findWidget(dsl, widgetName);
      if (widget) {
        widget.topRow += 4;
        widget.bottomRow += 4;
      }
    }
  }

  const exportWidget = findWidget(dsl, "btnExportLedenCsv");
  exportWidget.onClick = exportLedenCsv;
  exportWidget.dynamicTriggerPathList = [
    ...((exportWidget.dynamicTriggerPathList || []).filter((path) => path.key !== "onClick")),
    { key: "onClick" },
  ];

  layout.widgetNames = allWidgetNames(dsl);
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson({
  instruction: findWidget(updated, instructionName).text,
  zoekLabel: findWidget(updated, "inpZoeken").label,
  actiefLabel: findWidget(updated, "inpDatakwaliteit").label,
  actiefPlaceholder: findWidget(updated, "inpDatakwaliteit").placeholderText,
  tableData: findWidget(updated, "tblTellers").tableData,
});
