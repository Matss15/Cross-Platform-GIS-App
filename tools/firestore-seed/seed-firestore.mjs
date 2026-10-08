import {
  accountEmailLookupId,
  initializeAdminTool,
  loadSuperAdminConfig,
} from './lib/tool-config.mjs';

const { admin, db, now, projectId } = await initializeAdminTool();
const superAdmin = loadSuperAdminConfig();

const legacyAccountUids = {
  admin: '4jWlzxcsebZgJ8pjsU9ITKxnsmo2',
  bfp: 'x2VNSjsjkPNSmcCg4vBhxA6xmz52',
  barangay: 'kkjNs0XLcROYJ6oXQbwJku3RgCV2',
  citizen: 'VN6maPw1TQPc5OrJFKp6CIEetKq1',
};

const uids = {
  admin: 'akoangadmin_super_admin',
  bfp: legacyAccountUids.bfp,
  barangay: legacyAccountUids.barangay,
  citizen: legacyAccountUids.citizen,
};

const superAdminEmail = superAdmin.email;
const superAdminPassword = superAdmin.password;

const legacyAccountEmails = [
  'admin.rosario@gmail.com',
  'bfp.rosario@gmail.com',
  'barangay.rosario@gmail.com',
  'citizen.rosario@gmail.com',
];

const barangayNames = [
  'Alupay',
  'Antipolo',
  'Bagong Pook',
  'Balibago',
  'Bayawang',
  'Baybayin',
  'Bulihan',
  'Cahigam',
  'Calantas',
  'Colnelis',
  'Dagatan',
  'Itlugan',
  'Macalamcam A',
  'Macalamcam B',
  'Malaya',
  'Maligaya',
  'Marilag',
  'Masaya',
  'Matamis',
  'Mavalor',
  'Mayuro',
  'Namuco',
  'Namunga',
  'Natu',
  'Palakpak',
  'Pinagsibaan',
  'Putingkahoy',
  'Quilib',
  'Salao',
  'San Alejandro',
  'San Carlos',
  'San Isidro',
  'San Jose',
  'San Juan',
  'San Roque',
  'Santa Cruz',
  'Santiago',
  'Timbugan',
  'Tiquiwan',
  'Tulos',
  'Poblacion A',
  'Poblacion B',
  'Poblacion C',
  'Poblacion D',
  'Poblacion E',
  'Poblacion F',
  'Poblacion G',
  'Poblacion H',
];

// Same ids as the app: these two were first saved without a space.
const legacyBarangayIds = {
  bagong_pook: 'bagongpook',
  macalamcam_b: 'macalamcamb',
};

const barangayIdFor = (name) => {
  const id = name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
  return legacyBarangayIds[id] ?? id;
};

const withTimestamps = (data) => ({
  ...data,
  createdAt: now,
  updatedAt: now,
});

const seededBarangays = Object.fromEntries(
  barangayNames.map((name) => {
    const id = barangayIdFor(name);
    return [
      id,
      withTimestamps({
        id,
        name,
        municipality: 'Rosario',
        province: 'Batangas',
        psgcCode: '',
        correspondenceCode: '',
        classification: '',
        population: 0,
        captain: '',
        contactPerson: '',
        phone: '',
        riskLevel: 'Unassigned',
        latitude: 13.845,
        longitude: 121.2,
        activeIncidents: 0,
      }),
    ];
  }),
);

seededBarangays.baybayin.riskLevel = 'Critical';
seededBarangays.baybayin.activeIncidents = 1;
seededBarangays.itlugan.riskLevel = 'Medium';
seededBarangays.itlugan.activeIncidents = 1;
seededBarangays.poblacion_a.riskLevel = 'High';
seededBarangays.poblacion_a.activeIncidents = 1;

