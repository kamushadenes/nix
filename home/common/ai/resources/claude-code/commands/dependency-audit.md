---
allowed-tools: Read, Grep, Glob, Bash
description: Audit project dependencies for security, updates, and health
---

## Context

- Package files: !`find . -name "package.json" -o -name "requirements.txt" -o -name "go.mod" -o -name "Cargo.toml" -o -name "*.nix" 2>/dev/null | head -10`

## Your Task

Perform a comprehensive dependency audit:

### 1. Inventory
- List all direct dependencies with versions
- Identify dependency manager (npm, pip, cargo, go mod, nix)

### 2. Security Check
```bash
# For Node.js
npm audit --json 2>/dev/null || true

# For Python
pip-audit 2>/dev/null || true

# For Rust
cargo audit 2>/dev/null || true
```

### 3. Outdated Analysis
- Check for major version updates available
- Identify dependencies with breaking changes
- Flag abandoned/unmaintained packages

### 4. License Compliance
- List licenses in use
- Flag copyleft licenses if project is closed-source
- Identify license conflicts

### 5. Health Assessment
| Dependency | Version | Latest | Security | Maintained | License |
|------------|---------|--------|----------|------------|---------|
| pkg-name   | 1.2.3   | 2.0.0  | ⚠️ CVE   | ✅ Active  | MIT     |

### 6. Recommendations
1. [Critical security updates]
2. [Recommended updates]
3. [Dependencies to replace/remove]
