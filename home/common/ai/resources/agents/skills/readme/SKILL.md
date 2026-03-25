---
name: readme
description:
  Generate or update comprehensive README.md files for any project. Use when the
  user says "write readme", "create readme", "update readme", or asks for help
  with README.md specifically. Produces thorough README covering setup,
  architecture, and deployment. Docs/wiki-aware — automatically includes a
  Documentation section linking to docs/ or GitHub Wiki when they exist. For
  broader project documentation (API reference, developer guides, runbooks,
  ADRs, changelogs), use the `docs` skill instead.
---

# README Generator

Write a README.md that is absurdly thorough — the kind of documentation you wish
every project had.

## Before Writing

### Step 1: Deep Codebase Exploration

Explore thoroughly before writing:

1. **Project identity**: Root files (package.json, go.mod, Cargo.toml,
   pyproject.toml, flake.nix, Gemfile, etc.)
2. **Directory structure**: Top-level organization
3. **Configuration**: .env.example, Docker files, CI/CD, deployment configs
4. **Database/storage**: Schemas, migrations, ORM config
5. **Dependencies**: Lock files, dependency manifests
6. **Scripts/commands**: bin/, Makefile, package.json scripts, Taskfile
7. **Existing docs**: README, CONTRIBUTING, CHANGELOG, docs/, wiki
8. **Tests**: Frameworks, coverage config
9. **Deployment**: Dockerfile, fly.toml, render.yaml, k8s/, terraform/

### Step 2: Check for Existing Documentation

If the project has a GitHub Wiki or `docs/` directory, include a
**Documentation** section in the README linking to those resources:

```markdown
## Documentation

- [API Reference](docs/api.md)
- [Architecture](docs/architecture.md)
- [Developer Guide](docs/developer-guide.md)
- [Deployment Guide](docs/deployment.md)
```

Or for wiki:

```markdown
## Documentation

Full documentation on the [wiki](https://github.com/OWNER/REPO/wiki).
```

### Step 3: Ask Only If Critical

Only ask the user if you cannot determine what the project does.

## README Structure

See [references/readme-structure.md] for the full section-by-section template.

1. **Title + Overview** — Name, 2-3 sentence description, key features
2. **Tech Stack** — Major technologies
3. **Prerequisites** — What must be installed
4. **Getting Started** — Complete local dev guide (clone, install, configure,
   run)
5. **Documentation** — Links to wiki or docs/ (if they exist)
6. **Architecture** — Directory structure, data flow, key components
7. **Environment Variables** — Reference table (required vs optional)
8. **Available Scripts** — Table of all commands
9. **Testing** — How to run, structure, examples
10. **Deployment** — Platform-specific based on detected config
11. **Troubleshooting** — Common issues with solutions
12. **Contributing** — (if applicable)
13. **License** — (if applicable)

## Writing Principles

- **Be absurdly thorough** — when in doubt, include it
- **Code blocks liberally** — every command must be copy-pasteable
- **Show example output** — when helpful
- **Explain the why** — not just "run this command"
- **Assume fresh machine** — reader has never seen this codebase
- **Tables for reference** — env vars, scripts, options
- **Keep current** — use the project's actual package manager and tools
- **TOC** — for READMEs over ~200 lines

## MUST DO

- Explore codebase before writing
- If README.md exists and accurately reflects the codebase, report that no
  update is needed and stop
- Adapt sections to the actual project (skip irrelevant, add project-specific)
- Use actual file names, commands, and conventions
- Include a Documentation section linking to docs/ or wiki when they exist
- Write directly to `README.md` in project root

## MUST NOT

- Guess at configuration or commands — verify from actual files
- Rewrite a README that already accurately reflects the codebase
- Include placeholder text like "TODO" or "[your-value-here]"
- Skip codebase exploration
- Write a generic template — every README must be project-specific
- Include sections that don't apply to the project
