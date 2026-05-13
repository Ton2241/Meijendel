const appsmithDb = db.getSiblingDB("appsmith");

const now = new Date();
const organizationId = "69f336ab3d472de3cc650288";
const appViewerGroupId = "69f372c89e8d978bb38cc421";

const boardUsers = [
  {
    role: "voorzitter",
    name: "Voorzitter",
    email: "vogels@fastmail.nl",
    passwordHash: null,
  },
  {
    role: "secretaris",
    name: "Secretaris",
    email: "a.van.strien@outlook.com",
    passwordHash: "$2a$10$QG5.eu3czSFQ9KCsyCcTmuBbKr7YBL3ZOBGpv2nTTsoGG7KQkBV4q",
  },
  {
    role: "penningmeester",
    name: "Penningmeester",
    email: "f.regeer.cm@gmail.com",
    passwordHash: "$2a$10$XI5GB82JCZLhAaBQllwD1eREfuk4BL.vkxhxvMLvWajQ65.DIn.n.",
  },
  {
    role: "bestuurslid",
    name: "Bestuurslid",
    email: "aleegwater@hotmail.com",
    passwordHash: "$2a$10$4/Nib.D9sLRPblPMbpA0cu23UtYlUBHOjvsBNwUHq5iw9NBkiKKei",
  },
];

function sha256(value) {
  return require("crypto").createHash("sha256").update(value).digest("hex");
}

function userPolicies(groupId) {
  return [
    { permission: "read:users", permissionGroups: [groupId] },
    { permission: "manage:users", permissionGroups: [groupId] },
    { permission: "resetPassword:users", permissionGroups: [groupId] },
  ];
}

function policyMap(policies) {
  const map = {};
  for (const policy of policies) map[policy.permission] = policy;
  return map;
}

function permissionGroupPolicies(groupId) {
  return [
    { permission: "read:permissionGroupMembers", permissionGroups: [groupId] },
    { permission: "assign:permissionGroups", permissionGroups: [groupId] },
    { permission: "unassign:permissionGroups", permissionGroups: [groupId] },
  ];
}

appsmithDb.codexUserBackups.insertOne({
  createdAt: now,
  reason: "Voor toevoegen bestuursgebruikers",
  users: appsmithDb.user.find({ email: { $in: boardUsers.map((u) => u.email) } }).toArray(),
  appViewerGroup: appsmithDb.permissionGroup.findOne({ _id: ObjectId(appViewerGroupId) }),
});

const results = [];

for (const boardUser of boardUsers) {
  let user = appsmithDb.user.findOne({ email: boardUser.email });
  let created = false;

  if (!user) {
    if (!boardUser.passwordHash) throw new Error(`Geen wachtwoordhash voor nieuwe gebruiker ${boardUser.email}`);

    const userId = new ObjectId();
    const personalGroupId = new ObjectId();
    const policies = userPolicies(String(personalGroupId));
    const pgPolicies = permissionGroupPolicies(String(personalGroupId));

    appsmithDb.permissionGroup.insertOne({
      _id: personalGroupId,
      name: `${boardUser.email} User Management`,
      description: `User management permissions for ${boardUser.email}`,
      assignedToUserIds: [String(userId)],
      policyMap: policyMap(pgPolicies),
      policies: pgPolicies,
      createdAt: now,
      updatedAt: now,
      deleted: false,
      _class: "com.appsmith.server.domains.PermissionGroup",
    });

    appsmithDb.user.insertOne({
      _id: userId,
      name: boardUser.name,
      email: boardUser.email,
      hashedEmail: sha256(boardUser.email),
      password: boardUser.passwordHash,
      passwordResetInitiated: false,
      source: "FORM",
      state: "ACTIVATED",
      isEnabled: true,
      emailVerificationRequired: false,
      isAnonymous: false,
      organizationId,
      createdAt: now,
      updatedAt: now,
      deleted: false,
      policyMap: policyMap(policies),
      policies,
      _class: "com.appsmith.server.domains.User",
    });

    appsmithDb.userData.insertOne({
      _id: new ObjectId(),
      userId: String(userId),
      proficiency: "Novice",
      useCase: "internal application",
      releaseNotesViewedVersion: "v1.99",
      recentlyUsedEntityIds: [],
      isIntercomConsentGiven: false,
      createdAt: now,
      updatedAt: now,
      deleted: false,
      policyMap: {},
      policies: [],
      _class: "com.appsmith.server.domains.UserData",
    });

    user = appsmithDb.user.findOne({ _id: userId });
    created = true;
  } else {
    appsmithDb.user.updateOne(
      { _id: user._id },
      { $set: { isEnabled: true, deleted: false, updatedAt: now } },
    );
    user = appsmithDb.user.findOne({ _id: user._id });
  }

  appsmithDb.permissionGroup.updateOne(
    { _id: ObjectId(appViewerGroupId) },
    { $addToSet: { assignedToUserIds: String(user._id) }, $set: { updatedAt: now } },
  );

  results.push({
    role: boardUser.role,
    email: boardUser.email,
    userId: String(user._id),
    created,
  });
}

printjson({
  results,
  appViewerAssignedToUserIds: appsmithDb.permissionGroup.findOne({ _id: ObjectId(appViewerGroupId) }).assignedToUserIds,
});
