# Quick Start: Versioned Releases

## 🎯 TL;DR - Create Your First Release

```bash
# 1. Switch to versioned CI/CD (one-time setup)
mv .gitlab-ci.yml .gitlab-ci.yml.old
mv .gitlab-ci-versioned.yml .gitlab-ci.yml
git add .gitlab-ci.yml
git commit -m "Enable semantic versioning"
git push

# 2. Create a release tag
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0

# 3. Done! CI/CD publishes:
#    - 1.0.0, 1.0, 1
#    - jsonpath-1.0.0, jsonpath-1.0, jsonpath-1
#    - jq-1.0.0, jq-1.0, jq-1
#    - dual-1.0.0, dual-1.0, dual-1
```

## 📦 What You Get

After pushing `v1.0.0`:

```
✅ registry/image:1.0.0              # Exact version
✅ registry/image:1.0                # Auto-updates with patches
✅ registry/image:1                  # Auto-updates with minor/patches
✅ registry/image:jsonpath-1.0.0     # Variant-specific
✅ registry/image:jq-1.0.0
✅ registry/image:dual-1.0.0
```

## 🎨 Use in Your Deployments

```yaml
# Helm values.yaml
image:
  repository: registry/image
  tag: jsonpath-1.0.0  # Pin to exact version
```

## 🔄 Version Bumps

```bash
# Patch release (1.0.0 → 1.0.1)
git tag -a v1.0.1 -m "Fix: bug in key extraction"
git push origin v1.0.1

# Minor release (1.0.1 → 1.1.0)
git tag -a v1.1.0 -m "Feature: add new filter mode"
git push origin v1.1.0

# Major release (1.1.0 → 2.0.0)
git tag -a v2.0.0 -m "Breaking: change API format"
git push origin v2.0.0
```

## 💡 Tag Format Rules

✅ **Good:**
- `v1.0.0` - Standard format
- `v1.2.3` - Any semantic version
- `v2.0.0-beta.1` - Pre-release

❌ **Bad:**
- `1.0.0` - Missing 'v' prefix
- `v1.0` - Missing patch version
- `release-1.0.0` - Wrong prefix

## 🎯 Which Tag to Use?

| Environment | Recommended Tag | Why |
|------------|----------------|-----|
| **Production** | `jsonpath-1.0.0` | Immutable, predictable |
| **Staging** | `jsonpath-1.0` | Gets patches automatically |
| **Development** | `jsonpath-latest` | Always newest |
| **Testing** | `jsonpath-pr-42` | Test PR changes |

## 📖 Full Documentation

See [VERSIONING.md](VERSIONING.md) for complete details.
