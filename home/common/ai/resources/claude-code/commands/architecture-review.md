---
allowed-tools: Read, Grep, Glob, Bash, Task
description: Perform comprehensive architecture review of the codebase
---

## Context

- Current directory: !`pwd`
- Project structure: !`find . -type f -name "*.json" -o -name "*.yaml" -o -name "*.toml" | head -20`

## Your Task

Perform a comprehensive architecture review using the architecture-reviewer agent.

1. **Scope the review** - Identify main architectural components
2. **Analyze each dimension** - Work through all 15 review dimensions
3. **Synthesize findings** - Prioritize issues by impact
4. **Provide actionable recommendations**

Focus on:

- Structural patterns and their correctness
- Dependency health and coupling
- Scalability and performance readiness
- Security architecture
- Operational concerns

Deliver a prioritized list of architectural improvements.
