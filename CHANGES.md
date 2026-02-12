# Changes Made to JSON ApplicationSet Plugin

## Summary
Replaced the jq/subprocess-based JSON filtering with jsonpath-ng for better performance and reliability, and added fail-fast validation at startup.

## Key Changes

### 1. Replaced jq with jsonpath-ng
- **Before**: Used `subprocess.run(['jq', JSON_PATH], ...)` to filter JSON
- **After**: Use `jsonpath_ng.parse(JSON_PATH).find(data)` for native Python JSONPath filtering
- **Benefits**:
  - No external dependencies (jq no longer required)
  - Better performance (no subprocess overhead)
  - More reliable (no shell command parsing issues)
  - Pure Python implementation

### 2. Added Fail-Fast Validation
- Added `validate_json_source()` function that runs at startup
- Validates:
  - URL is reachable (with 30s timeout)
  - JSON is valid and parsable
  - JSONPath filter is valid and produces results
- Exits with error code 1 if any validation fails
- Provides detailed error messages to stderr

### 3. Other Improvements
- Changed default JSON_PATH from '.' to '$[*]' (more standard JSONPath)
- Improved error handling and parameter extraction logic
- Removed dependency on jq binary

## Testing
All existing tests pass:
- jsonpath-ng functionality tests
- Plugin implementation tests with various JSONPath expressions

## Backward Compatibility
The plugin maintains the same HTTP API and environment variable interface:
- `JSON_URL`: URL to fetch JSON from
- `JSON_PATH`: JSONPath expression to filter results
- Port: 4355 (unchanged)
