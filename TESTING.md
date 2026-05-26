# Testing Infrastructure Summary

Complete testing infrastructure for all three plugin variants with CI/CD integration.

## 📁 Test Structure

```
tests/
├── data/
│   ├── networks.json          # Object-of-objects fixture with one `aliasOf` entry
│   ├── simple_array.json      # Simple array test data
│   └── nested_object.json     # Nested object test data
├── test_jsonpath.sh           # Tests for plugin.py (JSONPath)
├── test_jq.sh                 # Tests for plugin_jq.py (jq)
├── test_dual.sh               # Tests for plugin_dual.py (both modes)
├── test_docker.sh             # Tests for Docker images
├── run_all_tests.sh           # Run all tests
└── README.md                  # Test documentation
```

## 🧪 Test Coverage

### Python Plugin Tests

#### test_jsonpath.sh
- ✅ Networks key extraction with filtering (5 items expected)
- ✅ Simple array query (3 items)
- ✅ Simple array with field-based filtering (2 items)
- ✅ Nested object key extraction (3 items)
- ✅ Nested object with exclusion filter (2 items)

#### test_jq.sh
- ✅ Networks jq transformation (5 items)
- ✅ Array mapping (3 items)
- ✅ Array filtering with jq select (2 items)
- ✅ Object to_entries conversion (3 items)
- ✅ Complex jq filtering (2 items)

#### test_dual.sh
- ✅ JSONPath mode: Networks (5 items)
- ✅ JSONPath mode: Simple array (3 items)
- ✅ JSONPath mode: Nested object (3 items)
- ✅ jq mode: Networks (5 items)
- ✅ jq mode: Array transform (3 items)
- ✅ jq mode: to_entries (3 items)

### Docker Image Tests

#### test_docker.sh
- ✅ JSONPath variant with Networks fixture
- ✅ jq variant with Networks fixture
- ✅ Dual variant in JSONPath mode
- ✅ Dual variant in jq mode

**Total Test Cases: 19**

## 🚀 Running Tests Locally

### Quick Start
```bash
# Run all tests
cd tests
./run_all_tests.sh
```

### Individual Test Suites
```bash
# Test JSONPath plugin
./test_jsonpath.sh

# Test jq plugin (requires jq)
./test_jq.sh

# Test dual mode plugin
./test_dual.sh

# Test Docker images (requires built images)
./test_docker.sh latest argocd-applicationset-json-plugin
```

### Prerequisites
```bash
# For Python tests
pip install jsonpath-ng

# For jq tests
brew install jq  # macOS
apt-get install jq  # Ubuntu/Debian

# For Docker tests
docker build -t argocd-applicationset-json-plugin:latest .
docker build -f Dockerfile.jq -t argocd-applicationset-json-plugin:jq-latest .
docker build -f Dockerfile.dual -t argocd-applicationset-json-plugin:dual-latest .
```

## 🔄 CI/CD Integration

### GitLab CI Pipeline

**File:** `.gitlab-ci.yml`

**Stages:**
1. **test** - Run Python plugin tests
   - Uses python:3.11-slim image
   - Installs jq, curl, jsonpath-ng
   - Runs `./run_all_tests.sh`
   - Produces test artifacts and logs

2. **build** - Build and test Docker images
   - Builds all three variants
   - Tests Docker images
   - Pushes to GitLab Container Registry (on main/MR)

3. **release** - Release to production
   - Tags with commit SHA
   - Pushes multiple tags (latest, variant-latest, etc.)

**Test Command:**
```yaml
script:
  - cd tests
  - ./run_all_tests.sh
```

**Triggers:**
- Every merge request
- Every push to main

### GitHub Actions Workflow

**File:** `.github/workflows/docker-build.yml`

**Jobs:**
1. **test** - Python plugin tests
   - Runs on ubuntu-latest
   - Python 3.11 setup
   - Installs jq and jsonpath-ng
   - Runs all test suites
   - Uploads test logs as artifacts

