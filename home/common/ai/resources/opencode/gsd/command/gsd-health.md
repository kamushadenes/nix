---
description: Diagnose planning directory health and optionally repair issues
argument-hint: [--repair]
tools:
  read: true
  bash: true
  write: true
  question: true
---
<objective>
Validate `.planning/` directory integrity and report actionable issues. Checks for missing files, invalid configurations, inconsistent state, and orphaned plans.
</objective>

<execution_context>
@/private/var/folders/jl/yb1gyxfs0gx15sjsjp2zt5w40000gn/T/tmp.EL9PeBxidH/.opencode/get-shit-done/workflows/health.md
</execution_context>

<process>
Execute the health workflow from @/private/var/folders/jl/yb1gyxfs0gx15sjsjp2zt5w40000gn/T/tmp.EL9PeBxidH/.opencode/get-shit-done/workflows/health.md end-to-end.
Parse --repair flag from arguments and pass to workflow.
</process>
