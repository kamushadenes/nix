---
allowed-tools: Task
description: Audit project dependencies for security, updates, and health
---

## Context

- Package files: !`find . -name "package.json" -o -name "requirements.txt" -o -name "go.mod" -o -name "Cargo.toml" -o -name "*.nix" 2>/dev/null | head -10`

## Your Task

Delegate the full dependency audit to the `dependency-checker` subagent to keep verbose audit output out of main context.

Use the **Task tool** with:

- `subagent_type`: "dependency-checker"
- `prompt`: Include the package files context above and request a comprehensive audit covering:
  1. Dependency inventory with versions
  2. Security vulnerabilities (npm audit, pip-audit, cargo audit)
  3. Outdated package analysis
  4. License compliance check
  5. Health assessment table
  6. Prioritized recommendations

The subagent will run all audit commands and produce a consolidated report.

## Display Results

After the subagent returns, display the findings summary to the user with:

- Critical security issues (if any)
- High-priority updates
- License concerns
- Overall health assessment