2. **build-and-push** - Build and test Docker images
   - Depends on `test` job passing
   - Matrix build (3 variants in parallel)
   - Tests each Docker image after build
   - Pushes to GitHub Container Registry

**Matrix Strategy:**
```yaml
matrix:
  variant:
    - jsonpath (Dockerfile)
    - jq (Dockerfile.jq)
    - dual (Dockerfile.dual)
```

**Triggers:**
- Pull requests to main
- Pushes to main

## 📊 Test Output Example

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

Test: Simple array - exclude items with 'skip' field
  JSON_PATH: $[*]
  ✓ PASSED: Got 2 items (expected 2)

Test: Nested object - extract environment names
  JSON_PATH: $.*
  ✓ PASSED: Got 3 items (expected 3)

Test: Nested object - exclude temporary environments
  JSON_PATH: $.*
  ✓ PASSED: Got 2 items (expected 2)

==========================================
Test Summary
==========================================
Passed: 5
Failed: 0
==========================================
```

## 🧩 Test Data Files

### networks.json
Object-of-objects fixture with 6 top-level entries (one has an `aliasOf` field).
Exercises key extraction and field-based filtering (5 results expected after exclusion).

### simple_array.json
```json
[
  {"name": "item1", "value": 100},
  {"name": "item2", "value": 200},
  {"name": "item3", "value": 300, "skip": true}
]
```
Tests:
- Array queries
- Field-based filtering (`skip` field)

### nested_object.json
```json
{
  "production": {"region": "us-east-1", "instances": 5},
  "staging": {"region": "us-west-2", "instances": 2},
  "development": {"region": "eu-west-1", "instances": 1, "temporary": true}
}
```
Tests:
- Key extraction from objects
- Filtering based on nested field (`temporary`)

## 🎯 Test Philosophy

1. **Realistic Shape** - Fixtures mirror real-world JSON structures (arrays, nested objects, alias entries)
2. **Multiple Scenarios** - Cover arrays, objects, filtering, transformations
3. **Both Modes** - Test JSONPath and jq separately and in dual mode
4. **End-to-End** - Test both Python scripts and Docker containers
5. **CI/CD First** - Tests block merges and deployments
6. **Fast Feedback** - Complete test suite runs in < 2 minutes

## 🔍 Adding New Tests

### 1. Add Test Data
```bash
# Create new test data file
cat > tests/data/my_test.json << 'EOF'
{"your": "data"}
EOF
```

### 2. Add Test Case
```bash
# In test_jsonpath.sh
run_test \
    "My new test description" \
    "file://$(pwd)/data/my_test.json" \
    '$[*]' \
    'false' \
    '' \
    5  # expected count
```

### 3. Run Tests
```bash
cd tests
./test_jsonpath.sh
```

## 📈 Test Metrics

| Metric | Value |
|--------|-------|
| Total Test Cases | 19 |
| Python Tests | 15 |
| Docker Tests | 4 |
| Test Data Files | 3 |
| Test Scripts | 4 |
| CI Pipelines | 2 |
| Coverage | All 3 variants |

## 🐛 Debugging Tests

### View Test Logs
```bash
# Local execution
cat /tmp/plugin.log
cat /tmp/plugin_jq.log
cat /tmp/plugin_dual.log

# CI artifacts (GitLab)
# Download from pipeline artifacts

# CI artifacts (GitHub)
# Download from Actions tab
```

### Run Single Test
```bash
# Modify test script to run only one test
# Comment out other run_test calls
./test_jsonpath.sh
```

### Test with Verbose Output
```bash
# Add to test script
set -x  # Enable bash debug mode
```

## ✅ Quality Gates

**Tests must pass before:**
- Merging pull requests
- Deploying to production
- Tagging releases
- Publishing Docker images

**Zero tolerance for:**
- Failing tests in main branch
- Broken Docker images
- Regression in functionality

## 🎉 Benefits

- ✅ Confidence in code changes
- ✅ Catch regressions early
- ✅ Verify all variants work
- ✅ Document expected behavior
- ✅ Enable safe refactoring
- ✅ Faster development cycles
