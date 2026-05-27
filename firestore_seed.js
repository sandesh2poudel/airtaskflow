// firestore_seed.js
// ═══════════════════════════════════════════════════════════════════════════
//  RUN THIS ONCE to seed initial users into Firestore
//  Node.js script using Firebase Admin SDK
//
//  STEP 1: npm install firebase-admin
//  STEP 2: Download serviceAccountKey.json from Firebase Console
//           → Project Settings → Service Accounts → Generate new private key
//  STEP 3: node firestore_seed.js
// ═══════════════════════════════════════════════════════════════════════════

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // put your key here

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const initialUsers = [
  {
    name: 'Super Admin',
    username: 'admin',
    password: 'admin123',   // ← CHANGE THIS after first login
    role: 'superadmin',
    team: '',
  },
  {
    name: 'Sales Person One',
    username: 'sales1',
    password: 'sales123',
    role: 'sales',
    team: 'Red',
  },
  {
    name: 'Sales Person Two',
    username: 'sales2',
    password: 'sales123',
    role: 'sales',
    team: 'Yellow',
  },
  {
    name: 'Team Leader Red',
    username: 'leader1',
    password: 'lead123',
    role: 'teamleader',
    team: 'Red',
  },
  {
    name: 'Team Leader Yellow',
    username: 'leader2',
    password: 'lead123',
    role: 'teamleader',
    team: 'Yellow',
  },
  {
    name: 'Writer One',
    username: 'writer1',
    password: 'write123',
    role: 'writer',
    team: '',
  },
  {
    name: 'Writer Two',
    username: 'writer2',
    password: 'write123',
    role: 'writer',
    team: '',
  },
];

async function seed() {
  console.log('🌱 Seeding Firestore users...\n');

  for (const user of initialUsers) {
    // Check if username already exists
    const existing = await db.collection('users')
      .where('username', '==', user.username)
      .get();

    if (!existing.empty) {
      console.log(`⚠️  Skipped (already exists): ${user.username}`);
      continue;
    }

    const ref = await db.collection('users').add(user);
    console.log(`✅ Created: ${user.name} (${user.username}) → ID: ${ref.id}`);
  }

  console.log('\n🎉 Seed complete!');
  console.log('\nDefault logins:');
  console.log('  admin    / admin123   → Super Admin');
  console.log('  sales1   / sales123   → Sales (Red Team)');
  console.log('  sales2   / sales123   → Sales (Yellow Team)');
  console.log('  leader1  / lead123    → Team Leader (Red)');
  console.log('  leader2  / lead123    → Team Leader (Yellow)');
  console.log('  writer1  / write123   → Writer');
  console.log('  writer2  / write123   → Writer');
  console.log('\n⚠️  IMPORTANT: Change all passwords after first login from Admin dashboard!');

  process.exit(0);
}

seed().catch(err => {
  console.error('❌ Seed error:', err);
  process.exit(1);
});
