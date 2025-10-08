#!/bin/bash
# PUBLIC_INTERFACE
# Health check for MongoDB readiness on port 27017.
# Uses multiple fallback methods to reliably detect MongoDB availability.
# Returns 0 on success, non-zero otherwise.

PORT="${1:-27017}"
HOST="${2:-127.0.0.1}"

# Silent mode - don't output unless debugging
DEBUG="${DEBUG:-false}"

debug_log() {
    if [ "${DEBUG}" = "true" ]; then
        echo "[healthcheck] $1" >&2
    fi
}

# Method 1: mongosh ping (most reliable)
if command -v mongosh >/dev/null 2>&1; then
    debug_log "Attempting mongosh ping on port ${PORT}..."
    if mongosh --port "${PORT}" --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        echo "ok"
        exit 0
    fi
    debug_log "mongosh ping failed"
fi

# Method 2: TCP connection test
debug_log "Attempting TCP connection to ${HOST}:${PORT}..."
if timeout 2 bash -c "echo > /dev/tcp/${HOST}/${PORT}" >/dev/null 2>&1; then
    echo "ok-tcp"
    exit 0
fi

# Method 3: Check socket status with ss
if command -v ss >/dev/null 2>&1; then
    debug_log "Checking socket status with ss..."
    if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        # Port is listening, try one more TCP test
        if (echo > /dev/tcp/${HOST}/${PORT}) >/dev/null 2>&1; then
            echo "ok-ss"
            exit 0
        fi
    fi
fi

# Method 4: Check with netstat (fallback)
if command -v netstat >/dev/null 2>&1; then
    debug_log "Checking with netstat..."
    if netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        echo "ok-netstat"
        exit 0
    fi
fi

# Method 5: Check if mongod process exists and is bound to our port
if pgrep -x mongod >/dev/null 2>&1; then
    debug_log "mongod process found, verifying port binding..."
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i ":${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
            echo "ok-lsof"
            exit 0
        fi
    fi
fi

debug_log "All health check methods failed"
echo "not ready"
exit 1
