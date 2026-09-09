import { initializeAdminTool } from './lib/tool-config.mjs';

const { db, auth, now, projectId } = await initializeAdminTool();
const profiles = {
  '4jwlzxcsebZgJ8pjsU9ITKxnsmo2': {
    role: 'admin',
    fullName: 'Rosario System Admin',
    email: 'admin.rosario@gmail.com',
  },
  'x2VNSjsjkPNSmcCg4vBhxA6xmz52': {
    role: 'bfp',
    fullName: 'BFP Rosario Staff',
    email: 'bfp.rosario@gmail.com',
  },
  'beiMaqVPeVNrGbKNMWP0YejdSW72': {
    role: 'bfp',
    fullName: 'Joshua Collao',
    email: 'bfp.gis.rosario@gmail.com',
  },
  'kkjNs0XLcROYJ6oXQbwJku3RgCV2': {
    role: 'barangay',
    fullName: 'Barangay Staff',
    email: 'barangay.rosario@gmail.com',
  },
  '8nEL4HNoJtO9Wgb5e8FYQht32K73': {
    role: 'barangay',
    fullName: 'Carlo Cuevillas',
    email: 'brgy.rosario@gmail.com',
  },
  'dgvklpNYgMM6JZ7p6eXt4RA0i0O2': {
    role: 'resident',
    fullName: 'DAVE BONG LARRAZABAL',
    email: '23-30723@g.batstate-u.edu.ph',
  },
};

for (const [uid, profile] of Object.entries(profiles)) {
  const user = await auth.getUser(uid);
  await db.collection('users').doc(uid).set(
    {
      uid,
      fullName: profile.fullName || user.displayName || 'BFP Rosario User',
      email: profile.email || user.email || '',
      phone: '',
      address: 'Rosario, Batangas',
      role: profile.role,
      barangayId: 'poblacion_a',
      barangayName: 'Poblacion A',
      profileImage: '',
      isVerified: profile.role === 'resident' ? false : true,
      verificationStatus: profile.role === 'resident' ? 'pending' : 'approved',
      createdAt: now,
      updatedAt: now,
    },
    { merge: true },
  );
}

console.log(`Restored ${Object.keys(profiles).length} role profiles in ${projectId}.`);
