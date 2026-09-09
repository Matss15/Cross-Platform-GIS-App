import { initializeAdminTool } from './lib/tool-config.mjs';

if (process.argv[2] !== '--confirm-incidents') {
  console.error('Safety check: pass --confirm-incidents to delete only the incidents collection.');
  process.exit(1);
}

const { db, projectId } = await initializeAdminTool();
const snapshot = await db.collection('incidents').get();

for (let offset = 0; offset < snapshot.docs.length; offset += 450) {
  const batch = db.batch();
  for (const doc of snapshot.docs.slice(offset, offset + 450)) {
    batch.delete(doc.ref);
  }
  await batch.commit();
}

const remaining = await db.collection('incidents').get();
console.log(`Project: ${projectId}`);
console.log(`Deleted ${snapshot.size} incident reports.`);
console.log(`Remaining incident reports: ${remaining.size}`);
