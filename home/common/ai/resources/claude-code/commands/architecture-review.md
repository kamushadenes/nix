---
allowed-tools: Task
description: Perform comprehensive architecture review of the codebase
---

## Context

- Current directory: !`pwd`
- Project structure: !`find . -type f -name "*.json" -o -name "*.yaml" -o -name "*.toml" | head -20`

## Your Task

Delegate the comprehensive architecture review to the `architecture-reviewer` subagent.

Use the **Task tool** with:

- `subagent_type`: "architecture-reviewer"
- `prompt`: Include the project context above and request a review across all 15 dimensions:
  1. Structure and system design
  2. Design patterns
  3. Dependencies and coupling
  4. Data management
  5. Component design
  6. Error handling
  7. Scalability
  8. Security architecture
  9. Testability
  10. Operations
  11. Documentation
  12. Extensibility
  13. Technology stack
  14. Performance
  15. Team alignment

Request findings prioritized by impact with actionable recommendations.

## Display Results

After the subagent returns, display:

- Executive summary (2-3 sentences)
- Top concerns by severity
- Prioritized recommendations
- Technical debt identified
