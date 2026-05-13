const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();
const inputNames = ["inpZoeken", "inpLidtype", "inpDatakwaliteit", "inpWoonplaats"];

function findWidget(widget, widgetName) {
  if (!widget) return null;
  if (widget.widgetName === widgetName) return widget;
  for (const child of widget.children || []) {
    const found = findWidget(child, widgetName);
    if (found) return found;
  }
  return null;
}

function setTrigger(input) {
  input.onSubmit = "";
  input.onTextChanged = "{{q_tellers.run()}}";
  input.dynamicTriggerPathList = [
    ...((input.dynamicTriggerPathList || []).filter((path) => !["onSubmit", "onTextChanged"].includes(path.key))),
    { key: "onTextChanged" },
  ];
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor herstel zoekveld-triggers ledeninformatie",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const dsl = page[pageKey].layouts[0].dsl;
  for (const name of inputNames) {
    const input = findWidget(dsl, name);
    if (!input) throw new Error(`${name} niet gevonden in ${pageKey}`);
    setTrigger(input);
  }
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson(Object.fromEntries(inputNames.map((name) => {
  const input = findWidget(updated, name);
  return [name, {
    label: input.label,
    onTextChanged: input.onTextChanged,
    onSubmit: input.onSubmit,
    dynamicTriggerPathList: input.dynamicTriggerPathList,
  }];
})));
