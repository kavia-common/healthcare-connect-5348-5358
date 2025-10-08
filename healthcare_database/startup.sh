#!/bin/bash

# MongoDB startup script for port 5001 (preview mode)
# Ensures MongoDB starts reliably and visualizer failures don't affect MongoDB
DB_NAME="${DB_NAME:-myapp}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-dbuser123}"
DB_PORT="${DB_PORT:-5001}"
DB_HOST="0.0.0.0"

echo "════════════════════════════════════════════════════════"
echo "[startup] MongoDB Startup Script"
echo "[startup] Port: ${DB_PORT} | Database: ${DB_NAME}"
echo "════════════════════════════════════════════════════════"

# Function to log with timestamp
log_info() {
    echo "[startup $(date +%H:%M:%S)] INFO: $1"
}

log_warn() {
    echo "[startup $(date +%H:%M:%S)] WARN: $1"
}

log_error() {
    echo "[startup $(date +%H:%M:%S)] ERROR: $1"
}

log_success() {
    echo "[startup $(date +%H:%M:%S)] ✓ $1"
}

# Ensure required directories exist with correct permissions
log_info "Setting up MongoDB directories..."
mkdir -p /var/lib/mongodb /var/run/mongodb 2>/dev/null || {
    if command -v sudo >/dev/null 2>&1; then
        sudo mkdir -p /var/lib/mongodb /var/run/mongodb
    else
        log_error "Cannot create directories and sudo not available"
        exit 1
    fi
}

# Set ownership (best effort - may fail in some environments)
chown -R "$(id -u):$(id -g)" /var/lib/mongodb /var/run/mongodb 2>/dev/null || {
    if command -v sudo >/dev/null 2>&1; then
        sudo chown -R "$(whoami)":"$(whoami)" /var/lib/mongodb /var/run/mongodb 2>/dev/null || true
    fi
}

chmod 755 /var/lib/mongodb 2>/dev/null || true
log_success "Directories prepared"

