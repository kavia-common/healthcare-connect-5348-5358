////////////////////////////////////////////////////////////////////////////////
// MongoDB Seed Script: Demo Users, Patients, Doctors, Consultations, Records
//
// Purpose:
// - Inserts demo data for previewing the application.
// - Non-destructive: uses upsert with $setOnInsert so existing data is not modified.
// - Creates user accounts with roles patient/doctor and their linked profiles.
// - Adds sample consultations and medical records referencing seeded users.
//
// How to run (recommended):
// 1) From repository root or container working dir: source the Mongo env file
//    source healthcare-connect-5348-5358/healthcare_database/db_visualizer/mongodb.env
//
// 2) Execute the seed script with mongosh using the URL from the env and pass DB name explicitly:
//    mongosh "$MONGODB_URL" --eval "var DB_NAME='${MONGODB_DB}'" healthcare-connect-5348-5358/healthcare_database/seed_mongo.js
//
// Notes:
// - If DB_NAME is not provided, the script will fallback to process.env.MONGODB_DB or default to "myapp".
// - Default credentials may be provisioned by startup.sh (see db_connection.txt or mongodb.env).
//
// Alternative (using db_connection.txt):
// - This file contains a ready-to-run mongosh command with a full connection string (including DB).
//   You can run the following from healthcare_database directory:
//     $(cat db_connection.txt) --eval "var DB_NAME='myapp'" seed_mongo.js
//   If the connection string already includes the DB name, DB_NAME is optional.
//   The script will auto-detect from env or default to "myapp" if not set.
//
////////////////////////////////////////////////////////////////////////////////

