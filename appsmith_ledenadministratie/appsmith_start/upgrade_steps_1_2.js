const appsmithDb = db.getSiblingDB("appsmith");

const appId = "69f372c89e8d978bb38cc423";
const pageId = "69f372c89e8d978bb38cc425";
const datasourceId = "69f373179e8d978bb38cc426";
const now = new Date();

const datasource = appsmithDb.datasource.findOne({ _id: ObjectId(datasourceId) });
const sampleAction = appsmithDb.newAction.findOne({ pageId, name: "q_stats", deleted: false });

const actionBodies = {
  q_stats: `SELECT label, waarde
FROM appsmith_teller_stats
ORDER BY FIELD(
  label,
  'totaal tellers',
  'actieve gewone leden',
  'aspiranten',
  'oudtellers',
  'zonder email',
  'zonder mobiel',
  'zonder woonplaats'
);`,
  q_tellers: `SELECT
  id,
  tellercode,
  naam,
  soort_lid,
  woonplaats,
  email,
  telefoon_mobiel,
  aantal_jaren_geteld,
  aantal_plots,
  aantal_plotjaren,
  eerste_jaar,
  laatste_jaar,
  datakwaliteit
FROM appsmith_teller_lijst
ORDER BY achternaam, voornaam, tellercode
LIMIT 500;`,
  q_teller_detail: `SELECT *
FROM appsmith_teller_detail
WHERE id = {{tblTellers.selectedRow.id || 0}};`,
  q_datakwaliteit: `SELECT id, tellercode, naam, soort_lid, aandachtspunt
FROM appsmith_teller_datakwaliteit
ORDER BY soort_lid, naam
LIMIT 500;`,
  q_teller_telhistorie: `SELECT teller_id, tellercode, naam, jaar, aantal_plots, kavels
FROM appsmith_teller_telhistorie
ORDER BY naam, jaar DESC;`,
  q_actieve_tellers_per_jaar: `SELECT jaar, actieve_tellers, getelde_plots, plotjaren
FROM appsmith_actieve_tellers_per_jaar
ORDER BY jaar DESC;`,
};

const dynamicKeys = {
  q_teller_detail: ["tblTellers.selectedRow.id || 0"],
};

const onLoadActions = new Set(["q_stats", "q_tellers", "q_datakwaliteit", "q_teller_telhistorie", "q_actieve_tellers_per_jaar"]);

function cloneAction(name) {
  const doc = structuredClone(sampleAction);
  doc._id = new ObjectId();
  doc.name = name;
  doc.fullyQualifiedName = name;
  doc.createdAt = now;
  doc.updatedAt = now;
  return doc;
}

