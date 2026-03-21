---
description: Cross-phase audit of all outstanding UAT and verification items
tools:
  read: true
  glob: true
  grep: true
  bash: true
---
<objective>
Scan all phases for pending, skipped, blocked, and human_needed UAT items. Cross-reference against codebase to detect stale documentation. Produce prioritized human test plan.
</objective>

<execution_context>
@/private/var/folders/jl/yb1gyxfs0gx15sjsjp2zt5w40000gn/T/tmp.F0tnwPm72m/.opencode/get-shit-done/workflows/audit-uat.md
</execution_context>

<context>
Core planning files are loaded in-workflow via CLI.

**Scope:**
Glob: .planning/phases/*/*-UAT.md
Glob: .planning/phases/*/*-VERIFICATION.md
</context>
