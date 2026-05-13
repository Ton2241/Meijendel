const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const detailWidgetNames = new Set([
  "txtDetailContactTitel",
  "txtDetailContact",
  "txtDetailTellingTitel",
  "txtDetailTelling",
  "txtDetailStatus",
]);

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

function textWidget({ name, id, parentId, top, bottom, left = 44, right = 60, text, size = "0.875rem", style = "", color = "#374151" }) {
  return {
    widgetName: name,
    widgetId: id,
    type: "TEXT_WIDGET",
    version: 1,
    parentId,
    renderMode: "CANVAS",
    isVisible: true,
    topRow: top,
    bottomRow: bottom,
    leftColumn: left,
    rightColumn: right,
    text,
    fontSize: size,
    fontStyle: style,
    textAlign: "LEFT",
    textColor: color,
    dynamicBindingPathList: text.includes("{{") ? [{ key: "text" }] : [],
    dynamicTriggerPathList: [],
  };
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor betere indeling detailpaneel lid",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  const dsl = layout.dsl;
  const infoCanvas = findWidget(dsl, "canInfoPerLid");
  if (!infoCanvas) throw new Error(`canInfoPerLid niet gevonden in ${pageKey}`);

  removeWidgetsByName(dsl, detailWidgetNames);

  const title = findWidget(dsl, "txtDetailTitel");
  const detail = findWidget(dsl, "txtDetail");
  if (!title) throw new Error(`txtDetailTitel niet gevonden in ${pageKey}`);
  if (!detail) throw new Error(`txtDetail niet gevonden in ${pageKey}`);

  title.topRow = 10;
  title.bottomRow = 14;
  title.leftColumn = 44;
  title.rightColumn = 60;
  title.text = "{{tblTellers.selectedRow.naam || 'Selecteer een teller'}}";
  title.fontSize = "1.125rem";
  title.fontStyle = "BOLD";
  title.textColor = "#111827";
  title.dynamicBindingPathList = [{ key: "text" }];

  detail.topRow = 15;
  detail.bottomRow = 21;
  detail.leftColumn = 44;
  detail.rightColumn = 60;
  detail.text = "{{(() => { const r = tblTellers.selectedRow || {}; if (!r.id) return 'Kies links een lid om de gegevens te bekijken.'; return `${r.tellercode || '-'}   |   ${r.soort_lid || '-'}\\nStatus: ${r.datakwaliteit || '-'}`; })()}}";
  detail.fontSize = "0.875rem";
  detail.fontStyle = "";
  detail.textColor = "#4B5563";
  detail.dynamicBindingPathList = [{ key: "text" }];

  const parentId = infoCanvas.widgetId;
  infoCanvas.children = infoCanvas.children || [];
  infoCanvas.children.push(
    textWidget({
      name: "txtDetailContactTitel",
      id: "dconttl1",
      parentId,
      top: 23,
      bottom: 27,
      text: "Contact",
      size: "0.875rem",
      style: "BOLD",
      color: "#1F2937",
    }),
    textWidget({
      name: "txtDetailContact",
      id: "dcontxt1",
      parentId,
      top: 28,
      bottom: 43,
      text: "{{(() => { const r = tblTellers.selectedRow || {}; return `Email\\n${r.email || '-'}\\n\\nMobiel\\n${r.telefoon_mobiel || '-'}\\n\\nWoonplaats\\n${r.woonplaats || '-'}`; })()}}",
      color: "#374151",
    }),
    textWidget({
      name: "txtDetailTellingTitel",
      id: "dteltit1",
      parentId,
      top: 46,
      bottom: 50,
      text: "Tellingen",
      size: "0.875rem",
      style: "BOLD",
      color: "#1F2937",
    }),
    textWidget({
      name: "txtDetailTelling",
      id: "dteltxt1",
      parentId,
      top: 51,
      bottom: 66,
      text: "{{(() => { const r = tblTellers.selectedRow || {}; return `Periode\\n${r.eerste_jaar || '-'} - ${r.laatste_jaar || '-'}\\n\\nJaren geteld       ${r.aantal_jaren_geteld || 0}\\nPlotjaren          ${r.aantal_plotjaren || 0}\\nUnieke plots       ${r.aantal_plots || 0}`; })()}}",
      color: "#374151",
    }),
    textWidget({
      name: "txtDetailStatus",
      id: "dstats01",
      parentId,
      top: 69,
      bottom: 76,
      text: "{{(() => { const r = tblTellers.selectedRow || {}; const status = String(r.datakwaliteit || '-'); return `Datakwaliteit\\n${status}`; })()}}",
      color: "#4B5563",
    }),
  );

  layout.widgetNames = allWidgetNames(dsl);
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson({
  titel: findWidget(updated, "txtDetailTitel").text,
  widgets: ["txtDetail", ...detailWidgetNames].map((name) => {
    const widget = findWidget(updated, name);
    return widget && { name, top: widget.topRow, bottom: widget.bottomRow };
  }),
});
