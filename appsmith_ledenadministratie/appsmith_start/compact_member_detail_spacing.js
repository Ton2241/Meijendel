const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const positions = {
  txtDetailTitel: [10, 14, 43, 60],
  txtDetail: [16, 20, 43, 49],
  txtDetailMetaValues: [16, 20, 49, 60],
  txtDetailContactTitel: [22, 25, 43, 60],
  txtDetailContactLabels: [27, 33, 43, 49],
  txtDetailContactValues: [27, 33, 49, 60],
  txtDetailTellingTitel: [35, 38, 43, 60],
  txtDetailTellingLabels: [40, 49, 43, 50],
  txtDetailTellingValues: [40, 49, 50, 60],
  txtDetailStatusLabel: [52, 56, 43, 50],
  txtDetailStatusValue: [52, 56, 50, 60],
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

function setPosition(widget, [top, bottom, left, right]) {
  widget.topRow = top;
  widget.bottomRow = bottom;
  widget.leftColumn = left;
  widget.rightColumn = right;
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor compactere witruimte detailvlak lid",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const dsl = page[pageKey].layouts[0].dsl;
  for (const [widgetName, position] of Object.entries(positions)) {
    const widget = findWidget(dsl, widgetName);
    if (!widget) throw new Error(`${widgetName} niet gevonden in ${pageKey}`);
    setPosition(widget, position);
  }
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson(Object.fromEntries(Object.keys(positions).map((name) => {
  const widget = findWidget(updated, name);
  return [name, [widget.topRow, widget.bottomRow, widget.leftColumn, widget.rightColumn]];
})));