const collections = {
  users: {
    [uids.admin]: withTimestamps({
      uid: uids.admin,
      fullName: 'System Administrator',
      email: superAdminEmail,
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
    }),
  },
  account_email_index: {
    [accountEmailLookupId(superAdminEmail)]: {
      uid: uids.admin,
      email: superAdminEmail,
      fullName: 'System Administrator',
      role: 'admin',
      adminLevel: 'super',
      updatedAt: now,
    },
  },
  barangays: seededBarangays,
  responders: {
    engine_01_team: withTimestamps({
      id: 'engine_01_team',
      name: 'Engine 01 Team',
      leader: 'FO2 Mark Reyes',
      phone: '09172201001',
      role: 'Fire Suppression',
      status: 'Dispatched',
      station: 'Rosario Fire Station',
      currentIncidentId: 'incident_baybayin_smoke',
      latitude: 13.8483,
      longitude: 121.2036,
    }),
    rescue_02_team: withTimestamps({
      id: 'rescue_02_team',
      name: 'Rescue 02 Team',
      leader: 'FO1 Ana Bautista',
      phone: '09172201002',
      role: 'Rescue and Medical',
      status: 'Available',
      station: 'Rosario Fire Station',
      currentIncidentId: '',
      latitude: 13.845,
      longitude: 121.2,
    }),
    investigation_03: withTimestamps({
      id: 'investigation_03',
      name: 'Investigation 03',
      leader: 'SFO1 Carlo Navarro',
      phone: '09172201003',
      role: 'Fire Investigation',
      status: 'Monitoring',
      station: 'Rosario Fire Station',
      currentIncidentId: 'incident_itlugan_grass',
      latitude: 13.8328,
      longitude: 121.1785,
    }),
  },
  fire_trucks: {
    engine_01: withTimestamps({
      id: 'engine_01',
      name: 'Engine 01',
      plateNumber: 'BFP-ROS-001',
      type: 'Fire Engine',
      capacityLiters: 4000,
      status: 'Dispatched',
      assignedResponderId: 'engine_01_team',
      latitude: 13.8483,
      longitude: 121.2036,
    }),
    rescue_02: withTimestamps({
      id: 'rescue_02',
      name: 'Rescue 02',
      plateNumber: 'BFP-ROS-002',
      type: 'Rescue Vehicle',
      capacityLiters: 0,
      status: 'Available',
      assignedResponderId: 'rescue_02_team',
      latitude: 13.845,
      longitude: 121.2,
    }),
  },
  incidents: {
    incident_baybayin_smoke: withTimestamps({
      id: 'incident_baybayin_smoke',
      uid: uids.citizen,
      reporterId: uids.citizen,
      reporterName: 'Juan Dela Cruz',
      phone: '09171000001',
      address: 'Baybayin Road, Rosario, Batangas',
      barangayId: 'baybayin',
      barangayName: 'Baybayin',
      type: 'Residential smoke report',
      description: 'Thick smoke reported behind a residential compound.',
      priority: 'Critical',
      status: 'Verified',
      assignedTo: 'Engine 01 Team',
      assignedResponder: 'engine_01_team',
      latitude: 13.8497,
      longitude: 121.2048,
      verifiedBy: uids.barangay,
      verifiedAt: now,
    }),
    incident_poblacion_market: withTimestamps({
      id: 'incident_poblacion_market',
      uid: uids.citizen,
      reporterId: uids.citizen,
      reporterName: 'Ana Mercado',
      phone: '09171000011',
      address: 'Poblacion A Market, Rosario, Batangas',
      barangayId: 'poblacion_a',
      barangayName: 'Poblacion A',
      type: 'Electrical spark near market',
      description: 'Sparks seen from a power line beside the market.',
      priority: 'High',
      status: 'Pending',
      assignedTo: '',
      assignedResponder: '',
      latitude: 13.8462,
      longitude: 121.2062,
      verifiedBy: '',
    }),
    incident_itlugan_grass: withTimestamps({
      id: 'incident_itlugan_grass',
      uid: uids.citizen,
      reporterId: uids.citizen,
      reporterName: 'Rico Flores',
      phone: '09171000012',
      address: 'Vacant lot, Itlugan, Rosario, Batangas',
      barangayId: 'itlugan',
      barangayName: 'Itlugan',
      type: 'Grass fire',
      description: 'Small grass fire spreading beside a vacant lot.',
      priority: 'Medium',
      status: 'Monitoring',
      assignedTo: 'Investigation 03',
      assignedResponder: 'investigation_03',
      latitude: 13.8328,
      longitude: 121.1785,
      verifiedBy: uids.barangay,
      verifiedAt: now,
    }),
  },
  announcements: {
    fire_prevention_week: withTimestamps({
      id: 'fire_prevention_week',
      title: 'Fire Prevention Reminder',
      message: 'Inspect electrical wiring and keep exits clear in every household.',
      audience: 'all',
      createdBy: uids.admin,
    }),
    barangay_drill: withTimestamps({
      id: 'barangay_drill',
      title: 'Barangay Evacuation Drill',
      message: 'Poblacion evacuation drill is scheduled this weekend.',
      audience: 'barangay',
      createdBy: uids.bfp,
    }),
  },
  notifications: {
    notif_citizen_01: {
      id: 'notif_citizen_01',
      uid: uids.citizen,
      title: 'Report verified',
      body: 'Your Baybayin smoke report has been verified by barangay.',
      read: false,
      createdAt: now,
    },
    notif_bfp_01: {
      id: 'notif_bfp_01',
      uid: uids.bfp,
      title: 'Dispatch assigned',
      body: 'Engine 01 Team assigned to Baybayin smoke report.',
      read: false,
      createdAt: now,
    },
  },
  settings: {
    demo_database: {
      seeded: true,
      seedVersion: 2,
      seededAt: now,
      collections: {
        users: 4,
        barangays: barangayNames.length,
        responders: 3,
        fire_trucks: 2,
        incidents: 3,
        announcements: 2,
        notifications: 2,
      },
    },
  },
};

const authUsers = [
  {
    uid: uids.admin,
    email: superAdminEmail,
    password: superAdminPassword,
    displayName: 'System Administrator',
  },
];

async function upsertAuthUser(user) {
  try {
    await admin.auth().updateUser(user.uid, {
      email: user.email,
      password: user.password,
      displayName: user.displayName,
      emailVerified: true,
      disabled: false,
    });
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    await admin.auth().createUser({
      uid: user.uid,
      email: user.email,
      password: user.password,
      displayName: user.displayName,
      emailVerified: true,
      disabled: false,
    });
  }
}

for (const user of authUsers) {
  await upsertAuthUser(user);
}

let total = 0;
const batch = db.batch();

for (const [role, uid] of Object.entries(legacyAccountUids)) {
  if (uid !== uids[role]) {
    batch.delete(db.collection('users').doc(uid));
    total += 1;
  }
}

for (const email of legacyAccountEmails) {
  batch.delete(db.collection('account_email_index').doc(accountEmailLookupId(email)));
  total += 1;
}

for (const [collectionName, documents] of Object.entries(collections)) {
  for (const [documentId, data] of Object.entries(documents)) {
    batch.set(db.collection(collectionName).doc(documentId), data, {
      merge: true,
    });
    total += 1;
  }
}

await batch.commit();

console.log(`Applied ${total} Firestore writes.`);
console.log(`Seeded ${authUsers.length} Firebase Auth admin user.`);
console.log(`Admin login email: ${superAdminEmail}`);
console.log('Password was read from BFP_SUPER_ADMIN_PASSWORD and was not printed.');
console.log(`Project: ${projectId}`);
