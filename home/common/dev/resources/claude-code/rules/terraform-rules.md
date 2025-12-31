---
paths: **/*.tf
---

# Terraform Development Rules

## Before Writing Code

Use the Terraform MCP to look up current documentation:

1. **Find provider resources**: `mcp__terraform__get_provider_capabilities` to see available resources/data sources
2. **Get resource docs**: `mcp__terraform__search_providers` → `mcp__terraform__get_provider_details`
3. **Find modules**: `mcp__terraform__search_modules` → `mcp__terraform__get_module_details`
4. **Check versions**: `mcp__terraform__get_latest_provider_version` or `mcp__terraform__get_latest_module_version`

## Workflow

```
# 1. Discover what's available
mcp__terraform__get_provider_capabilities(namespace="hashicorp", name="aws")

# 2. Get specific resource documentation
mcp__terraform__search_providers(
    provider_namespace="hashicorp",
    provider_name="aws",
    service_slug="lambda",
    provider_document_type="resources"
)
# Returns provider_doc_id like "10930286"

mcp__terraform__get_provider_details(provider_doc_id="10930286")

# 3. For modules
mcp__terraform__search_modules(module_query="aws vpc")
# Returns module_id like "terraform-aws-modules/vpc/aws/5.0.0"

mcp__terraform__get_module_details(module_id="terraform-aws-modules/vpc/aws/5.0.0")
```

## Best Practices

- Always check latest provider version before specifying version constraints
- Use registry documentation for correct argument names and types
- Search before get - search tools return IDs needed by detail tools
- For HCP Terraform/Enterprise: use workspace and run management tools
