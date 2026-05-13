const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();
const instructionText = "Vul eerst een of meer zoektermen in de boxen hieronder in. Geef daarna een enter.";

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
  reason: "Voor aanpassen zoekinstructie tekst",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const instruction = findWidget(page[pageKey].layouts[0].dsl, "txtInfoZoekInstructie");
  if (!instruction) throw new Error(`txtInfoZoekInstructie niet gevonden in ${pageKey}`);
  instruction.text = instructionText;
  instruction.fontStyle = "BOLD";
  instruction.dynamicBindingPathList = [];
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
const instruction = findWidget(updated, "txtInfoZoekInstructie");
printjson({ text: instruction.text, fontStyle: instruction.fontStyle });
