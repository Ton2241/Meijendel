const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();
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

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor herstel query triggers op tabs",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const tabs = findWidget(page[pageKey].layouts[0].dsl, "tabsLedenadministratie");
  if (!tabs) throw new Error(`tabsLedenadministratie niet gevonden in ${pageKey}`);

  tabs.onTabSelected = tabQueryTrigger;
  tabs.dynamicTriggerPathList = [
    ...((tabs.dynamicTriggerPathList || []).filter((path) => path.key !== "onTabSelected")),
    { key: "onTabSelected" },
  ];

  const jaaroverzicht = findWidget(page[pageKey].layouts[0].dsl, "tblJaaroverzicht");
  if (!jaaroverzicht) throw new Error(`tblJaaroverzicht niet gevonden in ${pageKey}`);
  jaaroverzicht.tableData = "{{q_actieve_tellers_per_jaar.data || []}}";
  jaaroverzicht.dynamicBindingPathList = [
    ...((jaaroverzicht.dynamicBindingPathList || []).filter((path) => path.key !== "tableData")),
    { key: "tableData" },
  ];
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson({
  onTabSelected: findWidget(updated, "tabsLedenadministratie").onTabSelected,
  jaaroverzichtTableData: findWidget(updated, "tblJaaroverzicht").tableData,
});
