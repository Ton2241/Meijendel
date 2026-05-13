const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();
const tabQueryTrigger = "{{q_tellers.run(); q_actieve_tellers_per_jaar.run(); q_datakwaliteit.run();}}";

function widgetId() {
  return new ObjectId().toString().slice(-8);
}

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
  if (!widget.children) return [];

  const removed = [];
  const kept = [];
  for (const child of widget.children) {
    if (names.has(child.widgetName)) {
      removed.push(child);
    } else {
      removed.push(...removeWidgetsByName(child, names));
      kept.push(child);
    }
  }
  widget.children = kept;
  return removed;
}

function setPosition(widget, topRow, bottomRow, leftColumn, rightColumn, parentId) {
  widget.topRow = topRow;
  widget.bottomRow = bottomRow;
  widget.leftColumn = leftColumn;
  widget.rightColumn = rightColumn;
  widget.parentId = parentId;
  return widget;
}

function makeCanvas(widgetName, tabId, tabName, children, bottomRow = 90) {
  const id = widgetId();
  return {
    widgetName,
    widgetId: id,
    type: "CANVAS_WIDGET",
    version: 1,
    parentId: "",
    renderMode: "CANVAS",
    detachFromLayout: true,
    canExtend: true,
    isVisible: true,
    isDisabled: false,
    shouldScrollContents: false,
    tabId,
    tabName,
    topRow: 0,
    bottomRow,
    leftColumn: 0,
    rightColumn: 64,
    minHeight: bottomRow,
    children,
  };
}

function makeTabs(childrenByTab) {
  const id = widgetId();
  const canvases = [
    makeCanvas("canInfoPerLid", "info", "Informatie per lid", childrenByTab.info),
    makeCanvas("canTelhistorie", "telhistorie", "Telhistorie van alle tellers", childrenByTab.telhistorie),
    makeCanvas("canActieveTellers", "actieve_tellers", "Actieve tellers per jaar", childrenByTab.actieveTellers),
    makeCanvas("canDatakwaliteit", "datakwaliteit", "Datakwaliteit", childrenByTab.datakwaliteit),
  ];

  for (const canvas of canvases) {
    canvas.parentId = id;
    for (const child of canvas.children || []) child.parentId = canvas.widgetId;
  }

  const tabsObj = {
    info: {
      label: "Informatie per lid",
      id: "info",
      widgetId: canvases[0].widgetId,
      isVisible: true,
      index: 0,
      positioning: "fixed",
    },
    telhistorie: {
      label: "Telhistorie van alle tellers",
      id: "telhistorie",
      widgetId: canvases[1].widgetId,
      isVisible: true,
      index: 1,
      positioning: "fixed",
    },
    actieve_tellers: {
      label: "Actieve tellers per jaar",
      id: "actieve_tellers",
      widgetId: canvases[2].widgetId,
      isVisible: true,
      index: 2,
      positioning: "fixed",
    },
    datakwaliteit: {
      label: "Datakwaliteit",
      id: "datakwaliteit",
      widgetId: canvases[3].widgetId,
      isVisible: true,
      index: 3,
      positioning: "fixed",
    },
  };

  return {
    widgetName: "tabsLedenadministratie",
    widgetId: id,
    type: "TABS_WIDGET",
    version: 3,
    parentId: "0",
    renderMode: "CANVAS",
    isVisible: true,
    isDisabled: false,
    topRow: 28,
    bottomRow: 123,
    leftColumn: 2,
    rightColumn: 62,
    rows: 95,
    columns: 60,
    shouldScrollContents: true,
    animateLoading: true,
    borderWidth: 1,
    borderColor: "#AEC764",
    backgroundColor: "#FFFFFF",
    minDynamicHeight: 95,
    tabsObj,
    shouldShowTabs: true,
    defaultTab: "Informatie per lid",
    onTabSelected: tabQueryTrigger,
    dynamicBindingPathList: [],
    dynamicTriggerPathList: [{ key: "onTabSelected" }],
    children: canvases,
  };
}

