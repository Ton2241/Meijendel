const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const qTellersBody = `SELECT
  id,
  tellercode,
  naam,
  soort_lid,
  woonplaats,
  email,
  telefoon_mobiel,
  aantal_jaren_geteld,
  aantal_plots,
  aantal_plotjaren,
  eerste_jaar,
  laatste_jaar,
  datakwaliteit
FROM appsmith_teller_lijst
WHERE
  (
    TRIM('{{(inpZoeken.text || "").replace(/'/g, "''")}}') = ''
    OR LOWER(CONCAT_WS(' ', tellercode, naam, email)) LIKE LOWER(CONCAT('%', '{{(inpZoeken.text || "").replace(/'/g, "''")}}', '%'))
  )
  AND (
    TRIM('{{(inpLidtype.text || "").replace(/'/g, "''")}}') = ''
    OR LOWER(TRIM(soort_lid)) = LOWER(TRIM('{{(inpLidtype.text || "").replace(/'/g, "''")}}'))
  )
  AND (
    TRIM('{{(inpDatakwaliteit.text || "").replace(/'/g, "''")}}') = ''
    OR LOWER(datakwaliteit) LIKE LOWER(CONCAT('%', '{{(inpDatakwaliteit.text || "").replace(/'/g, "''")}}', '%'))
  )
  AND (
    TRIM('{{(inpWoonplaats.text || "").replace(/'/g, "''")}}') = ''
    OR LOWER(woonplaats) LIKE LOWER(CONCAT('%', '{{(inpWoonplaats.text || "").replace(/'/g, "''")}}', '%'))
  )
ORDER BY achternaam, voornaam, tellercode
LIMIT 500;`;

const jsonPathKeys = [
  '(inpZoeken.text || "").replace(/\'/g, "\'\'")',
  '(inpLidtype.text || "").replace(/\'/g, "\'\'")',
  '(inpDatakwaliteit.text || "").replace(/\'/g, "\'\'")',
  '(inpWoonplaats.text || "").replace(/\'/g, "\'\'")',
];

const action = appsmithDb.newAction.findOne({ pageId, name: "q_tellers", deleted: false });
if (!action) throw new Error("q_tellers niet gevonden");

appsmithDb.codexActionBackups.insertOne({
  actionId: action._id,
  pageId,
  name: "q_tellers",
  createdAt: now,
  reason: "Voor correctie filters ledenadministratie",
  action,
});

const setAction = {
  "unpublishedAction.actionConfiguration.body": qTellersBody,
  "unpublishedAction.dynamicBindingPathList": [{ key: "body" }],
  "unpublishedAction.jsonPathKeys": jsonPathKeys,
  "publishedAction.actionConfiguration.body": qTellersBody,
  "publishedAction.dynamicBindingPathList": [{ key: "body" }],
  "publishedAction.jsonPathKeys": jsonPathKeys,
  updatedAt: now,
};

appsmithDb.newAction.updateOne({ _id: action._id }, { $set: setAction });

printjson({
  updated: appsmithDb.newAction.findOne(
    { _id: action._id },
    { name: 1, "unpublishedAction.actionConfiguration.body": 1, "unpublishedAction.jsonPathKeys": 1 },
  ),
});
