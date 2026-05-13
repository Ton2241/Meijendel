const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const qTelhistorieBody = `SELECT teller_id, tellercode, naam, jaar, aantal_plots, kavels
FROM appsmith_teller_telhistorie
WHERE {{inpTelhistorieJaar.text ? '1=1' : '1=0'}}
  AND jaar = {{Number(inpTelhistorieJaar.text || 0)}}
ORDER BY naam, jaar DESC;`;

const tabQueryTrigger = "{{q_tellers.run(); q_actieve_tellers_per_jaar.run(); q_datakwaliteit.run();}}";

function findWidget(widget, widgetName) {
  if (!widget) return null;
  if (widget.widgetName === widgetName) return widget;
  for (const child of widget.children || []) {
    const found = findWidget(child, widgetName);
    if (found) return found;
  }
  return null;
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

const action = appsmithDb.newAction.findOne({ pageId, name: "q_teller_telhistorie", deleted: false });
if (!action) throw new Error("q_teller_telhistorie niet gevonden");

appsmithDb.codexActionBackups.insertOne({
  actionId: action._id,
  pageId,
  name: "q_teller_telhistorie",
  createdAt: now,
  reason: "Voor server-side jaarfilter telhistorie",
  action,
});
appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor server-side jaarfilter telhistorie",
  page,
});

appsmithDb.newAction.updateOne(
  { _id: action._id },
  {
    $set: {
      "unpublishedAction.actionConfiguration.body": qTelhistorieBody,
      "unpublishedAction.executeOnLoad": false,
      "unpublishedAction.dynamicBindingPathList": [
        { key: "body" },
      ],
      "unpublishedAction.jsonPathKeys": [
        "inpTelhistorieJaar.text ? '1=1' : '1=0'",
        "Number(inpTelhistorieJaar.text || 0)",
      ],
      "publishedAction.actionConfiguration.body": qTelhistorieBody,
      "publishedAction.executeOnLoad": false,
      "publishedAction.dynamicBindingPathList": [
        { key: "body" },
      ],
      "publishedAction.jsonPathKeys": [
        "inpTelhistorieJaar.text ? '1=1' : '1=0'",
        "Number(inpTelhistorieJaar.text || 0)",
      ],
      updatedAt: now,
    },
  },
);

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const dsl = page[pageKey].layouts[0].dsl;

  const tabs = findWidget(dsl, "tabsLedenadministratie");
  if (!tabs) throw new Error(`tabsLedenadministratie niet gevonden in ${pageKey}`);
  tabs.onTabSelected = tabQueryTrigger;
  tabs.dynamicTriggerPathList = [
    ...((tabs.dynamicTriggerPathList || []).filter((path) => path.key !== "onTabSelected")),
    { key: "onTabSelected" },
  ];

  const input = findWidget(dsl, "inpTelhistorieJaar");
  if (!input) throw new Error(`inpTelhistorieJaar niet gevonden in ${pageKey}`);
  input.onTextChanged = "{{q_teller_telhistorie.run()}}";
  input.dynamicTriggerPathList = [
    ...((input.dynamicTriggerPathList || []).filter((path) => path.key !== "onTextChanged")),
    { key: "onTextChanged" },
  ];

  const table = findWidget(dsl, "tblTelhistorie");
  if (!table) throw new Error(`tblTelhistorie niet gevonden in ${pageKey}`);
  table.tableData = "{{q_teller_telhistorie.data || []}}";
  table.defaultPageSize = 100;
  table.isVisiblePagination = false;
  table.serverSidePaginationEnabled = false;
  table.dynamicBindingPathList = [
    ...((table.dynamicBindingPathList || []).filter((path) => path.key !== "tableData")),
    { key: "tableData" },
  ];

  const canvas = findWidget(dsl, "canTelhistorie");
  if (canvas) {
    canvas.bottomRow = Math.max(canvas.bottomRow || 90, 120);
    canvas.minHeight = Math.max(canvas.minHeight || 90, 120);
  }
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updatedAction = appsmithDb.newAction.findOne({ _id: action._id });
const updatedPage = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson({
  body: updatedAction.publishedAction.actionConfiguration.body,
  executeOnLoad: updatedAction.publishedAction.executeOnLoad,
  inputTrigger: findWidget(updatedPage, "inpTelhistorieJaar").onTextChanged,
  tableData: findWidget(updatedPage, "tblTelhistorie").tableData,
  tabTrigger: findWidget(updatedPage, "tabsLedenadministratie").onTabSelected,
});
