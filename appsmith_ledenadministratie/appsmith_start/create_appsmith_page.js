const appsmithDb = db.getSiblingDB("appsmith");

const now = new Date();
const appId = "69f372c89e8d978bb38cc423";
const pageId = "69f372c89e8d978bb38cc425";
const workspaceId = "69f372c89e8d978bb38cc41e";
const datasourceId = "69f373179e8d978bb38cc426";
const mysqlPluginId = "69f336aa3d472de3cc650278";
const adminGroup = "69f372c89e8d978bb38cc41f";
const developerGroup = "69f372c89e8d978bb38cc420";
const viewerGroup = "69f372c89e8d978bb38cc421";

const policyMap = {
  "read:actions": { permission: "read:actions", permissionGroups: [adminGroup, developerGroup, viewerGroup] },
  "execute:actions": { permission: "execute:actions", permissionGroups: [adminGroup, developerGroup, viewerGroup] },
  "manage:actions": { permission: "manage:actions", permissionGroups: [adminGroup, developerGroup] },
  "delete:actions": { permission: "delete:actions", permissionGroups: [adminGroup, developerGroup] },
};

const policies = Object.values(policyMap);

const datasourceRef = {
  id: datasourceId,
  name: "Meijendel MySQL",
  pluginId: mysqlPluginId,
};

function objectId() {
  return new ObjectId();
}

function actionDoc(name, body, executeOnLoad) {
  const id = objectId();
  const baseAction = {
    name,
    datasource: datasourceRef,
    pageId,
    pluginId: mysqlPluginId,
    pluginType: "DB",
    actionConfiguration: {
      timeoutInMillisecond: 10000,
      paginationType: "NONE",
      encodeParamsToggle: true,
      body,
      selfReferencingDataPaths: [],
    },
    executeOnLoad,
    dynamicBindingPathList: body.includes("{{") ? [{ key: "body" }] : [],
    isValid: true,
    invalids: [],
    jsonPathKeys: body.includes("{{") ? ["inpZoeken.text || \"\"", "tblTellers.selectedRow.id || 0"] : [],
  };

  return {
    _id: id,
    applicationId: appId,
    workspaceId,
    pageId,
    name,
    pluginId: mysqlPluginId,
    pluginType: "DB",
    datasource: datasourceRef,
    unpublishedAction: baseAction,
    publishedAction: baseAction,
    runBehaviour: executeOnLoad ? "ON_PAGE_LOAD" : "MANUAL",
    fullyQualifiedName: name,
    clientSideExecution: false,
    executeOnLoad,
    invalids: [],
    deleted: false,
    createdAt: now,
    updatedAt: now,
    policyMap,
    policies,
    _class: "com.appsmith.server.domains.NewAction",
  };
}

const queries = [
  actionDoc("q_stats", `SELECT label, waarde
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
);`, true),
  actionDoc("q_tellers", `SELECT
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
WHERE
  (
    '{{inpZoeken.text || ""}}' = ''
    OR naam LIKE CONCAT('%', '{{inpZoeken.text || ""}}', '%')
    OR tellercode LIKE CONCAT('%', '{{inpZoeken.text || ""}}', '%')
    OR woonplaats LIKE CONCAT('%', '{{inpZoeken.text || ""}}', '%')
  )
ORDER BY achternaam, voornaam, tellercode
LIMIT 500;`, true),
  actionDoc("q_teller_detail", `SELECT *
FROM appsmith_teller_detail
WHERE id = {{tblTellers.selectedRow.id || 0}};`, false),
  actionDoc("q_datakwaliteit", `SELECT id, tellercode, naam, soort_lid, aandachtspunt
FROM appsmith_teller_datakwaliteit
ORDER BY soort_lid, naam
LIMIT 500;`, true),
];

function widgetId() {
  return objectId().toString().slice(-8);
}

const w = {
  title: widgetId(),
  summary: widgetId(),
  search: widgetId(),
  table: widgetId(),
  detailTitle: widgetId(),
  detail: widgetId(),
  qualityTitle: widgetId(),
  qualityTable: widgetId(),
};

