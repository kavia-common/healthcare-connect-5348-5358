'use strict';

/**
 * Seed script for healthcare database.
 * - Reads MONGODB_URI and DB_NAME from .env (placed in healthcare_database directory)
 * - Inserts:
 *    * 1 demo patient user + patient profile
 *    * 2 sample doctor users + doctor profiles
 * - Designed to be idempotent (re-runnable without duplicating documents)
 *
 * Dependencies (install before running):
 *   npm install mongodb dotenv
 */

const path = require('path');
const { MongoClient } = require('mongodb');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

/**
 * Utility to ensure required env vars exist.
 * Throws a descriptive error if missing.
 */
function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}. Please set it in healthcare_database/.env`);
  }
  return value;
}

/**
 * Returns a timestamp object to keep created/updated fields consistent.
 */
function now() {
  return new Date();
}

/**
 * Upserts a user by email (lowercased).
 * @param {import('mongodb').Db} db
 * @param {{ email:string, password_hash:string, role:'patient'|'doctor'|'admin', status?:string }} user
 * @returns {Promise<import('mongodb').ObjectId>} inserted or existing user _id
 */
async function upsertUser(db, user) {
  const users = db.collection('users');
  const email = user.email.toLowerCase().trim();
  const nowTs = now();

  const update = {
    $setOnInsert: {
      email,
      password_hash: user.password_hash,
      role: user.role,
      status: user.status || 'active',
      created_at: nowTs
    },
    $set: {
      updated_at: nowTs
    }
  };

  const result = await users.findOneAndUpdate(
    { email },
    update,
    { upsert: true, returnDocument: 'after' }
  );

  return result.value._id;
}

/**
 * Upserts a patient profile by user_id.
 * @param {import('mongodb').Db} db
 * @param {import('mongodb').ObjectId} userId
 * @param {object} profile
 * @returns {Promise<import('mongodb').ObjectId>}
 */
async function upsertPatient(db, userId, profile) {
  const patients = db.collection('patients');
  const nowTs = now();
  const result = await patients.findOneAndUpdate(
    { user_id: userId },
    {
      $setOnInsert: {
        user_id: userId,
        first_name: profile.first_name,
        last_name: profile.last_name,
        date_of_birth: profile.date_of_birth,
        gender: profile.gender,
        phone: profile.phone || null,
        address: profile.address || null,
        emergency_contact: profile.emergency_contact || null,
        insurance: profile.insurance || null,
        created_at: nowTs
      },
      $set: {
        updated_at: nowTs
      }
    },
    { upsert: true, returnDocument: 'after' }
  );
  return result.value._id;
}

/**
 * Upserts a doctor profile by user_id.
 * @param {import('mongodb').Db} db
 * @param {import('mongodb').ObjectId} userId
 * @param {object} profile
 * @returns {Promise<import('mongodb').ObjectId>}
 */
async function upsertDoctor(db, userId, profile) {
  const doctors = db.collection('doctors');
  const nowTs = now();
  const result = await doctors.findOneAndUpdate(
    { user_id: userId },
    {
      $setOnInsert: {
        user_id: userId,
        first_name: profile.first_name,
        last_name: profile.last_name,
        specialty: profile.specialty,
        bio: profile.bio || null,
        years_of_experience: profile.years_of_experience || 0,
        languages: profile.languages || [],
        created_at: nowTs
      },
      $set: {
        updated_at: nowTs
      }
    },
    { upsert: true, returnDocument: 'after' }
  );
  return result.value._id;
}

(async () => {
  const MONGODB_URI = requireEnv('MONGODB_URI');
  const DB_NAME = requireEnv('DB_NAME');

  const client = new MongoClient(MONGODB_URI, {
    // sensible defaults
    maxPoolSize: 5
  });

  try {
    console.log('Connecting to MongoDB...');
    await client.connect();
    const db = client.db(DB_NAME);
    console.log(`Connected. Using database: ${DB_NAME}`);

    // Precomputed bcrypt hash for the demo password 'Password123!'
    // You may replace this with backend-generated hashes if desired.
    const DEMO_PASSWORD_HASH = '$2b$12$C6UzMDM.H6dfI/f/IKcEe.O9rJtr1cGukdxbYF9bBlt3F4iAfD7Ou';

    // 1) Demo patient user + profile
    const demoPatientEmail = 'patient.demo@example.com';
    const patientUserId = await upsertUser(db, {
      email: demoPatientEmail,
      password_hash: DEMO_PASSWORD_HASH,
      role: 'patient',
      status: 'active'
    });

    await upsertPatient(db, patientUserId, {
      first_name: 'Alex',
      last_name: 'Johnson',
      date_of_birth: new Date('1990-01-15'),
      gender: 'other',
      phone: '+1-555-0100',
      address: {
        line1: '123 Main St',
        line2: 'Unit 4B',
        city: 'Springfield',
        state: 'IL',
        postal_code: '62701',
        country: 'USA'
      },
      emergency_contact: {
        name: 'Taylor Johnson',
        phone: '+1-555-0101',
        relationship: 'Sibling'
      },
      insurance: {
        provider: 'Acme Health',
        member_id: 'ACM123456',
        group_number: 'GRP-42'
      }
    });
    console.log(`Ensured demo patient user (${demoPatientEmail}) and profile.`);

    // 2) Sample doctor #1
    const doctor1Email = 'dr.smith@example.com';
    const doctor1UserId = await upsertUser(db, {
      email: doctor1Email,
      password_hash: DEMO_PASSWORD_HASH,
      role: 'doctor',
      status: 'active'
    });

    await upsertDoctor(db, doctor1UserId, {
      first_name: 'Jordan',
      last_name: 'Smith',
      specialty: 'Cardiology',
      bio: 'Board-certified cardiologist with a focus on preventative care.',
      years_of_experience: 12,
      languages: ['English', 'Spanish']
    });
    console.log(`Ensured doctor profile for (${doctor1Email}).`);

    // 3) Sample doctor #2
    const doctor2Email = 'dr.lee@example.com';
    const doctor2UserId = await upsertUser(db, {
      email: doctor2Email,
      password_hash: DEMO_PASSWORD_HASH,
      role: 'doctor',
      status: 'active'
    });

    await upsertDoctor(db, doctor2UserId, {
      first_name: 'Morgan',
      last_name: 'Lee',
      specialty: 'Pediatrics',
      bio: 'Pediatrician dedicated to child wellness and family-centered care.',
      years_of_experience: 8,
      languages: ['English', 'Mandarin']
    });
    console.log(`Ensured doctor profile for (${doctor2Email}).`);

    console.log('Seeding complete ✅');
  } catch (err) {
    console.error('Seeding failed ❌');
    console.error(err);
    process.exitCode = 1;
  } finally {
    await client.close();
    console.log('MongoDB connection closed.');
  }
})();
