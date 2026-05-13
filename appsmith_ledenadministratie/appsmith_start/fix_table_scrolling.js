const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const canvasNames = ["canInfoPerLid", "canTelhistorie", "canActieveTellers", "canDatakwaliteit"];
const tableSettings = {
  tblTellers: 250,
  tblTelhistorie: 2000,
  tblJaaroverzicht: 100,
  tblDatakwaliteit: 250,
};

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
  reason: "Voor herstel scrollen tabellen zonder paginering",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const dsl = page[pageKey].layouts[0].dsl;

  const tabs = findWidget(dsl, "tabsLedenadministratie");
  if (!tabs) throw new Error(`tabsLedenadministratie niet gevonden in ${pageKey}`);
  tabs.shouldScrollContents = true;

  for (const canvasName of canvasNames) {
    const canvas = findWidget(dsl, canvasName);
    if (!canvas) throw new Error(`${canvasName} niet gevonden in ${pageKey}`);
    canvas.shouldScrollContents = true;
    canvas.canExtend = true;
  }

  for (const [tableName, pageSize] of Object.entries(tableSettings)) {
    const table = findWidget(dsl, tableName);
    if (!table) throw new Error(`${tableName} niet gevonden in ${pageKey}`);
    table.defaultPageSize = pageSize;
    table.isVisiblePagination = false;
    table.serverSidePaginationEnabled = false;
  }
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson({
  tabsShouldScroll: findWidget(updated, "tabsLedenadministratie").shouldScrollContents,
  canvases: Object.fromEntries(canvasNames.map((name) => [name, findWidget(updated, name).shouldScrollContents])),
  tables: Object.fromEntries(Object.keys(tableSettings).map((name) => {
    const table = findWidget(updated, name);
    return [name, {
      defaultPageSize: table.defaultPageSize,
      isVisiblePagination: table.isVisiblePagination,
    }];
  })),
});
