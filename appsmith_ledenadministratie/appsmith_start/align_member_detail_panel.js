const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const generatedDetailWidgets = new Set([
  "txtDetailContactTitel",
  "txtDetailContact",
  "txtDetailTellingTitel",
  "txtDetailTelling",
  "txtDetailStatus",
  "txtDetailContactLabels",
  "txtDetailContactValues",
  "txtDetailTellingLabels",
  "txtDetailTellingValues",
  "txtDetailStatusLabel",
  "txtDetailStatusValue",
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

function textWidget({ name, id, parentId, top, bottom, left, right, text, size = "0.875rem", style = "", color = "#374151" }) {
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

function applyDetailLayout(dsl) {
  const infoCanvas = findWidget(dsl, "canInfoPerLid");
  if (!infoCanvas) throw new Error("canInfoPerLid niet gevonden");

  removeWidgetsByName(dsl, generatedDetailWidgets);

  const title = findWidget(dsl, "txtDetailTitel");
  const detail = findWidget(dsl, "txtDetail");
  if (!title) throw new Error("txtDetailTitel niet gevonden");
  if (!detail) throw new Error("txtDetail niet gevonden");

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
  detail.bottomRow = 20;
  detail.leftColumn = 44;
  detail.rightColumn = 60;
  detail.text = "{{(() => { const r = tblTellers.selectedRow || {}; if (!r.id) return 'Kies links een lid om de gegevens te bekijken.'; return `${r.tellercode || '-'}\\n${r.soort_lid || '-'}`; })()}}";
  detail.fontSize = "0.875rem";
  detail.fontStyle = "";
  detail.textColor = "#6B7280";
  detail.dynamicBindingPathList = [{ key: "text" }];

  const parentId = infoCanvas.widgetId;
  infoCanvas.children = infoCanvas.children || [];
  infoCanvas.children.push(
    textWidget({
      name: "txtDetailContactTitel",
      id: "dconttl1",
      parentId,
      top: 24,
      bottom: 28,
      left: 44,
      right: 60,
      text: "Contact",
      style: "BOLD",
      color: "#1F2937",
    }),
    textWidget({
      name: "txtDetailContactLabels",
      id: "dconlbl1",
      parentId,
      top: 30,
      bottom: 43,
      left: 44,
      right: 49,
      text: "Email\n\nMobiel\n\nWoonplaats",
      color: "#6B7280",
    }),
    textWidget({
      name: "txtDetailContactValues",
      id: "dconval1",
      parentId,
      top: 30,
      bottom: 43,
      left: 49,
      right: 60,
      text: "{{(() => { const r = tblTellers.selectedRow || {}; return `${r.email || '-'}\\n\\n${r.telefoon_mobiel || '-'}\\n\\n${r.woonplaats || '-'}`; })()}}",
      color: "#374151",
    }),
    textWidget({
      name: "txtDetailTellingTitel",
      id: "dteltit1",
      parentId,
      top: 48,
      bottom: 52,
      left: 44,
      right: 60,
      text: "Tellingen",
      style: "BOLD",
      color: "#1F2937",
    }),
    textWidget({
      name: "txtDetailTellingLabels",
      id: "dtellbl1",
      parentId,
      top: 54,
      bottom: 69,
      left: 44,
      right: 50,
      text: "Periode\n\nJaren geteld\nPlotjaren\nUnieke plots",
      color: "#6B7280",
    }),
    textWidget({
      name: "txtDetailTellingValues",
      id: "dtelval1",
      parentId,
      top: 54,
      bottom: 69,
      left: 50,
      right: 60,
      text: "{{(() => { const r = tblTellers.selectedRow || {}; return `${r.eerste_jaar || '-'} - ${r.laatste_jaar || '-'}\\n\\n${r.aantal_jaren_geteld || 0}\\n${r.aantal_plotjaren || 0}\\n${r.aantal_plots || 0}`; })()}}",
      color: "#374151",
    }),
    textWidget({
      name: "txtDetailStatusLabel",
      id: "dstslbl1",
      parentId,
      top: 73,
      bottom: 77,
      left: 44,
      right: 50,
      text: "Datakwaliteit",
      color: "#6B7280",
    }),
    textWidget({
      name: "txtDetailStatusValue",
      id: "dstsval1",
      parentId,
      top: 73,
      bottom: 77,
      left: 50,
      right: 60,
      text: "{{tblTellers.selectedRow.datakwaliteit || '-'}}",
      color: "#374151",
    }),
  );
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor nette uitlijning detailpaneel lid",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  applyDetailLayout(layout.dsl);
  layout.widgetNames = allWidgetNames(layout.dsl);
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson([
  "txtDetailContactLabels",
  "txtDetailContactValues",
  "txtDetailTellingLabels",
  "txtDetailTellingValues",
  "txtDetailStatusLabel",
  "txtDetailStatusValue",
].map((name) => {
  const widget = findWidget(updated, name);
  return { name, top: widget.topRow, bottom: widget.bottomRow, left: widget.leftColumn, right: widget.rightColumn };
}));
