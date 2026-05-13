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
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor verkorten paginatitel onder VWG header",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const title = findWidget(page[pageKey].layouts[0].dsl, "txtTitel");
  if (!title) throw new Error(`txtTitel niet gevonden in ${pageKey}`);
  title.text = "Ledenadministratie";
  title.dynamicBindingPathList = [];
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson({ pageTitle: findWidget(updated, "txtTitel").text });
