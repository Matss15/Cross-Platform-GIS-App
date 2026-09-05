import { readFile } from 'node:fs/promises';
import process from 'node:process';

import admin from 'firebase-admin';

export async function initializeAdminTool() {
  const serviceAccountPath =
    process.argv[2] || process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (!serviceAccountPath) {
    throw new Error(
      'Missing service account key. Pass its JSON path as the first argument or set GOOGLE_APPLICATION_CREDENTIALS.',
    );
  }

  const serviceAccount = JSON.parse(
    await readFile(serviceAccountPath, { encoding: 'utf8' }),
  );

  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  return {
    admin,
    auth: admin.auth(),
    db: admin.firestore(),
    now: admin.firestore.FieldValue.serverTimestamp(),
    projectId: serviceAccount.project_id,
  };
}

export function loadSuperAdminConfig() {
  const password = process.env.BFP_SUPER_ADMIN_PASSWORD;

  if (!password || password.length < 8) {
    throw new Error(
      'Set BFP_SUPER_ADMIN_PASSWORD to a private password with at least 8 characters.',
    );
  }

  return {
    uid: 'akoangadmin_super_admin',
    email: (process.env.BFP_SUPER_ADMIN_EMAIL || 'akoangadmin@gmail.com')
      .trim()
      .toLowerCase(),
    password,
    displayName: 'System Administrator',
  };
}

export function accountEmailLookupId(email) {
  return Buffer.from(email.trim().toLowerCase(), 'utf8').toString('base64url');
}
