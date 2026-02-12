# Docker Image Versioning Guide

Complete guide for managing Docker image versions and tags.

## 🏷️ Current Tagging Strategy

### Standard Build (No Versioning)
Current `.gitlab-ci.yml` and `.github/workflows/docker-build.yml` use:

**On main branch:**
```
latest                      # JSONPath default
<sha>                       # Commit SHA
jsonpath-latest
jsonpath-<sha>
jq-latest
jq-<sha>
dual-latest
dual-<sha>
```

**On merge requests/PRs:**
```
mr-<number>                 # GitLab MR
pr-<number>                 # GitHub PR
jsonpath-mr-<number>
jq-mr-<number>
dual-mr-<number>
```

## 📌 Semantic Versioning Strategy

### With Version Tags (Recommended for Production)
Use `.gitlab-ci-versioned.yml` and `.github/workflows/docker-build-versioned.yml`:

**On git tag `v1.2.3`:**
```
1.2.3                       # Full version (JSONPath default)
1.2                         # Minor version
1                           # Major version

jsonpath-1.2.3              # Variant-specific full
jsonpath-1.2                # Variant-specific minor
jsonpath-1                  # Variant-specific major

jq-1.2.3
jq-1.2
jq-1

dual-1.2.3
dual-1.2
dual-1
```

### Version Tag Format
Follow semantic versioning: `v<major>.<minor>.<patch>`

Examples:
- `v1.0.0` - First stable release
- `v1.1.0` - Minor feature addition
- `v1.1.1` - Patch/bug fix
- `v2.0.0` - Breaking changes

## 🚀 How to Create a Release

### Method 1: Using Git Tags (Recommended)

```bash
# 1. Ensure you're on main with latest code
git checkout main
git pull origin main

# 2. Create and push a version tag
git tag -a v1.0.0 -m "Release version 1.0.0

- Add comprehensive test suite
- Add multi-variant Docker builds
- Add CI/CD integration
"

git push origin v1.0.0

# 3. CI/CD automatically builds and tags:
#    - 1.0.0, 1.0, 1
#    - jsonpath-1.0.0, jsonpath-1.0, jsonpath-1
#    - jq-1.0.0, jq-1.0, jq-1
#    - dual-1.0.0, dual-1.0, dual-1
```

### Method 2: Using GitHub Releases

```bash
# 1. Create tag locally
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0

# 2. Go to GitHub → Releases → Create Release
#    - Select tag: v1.0.0
#    - Title: Version 1.0.0
#    - Description: Release notes
#    - Publish release

# 3. CI/CD builds and publishes automatically
```

### Method 3: GitLab Release

```bash
# 1. Push tag
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0

# 2. In GitLab: Project → Releases → New Release
#    - Tag: v1.0.0
#    - Release notes: Changelog
#    - Create release

# 3. CI/CD pipeline triggers
```

## 📦 Image Tag Examples

### Example 1: Release v1.2.3

**What gets published:**

GitLab Container Registry:
```bash
${CI_REGISTRY_IMAGE}:1.2.3
${CI_REGISTRY_IMAGE}:1.2
${CI_REGISTRY_IMAGE}:1
${CI_REGISTRY_IMAGE}:jsonpath-1.2.3
${CI_REGISTRY_IMAGE}:jsonpath-1.2
${CI_REGISTRY_IMAGE}:jsonpath-1
${CI_REGISTRY_IMAGE}:jq-1.2.3
${CI_REGISTRY_IMAGE}:jq-1.2
${CI_REGISTRY_IMAGE}:jq-1
${CI_REGISTRY_IMAGE}:dual-1.2.3
${CI_REGISTRY_IMAGE}:dual-1.2
${CI_REGISTRY_IMAGE}:dual-1
```

GitHub Container Registry:
```bash
ghcr.io/owner/repo:1.2.3
ghcr.io/owner/repo:1.2
ghcr.io/owner/repo:1
ghcr.io/owner/repo:jsonpath-1.2.3
# ... etc
```

### Example 2: Main Branch Push

```bash
latest
<commit-sha>
jsonpath-latest
jsonpath-<commit-sha>
jq-latest
jq-<commit-sha>
dual-latest
dual-<commit-sha>
```

### Example 3: Pull Request #42

```bash
pr-42                       # GitHub
jsonpath-pr-42
jq-pr-42
dual-pr-42
```

## 🎯 Using Version Tags in Deployments

### Pin to Specific Version (Recommended for Production)
```yaml
image: registry/image:jsonpath-1.2.3  # Exact version, never changes
```

### Pin to Minor Version (Auto-updates patches)
```yaml
image: registry/image:jsonpath-1.2     # Gets 1.2.0, 1.2.1, 1.2.2, etc.
```

### Pin to Major Version (Auto-updates minor/patches)
```yaml
image: registry/image:jsonpath-1       # Gets any 1.x.x
```

### Use Latest (Not Recommended for Production)
```yaml
image: registry/image:jsonpath-latest  # Gets latest build from main
```

## 🔄 Migration from Current to Versioned

### Step 1: Switch CI/CD Files

**GitLab:**
```bash
# Backup current
mv .gitlab-ci.yml .gitlab-ci.yml.backup

# Enable versioned
mv .gitlab-ci-versioned.yml .gitlab-ci.yml

# Commit and push
git add .gitlab-ci.yml
git commit -m "Enable semantic versioning for Docker images"
git push
```

