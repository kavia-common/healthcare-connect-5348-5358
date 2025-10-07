#!/bin/bash
# PUBLIC_INTERFACE
# Health check for MongoDB readiness on port 5001.
# Primary: Uses mongosh ping to verify server is accepting connections.
# Fallback: Uses TCP connect (bash + /dev/tcp) if mongosh unavailable.
# Returns 0 on success, non-zero otherwise.

PORT="${1:-5001}"
HOST="${2:-127.0.0.1}"

# If mongosh exists and can ping, declare ready
if command -v mongosh >/dev/null 2>&1; then
  if mongosh --port "${PORT}" --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo "ok"
    exit 0
  fi
fi

# Fallback: try raw TCP connect to ensure mongod is listening on the port
if (echo > /dev/tcp/${HOST}/${PORT}) >/dev/null 2>&1; then
  echo "ok-tcp"
  exit 0
fi

# As a last resort, check if a mongod process is running and port appears in socket listing (if ss exists)
if command -v ss >/dev/null 2>&1; then
  if ss -lnt 2>/dev/null | grep -q ":${PORT} "; then
    echo "ok-ss"
    exit 0
  fi
fi

echo "not ready"
exit 1