for (const [name, body] of Object.entries(actionBodies)) {
  let action = appsmithDb.newAction.findOne({ pageId, name, deleted: false });
  if (!action) {
    action = cloneAction(name);
    appsmithDb.newAction.insertOne(action);
  }

  const isDynamic = body.includes("{{");
  const userSetOnLoad = onLoadActions.has(name);
  const jsonPathKeys = dynamicKeys[name] || [];
  const config = {
    timeoutInMillisecond: 10000,
    paginationType: "NONE",
    encodeParamsToggle: true,
    body,
    pluginSpecifiedTemplates: [{ value: false }],
  };

  appsmithDb.newAction.updateOne(
    { _id: action._id },
    {
      $set: {
        applicationId: appId,
        workspaceId: datasource.workspaceId,
        pageId,
        name,
        pluginId: datasource.pluginId,
        pluginType: "DB",
        datasource,
        "unpublishedAction.name": name,
        "unpublishedAction.datasource": datasource,
        "unpublishedAction.pageId": pageId,
        "unpublishedAction.pluginId": datasource.pluginId,
        "unpublishedAction.pluginType": "DB",
        "unpublishedAction.actionConfiguration": config,
        "unpublishedAction.runBehaviour": userSetOnLoad ? "AUTOMATIC" : "MANUAL",
        "unpublishedAction.dynamicBindingPathList": isDynamic ? [{ key: "body" }] : [],
        "unpublishedAction.isValid": true,
        "unpublishedAction.invalids": [],
        "unpublishedAction.jsonPathKeys": jsonPathKeys,
        "unpublishedAction.userSetOnLoad": userSetOnLoad,
        "unpublishedAction.confirmBeforeExecute": false,
        "publishedAction.name": name,
        "publishedAction.datasource": datasource,
        "publishedAction.pageId": pageId,
        "publishedAction.pluginId": datasource.pluginId,
        "publishedAction.pluginType": "DB",
        "publishedAction.actionConfiguration": config,
        "publishedAction.runBehaviour": userSetOnLoad ? "AUTOMATIC" : "MANUAL",
        "publishedAction.dynamicBindingPathList": isDynamic ? [{ key: "body" }] : [],
        "publishedAction.isValid": true,
        "publishedAction.invalids": [],
        "publishedAction.jsonPathKeys": jsonPathKeys,
        "publishedAction.userSetOnLoad": userSetOnLoad,
        "publishedAction.confirmBeforeExecute": false,
        runBehaviour: userSetOnLoad ? "AUTOMATIC" : "MANUAL",
        executeOnLoad: userSetOnLoad,
        deleted: false,
        updatedAt: now,
      },
    },
  );
}

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

function widgetId() {
  return new ObjectId().toString().slice(-8);
}

function inputWidget(name, label, placeholder, leftColumn, rightColumn) {
  return {
    widgetName: name,
    widgetId: widgetId(),
    type: "INPUT_WIDGET_V2",
    version: 2,
    parentId: "0",
    renderMode: "CANVAS",
    isVisible: true,
    topRow: 13,
    bottomRow: 20,
    leftColumn,
    rightColumn,
    label,
    placeholderText: placeholder,
    inputType: "TEXT",
    defaultText: "",
    dynamicBindingPathList: [],
    dynamicTriggerPathList: [{ key: "onTextChanged" }],
    onTextChanged: "{{q_tellers.run()}}",
  };
}

function textWidget(name, text, topRow, bottomRow, leftColumn, rightColumn, bold = false) {
  return {
    widgetName: name,
    widgetId: widgetId(),
    type: "TEXT_WIDGET",
    version: 1,
    parentId: "0",
    renderMode: "CANVAS",
    isVisible: true,
    topRow,
    bottomRow,
    leftColumn,
    rightColumn,
    text,
    fontSize: bold ? "1rem" : "0.875rem",
    fontStyle: bold ? "BOLD" : "",
    textAlign: "LEFT",
    textColor: "#1f2937",
    dynamicBindingPathList: text.includes("{{") ? [{ key: "text" }] : [],
    dynamicTriggerPathList: [],
  };
}

function tableWidget(name, tableData, topRow, bottomRow, leftColumn, rightColumn, columns, defaultPageSize = 10) {
  const widget = {
    widgetName: name,
    widgetId: widgetId(),
    type: "TABLE_WIDGET_V2",
    version: 2,
    parentId: "0",
    renderMode: "CANVAS",
    isVisible: true,
    topRow,
    bottomRow,
    leftColumn,
    rightColumn,
    dynamicTriggerPathList: [],
    primaryColumns: {},
    columnOrder: [],
    enableClientSideSearch: true,
    isVisibleSearch: true,
    isSortable: true,
  };
  configureTable(widget, tableData, columns, defaultPageSize);
  return widget;
}

