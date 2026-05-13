const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

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
ORDER BY l.achternaam, l.voornaam, l.tellercode
LIMIT 500;`;

const filteredTableData = `{{(() => {
  const rows = q_tellers.data || [];
  const zoek = String(inpZoeken.text || '').trim().toLowerCase();
  const lidtype = String(inpLidtype.text || '').trim().toLowerCase();
  const actiefJaar = String(inpDatakwaliteit.text || '').trim().toLowerCase();
  const woonplaats = String(inpWoonplaats.text || '').trim().toLowerCase();

  return rows.filter((r) => {
    const zoekTekst = [r.tellercode, r.naam, r.email].filter(Boolean).join(' ').toLowerCase();
    return (!zoek || zoekTekst.includes(zoek))
      && (!lidtype || String(r.soort_lid || '').trim().toLowerCase() === lidtype)
      && (!actiefJaar || String(r.actieve_jaren || '').split(',').map((jaar) => jaar.trim()).includes(actiefJaar))
      && (!woonplaats || String(r.woonplaats || '').toLowerCase().includes(woonplaats));
  });
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

const action = appsmithDb.newAction.findOne({ pageId, name: "q_tellers", deleted: false });
if (!action) throw new Error("q_tellers niet gevonden");

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
appsmithDb.codexActionBackups.insertOne({
  actionId: action._id,
  pageId,
  name: "q_tellers",
  createdAt: now,
  reason: "Voor herstel startup tabel leden",
  action,
});
appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor herstel startup tabel leden",
  page,
});

appsmithDb.newAction.updateOne(
  { _id: action._id },
  {
    $set: {
      "unpublishedAction.actionConfiguration.body": qTellersBody,
      "unpublishedAction.dynamicBindingPathList": [],
      "unpublishedAction.jsonPathKeys": [],
      "publishedAction.actionConfiguration.body": qTellersBody,
      "publishedAction.dynamicBindingPathList": [],
      "publishedAction.jsonPathKeys": [],
      updatedAt: now,
    },
  },
);

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  const tellers = findWidget(layout.dsl, "tblTellers");
  if (!tellers) throw new Error(`tblTellers niet gevonden in ${pageKey}`);

  tellers.tableData = filteredTableData;
  tellers.dynamicBindingPathList = [
    { key: "tableData" },
    ...Object.keys(tellers.primaryColumns || {}).map((id) => ({ key: `primaryColumns.${id}.computedValue` })),
  ];
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updatedPage = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
const updatedAction = appsmithDb.newAction.findOne({ _id: action._id });
printjson({
  q_tellers_dynamicBindings: updatedAction.unpublishedAction.dynamicBindingPathList,
  tblTellers_tableData: findWidget(updatedPage.unpublishedPage.layouts[0].dsl, "tblTellers").tableData,
});
