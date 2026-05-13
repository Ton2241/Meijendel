const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();
const instructionName = "txtTelhistorieInstructie";

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

function instructionWidget(parentId) {
  return {
    widgetName: instructionName,
    widgetId: "telinst1",
    type: "TEXT_WIDGET",
    version: 1,
    parentId,
    renderMode: "CANVAS",
    isVisible: true,
    topRow: 8,
    bottomRow: 12,
    leftColumn: 0,
    rightColumn: 60,
    text: "Vul eerst hieronder een jaartal in en geef een enter",
    fontSize: "0.875rem",
    fontStyle: "BOLD",
    textAlign: "LEFT",
    textColor: "#1F2937",
    dynamicBindingPathList: [],
    dynamicTriggerPathList: [],
  };
}

function applyInstruction(dsl) {
  removeWidgetsByName(dsl, new Set([instructionName]));

  const canvas = findWidget(dsl, "canTelhistorie");
  if (!canvas) throw new Error("canTelhistorie niet gevonden");
  canvas.children = canvas.children || [];
  canvas.children.push(instructionWidget(canvas.widgetId));

  const jaar = findWidget(dsl, "inpTelhistorieJaar");
  if (jaar) {
    jaar.topRow = 15;
    jaar.bottomRow = 22;
  }

  const exportButton = findWidget(dsl, "btnExportTelhistorieCsv");
  if (exportButton) {
    exportButton.topRow = 15;
    exportButton.bottomRow = 22;
  }

  const table = findWidget(dsl, "tblTelhistorie");
  if (table) {
    const height = (table.bottomRow || 100) - (table.topRow || 16);
    table.topRow = 24;
    table.bottomRow = 24 + Math.max(height, 72);
  }

  canvas.bottomRow = Math.max(canvas.bottomRow || 90, (table && table.bottomRow ? table.bottomRow + 4 : 100));
  canvas.minHeight = Math.max(canvas.minHeight || 90, canvas.bottomRow);
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor instructietekst telhistorie jaarfilter",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  applyInstruction(layout.dsl);
  layout.widgetNames = allWidgetNames(layout.dsl);
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson({
  instruction: findWidget(updated, instructionName).text,
  instructionRows: [findWidget(updated, instructionName).topRow, findWidget(updated, instructionName).bottomRow],
  yearRows: [findWidget(updated, "inpTelhistorieJaar").topRow, findWidget(updated, "inpTelhistorieJaar").bottomRow],
  exportRows: [findWidget(updated, "btnExportTelhistorieCsv").topRow, findWidget(updated, "btnExportTelhistorieCsv").bottomRow],
});
