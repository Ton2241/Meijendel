const appsmithDb = db.getSiblingDB("appsmith");

const appId = "69f372c89e8d978bb38cc423";
const pageId = "69f372c89e8d978bb38cc425";
const datasourceId = "69f373179e8d978bb38cc426";
const now = new Date();

const datasource = appsmithDb.datasource.findOne({ _id: ObjectId(datasourceId) });

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
};

const onLoadActions = new Set(["q_stats", "q_tellers", "q_datakwaliteit"]);

for (const [name, body] of Object.entries(actionBodies)) {
  const isDynamic = body.includes("{{");
  const userSetOnLoad = onLoadActions.has(name);
  const setAction = {
    [`unpublishedAction.name`]: name,
    [`unpublishedAction.datasource`]: datasource,
    [`unpublishedAction.pageId`]: pageId,
    [`unpublishedAction.pluginId`]: datasource.pluginId,
    [`unpublishedAction.pluginType`]: "DB",
    [`unpublishedAction.actionConfiguration`]: {
      timeoutInMillisecond: 10000,
      paginationType: "NONE",
      encodeParamsToggle: true,
      body,
      pluginSpecifiedTemplates: [{ value: false }],
    },
    [`unpublishedAction.runBehaviour`]: userSetOnLoad ? "AUTOMATIC" : "MANUAL",
    [`unpublishedAction.dynamicBindingPathList`]: isDynamic ? [{ key: "body" }] : [],
    [`unpublishedAction.isValid`]: true,
    [`unpublishedAction.invalids`]: [],
    [`unpublishedAction.jsonPathKeys`]: name === "q_teller_detail" ? ["tblTellers.selectedRow.id || 0"] : [],
    [`unpublishedAction.userSetOnLoad`]: userSetOnLoad,
    [`unpublishedAction.confirmBeforeExecute`]: false,
    [`publishedAction.name`]: name,
    [`publishedAction.datasource`]: datasource,
    [`publishedAction.pageId`]: pageId,
    [`publishedAction.pluginId`]: datasource.pluginId,
    [`publishedAction.pluginType`]: "DB",
    [`publishedAction.actionConfiguration`]: {
      timeoutInMillisecond: 10000,
      paginationType: "NONE",
      encodeParamsToggle: true,
      body,
      pluginSpecifiedTemplates: [{ value: false }],
    },
    [`publishedAction.runBehaviour`]: userSetOnLoad ? "AUTOMATIC" : "MANUAL",
    [`publishedAction.dynamicBindingPathList`]: isDynamic ? [{ key: "body" }] : [],
    [`publishedAction.isValid`]: true,
    [`publishedAction.invalids`]: [],
    [`publishedAction.jsonPathKeys`]: name === "q_teller_detail" ? ["tblTellers.selectedRow.id || 0"] : [],
    [`publishedAction.userSetOnLoad`]: userSetOnLoad,
    [`publishedAction.confirmBeforeExecute`]: false,
    runBehaviour: userSetOnLoad ? "AUTOMATIC" : "MANUAL",
    executeOnLoad: userSetOnLoad,
    updatedAt: now,
  };

  appsmithDb.newAction.updateOne(
    { pageId, name, deleted: false },
    { $set: setAction },
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

function configureTable(widget, tableData, columns) {
  widget.tableData = tableData;
  widget.primaryColumns = Object.fromEntries(columns.map((c) => [c.id, c]));
  widget.columnOrder = columns.map((c) => c.id);
  widget.derivedColumns = {};
  widget.defaultPageSize = 10;
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

  const tellers = findWidget(dsl, "tblTellers");
  configureTable(tellers, "{{q_tellers.data || []}}", [
    column("tblTellers", "tellercode", 0, "text", 95, "Code"),
    column("tblTellers", "naam", 1, "text", 180, "Naam"),
    column("tblTellers", "soort_lid", 2, "text", 120, "Lidtype"),
    column("tblTellers", "woonplaats", 3, "text", 150, "Woonplaats"),
    column("tblTellers", "email", 4, "text", 210, "Email"),
    column("tblTellers", "telefoon_mobiel", 5, "text", 130, "Mobiel"),
    column("tblTellers", "datakwaliteit", 6, "text", 130, "Datakwaliteit"),
  ]);

  const kwaliteit = findWidget(dsl, "tblDatakwaliteit");
  configureTable(kwaliteit, "{{q_datakwaliteit.data || []}}", [
    column("tblDatakwaliteit", "tellercode", 0, "text", 95, "Code"),
    column("tblDatakwaliteit", "naam", 1, "text", 180, "Naam"),
    column("tblDatakwaliteit", "soort_lid", 2, "text", 120, "Lidtype"),
    column("tblDatakwaliteit", "aandachtspunt", 3, "text", 320, "Aandachtspunt"),
  ]);

  const detail = findWidget(dsl, "txtDetail");
  detail.text = "{{(() => { const r = tblTellers.selectedRow || {}; return `Code: ${r.tellercode || '-'}\\nLidtype: ${r.soort_lid || '-'}\\nWoonplaats: ${r.woonplaats || '-'}\\nEmail: ${r.email || '-'}\\nMobiel: ${r.telefoon_mobiel || '-'}\\nJaren: ${r.eerste_jaar || '-'} - ${r.laatste_jaar || '-'}\\nPlots: ${r.aantal_plots || 0}\\nStatus: ${r.datakwaliteit || '-'}`; })()}}";
  detail.dynamicBindingPathList = [{ key: "text" }];

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
  actions: appsmithDb.newAction.find({ pageId, deleted: false }, { name: 1, runBehaviour: 1, "unpublishedAction.userSetOnLoad": 1 }).toArray(),
  tblTellers: findWidget(appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).unpublishedPage.layouts[0].dsl, "tblTellers"),
});
