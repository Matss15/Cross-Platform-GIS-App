import {
  accountEmailLookupId,
  initializeAdminTool,
  loadSuperAdminConfig,
} from './lib/tool-config.mjs';

const { auth, db, now, projectId } = await initializeAdminTool();

const legacyAccounts = [
  {
    uid: '4jWlzxcsebZgJ8pjsU9ITKxnsmo2',
    email: 'admin.rosario@gmail.com',
  },
  {
    uid: 'x2VNSjsjkPNSmcCg4vBhxA6xmz52',
    email: 'bfp.rosario@gmail.com',
  },
  {
    uid: 'kkjNs0XLcROYJ6oXQbwJku3RgCV2',
    email: 'barangay.rosario@gmail.com',
  },
  {
    uid: 'VN6maPw1TQPc5OrJFKp6CIEetKq1',
    email: 'citizen.rosario@gmail.com',
  },
];

const superAdmin = loadSuperAdminConfig();

async function deleteAuthUserByEmail(email) {
  try {
    const user = await auth.getUserByEmail(email);
    await auth.deleteUser(user.uid);
    return 1;
  } catch (error) {
    if (error.code === 'auth/user-not-found') return 0;
    throw error;
  }
}

async function deleteAuthUserByUid(uid) {
  try {
    await auth.deleteUser(uid);
    return 1;
  } catch (error) {
    if (error.code === 'auth/user-not-found') return 0;
    throw error;
  }
}

async function deleteLegacyFirestoreData() {
  let deletedDocs = 0;
  const batch = db.batch();

  for (const account of legacyAccounts) {
    batch.delete(db.collection('users').doc(account.uid));
    batch.delete(
      db.collection('account_email_index').doc(accountEmailLookupId(account.email)),
    );
    deletedDocs += 2;

    const matchingUsers = await db
      .collection('users')
      .where('email', '==', account.email)
      .get();
    for (const doc of matchingUsers.docs) {
      batch.delete(doc.ref);
      deletedDocs += 1;
    }
  }

  await batch.commit();
  return deletedDocs;
}

async function upsertSuperAdminAuthUser() {
  try {
    const existing = await auth.getUserByEmail(superAdmin.email);
    await auth.updateUser(existing.uid, {
      password: superAdmin.password,
      displayName: superAdmin.displayName,
      emailVerified: true,
      disabled: false,
    });
    return existing.uid;
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }

  try {
    const existing = await auth.getUser(superAdmin.uid);
    await auth.updateUser(existing.uid, {
      email: superAdmin.email,
      password: superAdmin.password,
      displayName: superAdmin.displayName,
      emailVerified: true,
      disabled: false,
    });
    return existing.uid;
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }

  const created = await auth.createUser({
    uid: superAdmin.uid,
    email: superAdmin.email,
    password: superAdmin.password,
    displayName: superAdmin.displayName,
    emailVerified: true,
    disabled: false,
  });

  return created.uid;
}

let deletedAuthUsers = 0;
for (const account of legacyAccounts) {
  deletedAuthUsers += await deleteAuthUserByEmail(account.email);
  deletedAuthUsers += await deleteAuthUserByUid(account.uid);
}

const deletedFirestoreDocs = await deleteLegacyFirestoreData();
const adminUid = await upsertSuperAdminAuthUser();

await db.collection('users').doc(adminUid).set(
  {
    uid: adminUid,
    fullName: superAdmin.displayName,
    email: superAdmin.email,
    phone: '',
    address: 'Rosario Municipal Command Office',
    role: 'admin',
    adminLevel: 'super',
    barangayId: 'poblacion_a',
    barangayName: 'Poblacion A',
    profileImage: '',
    latitude: 13.845,
    longitude: 121.2,
    isVerified: true,
    createdAt: now,
    updatedAt: now,
  },
  { merge: true },
);

await db
  .collection('account_email_index')
  .doc(accountEmailLookupId(superAdmin.email))
  .set(
    {
      uid: adminUid,
      email: superAdmin.email,
      fullName: superAdmin.displayName,
      role: 'admin',
      adminLevel: 'super',
      updatedAt: now,
    },
    { merge: true },
  );

await db.collection('settings').doc('account_reset').set(
  {
    resetAt: now,
    removedLegacyAccounts: legacyAccounts.map((account) => account.email),
    superAdminEmail: superAdmin.email,
  },
  { merge: true },
);

console.log(`Deleted ${deletedAuthUsers} legacy Firebase Auth users.`);
console.log(`Deleted ${deletedFirestoreDocs} legacy Firestore account documents/indexes.`);
console.log(`Super admin ready: ${superAdmin.email}`);
console.log('Password was read from BFP_SUPER_ADMIN_PASSWORD and was not printed.');
console.log(`Project: ${projectId}`);
