---
name: dependency-audit
description: Audit project dependencies for security vulnerabilities, outdated packages, and overall health. Use when the user asks to audit dependencies, check for vulnerabilities, or review package health.
---

# Dependency Audit Workflow

Delegate to a dependency-checker agent for comprehensive dependency analysis.

## Task for dependency-checker agent

### Context gathering

Identify the project's package manager(s) and read dependency files:
```bash
# Find dependency files
ls -la package.json package-lock.json yarn.lock pnpm-lock.yaml 2>/dev/null
ls -la Cargo.toml Cargo.lock 2>/dev/null
ls -la go.mod go.sum 2>/dev/null
ls -la requirements.txt setup.py pyproject.toml Pipfile 2>/dev/null
ls -la flake.nix flake.lock 2>/dev/null
ls -la Gemfile Gemfile.lock 2>/dev/null
```

### Audit dimensions

1. **Dependency Inventory**
   - Total count (direct vs transitive)
   - Dependency tree depth
   - Largest dependencies by size

2. **Security Vulnerabilities**
   - Run native audit tools:
     ```bash
     npm audit --json 2>/dev/null
     cargo audit 2>/dev/null
     pip audit 2>/dev/null
     gh api /repos/{owner}/{repo}/dependabot/alerts 2>/dev/null
     ```
   - CVE severity breakdown
   - Affected versions and fix availability

3. **Outdated Analysis**
   - Run outdated checks:
     ```bash
     npm outdated --json 2>/dev/null
     cargo outdated 2>/dev/null
     pip list --outdated 2>/dev/null
     ```
   - Major version gaps
   - Maintenance status of key dependencies

4. **License Compliance**
   - License types across all dependencies
   - Copyleft or restrictive licenses
   - Missing license declarations

5. **Health Assessment**
   - Unmaintained dependencies (no updates in 2+ years)
   - Deprecated packages
   - Single-maintainer risks
   - Duplicate dependencies

6. **Prioritized Recommendations**
   - Critical security patches (apply immediately)
   - High-priority updates (breaking changes, plan migration)
   - Medium-priority updates (routine updates)
   - Low-priority (cosmetic, minor improvements)

### Output format

## Summary
Brief health overview with risk rating (Critical/High/Medium/Low).

## Critical Security Issues
| Package | CVE | Severity | Fix Available | Action |
|-|-|-|-|-|

## High-Priority Updates
| Package | Current | Latest | Breaking | Risk |
|-|-|-|-|-|

## License Concerns
Any problematic licenses found.

## Overall Health
Dependency health score and key metrics.

## Recommended Actions
Prioritized list of actions to improve dependency health.
