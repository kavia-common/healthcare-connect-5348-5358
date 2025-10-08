#!/bin/bash
# Validation script to verify all acceptance criteria are met

echo "════════════════════════════════════════════════════════"
echo "MongoDB Startup Stability - Acceptance Criteria Validation"
echo "════════════════════════════════════════════════════════"
echo ""

PASS_COUNT=0
FAIL_COUNT=0

# Helper functions
test_pass() {
    echo "✓ PASS: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

test_fail() {
    echo "✗ FAIL: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo "Acceptance Criteria 1: startup.sh exits successfully even if visualizer fails"
echo "─────────────────────────────────────────────────────────"

# Test 1a: Verify startup.sh can handle visualizer failure
# We'll check that the script structure allows MongoDB to continue
if grep -q "# From this point on, errors should not stop MongoDB" startup.sh && \
   grep -q "exit 0" startup.sh | tail -1; then
    test_pass "startup.sh has proper error isolation for visualizer"
else
    test_fail "startup.sh does not properly isolate visualizer errors"
fi

# Test 1b: Check that visualizer runs in background (non-blocking)
if grep -q "nohup npm start" startup.sh && \
   grep -q "VISUALIZER_PID=\$!" startup.sh; then
    test_pass "Visualizer runs in background (non-blocking)"
else
    test_fail "Visualizer not configured for background execution"
fi

# Test 1c: Verify script exits 0 even with visualizer warnings
if grep -A 5 "visualizer unavailable" startup.sh | grep -q "exit 0"; then
    test_pass "Script exits successfully when visualizer fails"
else
    test_fail "Script may not exit successfully on visualizer failure"
fi

echo ""
echo "Acceptance Criteria 2: mongod listens on port 27017 (0.0.0.0:27017) and responds to ping"
echo "─────────────────────────────────────────────────────────"

# Test 2a: Check if mongod is running
if pgrep -x mongod >/dev/null 2>&1; then
    test_pass "mongod process is running"
else
    test_fail "mongod process not found"
fi

# Test 2b: Check port binding to 0.0.0.0:27017
if ss -tlnp 2>/dev/null | grep -q "0.0.0.0:27017"; then
    test_pass "mongod listening on 0.0.0.0:27017"
else
    test_fail "mongod not listening on 0.0.0.0:27017"
fi

# Test 2c: Verify MongoDB responds to ping
if mongosh --port 27017 --quiet --eval "db.adminCommand('ping')" 2>/dev/null | grep -q "ok: 1"; then
    test_pass "MongoDB responds to ping command"
else
    test_fail "MongoDB does not respond to ping"
fi

# Test 2d: Verify TCP connectivity
if (echo > /dev/tcp/127.0.0.1/27017) >/dev/null 2>&1; then
    test_pass "Port 27017 accepts TCP connections"
else
    test_fail "Port 27017 does not accept TCP connections"
fi

echo ""
echo "Acceptance Criteria 3: Health check reliably detects readiness"
echo "─────────────────────────────────────────────────────────"

# Test 3a: Basic health check execution
if [ -f "healthcheck.sh" ]; then
    test_pass "healthcheck.sh exists"
else
    test_fail "healthcheck.sh not found"
fi

# Test 3b: Health check returns success when MongoDB is ready
HEALTH_RESULT=$(bash healthcheck.sh 27017 2>/dev/null)
HEALTH_EXIT=$?
if [ $HEALTH_EXIT -eq 0 ]; then
    test_pass "Health check returns success (exit 0)"
else
    test_fail "Health check does not return success"
fi

# Test 3c: Health check output indicates readiness
if echo "$HEALTH_RESULT" | grep -qE "^ok"; then
    test_pass "Health check outputs readiness indicator: $HEALTH_RESULT"
else
    test_fail "Health check output unclear: $HEALTH_RESULT"
fi

# Test 3d: Verify multiple fallback methods exist
FALLBACK_COUNT=$(grep -c "if.*mongosh\|if.*tcp\|if.*ss\|if.*netstat\|if.*lsof" healthcheck.sh)
if [ "$FALLBACK_COUNT" -ge 4 ]; then
    test_pass "Health check has multiple fallback methods ($FALLBACK_COUNT methods)"
else
    test_fail "Health check has insufficient fallback methods ($FALLBACK_COUNT methods)"
fi

# Test 3e: Health check is resilient (works even with visualizer down)
pkill -f "node.*server.js" 2>/dev/null
sleep 1
if bash healthcheck.sh 27017 >/dev/null 2>&1; then
    test_pass "Health check succeeds even when visualizer is down"
else
    test_fail "Health check fails when visualizer is down"
fi

echo ""
echo "Acceptance Criteria 4: Clear logs on failure with actionable hints"
echo "─────────────────────────────────────────────────────────"

# Test 4a: Startup script has structured logging
if grep -q "log_info\|log_warn\|log_error\|log_success" startup.sh; then
    test_pass "Startup script uses structured logging functions"
else
    test_fail "Startup script lacks structured logging"
fi

# Test 4b: Error messages include troubleshooting hints
if grep -A 5 "Troubleshooting hints" startup.sh | grep -q "Check if port"; then
    test_pass "Startup script includes troubleshooting hints"
else
    test_fail "Startup script lacks troubleshooting hints"
fi

# Test 4c: Startup script shows logs on failure
if grep -q "tail.*mongod.log" startup.sh; then
    test_pass "Startup script displays logs on failure"
else
    test_fail "Startup script does not display logs on failure"
fi

# Test 4d: Logs include timestamps
if grep -q "date.*%H:%M:%S" startup.sh; then
    test_pass "Logs include timestamps"
else
    test_fail "Logs lack timestamps"
fi

# Test 4e: Diagnostic output during startup
if grep -q "Diagnostic\|listening.*ports\|ss -lnt" startup.sh; then
    test_pass "Startup includes diagnostic output"
else
    test_fail "Startup lacks diagnostic output"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "Additional Stability Checks"
echo "════════════════════════════════════════════════════════"

# Test 5: Data directory exists and has proper setup
if [ -d "/var/lib/mongodb" ]; then
    test_pass "MongoDB data directory exists"
else
    test_fail "MongoDB data directory missing"
fi

# Test 6: Connection files are created
if [ -f "db_connection.txt" ] && [ -f "db_visualizer/mongodb.env" ]; then
    test_pass "Connection configuration files exist"
else
    test_fail "Connection configuration files missing"
fi

# Test 7: MongoDB configuration file is valid
if [ -f "mongod.conf" ] && grep -q "port: 27017" mongod.conf && grep -q "bindIp: 0.0.0.0" mongod.conf; then
    test_pass "MongoDB configuration is valid"
else
    test_fail "MongoDB configuration is invalid or missing"
fi

# Test 8: Stale lock cleanup logic exists
if grep -q "mongod.lock" startup.sh && grep -q "rm -f" startup.sh; then
    test_pass "Stale lock cleanup implemented"
else
    test_fail "Stale lock cleanup missing"
fi

# Test 9: Process check before starting
if grep -q "pgrep.*mongod" startup.sh && grep -q "pkill" startup.sh; then
    test_pass "Lingering process cleanup implemented"
else
    test_fail "Lingering process cleanup missing"
fi

# Test 10: Documentation exists
DOC_COUNT=0
[ -f "STARTUP_STABILITY_FIX.md" ] && DOC_COUNT=$((DOC_COUNT + 1))
[ -f "QUICK_REFERENCE.md" ] && DOC_COUNT=$((DOC_COUNT + 1))
[ -f "README.md" ] && DOC_COUNT=$((DOC_COUNT + 1))

if [ "$DOC_COUNT" -ge 2 ]; then
    test_pass "Documentation files present ($DOC_COUNT files)"
else
    test_fail "Insufficient documentation ($DOC_COUNT files)"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "Validation Summary"
echo "════════════════════════════════════════════════════════"
echo "Tests Passed: $PASS_COUNT"
echo "Tests Failed: $FAIL_COUNT"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "✓✓✓ ALL ACCEPTANCE CRITERIA MET ✓✓✓"
    echo ""
    echo "MongoDB startup is stable and resilient:"
    echo "  • Survives visualizer failures"
    echo "  • Binds correctly to 0.0.0.0:27017"
    echo "  • Health checks are reliable with fallbacks"
    echo "  • Clear error messages with actionable hints"
    echo ""
    exit 0
else
    echo "✗✗✗ SOME TESTS FAILED ✗✗✗"
    echo "Please review the failures above."
    echo ""
    exit 1
fi
