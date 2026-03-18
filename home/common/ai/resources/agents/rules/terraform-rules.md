---
paths: **/*.tf
---

# Terraform Development Rules

## Best Practices

- Always check latest provider version before specifying version constraints
- Use registry documentation for correct argument names and types
- Never guess resource argument names — consult official docs first
- For HCP Terraform/Enterprise: use workspace and run management tools

## MCP Workflow

Use the Terraform MCP to look up current documentation:

1. **Find provider resources**: `mcp__terraform__get_provider_capabilities`
2. **Get resource docs**: `mcp__terraform__search_providers` →
   `mcp__terraform__get_provider_details`
3. **Find modules**: `mcp__terraform__search_modules` →
   `mcp__terraform__get_module_details`
4. **Check versions**: `mcp__terraform__get_latest_provider_version` or
   `mcp__terraform__get_latest_module_version`

Search before get — search tools return IDs needed by detail tools.
