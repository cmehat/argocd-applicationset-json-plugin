# ArgoCD ApplicationSet JSON Plugin

A generic ArgoCD ApplicationSet plugin that fetches JSON from a URL and applies JSONPath filtering to generate parameters.

## Authors

- cm

## Features

- Fetch JSON data from any HTTP/HTTPS endpoint
- Apply JSONPath expressions to filter and transform data
- Generate ApplicationSet parameters dynamically
- Simple HTTP server with token-based authentication

## Configuration

The plugin is configured via environment variables:

- `JSON_URL`: URL of the JSON endpoint to fetch (required)
- `JSON_PATH`: JSONPath expression to filter the data (default: `$[*]`)

## Building

```bash
docker build -t argocd-applicationset-json-plugin:latest .
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

## Example Use Cases

### Teztnets Networks

```yaml
env:
  - name: JSON_URL
    value: "https://teztnets.com/teztnets.json"
  - name: JSON_PATH
    value: "$[?(!@.aliasOf)]"
```

### Generic List of Items

```yaml
env:
  - name: JSON_URL
    value: "https://api.example.com/items"
  - name: JSON_PATH
    value: "$.data.items[*]"
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

Use the Helm chart available at `charts/argocd-applicationset-plugin-teztnets` to deploy this plugin to your Kubernetes cluster.

## License

MIT
