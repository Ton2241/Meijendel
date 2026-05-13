const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const safeFilteredTableData = `{{(() => {
  const rows = q_tellers.data || [];
  const textOf = (getter) => {
    try {
      return String(getter() || '').trim().toLowerCase();
    } catch (e) {
      return '';
    }
  };

  const zoek = textOf(() => inpZoeken.text);
  const lidtype = textOf(() => inpLidtype.text);
  const actiefJaar = textOf(() => inpDatakwaliteit.text);
  const woonplaats = textOf(() => inpWoonplaats.text);

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

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor veilige tabelbinding ledenlijst",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  const tellers = findWidget(layout.dsl, "tblTellers");
  if (!tellers) throw new Error(`tblTellers niet gevonden in ${pageKey}`);
  tellers.tableData = safeFilteredTableData;
  tellers.dynamicBindingPathList = [
    { key: "tableData" },
    ...Object.keys(tellers.primaryColumns || {}).map((id) => ({ key: `primaryColumns.${id}.computedValue` })),
  ];
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

printjson({
  tableData: findWidget(
    appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl,
    "tblTellers",
  ).tableData,
});