function column(widgetName, id, index, type = "text", width = 150, label = id) {
  return {
    allowCellWrapping: false,
    allowSameOptionsInNewRow: true,
    index,
    width,
    originalId: id,
    id,
    alias: label,
    horizontalAlignment: type === "number" ? "RIGHT" : "LEFT",
    verticalAlignment: "CENTER",
    columnType: type,
    textColor: "",
    textSize: "0.875rem",
    fontStyle: "",
    enableFilter: true,
    enableSort: true,
    isVisible: true,
    isDisabled: false,
    isCellEditable: false,
    isEditable: false,
    isCellVisible: true,
    isDerived: false,
    label,
    isSaveVisible: true,
    isDiscardVisible: true,
    computedValue: `{{(() => { const tableData = ${widgetName}.processedTableData || []; return tableData.length > 0 ? tableData.map((currentRow) => (currentRow["${id}"])) : ${id} })()}}`,
    sticky: "",
    validation: {},
    currencyCode: "USD",
    decimals: 0,
    thousandSeparator: false,
    notation: "standard",
    cellBackground: "",
  };
}

function configureTable(widget, tableData, columns, defaultPageSize = 10) {
  widget.tableData = tableData;
  widget.primaryColumns = Object.fromEntries(columns.map((c) => [c.id, c]));
  widget.columnOrder = columns.map((c) => c.id);
  widget.derivedColumns = {};
  widget.defaultPageSize = defaultPageSize;
  widget.serverSidePaginationEnabled = false;
  widget.enableServerSideFiltering = false;
  widget.enableClientSideSearch = true;
  widget.isVisibleSearch = true;
  widget.isVisiblePagination = true;
  widget.isVisibleFilters = true;
  widget.isSortable = true;
  widget.totalRecordsCount = 0;
  widget.dynamicBindingPathList = [
    { key: "tableData" },
    ...columns.map((c) => ({ key: `primaryColumns.${c.id}.computedValue` })),
  ];
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  const dsl = layout.dsl;

  removeWidgetsByName(dsl, new Set([
    "inpLidtype",
    "inpDatakwaliteit",
    "inpWoonplaats",
    "txtTelhistorieTitel",
    "tblTelhistorie",
    "txtJaaroverzichtTitel",
    "tblJaaroverzicht",
  ]));

  const search = findWidget(dsl, "inpZoeken");
  if (search) {
    search.leftColumn = 2;
    search.rightColumn = 17;
    search.placeholderText = "Naam, code of email";
    search.onTextChanged = "{{q_tellers.run()}}";
    search.dynamicTriggerPathList = [{ key: "onTextChanged" }];
  }

  dsl.children.push(
    inputWidget("inpLidtype", "Lidtype", "bijv. gewoon", 18, 29),
    inputWidget("inpDatakwaliteit", "Datakwaliteit", "bijv. mist email", 30, 43),
    inputWidget("inpWoonplaats", "Woonplaats", "bijv. Leiden", 44, 62),
    textWidget("txtTelhistorieTitel", "{{'Telhistorie: ' + (tblTellers.selectedRow.naam || '')}}", 58, 63, 44, 62, true),
    tableWidget("tblTelhistorie", "{{(q_teller_telhistorie.data || []).filter(r => String(r.teller_id) === String(tblTellers.selectedRow.id || 0))}}", 64, 86, 44, 62, [
      column("tblTelhistorie", "jaar", 0, "number", 80, "Jaar"),
      column("tblTelhistorie", "aantal_plots", 1, "number", 95, "Plots in jaar"),
      column("tblTelhistorie", "kavels", 2, "text", 320, "Kavels"),
    ], 25),
    textWidget("txtJaaroverzichtTitel", "Actieve tellers per jaar", 126, 131, 2, 35, true),
    tableWidget("tblJaaroverzicht", "{{q_actieve_tellers_per_jaar.data || []}}", 132, 170, 2, 62, [
      column("tblJaaroverzicht", "jaar", 0, "number", 90, "Jaar"),
      column("tblJaaroverzicht", "actieve_tellers", 1, "number", 140, "Actieve tellers"),
      column("tblJaaroverzicht", "getelde_plots", 2, "number", 130, "Getelde plots"),
      column("tblJaaroverzicht", "plotjaren", 3, "number", 120, "Plotjaren"),
    ]),
  );

  const tellers = findWidget(dsl, "tblTellers");
  tellers.topRow = 22;
  tellers.bottomRow = 76;
  tellers.leftColumn = 2;
  tellers.rightColumn = 42;
  tellers.onRowSelected = "{{q_teller_detail.run()}}";
  tellers.dynamicTriggerPathList = [{ key: "onRowSelected" }];
  configureTable(tellers, "{{q_tellers.data || []}}", [
    column("tblTellers", "tellercode", 0, "text", 95, "Code"),
    column("tblTellers", "naam", 1, "text", 180, "Naam"),
    column("tblTellers", "soort_lid", 2, "text", 120, "Lidtype"),
    column("tblTellers", "woonplaats", 3, "text", 150, "Woonplaats"),
    column("tblTellers", "aantal_jaren_geteld", 4, "number", 90, "Jaren"),
    column("tblTellers", "aantal_plotjaren", 5, "number", 105, "Plotjaren"),
    column("tblTellers", "aantal_plots", 6, "number", 115, "Unieke plots"),
    column("tblTellers", "email", 7, "text", 210, "Email"),
    column("tblTellers", "datakwaliteit", 8, "text", 130, "Datakwaliteit"),
  ]);

  const detailTitle = findWidget(dsl, "txtDetailTitel");
  detailTitle.topRow = 22;
  detailTitle.bottomRow = 27;

  const detail = findWidget(dsl, "txtDetail");
  detail.topRow = 28;
  detail.bottomRow = 56;
  detail.text = "{{(() => { const r = tblTellers.selectedRow || {}; return `Code: ${r.tellercode || '-'}\\nLidtype: ${r.soort_lid || '-'}\\nWoonplaats: ${r.woonplaats || '-'}\\nEmail: ${r.email || '-'}\\nMobiel: ${r.telefoon_mobiel || '-'}\\nPeriode: ${r.eerste_jaar || '-'} - ${r.laatste_jaar || '-'}\\nJaren geteld: ${r.aantal_jaren_geteld || 0}\\nPlotjaren: ${r.aantal_plotjaren || 0}\\nUnieke plots/kavels: ${r.aantal_plots || 0}\\nStatus: ${r.datakwaliteit || '-'}`; })()}}";
  detail.dynamicBindingPathList = [{ key: "text" }];

  const qualityTitle = findWidget(dsl, "txtDatakwaliteitTitel");
  qualityTitle.topRow = 90;
  qualityTitle.bottomRow = 95;

  const kwaliteit = findWidget(dsl, "tblDatakwaliteit");
  kwaliteit.topRow = 96;
  kwaliteit.bottomRow = 122;
  configureTable(kwaliteit, "{{q_datakwaliteit.data || []}}", [
    column("tblDatakwaliteit", "tellercode", 0, "text", 95, "Code"),
    column("tblDatakwaliteit", "naam", 1, "text", 180, "Naam"),
    column("tblDatakwaliteit", "soort_lid", 2, "text", 120, "Lidtype"),
    column("tblDatakwaliteit", "aandachtspunt", 3, "text", 320, "Aandachtspunt"),
  ]);

  dsl.minHeight = 1750;
  dsl.bottomRow = 1750;
  layout.widgetNames = [
    "MainContainer",
    ...dsl.children.map((child) => child.widgetName),
  ];
  layout.layoutOnLoadActions = [
    appsmithDb.newAction
      .find({ pageId, name: { $in: Array.from(onLoadActions) }, deleted: false })
      .toArray()
      .map((a) => ({
        id: a._id.toString(),
        name: a.name,
        collectionId: null,
        clientSideExecution: false,
      })),
  ];
  layout.validOnPageLoadActions = true;
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

printjson({
  activeActions: appsmithDb.newAction.find({ pageId, deleted: false }, { name: 1, runBehaviour: 1, "unpublishedAction.userSetOnLoad": 1 }).toArray(),
  widgets: appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).unpublishedPage.layouts[0].widgetNames,
});
