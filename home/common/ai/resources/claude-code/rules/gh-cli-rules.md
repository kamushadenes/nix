# GitHub CLI (gh) Rules

## Prefer gh over GitHub MCP

Always use `gh` CLI instead of GitHub MCP tools (`mcp__github__*`). The `gh` CLI is faster, more reliable, and already authenticated.

## Common Operations

- **Repos**: `gh repo view`, `gh repo clone`
- **PRs**: `gh pr create`, `gh pr view`, `gh pr merge`, `gh pr checks`
- **Issues**: `gh issue create`, `gh issue list`, `gh issue view`
- **Runs**: `gh run list`, `gh run view`, `gh run watch`
- **API**: `gh api` for any REST/GraphQL endpoint not covered by subcommands
- **Search**: `gh search repos`, `gh search issues`, `gh search prs`, `gh search code`

## GraphQL via gh api

Use heredoc to avoid shell escaping of `!` in GraphQL types:

```bash
query=$(cat <<'EOF'
query($owner: String!, $repo: String!) { ... }
EOF
)
gh api graphql -f query="$query" -f owner=OWNER -f repo=REPO
```

## Pagination

Use `--paginate` for REST endpoints. GraphQL requires manual cursor-based pagination.

## JSON Output

Use `--json` flag with `--jq` for structured output:

```bash
gh pr list --json number,title,state --jq '.[] | select(.state == "OPEN")'
```