const dsl = {
  widgetName: "MainContainer",
  backgroundColor: "none",
  rightColumn: 4896,
  snapColumns: 64,
  detachFromLayout: true,
  widgetId: "0",
  topRow: 0,
  bottomRow: 5000,
  containerStyle: "none",
  snapRows: 124,
  parentRowSpace: 1,
  type: "CANVAS_WIDGET",
  canExtend: true,
  version: 94,
  minHeight: 1292,
  dynamicTriggerPathList: [],
  parentColumnSpace: 1,
  dynamicBindingPathList: [],
  leftColumn: 0,
  children: [
    {
      widgetName: "txtTitel",
      widgetId: w.title,
      type: "TEXT_WIDGET",
      version: 1,
      parentId: "0",
      renderMode: "CANVAS",
      isVisible: true,
      topRow: 2,
      bottomRow: 7,
      leftColumn: 2,
      rightColumn: 31,
      text: "Ledenadministratie Meijendel",
      fontSize: "1.25rem",
      fontStyle: "BOLD",
      textAlign: "LEFT",
      textColor: "#1f2937",
      dynamicBindingPathList: [],
      dynamicTriggerPathList: [],
    },
    {
      widgetName: "txtStats",
      widgetId: w.summary,
      type: "TEXT_WIDGET",
      version: 1,
      parentId: "0",
      renderMode: "CANVAS",
      isVisible: true,
      topRow: 7,
      bottomRow: 11,
      leftColumn: 2,
      rightColumn: 62,
      text: "{{(q_stats.data || []).map(s => `${s.label}: ${s.waarde}`).join('   |   ')}}",
      fontSize: "0.875rem",
      fontStyle: "",
      textAlign: "LEFT",
      textColor: "#374151",
      dynamicBindingPathList: [{ key: "text" }],
      dynamicTriggerPathList: [],
    },
    {
      widgetName: "inpZoeken",
      widgetId: w.search,
      type: "INPUT_WIDGET_V2",
      version: 2,
      parentId: "0",
      renderMode: "CANVAS",
      isVisible: true,
      topRow: 13,
      bottomRow: 20,
      leftColumn: 2,
      rightColumn: 25,
      label: "Zoeken",
      placeholderText: "Naam, tellercode of woonplaats",
      inputType: "TEXT",
      defaultText: "",
      dynamicBindingPathList: [],
      dynamicTriggerPathList: [{ key: "onTextChanged" }],
      onTextChanged: "{{q_tellers.run()}}",
    },
    {
      widgetName: "tblTellers",
      widgetId: w.table,
      type: "TABLE_WIDGET_V2",
      version: 2,
      parentId: "0",
      renderMode: "CANVAS",
      isVisible: true,
      topRow: 22,
      bottomRow: 73,
      leftColumn: 2,
      rightColumn: 42,
      tableData: "{{q_tellers.data}}",
      dynamicBindingPathList: [{ key: "tableData" }],
      dynamicTriggerPathList: [{ key: "onRowSelected" }],
      onRowSelected: "{{q_teller_detail.run()}}",
      defaultSelectedRowIndex: 0,
      primaryColumns: {},
      columnOrder: [],
      enableClientSideSearch: true,
      isVisibleSearch: true,
      isSortable: true,
    },
    {
      widgetName: "txtDetailTitel",
      widgetId: w.detailTitle,
      type: "TEXT_WIDGET",
      version: 1,
      parentId: "0",
      renderMode: "CANVAS",
      isVisible: true,
      topRow: 22,
      bottomRow: 27,
      leftColumn: 44,
      rightColumn: 62,
      text: "{{tblTellers.selectedRow.naam || 'Selecteer een teller'}}",
      fontSize: "1rem",
      fontStyle: "BOLD",
      textAlign: "LEFT",
      textColor: "#1f2937",
      dynamicBindingPathList: [{ key: "text" }],
      dynamicTriggerPathList: [],
    },
    {
      widgetName: "txtDetail",
      widgetId: w.detail,
      type: "TEXT_WIDGET",
      version: 1,
      parentId: "0",
      renderMode: "CANVAS",
      isVisible: true,
      topRow: 28,
      bottomRow: 56,
      leftColumn: 44,
      rightColumn: 62,
      text: "{{(() => { const r = tblTellers.selectedRow || {}; return [`Code: ${r.tellercode || '-'}`, `Lidtype: ${r.soort_lid || '-'}`, `Woonplaats: ${r.woonplaats || '-'}`, `Email: ${r.email || '-'}`, `Mobiel: ${r.telefoon_mobiel || '-'}`, `Jaren: ${r.eerste_jaar || '-'} - ${r.laatste_jaar || '-'}`, `Plots: ${r.aantal_plots || 0}`, `Status: ${r.datakwaliteit || '-'}`].join('\\n'); })()}}",
      fontSize: "0.875rem",
      fontStyle: "",
      textAlign: "LEFT",
      textColor: "#374151",
      dynamicBindingPathList: [{ key: "text" }],
      dynamicTriggerPathList: [],
    },
    {
      widgetName: "txtDatakwaliteitTitel",
      widgetId: w.qualityTitle,
      type: "TEXT_WIDGET",
      version: 1,
      parentId: "0",
      renderMode: "CANVAS",
      isVisible: true,
      topRow: 77,
      bottomRow: 82,
      leftColumn: 2,
      rightColumn: 35,
      text: "Datakwaliteit: ontbrekende velden",
      fontSize: "1rem",
      fontStyle: "BOLD",
      textAlign: "LEFT",
      textColor: "#1f2937",
      dynamicBindingPathList: [],
      dynamicTriggerPathList: [],
    },
    {
      widgetName: "tblDatakwaliteit",
      widgetId: w.qualityTable,
      type: "TABLE_WIDGET_V2",
      version: 2,
      parentId: "0",
      renderMode: "CANVAS",
      isVisible: true,
      topRow: 83,
      bottomRow: 122,
      leftColumn: 2,
      rightColumn: 62,
      tableData: "{{q_datakwaliteit.data}}",
      dynamicBindingPathList: [{ key: "tableData" }],
      dynamicTriggerPathList: [],
      primaryColumns: {},
      columnOrder: [],
      enableClientSideSearch: true,
      isVisibleSearch: true,
      isSortable: true,
    },
  ],
};

