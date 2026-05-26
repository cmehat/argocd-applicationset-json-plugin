# ArgoCD ApplicationSet JSON Plugin

A generic ArgoCD `ApplicationSet` plugin that fetches JSON from a URL and applies JSONPath filtering to generate parameters.

## Authors

- Corentin Méhat 2026

## Features

- Fetch JSON data from any HTTP/HTTPS endpoint
- Apply JSONPath expressions to filter and transform data
- Extract object keys as parameter values
- Filter results based on field existence
- Generate ApplicationSet parameters dynamically
- Simple HTTP server with token-based authentication
- Fail-fast validation at startup

## Configuration

The plugin is configured via environment variables:

### Required
- `JSON_URL`: URL of the JSON endpoint to fetch

### JSONPath Mode (default and dual variants)
- `JSON_PATH`: JSONPath expression to filter the data (default: `$[*]`)
- `JSON_PATH_KEY_FIELD`: Field name for extracted keys (default: `name`)
- `JSON_PATH_KEYS_ONLY`: Return only `{name: "key"}` instead of full objects (default: `false`)
- `JSON_PATH_EXCLUDE_IF_EXISTS`: Exclude objects if this field exists (e.g., `aliasOf`)

### jq Mode (jq and dual variants)
- `JSON_FILTER`: jq filter expression (e.g., `to_entries | map(...)`)

### Dual Mode Only
- `JSON_FILTER_TYPE`: Explicit mode selection: `auto`, `jq`, or `jsonpath` (default: `auto`)

See [DUAL_MODE_GUIDE.md](DUAL_MODE_GUIDE.md) for complete dual mode documentation.

## Available Variants

This plugin is available in three variants:

| Variant | Dockerfile | Use Case | Dependencies |
|---------|------------|----------|--------------|
| **JSONPath** (default) | `Dockerfile` | Simple queries, no external deps | jsonpath-ng |
| **jq** | `Dockerfile.jq` | Complex transformations | jq binary |
| **Dual** | `Dockerfile.dual` | Both modes, maximum flexibility | jsonpath-ng + jq |

See [DECISION_MATRIX.md](DECISION_MATRIX.md) for detailed guidance on which version to use.

## Pre-built Images

All variants are automatically built and published via CI/CD:

### GitLab Container Registry
```bash
# JSONPath (default, recommended)
docker pull ${CI_REGISTRY_IMAGE}:latest
docker pull ${CI_REGISTRY_IMAGE}:jsonpath-latest

# jq-only
docker pull ${CI_REGISTRY_IMAGE}:jq-latest

# Dual mode
docker pull ${CI_REGISTRY_IMAGE}:dual-latest
```

### GitHub Container Registry
```bash
# JSONPath (default, recommended)
docker pull ghcr.io/OWNER/REPO:latest
docker pull ghcr.io/OWNER/REPO:jsonpath-latest

# jq-only
docker pull ghcr.io/OWNER/REPO:jq-latest

# Dual mode
docker pull ghcr.io/OWNER/REPO:dual-latest
```

## Building Locally

### JSONPath-only version (recommended)
```bash
docker build -t argocd-applicationset-json-plugin:jsonpath .
```

### jq-only version
```bash
docker build -f Dockerfile.jq -t argocd-applicationset-json-plugin:jq .
```

### Dual jq/JSONPath version
```bash
docker build -f Dockerfile.dual -t argocd-applicationset-json-plugin:dual .
```

## Running Locally

```bash
# Create a token file
echo "test-token" > token

# Run the plugin
docker run -p 4355:4355 \
  -e JSON_URL=https://example.com/data.json \
  -e JSON_PATH='$[*]' \
  -v $(pwd)/token:/var/run/argo/token:ro \
  argocd-applicationset-json-plugin:latest
```

## Testing

### Manual API Testing

```bash
curl http://localhost:4355/api/v1/getparams.execute \
  -H "Authorization: Bearer test-token" \
  -H "Content-Type: application/json" \
  -d '{
    "applicationSetName": "test",
    "input": {
      "parameters": {}
    }
  }'
```

### Automated Test Suite

The project includes comprehensive tests for all variants:

```bash
# Run all Python plugin tests
cd tests
./run_all_tests.sh

# Run specific variant tests
./test_jsonpath.sh  # JSONPath plugin
./test_jq.sh        # jq plugin (requires jq)
./test_dual.sh      # Dual mode plugin

# Test Docker images (after building)
./test_docker.sh latest argocd-applicationset-json-plugin
```

**Test Coverage:**
- ✅ JSONPath queries and filtering
- ✅ jq transformations
- ✅ Key extraction from objects
- ✅ Field-based filtering
- ✅ Docker image functionality
- ✅ Both modes in dual variant

See [tests/README.md](tests/README.md) for detailed testing documentation.

**CI/CD Testing:**
- Tests run automatically on every PR and commit
- All three variants are tested before deployment
- Python plugins tested in isolation
- Docker images tested end-to-end

## Example Use Cases

### Object-of-Objects (Extract Keys with Filtering)

Extract top-level keys of an object, excluding entries that are aliases of others:

```yaml
env:
  - name: JSON_URL
    value: "https://example.com/networks.json"
  - name: JSON_PATH
    value: "$.*"
  - name: JSON_PATH_KEYS_ONLY
    value: "true"
  - name: JSON_PATH_EXCLUDE_IF_EXISTS
    value: "aliasOf"
```

Given input:
```json
{
  "alpha":         { "category": "primary" },
  "beta":          { "category": "primary" },
  "gamma-staging": { "aliasOf": "gamma" },
  "gamma":         { "category": "primary" },
  "delta":         { "category": "primary" },
  "epsilon":       { "category": "primary" }
}
```

**Result:**
```json
[
  {"name": "alpha"},
  {"name": "beta"},
  {"name": "gamma"},
  {"name": "delta"},
  {"name": "epsilon"}
]
```

This is equivalent to the jq filter: `to_entries | map(select(.value.aliasOf == null) | {name: .key})`

### Generic List of Items

```yaml
env:
  - name: JSON_URL
    value: "https://api.example.com/items"
  - name: JSON_PATH
    value: "$.data.items[*]"
```

### GitHub Repositories (Filter by Property)

```yaml
env:
  - name: JSON_URL
    value: "https://api.github.com/users/octocat/repos"
  - name: JSON_PATH
    value: "$[?(@.private == false)]"
```

## Development

### Pre-commit Hooks

Install pre-commit hooks:

```bash
pip install pre-commit
pre-commit install
```

Run hooks manually:

```bash
pre-commit run --all-files
```

## Deployment

A Helm chart for this plugin lives at [cmehat/argocd-applicationset-json-plugin-chart](https://github.com/cmehat/argocd-applicationset-json-plugin-chart). It packages the plugin as an ArgoCD `ApplicationSet` plugin generator (Deployment + Service + ConfigMap + Secret) and ships an end-to-end example you can apply against any ArgoCD ≥ 2.3 install.

## License

MIT
