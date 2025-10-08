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

## Quickstart

1) Configure environment
- Copy `.env.example` to `.env`
- Default local values (aligns with backend config):
  ```
  MONGODB_URI=mongodb://localhost:5001
  DB_NAME=healthcare
  ```

2) Start MongoDB locally (example options)
- Docker example:
  ```
  docker run --name hc-mongo -p 5001:27017 -d mongo:7
  ```
  This exposes MongoDB on local port 5001 to match the rest of the stack.

3) (Optional) Seed data

Option A: Seed via Node.js
- Requirements: Node.js and npm
- Install dependencies:
  ```
  cd healthcare_database
  npm init -y
  npm install mongodb dotenv
  ```
- Run seed:
  ```
  node seeds/seed.js
  ```
  The script is idempotent and can be re-run. Note: The seed uses ObjectIds and some fields that may not perfectly align with the backend’s current models. Prefer using backend endpoints for creating data when possible.

Option B: Seed via mongosh (manual)
- Ensure your `MONGODB_URI` and `DB_NAME` are set in the environment or substitute in the commands
- See previous example commands for creating indexes or inserting minimal data as needed.

## Indexes

Index definitions are provided in `indexes/indexes.json`. Key indexes:
- users: unique index on email
- doctors: index on specialty
- consultations: compound index on (patient_id, datetime desc)
- medical_records: compound index on (patient_id, created_at desc)

The backend API will programmatically ensure indexes on startup by reading `indexes/indexes.json` (path resolved automatically or via `INDEXES_FILE`).

Example commands to create these indexes manually with mongosh (optional):
```sh
mongosh "$MONGODB_URI/$DB_NAME" --eval 'db.users.createIndex({email:1},{unique:true,name:"uniq_users_email"})'
mongosh "$MONGODB_URI/$DB_NAME" --eval 'db.doctors.createIndex({specialty:1},{name:"idx_doctors_specialty"})'
mongosh "$MONGODB_URI/$DB_NAME" --eval 'db.consultations.createIndex({patient_id:1, datetime:-1},{name:"idx_consultations_patient_datetime"})'
mongosh "$MONGODB_URI/$DB_NAME" --eval 'db.medical_records.createIndex({patient_id:1, created_at:-1},{name:"idx_medical_records_patient_created"})'
```

## Environment Variables

Create `healthcare_database/.env` (start with `.env.example`):
- MONGODB_URI — Mongo connection string (ex: `mongodb://localhost:5001`)
- DB_NAME — Database name (ex: `healthcare`)

Never commit real secrets to version control.

## E2E Validation Checklist

- MongoDB is reachable at `mongodb://localhost:5001`
- Database `healthcare` exists (automatically created when first written)
- Backend starts successfully and logs indicate indexes were ensured
- API `/docs` responds and basic flows work (register/login, list doctors, create consultation, list consultations, list records)

## Notes on Schema Alignment

- The seed script demonstrates richer schemas using ObjectIds and additional fields.
- The backend currently uses a simplified approach (e.g., string IDs for some collections like user `_id` = email).
- When in doubt, create data using backend API endpoints so the data shape matches backend expectations.
