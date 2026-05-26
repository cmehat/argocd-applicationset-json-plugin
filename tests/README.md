# Test Suite

This directory contains the test suite for all plugin variants.

## Test Data

- `data/networks.json` - Object-of-objects fixture with one entry containing an `aliasOf` field (exercises key extraction + filtering)
- `data/simple_array.json` - Simple array for basic tests
- `data/nested_object.json` - Nested object for key extraction tests

## Test Scripts

### Python Plugin Tests

Run tests directly against Python scripts:

```bash
# Test JSONPath plugin
cd tests
./test_jsonpath.sh

# Test jq plugin (requires jq installed)
./test_jq.sh

# Test dual plugin
./test_dual.sh
```

### Docker Image Tests

Test built Docker images:

```bash
# Build images first
docker build -t argocd-applicationset-json-plugin:latest .
docker build -f Dockerfile.jq -t argocd-applicationset-json-plugin:jq-latest .
docker build -f Dockerfile.dual -t argocd-applicationset-json-plugin:dual-latest .

# Run tests
cd tests
./test_docker.sh latest argocd-applicationset-json-plugin
```

### Run All Tests

```bash
cd tests
./run_all_tests.sh
```

## Test Coverage

Each test script validates:

### JSONPath Tests (`test_jsonpath.sh`)
- ✅ Key extraction from objects (`$.*`)
- ✅ Filtering based on field existence
- ✅ Array queries
- ✅ Nested object traversal
- ✅ `JSON_PATH_KEYS_ONLY` mode
- ✅ `JSON_PATH_EXCLUDE_IF_EXISTS` filtering

### jq Tests (`test_jq.sh`)
- ✅ `to_entries` transformation
- ✅ Complex filtering with `select()`
- ✅ Object key extraction
- ✅ Array mapping and transformation

### Dual Plugin Tests (`test_dual.sh`)
- ✅ Auto-detection of JSONPath mode
- ✅ Auto-detection of jq mode
- ✅ Both modes produce correct results
- ✅ Graceful handling when jq is not installed

### Docker Tests (`test_docker.sh`)
- ✅ JSONPath variant container
- ✅ jq variant container
- ✅ Dual variant in JSONPath mode
- ✅ Dual variant in jq mode
- ✅ File mount and data access

## CI/CD Integration

Tests are automatically run in:

- **GitLab CI** - `.gitlab-ci.yml` (test stage)
- **GitHub Actions** - `.github/workflows/docker-build.yml` (test job)

## Requirements

### For Python Tests
- Python 3.9+
- jsonpath-ng: `pip install jsonpath-ng`
- jq (for jq tests): `brew install jq` or `apt-get install jq`

### For Docker Tests
- Docker installed and running
- Built images with appropriate tags

## Test Output

Tests use color-coded output:
- 🟢 Green: Test passed
- 🔴 Red: Test failed
- 🟡 Yellow: Test skipped (missing dependencies)

Example output:
```
==========================================
Testing JSONPath Plugin (plugin.py)
==========================================

Test: Networks - Extract keys, exclude aliases
  JSON_PATH: $.*
  ✓ PASSED: Got 5 items (expected 5)

Test: Simple array - all items
  JSON_PATH: $[*]
  ✓ PASSED: Got 3 items (expected 3)

==========================================
Test Summary
==========================================
Passed: 5
Failed: 0
==========================================
```

## Adding New Tests

To add a new test case:

1. Add test data to `data/` directory
2. Add test case to appropriate script (`test_*.sh`)
3. Use the `run_test` function with:
   - Test name
   - JSON URL (use `file://$(pwd)/data/yourfile.json`)
   - Filter expression
   - Expected result count

Example:
```bash
run_test \
    "My new test" \
    "file://$(pwd)/data/mydata.json" \
    '$[*].name' \
    10
```

## Troubleshooting

### Port Already in Use
If you get "port 4355 already in use":
```bash
# Kill any running plugin processes
pkill -f "python.*plugin.py"
```

### File URL Not Working
Make sure to use absolute paths:
```bash
# Good
JSON_URL="file://$(pwd)/data/networks.json"

# Bad
JSON_URL="file://data/networks.json"
```

### jq Tests Failing
Ensure jq is installed:
```bash
# macOS
brew install jq

# Ubuntu/Debian
apt-get install jq

# Alpine
apk add jq
```
