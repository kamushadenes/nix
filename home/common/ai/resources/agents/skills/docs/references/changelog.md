# Changelog Documentation

Templates for changelogs and release notes.

## Changelog (CHANGELOG.md)

Follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- New feature description (#PR-number)

### Changed

- Modified behavior description (#PR-number)

## [1.2.0] - 2025-03-15

### Added

- OAuth2 authentication flow (#142)
- Rate limiting middleware with configurable thresholds (#138)
- Prometheus metrics endpoint at `/metrics` (#135)

### Changed

- Upgraded Node.js from 18 to 20 (#140)
- Switched from REST to GraphQL for the reporting API (#137)

### Fixed

- Connection pool exhaustion under high load (#141)
- Race condition in session cleanup (#139)

### Deprecated

- `GET /api/v1/reports` — use GraphQL endpoint instead. Will be removed in 2.0.

### Removed

- Legacy XML export format (#136)

### Security

- Patched XSS vulnerability in user profile rendering (#143)

## [1.1.0] - 2025-02-01

[...]

[Unreleased]: https://github.com/owner/repo/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/owner/repo/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/owner/repo/compare/v1.0.0...v1.1.0
```

### Change Categories

Use exactly these categories in this order:

| Category   | What Goes Here                                      |
| ---------- | --------------------------------------------------- |
| Added      | New features, new endpoints, new capabilities       |
| Changed    | Changes to existing functionality, behavior changes |
| Fixed      | Bug fixes                                           |
| Deprecated | Features that will be removed in a future version   |
| Removed    | Features removed in this version                    |
| Security   | Vulnerability fixes (even if also a "fix")          |

### Generating from Git History

Extract changes from git log to build a changelog:

```bash
# Commits since last tag
git log v1.1.0..HEAD --oneline --no-merges

# PRs merged since last tag (GitHub)
gh pr list --state merged --base main --search "merged:>2025-02-01" \
  --json number,title,labels --jq '.[] | "#\(.number) \(.title)"'

# Tags with dates
git tag -l --sort=-version:refname --format='%(refname:short) %(creatordate:short)'
```

Categorize each change by reading the PR title, description, and diff. Do not
rely solely on commit message prefixes — verify the actual change.

## Release Notes

For more detailed per-release communication:

```markdown
# Release Notes: v1.2.0

**Release date**: 2025-03-15

## Highlights

### OAuth2 Authentication

[2-3 sentence description of the feature, why it matters, and how to use it.
Link to relevant documentation.]

### GraphQL Reporting API

[2-3 sentence description. Include migration note if replacing an existing
feature.]

## Breaking Changes

- `GET /api/v1/reports` is deprecated. Migrate to the GraphQL endpoint. See
  [Migration Guide](docs/migration-v1.2.md).

## Full Changelog

See [CHANGELOG.md](CHANGELOG.md#120---2025-03-15) for the complete list.

## Upgrade Guide

\`\`\`bash

# Update to latest

[actual update commands]

# Run migrations (if applicable)

[actual migration commands] \`\`\`
```

## Tips

- Generate changelog from git history, but edit for clarity — raw commit
  messages are rarely good enough
- Link PR numbers so readers can find full context
- Keep entries concise — one line per change in CHANGELOG, expand in release
  notes
- Always include comparison links at the bottom of CHANGELOG.md
- Security fixes should call out the vulnerability type and severity
- Changelogs belong in the repo root, not in the wiki (they're versioned with
  code)
