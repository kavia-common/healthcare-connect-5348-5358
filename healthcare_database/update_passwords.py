#!/usr/bin/env python3
"""
Update seed user passwords with proper bcrypt hashes.
This ensures demo credentials work with the backend authentication.
"""

import sys
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Demo password for all users
DEMO_PASSWORD = "demo123"

# Generate hash
password_hash = pwd_context.hash(DEMO_PASSWORD)

print("Generated bcrypt hash for password 'demo123':")
print(password_hash)
print()
print("MongoDB update commands:")
print("-" * 70)

# Update commands for each demo user
users = [
    "jane.patient@example.com",
    "john.patient@example.com",
    "dr.smith@example.com",
    "dr.lee@example.com"
]

for email in users:
    print(f'db.users.updateOne({{email: "{email}"}}, {{$set: {{password_hash: "{password_hash}"}}}});')

print()
print("To apply these updates, run:")
print('mongosh "mongodb://appuser:dbuser123@localhost:5000/myapp?authSource=admin"')
print("Then paste the update commands above.")
