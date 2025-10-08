# Healthcare Connect Database

MongoDB database for the Healthcare Connect application.

## Overview

This container hosts a MongoDB instance that stores all application data including users, patients, doctors, consultations, and medical records.

## Database Schema

### Collections

#### 1. **users**
Stores authentication and user profile information.

**Fields:**
- `_id` (ObjectId): Unique user identifier
- `email` (string): User email address (unique)
- `hashed_password` (string): Bcrypt hashed password
- `full_name` (string, optional): User's full name
- `role` (string): User role - "patient", "doctor", or "admin"
- `is_active` (boolean): Account status

**Indexes:**
- Unique index on `email`

#### 2. **patients**
Patient profile information.

**Fields:**
- `_id` (ObjectId): Unique patient identifier
- `user_id` (ObjectId): Reference to users collection
- `age` (int, optional): Patient age
- `gender` (string, optional): Patient gender
- `address` (string, optional): Patient address

**Indexes:**
- Index on `user_id`

#### 3. **doctors**
Doctor profile information.

**Fields:**
- `_id` (ObjectId): Unique doctor identifier
- `user_id` (ObjectId): Reference to users collection
- `specialty` (string, optional): Medical specialty
- `bio` (string, optional): Doctor biography

**Indexes:**
- Index on `user_id`

#### 4. **consultations**
Scheduled consultations between patients and doctors.

**Fields:**
- `_id` (ObjectId): Unique consultation identifier
- `patient_id` (ObjectId): Reference to patients collection
- `doctor_id` (ObjectId): Reference to doctors collection
- `scheduled_at` (datetime): Scheduled date and time
- `notes` (string, optional): Consultation notes

**Indexes:**
- Index on `patient_id`
- Index on `doctor_id`
- Index on `scheduled_at`

#### 5. **medical_records**
Medical records for patients.

**Fields:**
- `_id` (ObjectId): Unique record identifier
- `patient_id` (ObjectId): Reference to patients collection
- `entries` (array of strings): Medical record entries

**Indexes:**
- Index on `patient_id`

## Seed Data / Demo Credentials

The database is initialized with the following demo users for testing:

### Admin User
- **Email:** admin@healthcare.com
- **Password:** admin123
- **Role:** admin

### Doctor Users
1. **Dr. Sarah Johnson**
   - **Email:** doctor1@healthcare.com
   - **Password:** doctor123
   - **Specialty:** Cardiology

2. **Dr. Michael Chen**
   - **Email:** doctor2@healthcare.com
   - **Password:** doctor123
   - **Specialty:** Pediatrics

### Patient Users
1. **John Smith**
   - **Email:** patient1@healthcare.com
   - **Password:** patient123
   - **Age:** 35
   - **Gender:** Male

2. **Emma Davis**
   - **Email:** patient2@healthcare.com
   - **Password:** patient123
   - **Age:** 28
   - **Gender:** Female

## Connection Information

### Local Development

**Connection String:** 
```
mongodb://appuser:dbuser123@localhost:5001/myapp?authSource=admin
```

**Database Name:** `myapp`

**Port:** 5001

**Credentials:**
- Username: `appuser`
- Password: `dbuser123`
- Auth Database: `admin`

### Environment Variables

The backend API uses the following environment variables to connect:

```bash
MONGO_URI=mongodb://appuser:dbuser123@localhost:5001/myapp?authSource=admin
MONGO_DB=myapp
```

## Setup Instructions

### Prerequisites
- Docker installed
- MongoDB client tools (optional, for direct access)

### Starting the Database

1. The database is automatically started as part of the docker-compose setup
2. To start manually:
   ```bash
   docker-compose up healthcare_database
   ```

### Accessing the Database

#### Using MongoDB Shell (mongosh)

```bash
mongosh mongodb://appuser:dbuser123@localhost:5001/myapp?authSource=admin
```

#### Using MongoDB Compass

1. Open MongoDB Compass
2. Use connection string: `mongodb://appuser:dbuser123@localhost:5001/myapp?authSource=admin`

### Verifying Setup

Check that collections exist:

```bash
mongosh mongodb://appuser:dbuser123@localhost:5001/myapp?authSource=admin --eval "db.getCollectionNames()"
```

Expected output should include: `users`, `patients`, `doctors`, `consultations`, `medical_records`

## Data Initialization

The database is initialized with:
- Demo users (admin, doctors, patients)
- Sample patient and doctor profiles
- Sample consultations
- Sample medical records

All seed data is created by the backend initialization scripts on first startup.

## Backup and Restore

### Backup Database

```bash
docker exec healthcare_database mongodump --uri="mongodb://appuser:dbuser123@localhost:27017/myapp?authSource=admin" --out=/backup
```

### Restore Database

```bash
docker exec healthcare_database mongorestore --uri="mongodb://appuser:dbuser123@localhost:27017/myapp?authSource=admin" /backup/myapp
```

## Troubleshooting

### Connection Issues

**Problem:** Cannot connect to MongoDB
**Solution:** 
- Ensure the container is running: `docker ps | grep healthcare_database`
- Check that port 5001 is not in use: `lsof -i :5001`
- Verify credentials in the connection string

**Problem:** Authentication failed
**Solution:**
- Ensure you're using `authSource=admin` in the connection string
- Verify username and password: `appuser` / `dbuser123`

### Performance Issues

**Problem:** Slow queries
**Solution:**
- Check indexes are created: `db.collection.getIndexes()`
- Monitor query performance: `db.setProfilingLevel(2)`

### Data Issues

**Problem:** Missing seed data
**Solution:**
- Check if backend initialization ran successfully
- Manually run seed scripts from backend container

## Security Notes

⚠️ **Important:** The credentials in this setup are for development only. 

For production:
1. Use strong, randomly generated passwords
2. Enable MongoDB authentication
3. Use TLS/SSL for connections
4. Implement network security (firewall rules, VPC)
5. Regular security audits and updates
6. Backup strategy with encryption

## Monitoring

### Check Database Status

```bash
mongosh mongodb://appuser:dbuser123@localhost:5001/myapp?authSource=admin --eval "db.serverStatus()"
```

### View Collection Stats

```bash
mongosh mongodb://appuser:dbuser123@localhost:5001/myapp?authSource=admin --eval "db.stats()"
```

### Monitor Connections

```bash
mongosh mongodb://appuser:dbuser123@localhost:5001/myapp?authSource=admin --eval "db.serverStatus().connections"
```
