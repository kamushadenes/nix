# AI Orchestration Rules

## GSD Framework (Primary Workflow)
- Use `/gsd:new-project` to initialize structured projects
- Use `/gsd:map-codebase` for brownfield projects
- Follow lifecycle: Initialize → Discuss → Plan → Execute → Verify
- Use `/gsd:quick` for ad-hoc tasks that still benefit from planning

## Subagents (Focused Analysis)
- Use Task tool for quick focused work within a session
- Review agents, debugger, planner etc. are subagents
- Better than GSD when only the result matters (quick analysis)

## When to Use GSD vs Subagents
**GSD**: Multi-phase projects, features needing planning, parallelizable work, state tracking
**Subagents**: Focused analysis, quick results, no lifecycle needed

## Subagent User Input

Subagents cannot use AskUserQuestion. Relay via AskUserQuestion, then pass back.
