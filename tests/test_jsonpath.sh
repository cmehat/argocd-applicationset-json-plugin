#!/bin/bash
set -e

echo "=========================================="
echo "Testing JSONPath Plugin (plugin.py)"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

FAILED=0
PASSED=0

# Function to run test
run_test() {
    local test_name="$1"
    local json_url="$2"
    local json_path="$3"
    local keys_only="$4"
    local exclude_field="$5"
    local expected_count="$6"

    echo ""
    echo "Test: $test_name"
    echo "  JSON_PATH: $json_path"

    export JSON_URL="$json_url"
    export JSON_PATH="$json_path"
    export JSON_PATH_KEYS_ONLY="$keys_only"
    export JSON_PATH_EXCLUDE_IF_EXISTS="$exclude_field"

    # Start plugin in background
    python3 ../plugin.py > /tmp/plugin.log 2>&1 &
    PLUGIN_PID=$!

    # Wait for server to start
    sleep 2

    # Test the endpoint
    RESULT=$(curl -s http://localhost:4355/api/v1/getparams.execute \
        -H "Authorization: Bearer default-token" \
        -H "Content-Type: application/json" \
        -d '{"applicationSetName": "test", "input": {"parameters": {}}}')

    # Kill plugin
    kill $PLUGIN_PID 2>/dev/null || true
    wait $PLUGIN_PID 2>/dev/null || true

    # Check result
    if echo "$RESULT" | grep -q "error"; then
        echo -e "  ${RED}✗ FAILED${NC}: Got error"
        echo "  Error: $RESULT"
        FAILED=$((FAILED + 1))
        return 1
    fi

    # Count results
    COUNT=$(echo "$RESULT" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data['output']['parameters']))" 2>/dev/null || echo "0")

    if [ "$COUNT" -eq "$expected_count" ]; then
        echo -e "  ${GREEN}✓ PASSED${NC}: Got $COUNT items (expected $expected_count)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAILED${NC}: Got $COUNT items (expected $expected_count)"
        echo "  Result: $RESULT"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# Change to tests directory
cd "$(dirname "$0")"

# Test 1: Teztnets with key extraction and filtering
run_test \
    "Teztnets - Extract keys, exclude aliases" \
    "file://$(pwd)/data/teztnets.json" \
    '$.*' \
    'true' \
    'aliasOf' \
    5

# Test 2: Simple array
run_test \
    "Simple array - all items" \
    "file://$(pwd)/data/simple_array.json" \
    '$[*]' \
    'false' \
    '' \
    3

# Test 3: Simple array with filtering
run_test \
    "Simple array - exclude items with 'skip' field" \
    "file://$(pwd)/data/simple_array.json" \
    '$[*]' \
    'false' \
    'skip' \
    2

# Test 4: Nested object - extract keys
run_test \
    "Nested object - extract environment names" \
    "file://$(pwd)/data/nested_object.json" \
    '$.*' \
    'true' \
    '' \
    3

# Test 5: Nested object - exclude temporary environments
run_test \
    "Nested object - exclude temporary environments" \
    "file://$(pwd)/data/nested_object.json" \
    '$.*' \
    'true' \
    'temporary' \
    2

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi

exit 0
