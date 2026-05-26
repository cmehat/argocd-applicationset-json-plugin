#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Testing Docker Images"
echo "=========================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0
PASSED=0

# Run one docker-based test.
#
# Usage:
#   test_docker_image <label> <image> <mode> <expected_count> <-e KEY=VAL ...>
#
# Env-var args are passed through as separate positional args so they can
# survive `docker run` argv parsing without inheriting shell-quoting artefacts
# (the previous embed-as-a-single-string approach leaked literal single quotes
# into the env-var values; see GHA run #26466616160 for the failure mode).
test_docker_image() {
    local variant="$1"
    local image="$2"
    local mode="$3"
    local expected_count="$4"
    shift 4
    local env_args=("$@")

    echo ""
    echo "Test: Docker $variant variant ($mode mode)"
    echo "  Image: $image"

    local container_id
    container_id=$(docker run -d -p 4355:4355 \
        -v "$(pwd)/data:/data:ro" \
        "${env_args[@]}" \
        "$image")

    # Diagnostic: print the env vars the plugin will see. Helpful when a
    # docker-side env-var quoting bug masquerades as a plugin filter bug.
    echo "  Container env:"
    docker inspect --format '{{range .Config.Env}}    {{println .}}{{end}}' "$container_id" 2>/dev/null | grep -E '^    (JSON_|PATH|HOME)' || true

    # shellcheck disable=SC2329  # invoked via trap, not directly
    cleanup() {
        docker stop "$container_id" >/dev/null 2>&1 || true
        docker rm "$container_id" >/dev/null 2>&1 || true
    }
    trap cleanup RETURN

    # Wait up to 15s for the plugin to start listening.
    local ready=false
    for _ in $(seq 1 30); do
        if curl -sf -o /dev/null --max-time 1 http://localhost:4355/api/v1/getparams.execute \
            -H "Authorization: Bearer default-token" \
            -H "Content-Type: application/json" \
            -d '{"applicationSetName":"test","input":{"parameters":{}}}' 2>/dev/null; then
            ready=true
            break
        fi
        sleep 0.5
    done
    if [[ "$ready" != "true" ]]; then
        # Still attempt the call so the diagnostic output is captured.
        echo "  (warning: plugin not responsive after 15s; calling anyway)"
    fi

    local result
    result=$(curl -s http://localhost:4355/api/v1/getparams.execute \
        -H "Authorization: Bearer default-token" \
        -H "Content-Type: application/json" \
        -d '{"applicationSetName":"test","input":{"parameters":{}}}' \
        || echo '{"error":"connection failed"}')

    if echo "$result" | grep -q '"error"'; then
        echo -e "  ${RED}✗ FAILED${NC}: Got error"
        echo "  Error: $result"
        echo "  --- container logs ---"
        docker logs "$container_id" 2>&1 | tail -20 | sed 's/^/    /'
        FAILED=$((FAILED + 1))
        return 1
    fi

    local count
    count=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['output']['parameters']))" 2>/dev/null || echo "0")

    if [[ "$count" -eq "$expected_count" ]]; then
        echo -e "  ${GREEN}✓ PASSED${NC}: Got $count items (expected $expected_count)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAILED${NC}: Got $count items (expected $expected_count)"
        echo "  Result: $result"
        echo "  --- container logs ---"
        docker logs "$container_id" 2>&1 | tail -20 | sed 's/^/    /'
        FAILED=$((FAILED + 1))
        return 1
    fi
}

cd "$(dirname "$0")"

IMAGE_TAG="${1:-latest}"
IMAGE_BASE="${2:-argocd-applicationset-json-plugin}"

echo "Testing images with tag: $IMAGE_TAG"
echo "Image base name: $IMAGE_BASE"

JSONPATH_ENV=(
    -e "JSON_URL=file:///data/networks.json"
    -e 'JSON_PATH=$.*'
    -e "JSON_PATH_KEYS_ONLY=true"
    -e "JSON_PATH_EXCLUDE_IF_EXISTS=aliasOf"
)

JQ_ENV=(
    -e "JSON_URL=file:///data/networks.json"
    -e 'JSON_FILTER=to_entries | map(select(.value.aliasOf == null) | {name: .key})'
)

# JSONPath variant
if docker image inspect "${IMAGE_BASE}:${IMAGE_TAG}" >/dev/null 2>&1; then
    test_docker_image "JSONPath" "${IMAGE_BASE}:${IMAGE_TAG}" "JSONPath" 5 "${JSONPATH_ENV[@]}" || true
else
    echo -e "${YELLOW}Skipping JSONPath variant: image not found${NC}"
fi

# jq variant
if docker image inspect "${IMAGE_BASE}:jq-${IMAGE_TAG}" >/dev/null 2>&1; then
    test_docker_image "jq" "${IMAGE_BASE}:jq-${IMAGE_TAG}" "jq" 5 "${JQ_ENV[@]}" || true
else
    echo -e "${YELLOW}Skipping jq variant: image not found${NC}"
fi

# Dual variant — both modes
if docker image inspect "${IMAGE_BASE}:dual-${IMAGE_TAG}" >/dev/null 2>&1; then
    test_docker_image "Dual (JSONPath mode)" "${IMAGE_BASE}:dual-${IMAGE_TAG}" "JSONPath" 5 "${JSONPATH_ENV[@]}" || true
    test_docker_image "Dual (jq mode)" "${IMAGE_BASE}:dual-${IMAGE_TAG}" "jq" 5 "${JQ_ENV[@]}" || true
else
    echo -e "${YELLOW}Skipping dual variant: image not found${NC}"
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "=========================================="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

if [[ $PASSED -eq 0 ]]; then
    echo -e "${YELLOW}Warning: No tests were run. Build images first.${NC}"
    exit 1
fi

exit 0