**GitHub:**
```bash
# Backup current
mv .github/workflows/docker-build.yml .github/workflows/docker-build.yml.backup

# Enable versioned
mv .github/workflows/docker-build-versioned.yml .github/workflows/docker-build.yml

# Commit and push
git add .github/workflows/docker-build.yml
git commit -m "Enable semantic versioning for Docker images"
git push
```

### Step 2: Create First Release

```bash
# Tag your current state as v1.0.0
git tag -a v1.0.0 -m "Initial versioned release"
git push origin v1.0.0

# CI/CD will build and publish versioned images
```

### Step 3: Update Helm Charts

Update your Helm chart values to use version tags:

```yaml
# values.yaml
image:
  repository: registry/image
  tag: jsonpath-1.0.0  # Pin to specific version
  pullPolicy: IfNotPresent
```

## 📋 Version Tag Decision Matrix

| Use Case | Recommended Tag | Example | Updates |
|----------|----------------|---------|---------|
| Production (stable) | Exact version | `1.2.3` | Never |
| Production (patch updates) | Minor version | `1.2` | Patches only |
| Staging | Major version | `1` | Minor + patches |
| Development | Latest | `latest` | Every commit |
| Testing | SHA | `abc123` | Never |
| PR preview | PR tag | `pr-42` | Each PR push |

## 🏷️ Complete Tag Reference

### After tagging v1.2.3:

```
Registry Tags Available:

Default (JSONPath):
  1.2.3 ──────────────► Exact version 1.2.3
  1.2   ──────────────► Latest 1.2.x (updates with 1.2.4, 1.2.5, etc.)
  1     ──────────────► Latest 1.x.x (updates with 1.3.0, 1.4.0, etc.)
  latest ─────────────► Latest from main branch (updates on every main push)
  <sha> ─────────────► Specific commit (immutable)

JSONPath Variant:
  jsonpath-1.2.3 ─────► Exact version
  jsonpath-1.2 ───────► Latest 1.2.x
  jsonpath-1 ─────────► Latest 1.x.x
  jsonpath-latest ────► Latest from main
  jsonpath-<sha> ─────► Specific commit

jq Variant:
  jq-1.2.3 ───────────► Exact version
  jq-1.2 ─────────────► Latest 1.2.x
  jq-1 ───────────────► Latest 1.x.x
  jq-latest ──────────► Latest from main
  jq-<sha> ───────────► Specific commit

Dual Variant:
  dual-1.2.3 ─────────► Exact version
  dual-1.2 ───────────► Latest 1.2.x
  dual-1 ─────────────► Latest 1.x.x
  dual-latest ────────► Latest from main
  dual-<sha> ─────────► Specific commit
```

## 🔍 Finding Available Tags

### GitLab Container Registry
```bash
# List all tags
curl -H "PRIVATE-TOKEN: $TOKEN" \
  "https://gitlab.com/api/v4/projects/$PROJECT_ID/registry/repositories/$REPO_ID/tags"

# Or via UI: Project → Packages & Registries → Container Registry
```

### GitHub Container Registry
```bash
# List tags via GitHub API
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/orgs/OWNER/packages/container/REPO/versions"

# Or via UI: Package page on GitHub
```

### Docker CLI
```bash
# Pull and inspect
docker pull registry/image:jsonpath-1.2.3
docker images | grep image
```

## 🎯 Best Practices

1. **Always use version tags for production**
   ```yaml
   # Good
   image: registry/image:jsonpath-1.2.3

   # Bad
   image: registry/image:latest
   ```

2. **Use semantic versioning**
   - v1.0.0 - Initial release
   - v1.1.0 - New features (backward compatible)
   - v1.1.1 - Bug fixes
   - v2.0.0 - Breaking changes

3. **Tag releases with detailed messages**
   ```bash
   git tag -a v1.2.0 -m "Release 1.2.0

   New features:
   - Add dual mode plugin
   - Add comprehensive tests

   Fixes:
   - Fix key extraction bug
   "
   ```

4. **Maintain a CHANGELOG.md**
   Keep track of changes between versions

5. **Test before tagging**
   ```bash
   # Run tests
   cd tests && ./run_all_tests.sh

   # Build locally
   docker build -t test:1.2.3 .

   # Test locally
   docker run test:1.2.3

   # Then tag and push
   git tag v1.2.3
   git push origin v1.2.3
   ```

## 🚨 Common Issues

### Issue: Tag Already Exists
```bash
# Error: tag 'v1.0.0' already exists
# Solution: Delete and recreate (careful!)
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

### Issue: Wrong Version Tagged
```bash
# Move tag to different commit
git tag -d v1.0.0
git tag -a v1.0.0 <commit-sha> -m "Release 1.0.0"
git push -f origin v1.0.0
```

### Issue: CI/CD Not Triggering on Tag
```bash
# Check pipeline configuration includes 'tags' trigger
# GitLab: only: - tags
# GitHub: on: push: tags: - 'v*.*.*'
```

## 📚 References

- [Semantic Versioning](https://semver.org/)
- [Docker Tagging Best Practices](https://docs.docker.com/engine/reference/commandline/tag/)
- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [GitHub Actions](https://docs.github.com/en/actions)
