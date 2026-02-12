#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TOTAL_FAILED=0

echo -e "${BLUE}=========================================="
echo "Running All Tests"
echo -e "==========================================${NC}"

cd "$(dirname "$0")"

# Test 1: JSONPath Plugin
echo -e "\n${BLUE}[1/3] Testing JSONPath Plugin...${NC}"
if ./test_jsonpath.sh; then
    echo -e "${GREEN}✓ JSONPath tests passed${NC}"
else
    echo -e "${RED}✗ JSONPath tests failed${NC}"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
fi

# Test 2: jq Plugin
echo -e "\n${BLUE}[2/3] Testing jq Plugin...${NC}"
if command -v jq &> /dev/null; then
    if ./test_jq.sh; then
        echo -e "${GREEN}✓ jq tests passed${NC}"
    else
        echo -e "${RED}✗ jq tests failed${NC}"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
else
    echo -e "${YELLOW}⊘ jq tests skipped (jq not installed)${NC}"
fi

# Test 3: Dual Plugin
echo -e "\n${BLUE}[3/3] Testing Dual Plugin...${NC}"
if ./test_dual.sh; then
    echo -e "${GREEN}✓ Dual plugin tests passed${NC}"
else
    echo -e "${RED}✗ Dual plugin tests failed${NC}"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
fi

# Final Summary
echo -e "\n${BLUE}=========================================="
echo "Final Test Summary"
echo -e "==========================================${NC}"

if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "${GREEN}All test suites passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}$TOTAL_FAILED test suite(s) failed ✗${NC}"
    exit 1
fi