function allWidgetNames(widget, names = []) {
  names.push(widget.widgetName);
  for (const child of widget.children || []) allWidgetNames(child, names);
  return names;
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor tabs-layout ledenadministratie",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  const layout = page[pageKey].layouts[0];
  const dsl = layout.dsl;

  const names = new Set([
    "inpZoeken",
    "txtInfoZoekInstructie",
    "inpLidtype",
    "inpDatakwaliteit",
    "inpWoonplaats",
    "btnExportLedenCsv",
    "tblTellers",
    "txtDetailTitel",
    "txtDetail",
    "txtDetailMetaValues",
    "txtDetailContactTitel",
    "txtDetailContact",
    "txtDetailContactLabels",
    "txtDetailContactValues",
    "txtDetailTellingTitel",
    "txtDetailTelling",
    "txtDetailTellingLabels",
    "txtDetailTellingValues",
    "txtDetailStatus",
    "txtDetailStatusLabel",
    "txtDetailStatusValue",
    "txtTelhistorieTitel",
    "txtTelhistorieInstructie",
    "inpTelhistorieJaar",
    "btnExportTelhistorieCsv",
    "tblTelhistorie",
    "txtJaaroverzichtTitel",
    "tblJaaroverzicht",
    "txtDatakwaliteitTitel",
    "tblDatakwaliteit",
  ]);
  const removed = removeWidgetsByName(dsl, names);
  removeWidgetsByName(dsl, new Set(["tabsLedenadministratie"]));
  const byName = Object.fromEntries(removed.map((w) => [w.widgetName, w]));

  if (byName.txtInfoZoekInstructie) setPosition(byName.txtInfoZoekInstructie, 1, 4, 0, 60, "");
  setPosition(byName.inpZoeken, 5, 12, 0, 15, "");
  byName.inpZoeken.label = "Naam, code of email";
  byName.inpZoeken.placeholderText = "bijv. lansink";
  setPosition(byName.inpLidtype, 5, 12, 16, 28, "");
  setPosition(byName.inpDatakwaliteit, 5, 12, 29, 43, "");
  byName.inpDatakwaliteit.label = "Actieve tellers";
  byName.inpDatakwaliteit.placeholderText = "jaartal, bijv. 2025";
  byName.inpDatakwaliteit.labelPosition = "Top";
  byName.inpDatakwaliteit.inputType = "NUMBER";
  setPosition(byName.inpWoonplaats, 5, 12, 44, 60, "");
  if (byName.btnExportLedenCsv) setPosition(byName.btnExportLedenCsv, 14, 19, 31, 41, "");
  setPosition(byName.tblTellers, 21, 78, 0, 41, "");
  setPosition(byName.txtDetailTitel, 10, 14, 43, 60, "");
  setPosition(byName.txtDetail, 14, 20, 43, 49, "");
  if (byName.txtDetailMetaValues) setPosition(byName.txtDetailMetaValues, 14, 20, 49, 60, "");
  if (byName.txtDetailContactTitel) setPosition(byName.txtDetailContactTitel, 21, 23, 43, 60, "");
  if (byName.txtDetailContact) setPosition(byName.txtDetailContact, 28, 43, 44, 60, "");
  if (byName.txtDetailContactLabels) setPosition(byName.txtDetailContactLabels, 23, 31, 43, 49, "");
  if (byName.txtDetailContactValues) setPosition(byName.txtDetailContactValues, 23, 31, 49, 60, "");
  if (byName.txtDetailTellingTitel) setPosition(byName.txtDetailTellingTitel, 32, 34, 43, 60, "");
  if (byName.txtDetailTelling) setPosition(byName.txtDetailTelling, 51, 66, 44, 60, "");
  if (byName.txtDetailTellingLabels) setPosition(byName.txtDetailTellingLabels, 34, 44, 43, 50, "");
  if (byName.txtDetailTellingValues) setPosition(byName.txtDetailTellingValues, 34, 44, 50, 60, "");
  if (byName.txtDetailStatus) setPosition(byName.txtDetailStatus, 69, 76, 44, 60, "");
  if (byName.txtDetailStatusLabel) setPosition(byName.txtDetailStatusLabel, 45, 50, 43, 50, "");
  if (byName.txtDetailStatusValue) setPosition(byName.txtDetailStatusValue, 45, 50, 50, 60, "");

  byName.txtTelhistorieTitel.text = "Telhistorie van alle tellers";
  byName.txtTelhistorieTitel.dynamicBindingPathList = [];
  setPosition(byName.txtTelhistorieTitel, 1, 6, 0, 60, "");
  if (byName.txtTelhistorieInstructie) setPosition(byName.txtTelhistorieInstructie, 8, 12, 0, 60, "");
  if (byName.inpTelhistorieJaar) {
    setPosition(byName.inpTelhistorieJaar, 15, 22, 0, 9, "");
    byName.inpTelhistorieJaar.onTextChanged = "{{q_teller_telhistorie.run()}}";
    byName.inpTelhistorieJaar.dynamicTriggerPathList = [
      ...((byName.inpTelhistorieJaar.dynamicTriggerPathList || []).filter((path) => path.key !== "onTextChanged")),
      { key: "onTextChanged" },
    ];
  }
  if (byName.btnExportTelhistorieCsv) setPosition(byName.btnExportTelhistorieCsv, 15, 22, 10, 20, "");
  byName.tblTelhistorie.tableData = "{{q_teller_telhistorie.data || []}}";
  byName.tblTelhistorie.isVisibleFilters = false;
  byName.tblTelhistorie.dynamicBindingPathList = (byName.tblTelhistorie.dynamicBindingPathList || [])
    .filter((path) => path.key !== "tableData")
    .concat([{ key: "tableData" }]);
  setPosition(byName.tblTelhistorie, 24, 96, 0, 60, "");

  setPosition(byName.txtJaaroverzichtTitel, 1, 6, 0, 60, "");
  setPosition(byName.tblJaaroverzicht, 7, 86, 0, 60, "");

  setPosition(byName.txtDatakwaliteitTitel, 1, 6, 0, 60, "");
  setPosition(byName.tblDatakwaliteit, 7, 86, 0, 60, "");

  const tabs = makeTabs({
    info: [
      byName.inpZoeken,
      byName.txtInfoZoekInstructie,
      byName.inpLidtype,
      byName.inpDatakwaliteit,
      byName.inpWoonplaats,
      byName.btnExportLedenCsv,
      byName.tblTellers,
      byName.txtDetailTitel,
      byName.txtDetail,
      byName.txtDetailMetaValues,
      byName.txtDetailContactTitel,
      byName.txtDetailContact,
      byName.txtDetailContactLabels,
      byName.txtDetailContactValues,
      byName.txtDetailTellingTitel,
      byName.txtDetailTelling,
      byName.txtDetailTellingLabels,
      byName.txtDetailTellingValues,
      byName.txtDetailStatus,
      byName.txtDetailStatusLabel,
      byName.txtDetailStatusValue,
    ].filter(Boolean),
    telhistorie: [byName.txtTelhistorieTitel, byName.txtTelhistorieInstructie, byName.inpTelhistorieJaar, byName.btnExportTelhistorieCsv, byName.tblTelhistorie].filter(Boolean),
    actieveTellers: [byName.txtJaaroverzichtTitel, byName.tblJaaroverzicht],
    datakwaliteit: [byName.txtDatakwaliteitTitel, byName.tblDatakwaliteit],
  });

  dsl.children.push(tabs);
  dsl.minHeight = 1120;
  dsl.bottomRow = 112;
  layout.widgetNames = allWidgetNames(dsl);
  layout.validOnPageLoadActions = true;
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).unpublishedPage.layouts[0].dsl;
printjson({
  tabs: findWidget(updated, "tabsLedenadministratie"),
  widgetNames: appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).unpublishedPage.layouts[0].widgetNames,
});
