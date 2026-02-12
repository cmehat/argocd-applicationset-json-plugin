# CI/CD Pipeline Documentation

This project uses both GitLab CI and GitHub Actions to automatically build and publish Docker images for all three plugin variants.

## Available Images

### Image Variants

| Variant | Base Plugin | Description | Size |
|---------|-------------|-------------|------|
| **jsonpath** (default) | plugin.py | Pure Python, no external deps | ~50MB |
| **jq** | plugin_jq.py | jq-only, requires jq binary | ~55MB |
| **dual** | plugin_dual.py | Both jq and JSONPath support | ~60MB |

### Image Tags

Each variant is tagged in multiple ways for flexibility:

#### On main branch (releases)
- `latest` - Latest JSONPath variant (default, recommended)
- `<sha>` - Specific commit of JSONPath variant
- `jsonpath-latest` - Latest JSONPath variant
- `jsonpath-<sha>` - Specific commit of JSONPath variant
- `jq-latest` - Latest jq-only variant
- `jq-<sha>` - Specific commit of jq-only variant
- `dual-latest` - Latest dual-mode variant
- `dual-<sha>` - Specific commit of dual-mode variant

#### On merge requests / pull requests
- `mr-<number>` - JSONPath variant for MR testing (GitLab only)
- `jsonpath-mr-<number>` - JSONPath variant for MR
- `jq-mr-<number>` - jq variant for MR
- `dual-mr-<number>` - Dual variant for MR
- `<variant>-pr-<number>` - For GitHub PRs

## GitLab CI/CD

### Pipeline Stages

1. **Build Stage** (runs on MRs and main)
   - Builds all three variants
   - For MRs: Pushes test images tagged with MR number
   - For main: Only builds, doesn't push

2. **Release Stage** (runs on main only)
   - Builds all three variants
   - Tags with commit SHA and `-latest`
   - Pushes all images to GitLab Container Registry

### Configuration

File: `.gitlab-ci.yml`

**Variables:**
- `IMAGE_NAME`: `${CI_REGISTRY_IMAGE}` (automatically set by GitLab)
- `DOCKER_TLS_CERTDIR`: Empty (for docker:dind)

**Images Built:**
```bash
# JSONPath variant
${CI_REGISTRY_IMAGE}:latest
${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHORT_SHA}
${CI_REGISTRY_IMAGE}:jsonpath-latest
${CI_REGISTRY_IMAGE}:jsonpath-${CI_COMMIT_SHORT_SHA}

# jq variant
${CI_REGISTRY_IMAGE}:jq-latest
${CI_REGISTRY_IMAGE}:jq-${CI_COMMIT_SHORT_SHA}

# Dual variant
${CI_REGISTRY_IMAGE}:dual-latest
${CI_REGISTRY_IMAGE}:dual-${CI_COMMIT_SHORT_SHA}
```

### Usage

Pull from GitLab registry:
```bash
docker pull ${CI_REGISTRY_IMAGE}:latest              # JSONPath (recommended)
docker pull ${CI_REGISTRY_IMAGE}:jq-latest           # jq-only
docker pull ${CI_REGISTRY_IMAGE}:dual-latest         # Dual mode
```

## GitHub Actions

### Workflow

File: `.github/workflows/docker-build.yml`

**Triggers:**
- Push to `main` branch
- Pull requests to `main` branch

**Matrix Strategy:**
Builds all three variants in parallel using a matrix:
```yaml
variant:
  - jsonpath (Dockerfile)
  - jq (Dockerfile.jq)
  - dual (Dockerfile.dual)
```

**Images Built:**
```bash
# JSONPath variant (default)
ghcr.io/${OWNER}/${REPO}:latest
ghcr.io/${OWNER}/${REPO}:${SHA}
ghcr.io/${OWNER}/${REPO}:jsonpath-latest
ghcr.io/${OWNER}/${REPO}:jsonpath-${SHA}

# jq variant
ghcr.io/${OWNER}/${REPO}:jq-latest
ghcr.io/${OWNER}/${REPO}:jq-${SHA}

# Dual variant
ghcr.io/${OWNER}/${REPO}:dual-latest
ghcr.io/${OWNER}/${REPO}:dual-${SHA}
```

### Features

