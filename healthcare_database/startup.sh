#!/bin/bash

# MongoDB startup script aligned for previews (binds 0.0.0.0 on port 5001)
DB_NAME="myapp"
DB_USER="appuser"
DB_PASSWORD="dbuser123"
DB_PORT="5001"  # previews expect 5001

echo "Starting MongoDB setup (port ${DB_PORT})..."

# Ensure data and log directories exist with correct permissions
sudo mkdir -p /var/lib/mongodb /var/run/mongodb
sudo chown -R "$(whoami)":"$(whoami)" /var/lib/mongodb /var/run/mongodb 2>/dev/null || true
sudo chmod 700 /var/lib/mongodb 2>/dev/null || true

# If already running and responding on desired port, print info and exit
if mongosh --port ${DB_PORT} --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo "MongoDB is already running on port ${DB_PORT}!"
    if mongosh "mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}?authSource=admin" --eval "db.getName()" > /dev/null 2>&1; then
        echo "Database ${DB_NAME} is accessible with user ${DB_USER}."
    else
        echo "MongoDB is running but authentication might not be configured."
    fi
    echo ""
    echo "Database: ${DB_NAME}"
    echo "Admin user: ${DB_USER} (password: ${DB_PASSWORD})"
    echo "App user: appuser (password: ${DB_PASSWORD})"
    echo "Port: ${DB_PORT}"
    echo ""
    echo "To connect to the database, use:"
    echo "mongosh mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}?authSource=admin"
    echo "Script stopped - server already running."
    # Keep connection files in sync
    echo "mongosh mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}?authSource=admin" > db_connection.txt
    cat > db_visualizer/mongodb.env << EOF
export MONGODB_URL="mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/?authSource=admin"
export MONGODB_DB="${DB_NAME}"
EOF
    exit 0
fi

# If MongoDB is running but on a different port, stop it (best effort)
if pgrep -x mongod > /dev/null; then
    echo "mongod process detected; attempting to stop to free port ${DB_PORT}..."
    sudo pkill -x mongod || true
    sleep 2
fi

# Clean up any existing socket files
sudo rm -f /tmp/mongodb-*.sock 2>/dev/null || true

# Create a minimal mongod.conf for consistent startup
cat > mongod.conf << EOF
storage:
  dbPath: /var/lib/mongodb
systemLog:
  destination: file
  path: /var/lib/mongodb/mongod.log
  logAppend: true
net:
  bindIp: 0.0.0.0
  port: ${DB_PORT}
processManagement:
  fork: false
EOF

# Start MongoDB server binding to 0.0.0.0 on the expected port using nohup
echo "Starting MongoDB server on 0.0.0.0:${DB_PORT}..."
nohup mongod --config "$(pwd)/mongod.conf" --unixSocketPrefix /var/run/mongodb > /var/lib/mongodb/mongod.log 2>&1 &

# Wait for MongoDB to start and respond
echo "Waiting for MongoDB to start..."
for i in {1..30}; do
    if mongosh --port ${DB_PORT} --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        echo "MongoDB is ready on port ${DB_PORT}!"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

# Final readiness check; exit with error if not ready
if ! mongosh --port ${DB_PORT} --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo "ERROR: MongoDB failed to start on port ${DB_PORT}."
    echo "Check logs at /var/lib/mongodb/mongod.log"
    exit 1
fi

# Create database and users
echo "Setting up database and users..."
mongosh --port ${DB_PORT} << EOF
use admin
if (db.getUser("${DB_USER}") == null) {
  db.createUser({
    user: "${DB_USER}",
    pwd: "${DB_PASSWORD}",
    roles: [
      { role: "userAdminAnyDatabase", db: "admin" },
      { role: "readWriteAnyDatabase", db: "admin" }
    ]
  });
}

use ${DB_NAME}
if (db.getUser("appuser") == null) {
  db.createUser({
    user: "appuser",
    pwd: "${DB_PASSWORD}",
    roles: [{ role: "readWrite", db: "${DB_NAME}" }]
  });
}
print("MongoDB setup complete!");
EOF

# Save connection details to files for tooling and previews
echo "mongosh mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}?authSource=admin" > db_connection.txt
echo "Connection string saved to db_connection.txt"

cat > db_visualizer/mongodb.env << EOF
export MONGODB_URL="mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/?authSource=admin"
export MONGODB_DB="${DB_NAME}"
EOF

echo "MongoDB setup complete!"
echo "Database: ${DB_NAME}"
echo "Admin user: ${DB_USER} (password: ${DB_PASSWORD})"
echo "App user: appuser (password: ${DB_PASSWORD})"
echo "Port: ${DB_PORT}"
echo ""
echo "Environment variables saved to db_visualizer/mongodb.env"
echo "To use with Node.js viewer, run: source db_visualizer/mongodb.env"
echo "To connect, run:"
echo "mongosh -u ${DB_USER} -p ${DB_PASSWORD} --port ${DB_PORT} --authenticationDatabase admin ${DB_NAME}"
echo "$(cat db_connection.txt)"
echo ""
echo "MongoDB is running in the background."