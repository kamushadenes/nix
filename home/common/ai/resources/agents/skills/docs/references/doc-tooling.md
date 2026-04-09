# Documentation Tooling Adaptation

When a project uses a documentation framework, adapt file placement and
frontmatter accordingly. Content structure (sections, headings) does not change —
only location and metadata.

## Detection

During Step 1 (Explore), check for these files:

| File | Framework |
|-|-|
| `docusaurus.config.*` | Docusaurus |
| `.vitepress/config.*` | VitePress |
| `mkdocs.yml` | MkDocs |
| `.storybook/` | Storybook (no doc effect) |

Report the detected framework in the documentation plan (Step 4).

## Docusaurus

- Write to `docs/{filename}` (e.g., `docs/architecture.md`)
- Add YAML frontmatter before the ownership marker:

```yaml
---
title: Architecture
sidebar_position: 2
description: System architecture and component overview
---
```

- `sidebar_position` values: 1 for overview/README, 2 for architecture, 3 for
  getting started, increment from there

## VitePress

- Write to `docs/{filename}`
- Add YAML frontmatter:

```yaml
---
title: Architecture
description: System architecture and component overview
---
```

- No `sidebar_position` — VitePress sidebars are configured in
  `.vitepress/config.*`

## MkDocs

- Write to `docs/{filename}`
- Add YAML frontmatter with `title` only:

```yaml
---
title: Architecture
---
```

- Respect the `nav:` section in `mkdocs.yml` if present — use matching
  filenames. Read `mkdocs.yml` before writing to check for existing nav entries.

## No Framework Detected

- Write to `docs/` directory by default
- Exceptions: `README.md` and `CONTRIBUTING.md` stay at project root
- No frontmatter added
- Create the `docs/` directory if it does not exist