- **Build cache**: Uses GitHub Actions cache for faster builds
- **Matrix build**: Builds all variants in parallel
- **Auto-tagging**: Automatically generates appropriate tags
- **GHCR integration**: Publishes to GitHub Container Registry

### Usage

Pull from GitHub Container Registry:
```bash
docker pull ghcr.io/OWNER/REPO:latest              # JSONPath (recommended)
docker pull ghcr.io/OWNER/REPO:jq-latest           # jq-only
docker pull ghcr.io/OWNER/REPO:dual-latest         # Dual mode
```

## Selecting the Right Image

### For Production (Recommended)
```bash
# Use the default JSONPath variant
docker pull <registry>:latest
# or explicitly
docker pull <registry>:jsonpath-latest
```

**Reasons:**
- ✅ No external dependencies
- ✅ Fastest performance
- ✅ Smallest image size
- ✅ Pure Python
- ✅ Works for 80% of use cases

### For Complex Transformations
```bash
# Use the jq variant
docker pull <registry>:jq-latest
```

**When:**
- You need jq's transformation capabilities
- You're migrating existing jq filters
- You need `to_entries`, `group_by`, etc.

### For Maximum Flexibility
```bash
# Use the dual variant
docker pull <registry>:dual-latest
```

**When:**
- You want both options available
- Different teams prefer different syntax
- You're experimenting with both modes
- Migration period from jq to JSONPath

## Testing Images Locally

### Pull and Test JSONPath Variant
```bash
docker pull <registry>:jsonpath-latest

docker run -p 4355:4355 \
  -e JSON_URL=https://teztnets.com/teztnets.json \
  -e JSON_PATH='$.*' \
  -e JSON_PATH_KEYS_ONLY=true \
  -e JSON_PATH_EXCLUDE_IF_EXISTS=aliasOf \
  <registry>:jsonpath-latest
```

### Pull and Test jq Variant
```bash
docker pull <registry>:jq-latest

docker run -p 4355:4355 \
  -e JSON_URL=https://teztnets.com/teztnets.json \
  -e JSON_FILTER='to_entries | map(select(.value.aliasOf == null) | {name: .key})' \
  <registry>:jq-latest
```

### Pull and Test Dual Variant
```bash
docker pull <registry>:dual-latest

# Use JSONPath mode
docker run -p 4355:4355 \
  -e JSON_URL=https://teztnets.com/teztnets.json \
  -e JSON_PATH='$.*' \
  -e JSON_PATH_KEYS_ONLY=true \
  -e JSON_PATH_EXCLUDE_IF_EXISTS=aliasOf \
  <registry>:dual-latest

# Or use jq mode
docker run -p 4355:4355 \
  -e JSON_URL=https://teztnets.com/teztnets.json \
  -e JSON_FILTER='to_entries | map(select(.value.aliasOf == null) | {name: .key})' \
  <registry>:dual-latest
```

## Troubleshooting

### GitLab CI Issues

**Build fails with "docker: command not found"**
- Ensure `docker:dind` service is enabled
- Check `DOCKER_TLS_CERTDIR` is set correctly

**Registry authentication fails**
- Verify `CI_REGISTRY_USER` and `CI_REGISTRY_PASSWORD` are available
- Check project Container Registry is enabled

### GitHub Actions Issues

**Permission denied when pushing**
- Ensure workflow has `packages: write` permission
- Verify GHCR is enabled for the repository

**Build cache misses**
- Check if `cache-from` and `cache-to` are configured
- Verify GitHub Actions cache is not full

## Build Time Comparison

| Variant | First Build | Cached Build | Image Size |
|---------|-------------|--------------|------------|
| JSONPath | ~2min | ~30s | ~50MB |
| jq | ~2.5min | ~35s | ~55MB |
| Dual | ~3min | ~40s | ~60MB |

## Security Scanning

Both CI/CD pipelines can be extended with security scanning:

### Add to GitLab CI
```yaml
security_scan:
  stage: test
  image: aquasec/trivy:latest
  script:
    - trivy image ${IMAGE_NAME}:latest
```

### Add to GitHub Actions
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/${{ github.repository }}:latest
```

## References

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Build Best Practices](https://docs.docker.com/develop/dev-best-practices/)
