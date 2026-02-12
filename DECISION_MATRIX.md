# Plugin Implementation Decision Matrix

## Three Options

| Plugin | Best For | Pros | Cons |
|--------|----------|------|------|
| **plugin.py** (JSONPath) | Simple queries, no dependencies | ✅ Pure Python<br>✅ Fast startup<br>✅ Key extraction<br>✅ No external deps | ❌ Limited transformations<br>❌ Can't iterate object keys natively |
| **plugin_jq.py** (jq) | Complex transformations | ✅ Full jq power<br>✅ Native key iteration<br>✅ Complex filtering | ❌ Requires jq binary<br>❌ Subprocess overhead<br>❌ Slower startup |
| **plugin_dual.py** (Both) | Flexibility, migration | ✅ Best of both<br>✅ Auto-detection<br>✅ Easy migration<br>✅ One plugin for all | ⚠️ Larger codebase<br>⚠️ Still needs jq if using jq mode |

## Recommendation by Use Case

### Use Case: Teztnets Networks (Your Case)

**Goal:** Get network names, exclude aliases

**Option 1: JSONPath** ⭐ Recommended
```bash
# plugin.py (current)
JSON_PATH='$.*'
JSON_PATH_KEYS_ONLY='true'
JSON_PATH_EXCLUDE_IF_EXISTS='aliasOf'
```
✅ No dependencies, fast, clean solution

**Option 2: jq**
```bash
# plugin_jq.py
JSON_FILTER='to_entries | map(select(.value.aliasOf == null) | {name: .key})'
```
✅ More familiar syntax if you know jq

**Option 3: Dual** ⭐⭐ Best for teams
```bash
# plugin_dual.py - Use either syntax!
# Try JSONPath first, fall back to jq if needed
```
✅ Maximum flexibility

---

### Use Case: Simple Array Queries

**Example:** `$.data.items[*]`

**Recommendation:** `plugin.py` (JSONPath)
- JSONPath is perfect for this
- No need for jq complexity

---

### Use Case: Complex Transformations

**Example:** Create new object structure, multiple fields

**Recommendation:** `plugin_jq.py` (jq) or `plugin_dual.py`
- jq excels at transformations
- JSONPath would be awkward

---

### Use Case: Production Deployment

**Recommendation:** `plugin_dual.py`
- Supports both modes
- Easy to switch without redeployment
- Team can use preferred syntax

---

### Use Case: Air-gapped Environment

**Recommendation:** `plugin.py` (JSONPath)
- No external dependencies
- Easier to audit
- Smaller container image

---

## Migration Paths

### Path 1: Start Simple → Add Complexity
1. Start with `plugin.py` (JSONPath)
2. If you hit limitations → switch to `plugin_dual.py`
3. Add jq to container, use `JSON_FILTER` for complex cases

### Path 2: Use Both from Start
1. Deploy `plugin_dual.py`
2. Use JSONPath for 80% of queries
3. Use jq for the remaining 20% that need transformations

### Path 3: jq Only (Legacy)
1. Keep `plugin_jq.py`
2. Best if you already have jq expertise
3. Accept the subprocess overhead

---

## Performance Considerations

### Startup Time (until server is ready)

| Plugin | Cold Start | With Validation |
|--------|------------|-----------------|
| plugin.py | ~50ms | +200ms (network) |
| plugin_jq.py | ~100ms | +200ms (network) |
| plugin_dual.py | ~60ms | +200ms (network) |

### Request Latency (per API call)

| Plugin | Small Data (<10KB) | Large Data (>1MB) |
|--------|-------------------|-------------------|
| plugin.py | ~5ms | ~20ms |
| plugin_jq.py | ~15ms (subprocess) | ~50ms |
| plugin_dual.py | 5-15ms (depends) | 20-50ms |

---

## Container Size Impact

| Plugin | Base Image | With Dependencies | Total Size |
|--------|-----------|-------------------|-----------|
| plugin.py | python:3.9-alpine | +jsonpath-ng | ~50MB |
| plugin_jq.py | python:3.9-alpine | +jq | ~55MB |
| plugin_dual.py | python:3.9-alpine | +jsonpath-ng +jq | ~60MB |

---

## My Recommendation for You

Based on your Teztnets use case:

### Short-term: Use `plugin.py` ✅
- You've already implemented key extraction
- Works perfectly for your use case
- Simpler to maintain
- Faster performance

### Long-term: Migrate to `plugin_dual.py` 🚀
- Keeps your current functionality
- Adds flexibility for future use cases
- Easy to add jq later if needed
- Team can use preferred syntax

### Implementation Steps:

1. **Now:** Keep using `plugin.py`
   ```bash
   # Works perfectly for teztnets
   JSON_PATH='$.*'
   JSON_PATH_KEYS_ONLY='true'
   JSON_PATH_EXCLUDE_IF_EXISTS='aliasOf'
   ```

2. **Later:** When you need jq features
   ```bash
   # Replace plugin.py with plugin_dual.py
   cp plugin_dual.py plugin.py

   # Add jq to Dockerfile
   RUN apk add --no-cache jq

   # Now you can use either syntax!
   ```

3. **Dockerfile example:**
   ```dockerfile
   FROM python:3.9-alpine

   # Install dependencies
   RUN apk add --no-cache jq  # Only if using dual mode
   RUN pip install jsonpath-ng

   # Copy plugin
   COPY plugin_dual.py /plugin.py

   CMD ["/plugin.py"]
   ```

---

## Summary

**For your specific case (Teztnets):**
- ✅ **Use `plugin.py`** with JSONPath (current implementation)
- Keep `plugin_dual.py` as future option
- Keep `plugin_jq.py` for reference

**You get:**
- ✅ No jq dependency
- ✅ Fast performance
- ✅ Clean solution
- ✅ Easy to understand
- ✅ Exactly the output you need

**When to switch to dual mode:**
- When team wants jq syntax
- When you need complex transformations
- When migrating existing jq filters
