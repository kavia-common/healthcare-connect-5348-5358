#!/bin/bash
# PUBLIC_INTERFACE
# Health check for MongoDB readiness on port 5001.
# Uses mongosh ping command to verify server is accepting connections.
# Returns 0 on success, non-zero otherwise.

PORT="${1:-5001}"

if mongosh --port "${PORT}" --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
  echo "ok"
  exit 0
else
  echo "not ready"
  exit 1
fi