# Remove stale lock files that could prevent startup
log_info "Cleaning stale lock files..."
rm -f /var/lib/mongodb/mongod.lock /var/lib/mongodb/*.pid 2>/dev/null || true
rm -f /tmp/mongodb-*.sock 2>/dev/null || true

# Check if MongoDB is already running on the target port
log_info "Checking for existing MongoDB instance..."
if command -v mongosh >/dev/null 2>&1; then
    if mongosh --port "${DB_PORT}" --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        log_success "MongoDB already running and responding on port ${DB_PORT}"
        # Update connection files
        echo "mongosh mongodb://localhost:${DB_PORT}/${DB_NAME}" > db_connection.txt
        mkdir -p db_visualizer
        cat > db_visualizer/mongodb.env << EOF
export MONGODB_URL="mongodb://localhost:${DB_PORT}/"
export MONGODB_DB="${DB_NAME}"
EOF
        log_success "Connection files updated"
        exit 0
    fi
fi

# TCP fallback check
if (echo > /dev/tcp/127.0.0.1/${DB_PORT}) >/dev/null 2>&1; then
    log_success "MongoDB already listening on port ${DB_PORT} (TCP check)"
    echo "mongosh mongodb://localhost:${DB_PORT}/${DB_NAME}" > db_connection.txt
    mkdir -p db_visualizer
    cat > db_visualizer/mongodb.env << EOF
export MONGODB_URL="mongodb://localhost:${DB_PORT}/"
export MONGODB_DB="${DB_NAME}"
EOF
    exit 0
fi

# Check for lingering mongod processes that might block the port
if pgrep -x mongod >/dev/null 2>&1; then
    log_warn "Found existing mongod process, attempting cleanup..."
    pkill -x mongod 2>/dev/null || sudo pkill -x mongod 2>/dev/null || true
    sleep 3
fi

# Create MongoDB configuration file
log_info "Creating MongoDB configuration..."
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
security:
  authorization: "disabled"
EOF

log_success "Configuration created"

# Start MongoDB in background
log_info "Starting MongoDB server on ${DB_HOST}:${DB_PORT}..."
nohup mongod --config "$(pwd)/mongod.conf" --unixSocketPrefix /var/run/mongodb \
    >> /var/lib/mongodb/mongod.log 2>&1 &
MONGOD_PID=$!

log_info "MongoDB started with PID ${MONGOD_PID}, waiting for readiness..."

# Wait for MongoDB to become ready with multiple check methods
ready=0
for attempt in $(seq 1 60); do
    # Primary check: mongosh ping
    if command -v mongosh >/dev/null 2>&1; then
        if mongosh --port "${DB_PORT}" --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
            log_success "MongoDB is ready (mongosh ping succeeded)"
            ready=1
            break
        fi
    fi
    
    # Fallback: TCP connection
    if (echo > /dev/tcp/127.0.0.1/${DB_PORT}) >/dev/null 2>&1; then
        log_success "MongoDB port ${DB_PORT} is responding (TCP check)"
        ready=1
        break
    fi
    
    # Check if process is still alive
    if ! kill -0 ${MONGOD_PID} 2>/dev/null; then
        log_error "MongoDB process died during startup"
        break
    fi
    
    # Show diagnostic info on attempt 5
    if [ "${attempt}" -eq 5 ] && command -v ss >/dev/null 2>&1; then
        log_info "Diagnostic: Listening ports..."
        ss -tlnp 2>/dev/null | grep -E "LISTEN.*:${DB_PORT}" || echo "  Port ${DB_PORT} not yet bound"
    fi
    
    echo "[startup] Waiting for MongoDB... (${attempt}/60)"
    sleep 1
done

# Final readiness verification
if [ "${ready}" -ne 1 ]; then
    log_error "MongoDB failed to start on port ${DB_PORT} after 60 seconds"
    log_error "─────────────────────────────────────────"
    log_error "Troubleshooting hints:"
    log_error "  1. Check if port ${DB_PORT} is already in use: ss -tlnp | grep ${DB_PORT}"
    log_error "  2. Verify /var/lib/mongodb permissions: ls -la /var/lib/mongodb"
    log_error "  3. Check logs: tail -100 /var/lib/mongodb/mongod.log"
    log_error "  4. Ensure mongod binary is available: which mongod"
    log_error "─────────────────────────────────────────"
    
    if [ -f /var/lib/mongodb/mongod.log ]; then
        log_error "Last 50 lines of MongoDB log:"
        tail -50 /var/lib/mongodb/mongod.log 2>/dev/null || sudo tail -50 /var/lib/mongodb/mongod.log 2>/dev/null || true
    fi
    exit 1
fi

# MongoDB is ready - now handle authentication if requested
ENABLE_AUTH="${ENABLE_AUTH:-false}"
if [ "${ENABLE_AUTH}" = "true" ] && command -v mongosh >/dev/null 2>&1; then
    log_info "Creating MongoDB users (ENABLE_AUTH=true)..."
    mongosh --port "${DB_PORT}" --quiet << EOF
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
  print("Admin user created");
}
use ${DB_NAME}
if (db.getUser("appuser") == null) {
  db.createUser({
    user: "appuser",
    pwd: "${DB_PASSWORD}",
    roles: [{ role: "readWrite", db: "${DB_NAME}" }]
  });
  print("App user created");
}
EOF
    
    # Save authenticated connection details
    echo "mongosh mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}?authSource=admin" > db_connection.txt
    mkdir -p db_visualizer
    cat > db_visualizer/mongodb.env << EOF
export MONGODB_URL="mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/?authSource=admin"
export MONGODB_DB="${DB_NAME}"
EOF
    log_success "Authentication enabled"
else
    log_info "Running without authentication (preview mode)"
    # Save non-authenticated connection details
    echo "mongosh mongodb://localhost:${DB_PORT}/${DB_NAME}" > db_connection.txt
    mkdir -p db_visualizer
    cat > db_visualizer/mongodb.env << EOF
export MONGODB_URL="mongodb://localhost:${DB_PORT}/"
export MONGODB_DB="${DB_NAME}"
EOF
fi

log_success "MongoDB setup complete!"
echo "════════════════════════════════════════════════════════"
echo "[startup] MongoDB Status:"
echo "[startup]   - Database: ${DB_NAME}"
echo "[startup]   - Port: ${DB_PORT}"
echo "[startup]   - Host: ${DB_HOST}"
echo "[startup]   - Auth: ${ENABLE_AUTH}"
echo "[startup]   - Logs: /var/lib/mongodb/mongod.log"
echo "[startup]   - Connection: $(cat db_connection.txt)"
echo "════════════════════════════════════════════════════════"

# From this point on, errors should not stop MongoDB
# Try to start db_visualizer but don't fail if it doesn't work
log_info "Attempting to start db_visualizer (optional)..."

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    log_warn "Node.js/npm not available - skipping visualizer"
    log_info "MongoDB is accessible at: mongodb://localhost:${DB_PORT}/${DB_NAME}"
    exit 0
fi

if [ ! -d "db_visualizer" ]; then
    log_warn "db_visualizer directory not found - skipping"
    exit 0
fi

cd db_visualizer || {
    log_warn "Cannot access db_visualizer directory"
    exit 0
}

# Check and install dependencies if needed
if [ ! -d "node_modules" ] || [ ! -d "node_modules/express/lib" ]; then
    log_info "Installing visualizer dependencies..."
    if npm ci --silent >/dev/null 2>&1; then
        log_success "Dependencies installed (npm ci)"
    elif npm install --silent >/dev/null 2>&1; then
        log_success "Dependencies installed (npm install)"
    else
        log_warn "Failed to install dependencies - visualizer unavailable"
        log_info "MongoDB is running normally on port ${DB_PORT}"
        exit 0
    fi
fi

# Start visualizer in background (non-blocking)
log_info "Starting visualizer in background..."
nohup npm start >/dev/null 2>&1 &
VISUALIZER_PID=$!

# Brief check if visualizer started
sleep 2
if kill -0 ${VISUALIZER_PID} 2>/dev/null; then
    log_success "db_visualizer started (PID: ${VISUALIZER_PID})"
else
    log_warn "db_visualizer failed to start, but MongoDB is running"
fi

log_info "Startup complete - MongoDB is ready on port ${DB_PORT}"
exit 0
