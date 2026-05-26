# Dual jq/JSONPath Plugin Guide

The `plugin_dual.py` supports both **jq** (powerful transformations) and **JSONPath** (efficient queries) filters.

## Quick Decision Guide

**Use jq when:**
- ✅ You need complex transformations (`to_entries`, `map`, etc.)
- ✅ You need to access object keys as values
- ✅ You need advanced filtering with custom logic
- ❌ Requires jq to be installed

**Use JSONPath when:**
- ✅ You want pure Python (no external dependencies)
- ✅ You have simple queries (`$[*]`, `$.data`, etc.)
- ✅ You want better performance (no subprocess)
- ❌ Limited transformation capabilities

## Configuration

### Mode Selection

The plugin auto-detects which mode to use, or you can explicitly set it:

```yaml
env:
  # Auto-detect (default)
  - name: JSON_FILTER_TYPE
    value: "auto"  # or "jq" or "jsonpath"
```

**Auto-detection rules:**
1. If only `JSON_FILTER` is set → use **jq**
2. If only `JSON_PATH` is set → use **JSONPath**
3. If both are set → use **jq** (preferred)
4. If neither is set → use **JSONPath** with default `$[*]`

### Environment Variables

| Variable | Mode | Description |
|----------|------|-------------|
| `JSON_URL` | Both | URL to fetch JSON from (required) |
| `JSON_FILTER` | jq | jq filter expression |
| `JSON_PATH` | JSONPath | JSONPath expression |
| `JSON_FILTER_TYPE` | Both | Explicit mode: `auto`, `jq`, `jsonpath` |
| `JSON_PATH_KEY_FIELD` | JSONPath | Field name for extracted keys (default: `name`) |
| `JSON_PATH_KEYS_ONLY` | JSONPath | Return only `{name: key}` (default: `false`) |
| `JSON_PATH_EXCLUDE_IF_EXISTS` | JSONPath | Exclude if field exists |

## Examples

### Example 1: jq Mode - Extract Object Keys, Skip Aliases

```bash
export JSON_URL='https://example.com/networks.json'
export JSON_FILTER='to_entries | map(select(.value.aliasOf == null) | {name: .key})'
./plugin_dual.py
```

**Output:**
```json
[
  {"name": "alpha"},
  {"name": "beta"},
  {"name": "gamma"},
  {"name": "delta"},
  {"name": "epsilon"}
]
```

### Example 2: JSONPath Mode - Same Result

```bash
export JSON_URL='https://example.com/networks.json'
export JSON_PATH='$.*'
export JSON_PATH_KEYS_ONLY='true'
export JSON_PATH_EXCLUDE_IF_EXISTS='aliasOf'
./plugin_dual.py
```

**Output:** Same as jq mode!

### Example 3: JSONPath Mode - GitHub Repos

```bash
export JSON_URL='https://api.github.com/users/octocat/repos'
export JSON_PATH='$[?(@.private == false)].name'
./plugin_dual.py
```

### Example 4: jq Mode - Complex Transformation

```bash
export JSON_URL='https://api.example.com/data'
export JSON_FILTER='.items | map({name: .id, region: .location.region, tags: .metadata.tags | join(",")})'
./plugin_dual.py
```

## Kubernetes Deployment

### Using jq Mode

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: json-plugin-config
data:
  JSON_URL: "https://example.com/networks.json"
  JSON_FILTER: 'to_entries | map(select(.value.aliasOf == null) | {name: .key})'
  JSON_FILTER_TYPE: "jq"  # Explicit
```

### Using JSONPath Mode

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: json-plugin-config
data:
  JSON_URL: "https://example.com/networks.json"
  JSON_PATH: "$.*"
  JSON_PATH_KEYS_ONLY: "true"
  JSON_PATH_EXCLUDE_IF_EXISTS: "aliasOf"
  JSON_FILTER_TYPE: "jsonpath"  # Explicit
```

## Migration Guide

### From plugin_original.py (jq-only)

No changes needed! Just replace the plugin file:

```bash
cp plugin_dual.py plugin.py
```

Your `JSON_FILTER` variables will work as-is.

### From plugin.py (JSONPath-only)

No changes needed! Your `JSON_PATH` variables will work as-is.

### Adding jq support to existing JSONPath deployment

1. Install jq in your container:
   ```dockerfile
   RUN apk add --no-cache jq  # Alpine
   # or
   RUN apt-get update && apt-get install -y jq  # Debian/Ubuntu
   ```

2. Update environment variables:
   ```yaml
   env:
     - name: JSON_FILTER  # Add this
       value: "your jq filter"
     # Keep existing JSON_PATH vars as fallback
   ```

## Performance Comparison

| Aspect | jq | JSONPath |
|--------|----|----|
| Startup time | Slower (subprocess) | Fast (pure Python) |
| Memory usage | Higher | Lower |
| Query speed | Fast for small data | Very fast |
| Transformation | ✅ Full power | ⚠️ Limited |
| Dependencies | Requires jq binary | None |

## Troubleshooting

### "jq is not installed"

**Solution:** Either install jq in your container or switch to JSONPath mode:

```bash
export JSON_FILTER_TYPE='jsonpath'
```

### "Parse error" with jq filter

**Solution:** Test your jq filter locally first:

```bash
curl https://your-url.com/data.json | jq 'your-filter'
```

### JSONPath doesn't support my transformation

**Solution:** Switch to jq mode or simplify your query.

## Best Practices

1. **Development**: Use JSONPath for simple queries (faster iteration)
2. **Production**: Use jq if you need complex transformations
3. **Performance-critical**: Use JSONPath (no subprocess overhead)
4. **Always validate**: The plugin validates at startup and fails fast
5. **Version control**: Commit your filter expressions separately for testing

## Switching Between Modes

You can switch modes at runtime:

```bash
# Try JSONPath first
JSON_PATH='$.*' ./plugin_dual.py

# If that doesn't work, use jq
JSON_FILTER='to_entries | map(...)' ./plugin_dual.py
```

The plugin will automatically detect and use the appropriate mode!
