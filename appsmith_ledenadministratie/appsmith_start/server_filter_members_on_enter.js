const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

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
WHERE {{(
    (inpZoeken.text || '').trim()
    || (inpLidtype.text || '').trim()
    || (inpDatakwaliteit.text || '').trim()
    || (inpWoonplaats.text || '').trim()
  ) ? 1 : 0}} = 1
  AND (
    {{(inpZoeken.text || '').trim() ? 0 : 1}} = 1
    OR LOWER(CONCAT_WS(' ', l.tellercode, l.naam, l.email)) LIKE {{'%' + (inpZoeken.text || '').trim().toLowerCase() + '%'}}
  )
  AND (
    {{(inpLidtype.text || '').trim() ? 0 : 1}} = 1
    OR LOWER(TRIM(l.soort_lid)) = {{(inpLidtype.text || '').trim().toLowerCase()}}
  )
  AND (
    {{(inpDatakwaliteit.text || '').trim() ? 0 : 1}} = 1
    OR EXISTS (
      SELECT 1
      FROM plot_jaar_teller pjt_actief
      WHERE pjt_actief.teller_id = l.id
        AND pjt_actief.jaar = {{Number((inpDatakwaliteit.text || '').trim() || 0)}}
    )
  )
  AND (
    {{(inpWoonplaats.text || '').trim() ? 0 : 1}} = 1
    OR LOWER(l.woonplaats) LIKE {{'%' + (inpWoonplaats.text || '').trim().toLowerCase() + '%'}}
  )
ORDER BY l.achternaam, l.voornaam, l.tellercode
LIMIT 500;`;

const exportLedenCsv = `{{(() => {
  const rows = q_tellers.data || [];
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

function setEnterTrigger(input) {
  input.onTextChanged = "";
  input.onSubmit = "{{q_tellers.run()}}";
  input.dynamicTriggerPathList = [
    ...((input.dynamicTriggerPathList || []).filter((path) => !["onTextChanged", "onSubmit"].includes(path.key))),
    { key: "onSubmit" },
  ];
}

function setInputLayout(input, label, placeholder, top, bottom, left, right) {
  input.label = label;
  input.placeholderText = placeholder;
  input.labelPosition = "Top";
  input.topRow = top;
  input.bottomRow = bottom;
  input.leftColumn = left;
  input.rightColumn = right;
  setEnterTrigger(input);
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
  reason: "Voor server-side ledenfilter op Enter",
  action,
});
appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor uitlijning actieve tellers en Enter-trigger",
  page,
});

appsmithDb.newAction.updateOne(
  { _id: action._id },
  {
    $set: {
      "unpublishedAction.actionConfiguration.body": qTellersBody,
      "unpublishedAction.executeOnLoad": false,
      "unpublishedAction.dynamicBindingPathList": [
        { key: "actionConfiguration.body" },
      ],
      "unpublishedAction.jsonPathKeys": [
        "(\n    (inpZoeken.text || '').trim()\n    || (inpLidtype.text || '').trim()\n    || (inpDatakwaliteit.text || '').trim()\n    || (inpWoonplaats.text || '').trim()\n  ) ? 1 : 0",
        "(inpZoeken.text || '').trim() ? 0 : 1",
        "'%' + (inpZoeken.text || '').trim().toLowerCase() + '%'",
        "(inpLidtype.text || '').trim() ? 0 : 1",
        "(inpLidtype.text || '').trim().toLowerCase()",
        "(inpDatakwaliteit.text || '').trim() ? 0 : 1",
        "Number((inpDatakwaliteit.text || '').trim() || 0)",
        "(inpWoonplaats.text || '').trim() ? 0 : 1",
        "'%' + (inpWoonplaats.text || '').trim().toLowerCase() + '%'",
      ],
      "publishedAction.actionConfiguration.body": qTellersBody,
      "publishedAction.executeOnLoad": false,
      "publishedAction.dynamicBindingPathList": [
        { key: "actionConfiguration.body" },
      ],
      "publishedAction.jsonPathKeys": [
        "(\n    (inpZoeken.text || '').trim()\n    || (inpLidtype.text || '').trim()\n    || (inpDatakwaliteit.text || '').trim()\n    || (inpWoonplaats.text || '').trim()\n  ) ? 1 : 0",
        "(inpZoeken.text || '').trim() ? 0 : 1",
        "'%' + (inpZoeken.text || '').trim().toLowerCase() + '%'",
        "(inpLidtype.text || '').trim() ? 0 : 1",
        "(inpLidtype.text || '').trim().toLowerCase()",
        "(inpDatakwaliteit.text || '').trim() ? 0 : 1",
        "Number((inpDatakwaliteit.text || '').trim() || 0)",
        "(inpWoonplaats.text || '').trim() ? 0 : 1",
        "'%' + (inpWoonplaats.text || '').trim().toLowerCase() + '%'",
      ],
      updatedAt: now,
    },
  },
);

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const dsl = page[pageKey].layouts[0].dsl;
  const zoek = findWidget(dsl, "inpZoeken");
  const lidtype = findWidget(dsl, "inpLidtype");
  const actief = findWidget(dsl, "inpDatakwaliteit");
  const woonplaats = findWidget(dsl, "inpWoonplaats");
  const table = findWidget(dsl, "tblTellers");
  const exportButton = findWidget(dsl, "btnExportLedenCsv");

  if (!zoek || !lidtype || !actief || !woonplaats || !table || !exportButton) {
    throw new Error(`Een of meer widgets niet gevonden in ${pageKey}`);
  }

  setInputLayout(zoek, "Naam, code of email", "bijv. lansink", 5, 12, 0, 15);
  setInputLayout(lidtype, "Lidtype", "bijv. gewoon", 5, 12, 16, 28);
  setInputLayout(actief, "Actieve tellers", "jaartal, bijv. 2025", 5, 12, 29, 43);
  actief.inputType = "NUMBER";
  setInputLayout(woonplaats, "Woonplaats", "bijv. Leiden", 5, 12, 44, 60);

  table.tableData = "{{q_tellers.data || []}}";
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

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
const updatedAction = appsmithDb.newAction.findOne({ pageId, name: "q_tellers", deleted: false });
printjson({
  executeOnLoad: updatedAction.publishedAction.executeOnLoad,
  activeLabel: findWidget(updated, "inpDatakwaliteit").label,
  activeLabelPosition: findWidget(updated, "inpDatakwaliteit").labelPosition,
  activeOnSubmit: findWidget(updated, "inpDatakwaliteit").onSubmit,
  activeOnTextChanged: findWidget(updated, "inpDatakwaliteit").onTextChanged,
  tableData: findWidget(updated, "tblTellers").tableData,
});
