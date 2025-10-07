#!/bin/bash
set -euo pipefail

# Ensure script is executable and has a valid shebang for entrypoint execution.
# MongoDB startup script aligned for previews (binds 0.0.0.0 on port 5001)
DB_NAME="${DB_NAME:-myapp}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-dbuser123}"
DB_PORT="${DB_PORT:-5001}"  # previews expect 5001
DB_HOST="0.0.0.0"

echo "[startup] Starting MongoDB setup (port ${DB_PORT})..."

# Ensure data and runtime directories exist with correct permissions
sudo mkdir -p /var/lib/mongodb /var/run/mongodb || true
sudo chown -R "$(whoami)":"$(whoami)" /var/lib/mongodb /var/run/mongodb 2>/dev/null || true
sudo chmod 700 /var/lib/mongodb 2>/dev/null || true

# Remove stale lock/pid files to avoid startup failures
rm -f /var/lib/mongodb/mongod.lock /var/lib/mongodb/*.pid 2>/dev/null || true
sudo rm -f /tmp/mongodb-*.sock 2>/dev/null || true

# If already running and responding on desired port, print info and exit
if command -v mongosh >/dev/null 2>&1; then
  if mongosh --port "${DB_PORT}" --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
      echo "[startup] MongoDB is already running on port ${DB_PORT}!"
      if mongosh "mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}?authSource=admin" --eval "db.getName()" > /dev/null 2>&1; then
          echo "[startup] Database ${DB_NAME} is accessible with user ${DB_USER}."
      else
          echo "[startup] MongoDB is running but authentication might not be configured."
      fi
      # Keep connection files in sync
      echo "mongosh mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}?authSource=admin" > db_connection.txt
      cat > db_visualizer/mongodb.env << EOF
export MONGODB_URL="mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/?authSource=admin"
export MONGODB_DB="${DB_NAME}"
EOF
      exit 0
  fi
fi

# If mongod is running but not reachable on target port, best-effort stop to free it
if pgrep -x mongod > /dev/null 2>&1; then
    echo "[startup] mongod process detected; attempting to stop to free port ${DB_PORT}..."
    sudo pkill -x mongod || true
    sleep 2
fi

# Provide an explicit inline config to avoid dependency on system paths
cat > mongod.conf << EOF
storage:
  dbPath: /var/lib/mongodb
systemLog:
  destination: file
  path: /var/lib/mongodb/mongod.log
  logAppend: true
net:
  bindIp: ${DB_HOST}
  port: ${DB_PORT}
processManagement:
  fork: false
EOF

# Start MongoDB server binding to 0.0.0.0 on the expected port using nohup
echo "[startup] Starting MongoDB server on ${DB_HOST}:${DB_PORT}..."
nohup mongod --config "$(pwd)/mongod.conf" --unixSocketPrefix /var/run/mongodb > /var/lib/mongodb/mongod.log 2>&1 &

# Wait for MongoDB to start and respond
echo "[startup] Waiting for MongoDB to start..."
ready=0
for i in {1..45}; do
    # Prefer mongosh ping, else use TCP probe
    if command -v mongosh >/dev/null 2>&1; then
      if mongosh --port "${DB_PORT}" --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
          echo "[startup] MongoDB is ready on port ${DB_PORT}!"
          ready=1
          break
      fi
    else
      if (echo > /dev/tcp/127.0.0.1/${DB_PORT}) >/dev/null 2>&1; then
          echo "[startup] MongoDB TCP port ${DB_PORT} is open."
          ready=1
          break
      fi
    fi
    echo "[startup] Waiting... ($i/45)"
    sleep 2
done

# Final readiness check; exit with error if not ready
if [ "${ready}" -ne 1 ]; then
    echo "[startup] ERROR: MongoDB failed to start on port ${DB_PORT}."
    echo "[startup] Tail of log:"
    tail -n 100 /var/lib/mongodb/mongod.log || true
    exit 1
fi

# Create database and users if mongosh is available
if command -v mongosh >/dev/null 2>&1; then
  echo "[startup] Setting up database and users..."
  mongosh --port "${DB_PORT}" << EOF
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
else
  echo "[startup] mongosh not found; skipping user creation. Instance running unauthenticated."
fi

# Save connection details to files for tooling and previews
echo "mongosh mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}?authSource=admin" > db_connection.txt
cat > db_visualizer/mongodb.env << EOF
export MONGODB_URL="mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/?authSource=admin"
export MONGODB_DB="${DB_NAME}"
EOF

echo "[startup] MongoDB setup complete!"
echo "[startup] Database: ${DB_NAME}"
echo "[startup] Admin user: ${DB_USER} (password: ${DB_PASSWORD})"
echo "[startup] App user: appuser (password: ${DB_PASSWORD})"
echo "[startup] Port: ${DB_PORT}"
echo "[startup] Logs: /var/lib/mongodb/mongod.log"