const widgetNames = [
  "MainContainer",
  "txtTitel",
  "txtStats",
  "inpZoeken",
  "tblTellers",
  "txtDetailTitel",
  "txtDetail",
  "txtDatakwaliteitTitel",
  "tblDatakwaliteit",
];

appsmithDb.application.updateOne(
  { _id: ObjectId(appId) },
  {
    $set: {
      name: "Ledenadministratie Meijendel",
      slug: "ledenadministratie-meijendel",
      updatedAt: now,
    },
  },
);

appsmithDb.datasource.updateOne(
  { _id: ObjectId(datasourceId) },
  { $set: { name: "Meijendel MySQL", updatedAt: now } },
);

appsmithDb.newAction.deleteMany({ applicationId: appId, pageId, name: { $in: queries.map(q => q.name) } });
appsmithDb.newAction.insertMany(queries);

const layoutOnLoadActions = [
  queries
    .filter(q => q.executeOnLoad)
    .map(q => ({
      id: q._id.toString(),
      name: q.name,
      collectionId: null,
      clientSideExecution: false,
    })),
];

appsmithDb.newPage.updateOne(
  { _id: ObjectId(pageId) },
  {
    $set: {
      "unpublishedPage.name": "Leden",
      "unpublishedPage.slug": "leden",
      "unpublishedPage.layouts.0.dsl": dsl,
      "unpublishedPage.layouts.0.widgetNames": widgetNames,
      "unpublishedPage.layouts.0.layoutOnLoadActions": layoutOnLoadActions,
      "unpublishedPage.layouts.0.validOnPageLoadActions": true,
      "publishedPage.name": "Leden",
      "publishedPage.slug": "leden",
      "publishedPage.layouts.0.dsl": dsl,
      "publishedPage.layouts.0.widgetNames": widgetNames,
      "publishedPage.layouts.0.layoutOnLoadActions": layoutOnLoadActions,
      "publishedPage.layouts.0.validOnPageLoadActions": true,
      updatedAt: now,
    },
  },
);

printjson({
  application: appsmithDb.application.findOne({ _id: ObjectId(appId) }, { name: 1, slug: 1 }),
  page: appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }, { "unpublishedPage.name": 1, "unpublishedPage.layouts.widgetNames": 1 }),
  actions: appsmithDb.newAction.find({ applicationId: appId, pageId }, { name: 1, executeOnLoad: 1 }).toArray(),
});