(function() {
  // Resolve target database name with fallbacks
  const resolvedDbName =
    (typeof DB_NAME !== 'undefined' && DB_NAME) ||
    ((typeof process !== 'undefined' && process.env && process.env.MONGODB_DB) ? process.env.MONGODB_DB : null) ||
    'myapp';

  // Get a handle to the target database without changing the existing connection
  const targetDb = db.getSiblingDB(resolvedDbName);

  // Utility: current timestamp
  function now() {
    return new Date();
  }

  // State tracking for summary
  const summary = {
    users: { inserted: 0, skipped: 0 },
    patients: { inserted: 0, skipped: 0 },
    doctors: { inserted: 0, skipped: 0 },
    consultations: { inserted: 0, skipped: 0 },
    medical_records: { inserted: 0, skipped: 0 }
  };

  // Helper to upsert a user by email
  function upsertUser(email, password_hash, role) {
    // Only set data on insert to be non-destructive if the user already exists
    const res = targetDb.users.updateOne(
      { email },
      {
        $setOnInsert: {
          email,
          password_hash,
          role,
          created_at: now()
        }
      },
      { upsert: true }
    );

    const inserted = res.upsertedCount === 1 || !!res.upsertedId;
    if (inserted) summary.users.inserted += 1;
    else summary.users.skipped += 1;

    // Fetch the user document to retrieve _id for linking
    const userDoc = targetDb.users.findOne({ email });
    return { inserted, user: userDoc };
  }

  // Helper to upsert a patient profile by user_id (unique)
  function upsertPatientProfile(user_id, profile) {
    const base = {
      user_id,
      created_at: now(),
      updated_at: now()
    };

    const res = targetDb.patients.updateOne(
      { user_id },
      {
        // Do not change existing docs; insert only if missing
        $setOnInsert: Object.assign({}, base, profile)
      },
      { upsert: true }
    );

    const inserted = res.upsertedCount === 1 || !!res.upsertedId;
    if (inserted) summary.patients.inserted += 1;
    else summary.patients.skipped += 1;

    return inserted;
  }

  // Helper to upsert a doctor profile by user_id (unique)
  function upsertDoctorProfile(user_id, profile) {
    const base = {
      user_id,
      created_at: now(),
      updated_at: now()
    };

    const res = targetDb.doctors.updateOne(
      { user_id },
      {
        // Do not change existing docs; insert only if missing
        $setOnInsert: Object.assign({}, base, profile)
      },
      { upsert: true }
    );

    const inserted = res.upsertedCount === 1 || !!res.upsertedId;
    if (inserted) summary.doctors.inserted += 1;
    else summary.doctors.skipped += 1;

    return inserted;
  }

  // Helper to upsert a consultation (idempotent on patient_id+doctor_id+scheduled_at)
  function upsertConsultation(patient_id, doctor_id, scheduled_at, docExtras) {
    const filter = { patient_id, doctor_id, scheduled_at };
    const base = {
      patient_id, doctor_id, scheduled_at,
      status: 'scheduled',
      created_at: now(),
      updated_at: now()
    };
    const payload = Object.assign({}, base, docExtras || {});
    const res = targetDb.consultations.updateOne(
      filter,
      { $setOnInsert: payload },
      { upsert: true }
    );
    const inserted = res.upsertedCount === 1 || !!res.upsertedId;
    if (inserted) summary.consultations.inserted += 1;
    else summary.consultations.skipped += 1;
    return inserted;
  }

  // Helper to upsert a medical record (idempotent on patient_id+title)
  function upsertMedicalRecord(patient_id, title, docExtras) {
    const filter = { patient_id, title };
    const base = {
      patient_id,
      title,
      created_at: now(),
      updated_at: now()
    };
    const payload = Object.assign({}, base, docExtras || {});
    const res = targetDb.medical_records.updateOne(
      filter,
      { $setOnInsert: payload },
      { upsert: true }
    );
    const inserted = res.upsertedCount === 1 || !!res.upsertedId;
    if (inserted) summary.medical_records.inserted += 1;
    else summary.medical_records.skipped += 1;
    return inserted;
  }

  // Demo data
  // Note: password_hash values below are placeholder bcrypt-like hashes (length >= 60) for demo purposes only.
  const DEMO_PASSWORD_HASH = "$2b$12$abcdefghijklmnopqrstuv12345678901234567890123456789012"; // demo only

  const demoUsers = [
    // Patients
    {
      email: "jane.patient@example.com",
      role: "patient",
      password_hash: DEMO_PASSWORD_HASH,
      patientProfile: {
        full_name: "Jane Doe",
        dob: new Date("1990-05-12"),
        gender: "female",
        contact_info: {
          phone: "+1-555-0101",
          email: "jane.patient@example.com",
          address: "100 Health St, Wellness City"
        },
        medical_history: ["asthma"]
      }
    },
    {
      email: "john.patient@example.com",
      role: "patient",
      password_hash: DEMO_PASSWORD_HASH,
      patientProfile: {
        full_name: "John Smith",
        dob: new Date("1985-09-22"),
        gender: "male",
        contact_info: {
          phone: "+1-555-0102",
          email: "john.patient@example.com",
          address: "200 Harmony Ave, Caretown"
        },
        medical_history: ["hypertension"]
      }
    },

    // Doctors
    {
      email: "dr.smith@example.com",
      role: "doctor",
      password_hash: DEMO_PASSWORD_HASH,
      doctorProfile: {
        full_name: "Dr. Alice Smith",
        specialization: "Cardiology",
        license_no: "DOC-1001",
        availability: [
          { day: "mon", slots: [{ start: "09:00", end: "12:00" }, { start: "14:00", end: "17:00" }] },
          { day: "wed", slots: [{ start: "09:00", end: "12:00" }] },
          { day: "fri", slots: [{ start: "10:00", end: "13:00" }] }
        ]
      }
    },
    {
      email: "dr.lee@example.com",
      role: "doctor",
      password_hash: DEMO_PASSWORD_HASH,
      doctorProfile: {
        full_name: "Dr. Brian Lee",
        specialization: "Dermatology",
        license_no: "DOC-1002",
        availability: [
          { day: "tue", slots: [{ start: "11:00", end: "15:00" }] },
          { day: "thu", slots: [{ start: "09:30", end: "12:30" }, { start: "13:30", end: "16:30" }] }
        ]
      }
    }
  ];

  print(`Seeding MongoDB database: ${resolvedDbName}`);
  print(`Using non-destructive upserts (skip if exists)...`);

  // Execute seeding for users and linked profiles
  demoUsers.forEach((entry) => {
    const { email, password_hash, role } = entry;
    const { user } = upsertUser(email, password_hash, role);

    if (!user || !user._id) {
      print(`⚠ Failed to resolve user _id for ${email}, skipping profile creation.`);
      return;
    }

    // Link patient/doctor profile
    if (role === "patient" && entry.patientProfile) {
      upsertPatientProfile(user._id, entry.patientProfile);
    } else if (role === "doctor" && entry.doctorProfile) {
      // Ensure license_no is part of insert payload
      const profile = Object.assign({}, entry.doctorProfile);
      upsertDoctorProfile(user._id, profile);
    }
  });

  // Resolve patient and doctor documents by user email to create cross-linked data
  function userIdByEmail(email) {
    const u = targetDb.users.findOne({ email });
    return u ? u._id : null;
  }
  function patientByUserEmail(email) {
    const uid = userIdByEmail(email);
    return uid ? targetDb.patients.findOne({ user_id: uid }) : null;
  }
  function doctorByUserEmail(email) {
    const uid = userIdByEmail(email);
    return uid ? targetDb.doctors.findOne({ user_id: uid }) : null;
  }

  const janePatient = patientByUserEmail("jane.patient@example.com");
  const johnPatient = patientByUserEmail("john.patient@example.com");
  const drAlice = doctorByUserEmail("dr.smith@example.com");
  const drBrian = doctorByUserEmail("dr.lee@example.com");

  // Seed sample consultations (1-2 at least) - idempotent via (patient_id, doctor_id, scheduled_at)
  if (janePatient && drAlice) {
    upsertConsultation(
      janePatient._id,
      drAlice._id,
      new Date("2025-01-10T10:00:00Z"),
      {
        status: "scheduled",
        notes: "Initial cardiology consultation.",
        prescriptions: []
      }
    );
  }
  if (johnPatient && drBrian) {
    upsertConsultation(
      johnPatient._id,
      drBrian._id,
      new Date("2025-01-11T14:30:00Z"),
      {
        status: "completed",
        notes: "Follow-up visit for skin rash; condition improved.",
        prescriptions: [
          { name: "Hydrocortisone cream", dosage: "apply twice daily", instructions: "External use only" }
        ],
        updated_at: now()
      }
    );
  }

  // Seed sample medical records (1-2 at least) - idempotent via (patient_id, title)
  if (janePatient) {
    upsertMedicalRecord(
      janePatient._id,
      "Annual Checkup Summary 2024",
      {
        description: "General annual checkup results with lifestyle recommendations.",
        attachments: [
          { name: "checkup_summary.pdf", url: "/files/checkup_summary_2024.pdf", type: "application/pdf", size: 58231 }
        ]
      }
    );
  }
  if (johnPatient) {
    upsertMedicalRecord(
      johnPatient._id,
      "Blood Test Results - Dec 2024",
      {
        description: "CBC and lipid panel results; mild LDL elevation.",
        attachments: [
          { name: "blood_tests_dec_2024.pdf", url: "/files/blood_tests_dec_2024.pdf", type: "application/pdf", size: 73420 }
        ]
      }
    );
  }

  // Print summary
  print("\nSeed Summary:");
  print(`- users: inserted=${summary.users.inserted}, skipped=${summary.users.skipped}`);
  print(`- patients: inserted=${summary.patients.inserted}, skipped=${summary.patients.skipped}`);
  print(`- doctors: inserted=${summary.doctors.inserted}, skipped=${summary.doctors.skipped}`);
  print(`- consultations: inserted=${summary.consultations.inserted}, skipped=${summary.consultations.skipped}`);
  print(`- medical_records: inserted=${summary.medical_records.inserted}, skipped=${summary.medical_records.skipped}`);
  print("\nDone.");
})();
