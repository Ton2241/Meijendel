const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const headerWidgetNames = new Set([
  "txtVwgTopBand",
  "txtVwgTitle",
  "txtVwgBird",
  "txtVwgMemberButton",
  "txtVwgSearch",
  "txtVwgPhotoBand",
  "txtVwgPhotoLeft",
  "txtVwgPhotoMid",
  "txtVwgPhotoRight",
  "txtVwgNavHome",
  "txtVwgNavMeijendel",
  "txtVwgNavSoorten",
  "txtVwgNavNieuws",
  "txtVwgNavLinks",
  "txtVwgNavWerkgroep",
  "txtVwgNavLeden",
  "txtVwgSubNav",
  "txtVwgPageTitle",
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

function textWidget({ name, id, top, bottom, left, right, text, size, style = "", color, background }) {
  return {
    widgetName: name,
    widgetId: id,
    type: "TEXT_WIDGET",
    version: 1,
    parentId: "0",
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
    backgroundColor: background,
    dynamicBindingPathList: [],
    dynamicTriggerPathList: [],
  };
}

function applyHeader(dsl) {
  removeWidgetsByName(dsl, headerWidgetNames);
  dsl.backgroundColor = "#F3F6EF";

  const title = findWidget(dsl, "txtTitel");
  if (title) {
    title.text = "Ledenadministratie";
    title.topRow = 9;
    title.bottomRow = 15;
    title.leftColumn = 2;
    title.rightColumn = 62;
    title.fontSize = "1.5rem";
    title.fontStyle = "BOLD";
    title.textColor = "#111827";
    title.backgroundColor = "none";
    title.dynamicBindingPathList = [];
  }

  const stats = findWidget(dsl, "txtStats");
  if (stats) {
    stats.topRow = 15;
    stats.bottomRow = 18;
  }

  const tabs = findWidget(dsl, "tabsLedenadministratie");
  if (tabs) {
    tabs.topRow = 19;
    tabs.bottomRow = 114;
    tabs.borderColor = "#E5E7EB";
    tabs.backgroundColor = "#FFFFFF";
  }

  dsl.children = dsl.children || [];
  dsl.children.push(
    textWidget({
      name: "txtVwgTopBand",
      id: "vwgbg001",
      top: 1,
      bottom: 7,
      left: 2,
      right: 62,
      text: "",
      size: "1rem",
      color: "#F8FAF0",
      background: "#354331",
    }),
    textWidget({
      name: "txtVwgTitle",
      id: "vwgttl01",
      top: 1,
      bottom: 7,
      left: 3,
      right: 62,
      text: "Vogelwerkgroep Meijendel",
      size: "1.75rem",
      color: "#F8FAF0",
      background: "#354331",
    }),
  );

  dsl.bottomRow = Math.max(dsl.bottomRow || 0, 118);
  dsl.minHeight = Math.max(dsl.minHeight || 0, 1180);
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor vereenvoudigde VWG header",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  applyHeader(layout.dsl);
  layout.widgetNames = allWidgetNames(layout.dsl);
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
printjson({
  headerTitle: findWidget(updated, "txtVwgTitle").text,
  removedNav: !findWidget(updated, "txtVwgNavHome"),
  tabsTop: findWidget(updated, "tabsLedenadministratie").topRow,
});
