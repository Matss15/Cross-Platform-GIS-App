import { accountEmailLookupId, initializeAdminTool } from './lib/tool-config.mjs';

const { auth, db, projectId } = await initializeAdminTool();
const citizenProfiles = [];

for (const role of ['resident', 'citizen']) {
  const snapshot = await db.collection('users').where('role', '==', role).get();
  citizenProfiles.push(...snapshot.docs);
}

const citizenIds = new Set(citizenProfiles.map((doc) => doc.id));
const emailIndexDeletes = new Set();

for (const profile of citizenProfiles) {
  const email = profile.data().email;
  if (typeof email === 'string' && email.trim()) {
    emailIndexDeletes.add(accountEmailLookupId(email));
  }
}

const allUsers = [];
let pageToken;
do {
  const page = await auth.listUsers(1000, pageToken);
  allUsers.push(...page.users);
  pageToken = page.pageToken;
} while (pageToken);

const authUsersToDelete = allUsers.filter((user) => citizenIds.has(user.uid));
for (let offset = 0; offset < authUsersToDelete.length; offset += 1000) {
  await auth.deleteUsers(
    authUsersToDelete.slice(offset, offset + 1000).map((user) => user.uid),
  );
}

const refsToDelete = [
  ...citizenProfiles.map((doc) => doc.ref),
  ...[...emailIndexDeletes].map((id) =>
    db.collection('account_email_index').doc(id),
  ),
];

for (let offset = 0; offset < refsToDelete.length; offset += 450) {
  const batch = db.batch();
  for (const ref of refsToDelete.slice(offset, offset + 450)) batch.delete(ref);
  await batch.commit();
}

console.log(`Project: ${projectId}`);
console.log(`Deleted ${authUsersToDelete.length} citizen Firebase Auth accounts.`);
console.log(`Deleted ${citizenProfiles.length} citizen Firestore profiles.`);
console.log(`Deleted ${emailIndexDeletes.size} citizen email indexes.`);
console.log('Incidents, notifications, and activity logs were not modified.');
