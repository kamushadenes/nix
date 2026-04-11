---
name: readme
description: Generate or update a comprehensive README.md for the current project. Use when the user asks to write, create, or update a README.
---

# README Generation Workflow

Generate or update the project's README.md.

## Workflow

### 1. Explore the Codebase

- Map the full project structure, entry points, dependencies, and build system
- Identify the primary language, framework, and tooling
- Check for existing README.md and preserve project-specific content

### 2. Adapt Sections to the Codebase

Write directly to `README.md` in the project root. Include only sections relevant to what actually exists:

- **Project title and description** -- what it does, who it's for
- **Installation / Getting started** -- setup instructions, prerequisites
- **Usage** -- core workflows, CLI commands, API examples
- **Architecture** -- high-level overview if the project is non-trivial
- **Configuration** -- environment variables, config files
- **Development** -- how to build, test, lint, contribute
- **Deployment** -- how to deploy (if applicable)
- **Documentation** -- links to docs/ directory or GitHub Wiki if they exist
- **License** -- if a LICENSE file exists

### 3. Quality Checks

- Verify all referenced file paths and commands actually exist
- Ensure code examples are accurate
- Check that links work (relative paths, URLs)

## Important

- If a README.md already exists, read it first and improve it -- preserve existing project-specific content
- Do not invent features or sections for things that don't exist in the codebase
- For comprehensive documentation beyond README, use the `docs` skill instead
