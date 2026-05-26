#!/bin/bash
set -e

echo "=========================================="
echo "Testing Docker Images"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0
PASSED=0

# Function to test docker image
test_docker_image() {
    local variant="$1"
    local image="$2"
    local mode="$3"
    local env_vars="$4"
    local expected_count="$5"

    echo ""
    echo "Test: Docker $variant variant ($mode mode)"
    echo "  Image: $image"

    # Start container
    CONTAINER_ID=$(docker run -d -p 4355:4355 \
        -v "$(pwd)/data:/data:ro" \
        $env_vars \
        "$image")

    # Wait for container to be ready
    echo "  Waiting for container to start..."
    sleep 5

    # Test the endpoint
    RESULT=$(curl -s http://localhost:4355/api/v1/getparams.execute \
        -H "Authorization: Bearer default-token" \
        -H "Content-Type: application/json" \
        -d '{"applicationSetName": "test", "input": {"parameters": {}}}' || echo '{"error": "connection failed"}')

    # Stop and remove container
    docker stop "$CONTAINER_ID" > /dev/null 2>&1
    docker rm "$CONTAINER_ID" > /dev/null 2>&1

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

# Determine image tag to test
IMAGE_TAG="${1:-latest}"
IMAGE_BASE="${2:-argocd-applicationset-json-plugin}"

echo "Testing images with tag: $IMAGE_TAG"
echo "Image base name: $IMAGE_BASE"

# Test JSONPath variant
if docker image inspect "${IMAGE_BASE}:${IMAGE_TAG}" > /dev/null 2>&1; then
    test_docker_image \
        "JSONPath" \
        "${IMAGE_BASE}:${IMAGE_TAG}" \
        "JSONPath" \
        "-e JSON_URL=file:///data/networks.json -e JSON_PATH='\$.*' -e JSON_PATH_KEYS_ONLY=true -e JSON_PATH_EXCLUDE_IF_EXISTS=aliasOf" \
        5
else
    echo -e "${YELLOW}Skipping JSONPath variant: image not found${NC}"
fi

# Test jq variant
if docker image inspect "${IMAGE_BASE}:jq-${IMAGE_TAG}" > /dev/null 2>&1; then
    test_docker_image \
        "jq" \
        "${IMAGE_BASE}:jq-${IMAGE_TAG}" \
        "jq" \
        "-e JSON_URL=file:///data/networks.json -e JSON_FILTER='to_entries | map(select(.value.aliasOf == null) | {name: .key})'" \
        5
else
    echo -e "${YELLOW}Skipping jq variant: image not found${NC}"
fi

# Test dual variant - JSONPath mode
if docker image inspect "${IMAGE_BASE}:dual-${IMAGE_TAG}" > /dev/null 2>&1; then
    test_docker_image \
        "Dual (JSONPath mode)" \
        "${IMAGE_BASE}:dual-${IMAGE_TAG}" \
        "JSONPath" \
        "-e JSON_URL=file:///data/networks.json -e JSON_PATH='\$.*' -e JSON_PATH_KEYS_ONLY=true -e JSON_PATH_EXCLUDE_IF_EXISTS=aliasOf" \
        5

    # Test dual variant - jq mode
    test_docker_image \
        "Dual (jq mode)" \
        "${IMAGE_BASE}:dual-${IMAGE_TAG}" \
        "jq" \
        "-e JSON_URL=file:///data/networks.json -e JSON_FILTER='to_entries | map(select(.value.aliasOf == null) | {name: .key})'" \
        5
else
    echo -e "${YELLOW}Skipping dual variant: image not found${NC}"
fi

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

if [ $PASSED -eq 0 ]; then
    echo -e "${YELLOW}Warning: No tests were run. Build images first.${NC}"
    exit 1
fi

exit 0
