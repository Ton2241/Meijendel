const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const tabsName = "tabsLedenadministratie";
const tabLayouts = {
  canInfoPerLid: { table: "tblTellers", rows: 200, rowUnits: 4, extra: 20 },
  canTelhistorie: { table: "tblTelhistorie", rows: 1869, rowUnits: 4, extra: 20 },
  canActieveTellers: { table: "tblJaaroverzicht", rows: 69, rowUnits: 4, extra: 20 },
  canDatakwaliteit: { table: "tblDatakwaliteit", rows: 156, rowUnits: 4, extra: 20 },
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
  reason: "Voor browser-page scroll bij tabellen zonder paginering",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  const dsl = layout.dsl;
  const tabs = findWidget(dsl, tabsName);
  if (!tabs) throw new Error(`${tabsName} niet gevonden in ${pageKey}`);

  tabs.shouldScrollContents = false;

  let maxCanvasBottom = 0;
  for (const [canvasName, config] of Object.entries(tabLayouts)) {
    const canvas = findWidget(dsl, canvasName);
    const table = findWidget(dsl, config.table);
    if (!canvas) throw new Error(`${canvasName} niet gevonden in ${pageKey}`);
    if (!table) throw new Error(`${config.table} niet gevonden in ${pageKey}`);

    const tableBottom = table.topRow + config.extra + config.rows * config.rowUnits;
    table.bottomRow = tableBottom;
    table.defaultPageSize = Math.max(config.rows, table.defaultPageSize || 0);
    table.isVisiblePagination = false;
    table.serverSidePaginationEnabled = false;

    canvas.shouldScrollContents = false;
    canvas.canExtend = true;
    canvas.bottomRow = tableBottom + 4;
    canvas.minHeight = tableBottom + 4;
    maxCanvasBottom = Math.max(maxCanvasBottom, canvas.bottomRow);
  }

  tabs.bottomRow = tabs.topRow + maxCanvasBottom + 5;
  tabs.rows = maxCanvasBottom + 5;
  tabs.minDynamicHeight = maxCanvasBottom + 5;

  dsl.bottomRow = Math.max(dsl.bottomRow || 0, tabs.bottomRow + 5);
  dsl.minHeight = Math.max(dsl.minHeight || 0, (tabs.bottomRow + 5) * 10);
  layout.validOnPageLoadActions = true;
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
const tabs = findWidget(updated, tabsName);
printjson({
  tabs: { top: tabs.topRow, bottom: tabs.bottomRow, rows: tabs.rows, shouldScrollContents: tabs.shouldScrollContents },
  tables: Object.fromEntries(Object.values(tabLayouts).map((config) => {
    const table = findWidget(updated, config.table);
    return [config.table, { top: table.topRow, bottom: table.bottomRow, pageSize: table.defaultPageSize, pagination: table.isVisiblePagination }];
  })),
});
