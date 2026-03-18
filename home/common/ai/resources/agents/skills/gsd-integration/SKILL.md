---
name: gsd-integration
description: Get Shit Done framework integration. Use when deciding between /gsd commands
  and direct execution for development tasks.
---

# GSD Integration

## When to Use GSD
- New features with multiple phases
- Projects needing state tracking across sessions
- Work requiring planning → execution → verification lifecycle
- Brownfield analysis (`/gsd:map-codebase`)

## When NOT to Use GSD
- Quick one-off tasks (just do them directly)
- Code reviews (use /deep-review, /code-review)
- Simple commits (/commit)
- Infrastructure tasks (/new-lxc, /migrate-lxc)

## Quick Reference
| Task | Command |
|------|---------|
| New multi-phase project | `/gsd:new-project` |
| Existing codebase analysis | `/gsd:map-codebase` |
| Quick tracked task | `/gsd:quick` |
| Check progress | `/gsd:progress` |
| Configure settings | `/gsd:settings` |
