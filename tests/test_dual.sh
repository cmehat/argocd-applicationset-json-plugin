#!/bin/bash
set -e

echo "=========================================="
echo "Testing Dual Plugin (plugin_dual.py)"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

FAILED=0
PASSED=0

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Warning: jq is not installed, skipping jq mode tests${NC}"
    SKIP_JQ=true
else
    SKIP_JQ=false
fi

# Function to run test
run_test() {
    local test_name="$1"
    local mode="$2"
    local json_url="$3"
    local filter_expr="$4"
    local expected_count="$5"

    echo ""
    echo "Test: $test_name (mode: $mode)"

    export JSON_URL="$json_url"

    if [ "$mode" = "jsonpath" ]; then
        export JSON_PATH="$filter_expr"
        export JSON_PATH_KEYS_ONLY="${6:-false}"
        export JSON_PATH_EXCLUDE_IF_EXISTS="${7:-}"
        unset JSON_FILTER
        echo "  JSON_PATH: $filter_expr"
    else
        export JSON_FILTER="$filter_expr"
        unset JSON_PATH
        unset JSON_PATH_KEYS_ONLY
        unset JSON_PATH_EXCLUDE_IF_EXISTS
        echo "  JSON_FILTER: $filter_expr"
    fi

    # Start plugin in background
    python3 ../plugin_dual.py > /tmp/plugin_dual.log 2>&1 &
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

echo ""
echo "Testing JSONPath Mode"
echo "=========================================="

# JSONPath Tests
run_test \
    "Teztnets - JSONPath with key extraction" \
    "jsonpath" \
    "file://$(pwd)/data/teztnets.json" \
    '$.*' \
    5 \
    'true' \
    'aliasOf'

run_test \
    "Simple array - JSONPath all items" \
    "jsonpath" \
    "file://$(pwd)/data/simple_array.json" \
    '$[*]' \
    3

run_test \
    "Nested object - JSONPath extract keys" \
    "jsonpath" \
    "file://$(pwd)/data/nested_object.json" \
    '$.*' \
    3 \
    'true' \
    ''

if [ "$SKIP_JQ" = false ]; then
    echo ""
    echo "Testing jq Mode"
    echo "=========================================="

    # jq Tests
    run_test \
        "Teztnets - jq filter" \
        "jq" \
        "file://$(pwd)/data/teztnets.json" \
        'to_entries | map(select(.value.aliasOf == null) | {name: .key})' \
        5

    run_test \
        "Simple array - jq transform" \
        "jq" \
        "file://$(pwd)/data/simple_array.json" \
        'map({name: .name})' \
        3

    run_test \
        "Nested object - jq to_entries" \
        "jq" \
        "file://$(pwd)/data/nested_object.json" \
        'to_entries | map({name: .key})' \
        3
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
if [ "$SKIP_JQ" = true ]; then
    echo -e "${RED}Note: jq mode tests were skipped (jq not installed)${NC}"
fi
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi

exit 0
