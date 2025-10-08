#!/bin/bash
# Verification script to confirm all references to port 5001 have been changed to 27017

echo "══════════════════════════════════════════════════════"
echo "MongoDB Port Change Verification"
echo "══════════════════════════════════════════════════════"
echo ""

ERRORS=0
WARNINGS=0

# Function to check if port 5001 still exists in a file
check_file_for_old_port() {
    local file=$1
    local context=$2
    
    if [ -f "$file" ]; then
        if grep -q "5001" "$file" 2>/dev/null; then
            echo "⚠ WARNING: Found '5001' in $file"
            echo "  Context: $context"
            grep -n "5001" "$file" | head -3
            WARNINGS=$((WARNINGS + 1))
        else
            echo "✓ $file - No old port references"
        fi
    else
        echo "✗ ERROR: $file not found"
        ERRORS=$((ERRORS + 1))
    fi
}

# Function to check if port 27017 exists in a file
check_file_for_new_port() {
    local file=$1
    local context=$2
    
    if [ -f "$file" ]; then
        if grep -q "27017" "$file" 2>/dev/null; then
            echo "✓ $file - Contains new port 27017"
        else
            echo "✗ ERROR: $file missing port 27017"
            echo "  Context: $context"
            ERRORS=$((ERRORS + 1))
        fi
    fi
}

echo "Checking configuration files..."
echo "─────────────────────────────────────────"
check_file_for_new_port "mongod.conf" "Should have 'port: 27017'"
check_file_for_new_port "db_connection.txt" "Should have 'localhost:27017'"
check_file_for_new_port "db_visualizer/mongodb.env" "Should have 'localhost:27017'"

echo ""
echo "Checking scripts..."
echo "─────────────────────────────────────────"
check_file_for_new_port "startup.sh" "Should have default DB_PORT=27017"
check_file_for_new_port "healthcheck.sh" "Should have default PORT=27017"
check_file_for_new_port "test_startup.sh" "Should test port 27017"
check_file_for_new_port "validate_acceptance_criteria.sh" "Should validate port 27017"

echo ""
echo "Checking documentation..."
echo "─────────────────────────────────────────"
check_file_for_new_port "README.md" "Should reference port 27017"
check_file_for_new_port "QUICK_REFERENCE.md" "Should show port 27017"
check_file_for_new_port "STARTUP_STABILITY_FIX.md" "Should document port 27017"

echo ""
echo "Scanning for old port references (5001)..."
echo "─────────────────────────────────────────"
check_file_for_old_port "startup.sh" "Startup script"
check_file_for_old_port "healthcheck.sh" "Health check script"
check_file_for_old_port "test_startup.sh" "Test script"
check_file_for_old_port "validate_acceptance_criteria.sh" "Validation script"
check_file_for_old_port "mongod.conf" "MongoDB configuration"
check_file_for_old_port "README.md" "Main documentation"

echo ""
echo "Checking schema..."
echo "─────────────────────────────────────────"
check_file_for_new_port "schema/collections.json" "Should have connection URL with port 27017"

echo ""
echo "══════════════════════════════════════════════════════"
echo "Verification Summary"
echo "══════════════════════════════════════════════════════"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✓✓✓ ALL PORT REFERENCES UPDATED SUCCESSFULLY ✓✓✓"
    echo ""
    echo "MongoDB is now configured for port 27017"
    echo "To start MongoDB: bash startup.sh"
    echo "To verify: ss -tlnp | grep 27017"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠ Port change complete with warnings"
    echo "Review the warnings above - they may be in comments or documentation"
    echo ""
    exit 0
else
    echo "✗ Port change incomplete - please review errors above"
    echo ""
    exit 1
fi
