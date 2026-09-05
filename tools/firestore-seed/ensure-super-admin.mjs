import {
  accountEmailLookupId,
  initializeAdminTool,
  loadSuperAdminConfig,
} from './lib/tool-config.mjs';

const { auth, db, now, projectId } = await initializeAdminTool();
const superAdmin = loadSuperAdminConfig();

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

const adminUid = await upsertSuperAdminAuthUser();
const userRef = db.collection('users').doc(adminUid);
const existingProfile = await userRef.get();
const existingCreatedAt = existingProfile.data()?.createdAt;

await userRef.set(
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
    birthdate: '1990-03-15',
    emergencyContactName: 'Rosario Command Office',
    emergencyContactPhone: '(043) 312-1102',
    biodata: 'System administrator for BFP Rosario GIS.',
    profileImage: '',
    latitude: 13.845,
    longitude: 121.2,
    isVerified: true,
    createdAt: existingCreatedAt ?? now,
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

console.log(`Super admin ready: ${superAdmin.email}`);
console.log('Password was read from BFP_SUPER_ADMIN_PASSWORD and was not printed.');
console.log(`Project: ${projectId}`);
