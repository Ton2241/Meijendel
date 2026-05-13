const appsmithDb = db.getSiblingDB("appsmith");

const appId = "69f372c89e8d978bb38cc423";
const ledenPageId = "69f372c89e8d978bb38cc425";
const bezoekersdrukPageId = "69f377aa2f7ecd5b7f1b8a7e";
const datasourceId = "69f373179e8d978bb38cc426";
const now = new Date();

appsmithDb.newAction.updateMany(
  {
    pageId: bezoekersdrukPageId,
  },
  {
    $set: {
      deleted: true,
      updatedAt: now,
    },
  },
);

appsmithDb.newPage.updateOne(
  {
    _id: ObjectId(bezoekersdrukPageId),
  },
  {
    $set: {
      deleted: true,
      updatedAt: now,
    },
  },
);

appsmithDb.application.updateOne(
  {
    _id: ObjectId(appId),
  },
  {
    $set: {
      name: "Ledenadministratie Meijendel",
      slug: "ledenadministratie-meijendel",
      pages: [
        {
          _id: ObjectId(ledenPageId),
          isDefault: true,
          defaultPageId: ledenPageId,
        },
      ],
      publishedPages: [
        {
          _id: ObjectId(ledenPageId),
          isDefault: true,
          defaultPageId: ledenPageId,
        },
      ],
      updatedAt: now,
    },
  },
);

appsmithDb.datasourceStorage.updateOne(
  {
    datasourceId,
  },
  {
    $set: {
      "datasourceConfiguration.connection.mode": "READ_ONLY",
      updatedAt: now,
    },
  },
);

printjson({
  application: appsmithDb.application.findOne({ _id: ObjectId(appId) }, { name: 1, slug: 1, pages: 1 }),
  activePages: appsmithDb.newPage.find({ applicationId: appId, deleted: false }, { "unpublishedPage.name": 1, "unpublishedPage.slug": 1 }).toArray(),
  activeActions: appsmithDb.newAction.find({ pageId: ledenPageId, deleted: false }, { name: 1, "unpublishedAction.actionConfiguration.body": 1 }).toArray(),
  deletedBezoekersdrukActions: appsmithDb.newAction.countDocuments({ pageId: bezoekersdrukPageId, deleted: true }),
  datasourceMode: appsmithDb.datasourceStorage.findOne({ datasourceId }, { "datasourceConfiguration.connection.mode": 1 }),
});
