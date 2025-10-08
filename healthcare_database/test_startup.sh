#!/bin/bash
# Test script to verify MongoDB startup and health check resilience

echo "════════════════════════════════════════════════════════"
echo "MongoDB Startup Test Script"
echo "════════════════════════════════════════════════════════"

# Test 1: Check if MongoDB is running
echo ""
echo "Test 1: MongoDB Running Status"
echo "─────────────────────────────────────────"
if pgrep -x mongod >/dev/null 2>&1; then
    echo "✓ mongod process is running"
    ps aux | grep mongod | grep -v grep | head -1
else
    echo "✗ mongod process not found"
fi

# Test 2: Check port binding
echo ""
echo "Test 2: Port 27017 Binding"
echo "─────────────────────────────────────────"
if ss -tlnp 2>/dev/null | grep -q ":27017 "; then
    echo "✓ Port 27017 is bound and listening"
    ss -tlnp 2>/dev/null | grep ":27017 "
else
    echo "✗ Port 27017 is not bound"
fi

# Test 3: Health Check Script
echo ""
echo "Test 3: Health Check Script"
echo "─────────────────────────────────────────"
if [ -f "healthcheck.sh" ]; then
    result=$(./healthcheck.sh 27017)
    if [ $? -eq 0 ]; then
        echo "✓ Health check passed: ${result}"
    else
        echo "✗ Health check failed"
    fi
else
    echo "✗ healthcheck.sh not found"
fi

# Test 4: MongoDB connectivity
echo ""
echo "Test 4: MongoDB Connectivity"
echo "─────────────────────────────────────────"
if command -v mongosh >/dev/null 2>&1; then
    if mongosh --port 27017 --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        echo "✓ MongoDB responds to ping command"
        mongosh --port 27017 --quiet --eval "print('Server version: ' + db.version())"
    else
        echo "✗ MongoDB does not respond to ping"
    fi
else
    echo "⚠ mongosh not available"
fi

# Test 5: Connection files
echo ""
echo "Test 5: Connection Files"
echo "─────────────────────────────────────────"
if [ -f "db_connection.txt" ]; then
    echo "✓ db_connection.txt exists:"
    cat db_connection.txt
else
    echo "✗ db_connection.txt not found"
fi

if [ -f "db_visualizer/mongodb.env" ]; then
    echo "✓ db_visualizer/mongodb.env exists:"
    cat db_visualizer/mongodb.env
else
    echo "✗ db_visualizer/mongodb.env not found"
fi

# Test 6: Data directory
echo ""
echo "Test 6: Data Directory Status"
echo "─────────────────────────────────────────"
if [ -d "/var/lib/mongodb" ]; then
    echo "✓ /var/lib/mongodb exists"
    echo "  Permissions: $(stat -c '%a %U:%G' /var/lib/mongodb 2>/dev/null || echo 'unavailable')"
else
    echo "✗ /var/lib/mongodb not found"
fi

# Test 7: Log file
echo ""
echo "Test 7: Log File"
echo "─────────────────────────────────────────"
if [ -f "/var/lib/mongodb/mongod.log" ]; then
    echo "✓ mongod.log exists"
    echo "  Recent errors:"
    sudo tail -20 /var/lib/mongodb/mongod.log 2>/dev/null | grep -i error || echo "  No recent errors"
else
    echo "✗ mongod.log not found"
fi

# Test 8: db_visualizer status
echo ""
echo "Test 8: db_visualizer Status"
echo "─────────────────────────────────────────"
if pgrep -f "node.*server.js" >/dev/null 2>&1; then
    echo "✓ db_visualizer is running"
    ps aux | grep "node.*server.js" | grep -v grep
else
    echo "⚠ db_visualizer not running (optional component)"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "Test Summary Complete"
echo "════════════════════════════════════════════════════════"
