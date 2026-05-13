const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

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
appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor tabs trigger q_tellers",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const tabs = findWidget(page[pageKey].layouts[0].dsl, "tabsLedenadministratie");
  if (!tabs) throw new Error(`tabsLedenadministratie niet gevonden in ${pageKey}`);

  tabs.onTabSelected = "{{q_tellers.run()}}";
  tabs.dynamicTriggerPathList = [
    ...((tabs.dynamicTriggerPathList || []).filter((path) => path.key !== "onTabSelected")),
    { key: "onTabSelected" },
  ];
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

printjson({
  onTabSelected: findWidget(
    appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl,
    "tabsLedenadministratie",
  ).onTabSelected,
});
