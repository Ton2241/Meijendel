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

function setRunTrigger(input) {
  input.onTextChanged = "{{q_tellers.run()}}";
  input.onSubmit = "{{q_tellers.run()}}";
  input.dynamicTriggerPathList = [
    ...((input.dynamicTriggerPathList || []).filter((path) => !["onTextChanged", "onSubmit"].includes(path.key))),
    { key: "onTextChanged" },
    { key: "onSubmit" },
  ];
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

const action = appsmithDb.newAction.findOne({ pageId, name: "q_tellers", deleted: false });
if (!action) throw new Error("q_tellers niet gevonden");

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor herstel directe filterreactie via q_tellers.run",
  page,
});
appsmithDb.codexActionBackups.insertOne({
  actionId: action._id,
  pageId,
  name: "q_tellers",
  createdAt: now,
  reason: "Controlepunt voor vaste q_tellers-query bij filterreactie",
  action,
});

// De query blijft bewust statisch. De tabel filtert client-side; q_tellers.run()
// dient hier alleen als betrouwbare Appsmith-refresh na invoer.
appsmithDb.newAction.updateOne(
  { _id: action._id },
  {
    $set: {
      "unpublishedAction.executeOnLoad": true,
      "unpublishedAction.dynamicBindingPathList": [],
      "unpublishedAction.jsonPathKeys": [],
      "publishedAction.executeOnLoad": true,
      "publishedAction.dynamicBindingPathList": [],
      "publishedAction.jsonPathKeys": [],
      updatedAt: now,
    },
  },
);

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const dsl = page[pageKey].layouts[0].dsl;
  for (const name of inputNames) {
    const input = findWidget(dsl, name);
    if (!input) throw new Error(`${name} niet gevonden in ${pageKey}`);
    setRunTrigger(input);
  }
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
const updatedAction = appsmithDb.newAction.findOne({ pageId, name: "q_tellers", deleted: false });
printjson({
  queryHasBindings: updatedAction.publishedAction.actionConfiguration.body.includes("{{"),
  executeOnLoad: updatedAction.publishedAction.executeOnLoad,
  dynamicBindingPathList: updatedAction.publishedAction.dynamicBindingPathList,
  triggers: Object.fromEntries(inputNames.map((name) => {
    const input = findWidget(updated, name);
    return [name, { onTextChanged: input.onTextChanged, onSubmit: input.onSubmit }];
  })),
});
