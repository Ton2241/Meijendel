const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();
const inputNames = ["inpZoeken", "inpLidtype", "inpDatakwaliteit", "inpWoonplaats"];
const instructionText = "Vul eerst een zoekterm in een of meer boxen hieronder in. Geef daarna een enter.";

const qTellersBody = `SELECT
  l.id,
  l.tellercode,
  l.naam,
  l.soort_lid,
  l.woonplaats,
  l.email,
  l.telefoon_mobiel,
  l.aantal_jaren_geteld,
  l.aantal_plots,
  l.aantal_plotjaren,
  l.eerste_jaar,
  l.laatste_jaar,
  l.datakwaliteit,
  (
    SELECT GROUP_CONCAT(DISTINCT pjt.jaar ORDER BY pjt.jaar SEPARATOR ',')
    FROM plot_jaar_teller pjt
    WHERE pjt.teller_id = l.id
  ) AS actieve_jaren
FROM appsmith_teller_lijst l
WHERE (
    '{{(inpZoeken.text || "").trim().replace(/'/g, "''")}}' <> ''
    OR '{{(inpLidtype.text || "").trim().replace(/'/g, "''")}}' <> ''
    OR '{{(inpDatakwaliteit.text || "").trim().replace(/'/g, "''")}}' <> ''
    OR '{{(inpWoonplaats.text || "").trim().replace(/'/g, "''")}}' <> ''
  )
  AND (
    '{{(inpZoeken.text || "").trim().replace(/'/g, "''")}}' = ''
    OR LOWER(CONCAT_WS(' ', l.tellercode, l.naam, l.email)) LIKE LOWER(CONCAT('%', '{{(inpZoeken.text || "").trim().replace(/'/g, "''")}}', '%'))
  )
  AND (
    '{{(inpLidtype.text || "").trim().replace(/'/g, "''")}}' = ''
    OR LOWER(TRIM(l.soort_lid)) = LOWER('{{(inpLidtype.text || "").trim().replace(/'/g, "''")}}')
  )
  AND (
    '{{(inpDatakwaliteit.text || "").trim().replace(/'/g, "''")}}' = ''
    OR EXISTS (
      SELECT 1
      FROM plot_jaar_teller pjt_actief
      WHERE pjt_actief.teller_id = l.id
        AND pjt_actief.jaar = {{Number((inpDatakwaliteit.text || '').trim() || 0)}}
    )
  )
  AND (
    '{{(inpWoonplaats.text || "").trim().replace(/'/g, "''")}}' = ''
    OR LOWER(COALESCE(l.woonplaats, '')) LIKE LOWER(CONCAT('%', '{{(inpWoonplaats.text || "").trim().replace(/'/g, "''")}}', '%'))
  )
ORDER BY l.achternaam, l.voornaam, l.tellercode
LIMIT 500;`;

const jsonPathKeys = [
  '(inpZoeken.text || "").trim().replace(/\'/g, "\'\'")',
  '(inpLidtype.text || "").trim().replace(/\'/g, "\'\'")',
  '(inpDatakwaliteit.text || "").trim().replace(/\'/g, "\'\'")',
  '(inpWoonplaats.text || "").trim().replace(/\'/g, "\'\'")',
  "Number((inpDatakwaliteit.text || '').trim() || 0)",
];

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

appsmithDb.codexActionBackups.insertOne({
  actionId: action._id,
  pageId,
  name: "q_tellers",
  createdAt: now,
  reason: "Voor herstel SQL ledenzoekvelden",
  action,
});
appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor herstel zoektekst en zoektriggers",
  page,
});

appsmithDb.newAction.updateOne(
  { _id: action._id },
  {
    $set: {
      "unpublishedAction.actionConfiguration.body": qTellersBody,
      "unpublishedAction.executeOnLoad": false,
      "unpublishedAction.dynamicBindingPathList": [{ key: "body" }],
      "unpublishedAction.jsonPathKeys": jsonPathKeys,
      "publishedAction.actionConfiguration.body": qTellersBody,
      "publishedAction.executeOnLoad": false,
      "publishedAction.dynamicBindingPathList": [{ key: "body" }],
      "publishedAction.jsonPathKeys": jsonPathKeys,
      updatedAt: now,
    },
  },
);

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const dsl = page[pageKey].layouts[0].dsl;
  const instruction = findWidget(dsl, "txtInfoZoekInstructie");
  if (!instruction) throw new Error(`txtInfoZoekInstructie niet gevonden in ${pageKey}`);
  instruction.text = instructionText;
  instruction.fontStyle = "BOLD";
  instruction.dynamicBindingPathList = [];

  for (const name of inputNames) {
    const input = findWidget(dsl, name);
    if (!input) throw new Error(`${name} niet gevonden in ${pageKey}`);
    setTrigger(input);
  }
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updatedPage = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
const updatedAction = appsmithDb.newAction.findOne({ pageId, name: "q_tellers", deleted: false });
printjson({
  instruction: findWidget(updatedPage, "txtInfoZoekInstructie").text,
  executeOnLoad: updatedAction.publishedAction.executeOnLoad,
  dynamicBindingPathList: updatedAction.publishedAction.dynamicBindingPathList,
  jsonPathKeys: updatedAction.publishedAction.jsonPathKeys,
  triggers: Object.fromEntries(inputNames.map((name) => {
    const input = findWidget(updatedPage, name);
    return [name, { onTextChanged: input.onTextChanged, onSubmit: input.onSubmit }];
  })),
});
