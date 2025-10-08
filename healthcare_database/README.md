# Healthcare Database (MongoDB)

This container stores user accounts, patient profiles, doctors, consultations, and medical records for the Healthcare Connect application.

Contents:
- schema/ — JSON-like schema definitions to guide backend validation
- indexes/ — Index specifications (including unique and compound indexes)
- seeds/ — Node.js seed script to populate sample data
- .env.example — Environment variables required by the seed script

## Collections

- users
- patients
- doctors
- consultations
- medical_records

See the `schema/*.json` files for field shapes, types, and required fields designed for backend validation and optional MongoDB collection validators.

## Indexes

Index definitions are provided in `indexes/indexes.json`. Key indexes:
- users: unique index on email
- doctors: index on specialty
- consultations: compound index on (patient_id, datetime desc)
- medical_records: compound index on (patient_id, created_at desc)

Example commands to create these indexes with mongosh:

```sh
# Ensure you have MONGODB_URI and DB_NAME environment variables set (or replace in the commands below)
mongosh "$MONGODB_URI/$DB_NAME" --eval 'db.users.createIndex({email:1},{unique:true,name:"uniq_users_email"})'
mongosh "$MONGODB_URI/$DB_NAME" --eval 'db.doctors.createIndex({specialty:1},{name:"idx_doctors_specialty"})'
mongosh "$MONGODB_URI/$DB_NAME" --eval 'db.consultations.createIndex({patient_id:1, datetime:-1},{name:"idx_consultations_patient_datetime"})'
mongosh "$MONGODB_URI/$DB_NAME" --eval 'db.medical_records.createIndex({patient_id:1, created_at:-1},{name:"idx_medical_records_patient_created"})'
```

Note: The backend may also programmatically ensure indexes on startup.

## Seeding Data

The seed script inserts:
- A demo patient user + patient profile
- Two doctor users + doctor profiles

Default demo accounts:
- patient.demo@example.com
- dr.smith@example.com
- dr.lee@example.com

A precomputed bcrypt-like password hash string is stored; update hashes to align with your backend’s authentication if needed.

### Option A: Seed via Node.js

Requirements:
- Node.js and npm
- MongoDB reachable at `MONGODB_URI`

Steps:
1. Copy `.env.example` to `.env` and set values:
   ```
   cp healthcare_database/.env.example healthcare_database/.env
   ```
   Edit `healthcare_database/.env` to include:
   ```
   MONGODB_URI=mongodb://localhost:27017
   DB_NAME=healthcare_connect_dev
   ```
2. Install dependencies:
   ```
   cd healthcare_database
   npm init -y
   npm install mongodb dotenv
   ```
3. Run the seed script:
   ```
   node seeds/seed.js
   ```

The script is idempotent and can be run multiple times.

### Option B: Seed via mongosh (quick manual insert)

Alternatively, insert minimal seed data using mongosh:

```sh
# Users (patient + 2 doctors)
mongosh "$MONGODB_URI/$DB_NAME" --eval '
const now=new Date();
db.users.updateOne({email:"patient.demo@example.com"},{$setOnInsert:{email:"patient.demo@example.com",password_hash:"$2b$12$C6UzMDM.H6dfI/f/IKcEe.O9rJtr1cGukdxbYF9bBlt3F4iAfD7Ou",role:"patient",status:"active",created_at:now},$set:{updated_at:now}},{upsert:true});
db.users.updateOne({email:"dr.smith@example.com"},{$setOnInsert:{email:"dr.smith@example.com",password_hash:"$2b$12$C6UzMDM.H6dfI/f/IKcEe.O9rJtr1cGukdxbYF9bBlt3F4iAfD7Ou",role:"doctor",status:"active",created_at:now},$set:{updated_at:now}},{upsert:true});
db.users.updateOne({email:"dr.lee@example.com"},{$setOnInsert:{email:"dr.lee@example.com",password_hash:"$2b$12$C6UzMDM.H6dfI/f/IKcEe.O9rJtr1cGukdxbYF9bBlt3F4iAfD7Ou",role:"doctor",status:"active",created_at:now},$set:{updated_at:now}},{upsert:true});
const patientUser=db.users.findOne({email:"patient.demo@example.com"});
const drSmith=db.users.findOne({email:"dr.smith@example.com"});
const drLee=db.users.findOne({email:"dr.lee@example.com"});

db.patients.updateOne({user_id:patientUser._id},{
  $setOnInsert:{
    user_id:patientUser._id,first_name:"Alex",last_name:"Johnson",date_of_birth:new Date("1990-01-15"),gender:"other",
    phone:"+1-555-0100",
    address:{line1:"123 Main St",line2:"Unit 4B",city:"Springfield",state:"IL",postal_code:"62701",country:"USA"},
    emergency_contact:{name:"Taylor Johnson",phone:"+1-555-0101",relationship:"Sibling"},
    insurance:{provider:"Acme Health",member_id:"ACM123456",group_number:"GRP-42"},
    created_at:now
  },
  $set:{updated_at:now}
},{upsert:true});

db.doctors.updateOne({user_id:drSmith._id},{
  $setOnInsert:{
    user_id:drSmith._id,first_name:"Jordan",last_name:"Smith",specialty:"Cardiology",bio:"Board-certified cardiologist with a focus on preventative care.",years_of_experience:12,languages:["English","Spanish"],created_at:now
  },
  $set:{updated_at:now}
},{upsert:true});

db.doctors.updateOne({user_id:drLee._id},{
  $setOnInsert:{
    user_id:drLee._id,first_name:"Morgan",last_name:"Lee",specialty:"Pediatrics",bio:"Pediatrician dedicated to child wellness and family-centered care.",years_of_experience:8,languages:["English","Mandarin"],created_at:now
  },
  $set:{updated_at:now}
},{upsert:true});
'
```

## Environment Variables

Create `healthcare_database/.env` (start with `.env.example`):
- MONGODB_URI — Mongo connection string
- DB_NAME — Database name to use

Never commit real secrets to version control.

## Notes

- These schemas are provided to inform backend validation. You may optionally apply them as collection validators when creating collections.
- Indexes should be created before heavy usage to enforce uniqueness and query performance.
- The seed script is safe to run multiple times; it will not duplicate users or profiles.
