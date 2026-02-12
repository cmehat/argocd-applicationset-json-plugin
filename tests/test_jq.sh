#!/bin/bash
set -e

echo "=========================================="
echo "Testing jq Plugin (plugin_jq.py)"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

FAILED=0
PASSED=0

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Install jq: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Function to run test
run_test() {
    local test_name="$1"
    local json_url="$2"
    local json_filter="$3"
    local expected_count="$4"

    echo ""
    echo "Test: $test_name"
    echo "  JSON_FILTER: $json_filter"

    export JSON_URL="$json_url"
    export JSON_FILTER="$json_filter"

    # Start plugin in background
    python3 ../plugin_jq.py > /tmp/plugin_jq.log 2>&1 &
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

# Test 1: Teztnets with jq filter
run_test \
    "Teztnets - jq filter to extract non-alias networks" \
    "file://$(pwd)/data/teztnets.json" \
    'to_entries | map(select(.value.aliasOf == null) | {name: .key})' \
    5

# Test 2: Simple array - map to names
run_test \
    "Simple array - extract names" \
    "file://$(pwd)/data/simple_array.json" \
    'map({name: .name, value: .value})' \
    3

# Test 3: Simple array - filter and transform
run_test \
    "Simple array - filter out items with skip field" \
    "file://$(pwd)/data/simple_array.json" \
    'map(select(.skip == null))' \
    2

# Test 4: Nested object - convert to array with keys
run_test \
    "Nested object - convert to array with environment names" \
    "file://$(pwd)/data/nested_object.json" \
    'to_entries | map({name: .key, region: .value.region})' \
    3

# Test 5: Nested object - filter non-temporary
run_test \
    "Nested object - exclude temporary environments" \
    "file://$(pwd)/data/nested_object.json" \
    'to_entries | map(select(.value.temporary == null) | {name: .key, region: .value.region})' \
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
