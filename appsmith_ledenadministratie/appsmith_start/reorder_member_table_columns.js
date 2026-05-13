const appsmithDb = db.getSiblingDB("appsmith");

const pageId = "69f372c89e8d978bb38cc425";
const now = new Date();

const desiredOrder = [
  "tellercode",
  "naam",
  "soort_lid",
  "woonplaats",
  "email",
  "telefoon_mobiel",
  "eerste_jaar",
  "laatste_jaar",
  "aantal_jaren_geteld",
  "aantal_plotjaren",
  "aantal_plots",
  "datakwaliteit",
  "id",
];

const columnSpecs = {
  tellercode: { label: "Code", type: "text", width: 95, align: "LEFT" },
  naam: { label: "Naam", type: "text", width: 180, align: "LEFT" },
  soort_lid: { label: "Lidtype", type: "text", width: 120, align: "LEFT" },
  woonplaats: { label: "Woonplaats", type: "text", width: 150, align: "LEFT" },
  email: { label: "Email", type: "text", width: 210, align: "LEFT" },
  telefoon_mobiel: { label: "Mobiel", type: "text", width: 130, align: "LEFT" },
  eerste_jaar: { label: "Eerste jaar", type: "number", width: 105, align: "RIGHT" },
  laatste_jaar: { label: "Laatste jaar", type: "number", width: 110, align: "RIGHT" },
  aantal_jaren_geteld: { label: "Jaren", type: "number", width: 90, align: "RIGHT" },
  aantal_plotjaren: { label: "Plotjaren", type: "number", width: 105, align: "RIGHT" },
  aantal_plots: { label: "Unieke plots", type: "number", width: 115, align: "RIGHT" },
  datakwaliteit: { label: "Datakwaliteit", type: "text", width: 130, align: "LEFT" },
  id: { label: "id", type: "number", width: 80, align: "RIGHT" },
};

function findWidget(widget, widgetName) {
  if (!widget) return null;
  if (widget.widgetName === widgetName) return widget;
  for (const child of widget.children || []) {
    const found = findWidget(child, widgetName);
    if (found) return found;
  }
  return null;
}

function computedValue(tableName, columnId) {
  return `{{(() => { const tableData = ${tableName}.processedTableData || []; return tableData.length > 0 ? tableData.map((currentRow) => (currentRow["${columnId}"])) : ${columnId} })()}}`;
}

function makeColumn(tableName, columnId, index, existing = {}) {
  const spec = columnSpecs[columnId];
  return {
    ...existing,
    allowCellWrapping: false,
    allowSameOptionsInNewRow: true,
    index,
    width: spec.width,
    originalId: columnId,
    id: columnId,
    alias: spec.label,
    horizontalAlignment: spec.align,
    verticalAlignment: "CENTER",
    columnType: spec.type,
    textColor: "",
    textSize: "0.875rem",
    fontStyle: "",
    enableFilter: true,
    enableSort: true,
    isVisible: true,
    isDisabled: false,
    isCellEditable: false,
    isEditable: false,
    isCellVisible: true,
    isDerived: false,
    label: spec.label,
    isSaveVisible: true,
    isDiscardVisible: true,
    computedValue: computedValue(tableName, columnId),
    sticky: "",
    validation: {},
    currencyCode: "USD",
    decimals: 0,
    thousandSeparator: false,
    notation: "standard",
    cellBackground: "",
  };
}

function applyOrder(dsl) {
  const table = findWidget(dsl, "tblTellers");
  if (!table) throw new Error("tblTellers niet gevonden");

  table.primaryColumns = table.primaryColumns || {};
  desiredOrder.forEach((columnId, index) => {
    table.primaryColumns[columnId] = makeColumn("tblTellers", columnId, index, table.primaryColumns[columnId]);
  });

  table.columnOrder = desiredOrder;
  table.dynamicBindingPathList = [
    { key: "tableData" },
    ...desiredOrder.map((columnId) => ({ key: `primaryColumns.${columnId}.computedValue` })),
  ];
}

const page = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) });
if (!page) throw new Error(`Pagina ${pageId} niet gevonden`);

appsmithDb.codexPageBackups.insertOne({
  pageId,
  createdAt: now,
  reason: "Voor verplaatsen kolommen leden tabel",
  page,
});

for (const pageKey of ["unpublishedPage", "publishedPage"]) {
  applyOrder(page[pageKey].layouts[0].dsl);
}

appsmithDb.newPage.replaceOne({ _id: ObjectId(pageId) }, page);

const updated = appsmithDb.newPage.findOne({ _id: ObjectId(pageId) }).publishedPage.layouts[0].dsl;
const table = findWidget(updated, "tblTellers");
printjson({
  columnOrder: table.columnOrder,
  labels: Object.fromEntries(table.columnOrder.map((id) => [id, table.primaryColumns[id].label])),
});
