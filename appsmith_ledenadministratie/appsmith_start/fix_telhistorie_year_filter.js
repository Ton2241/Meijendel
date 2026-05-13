const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const telhistorieFilterNames = new Set(["inpTelhistorieJaar"]);
const filteredTelhistorieData = `{{(() => {
  const rows = q_teller_telhistorie.data || [];
  const jaar = String(inpTelhistorieJaar.text || '').trim();
  if (!jaar) return rows;
  return rows.filter((r) => String(r.jaar || '').trim() === jaar);
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

function yearInput(parentId) {
  return {
    widgetName: "inpTelhistorieJaar",
    widgetId: "teljaar1",
    type: "INPUT_WIDGET_V2",
    version: 2,
    parentId,
    renderMode: "CANVAS",
    isVisible: true,
    topRow: 7,
    bottomRow: 14,
    leftColumn: 0,
    rightColumn: 9,
    label: "Jaar",
    placeholderText: "bijv. 2025",
    inputType: "TEXT",
    defaultText: "",
    dynamicBindingPathList: [],
    dynamicTriggerPathList: [],
  };
}

function applyTelhistorieFilter(dsl) {
  const canvas = findWidget(dsl, "canTelhistorie");
  if (!canvas) throw new Error("canTelhistorie niet gevonden");

  removeWidgetsByName(dsl, telhistorieFilterNames);
  canvas.children = canvas.children || [];
  canvas.children.push(yearInput(canvas.widgetId));

  const table = findWidget(dsl, "tblTelhistorie");
  if (!table) throw new Error("tblTelhistorie niet gevonden");

  table.topRow = 16;
  table.bottomRow = 88;
  table.leftColumn = 0;
  table.rightColumn = 60;
  table.tableData = filteredTelhistorieData;
  table.enableClientSideSearch = true;
  table.isVisibleSearch = true;
  table.isVisibleFilters = false;
  table.enableServerSideFiltering = false;
  table.dynamicBindingPathList = [
    ...((table.dynamicBindingPathList || []).filter((path) => path.key !== "tableData")),
    { key: "tableData" },
  ];
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor eigen jaarfilter telhistorie",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  applyTelhistorieFilter(layout.dsl);
  layout.widgetNames = allWidgetNames(layout.dsl);
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson({
  input: findWidget(updated, "inpTelhistorieJaar"),
  table: {
    tableData: findWidget(updated, "tblTelhistorie").tableData,
    topRow: findWidget(updated, "tblTelhistorie").topRow,
    isVisibleFilters: findWidget(updated, "tblTelhistorie").isVisibleFilters,
  },
});
