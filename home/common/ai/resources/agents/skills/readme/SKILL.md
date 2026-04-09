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

### Readability First

A README is often the first thing someone reads. It should build understanding
progressively: start with what the project does, then how to use it, then how it
works. A reader who stops at any point should have gained something useful.

- **Lead with context** — open each section explaining _why_ before _what_
- **Build progressively** — simple to complex, overview to detail. Never
  overwhelm the reader with everything at once
- **One idea per paragraph** — dense blocks lose readers. Break them up
- **Assume fresh machine** — the reader has never seen this codebase
- **Explain the why** — not just "run this command"

### Technical Quality

- **Be absurdly thorough** — when in doubt, include it
- **Code blocks liberally** — every command must be copy-pasteable
- **Show example output** — when helpful
- **Keep current** — use the project's actual package manager and tools

### Formatting

- **Tables for reference** — env vars, scripts, options
- **TOC** — for READMEs over ~200 lines
- **Mermaid for diagrams** — always use ` ```mermaid ` fenced code blocks for
  architecture diagrams, data flows, and component relationships. Never use
  ASCII art for diagrams

### Diagrams Are Mandatory for Complex Content

Actively create Mermaid diagrams whenever a concept would be clearer visually
than as prose. Don't wait to be asked — if a section describes a multi-step
workflow, architecture, or data flow, it needs a diagram.

**Always include a diagram for:**

- **Architecture section** — component relationships, system layers, service
  boundaries (use `graph TD/LR`)
- **Data flows** — how requests, data, or events move through the system (use
  `graph LR` or `sequenceDiagram`)
- **Multi-step workflows** — CI/CD, deployment, build pipelines, dev workflows
  (use `flowchart`)
- **State transitions** — entity lifecycles, order flows, auth states (use
  `stateDiagram-v2`)

**Rules:**

- One diagram per concept — don't overload a single diagram
- Label edges — unlabeled arrows are ambiguous
- Keep under ~15 nodes — split large diagrams
- Precede every diagram with a sentence explaining what it shows

## MUST DO

- Explore codebase before writing
- If README.md exists and accurately reflects the codebase, report that no
  update is needed and stop
- Adapt sections to the actual project (skip irrelevant, add project-specific)
- Use actual file names, commands, and conventions
- Include a Documentation section linking to docs/ or wiki when they exist
- Write directly to `README.md` in project root
- Include Mermaid diagrams for architecture, data flows, multi-step workflows,
  and any other complex concept — diagrams are mandatory, not optional (see
  "Diagrams Are Mandatory for Complex Content" above)

## MUST NOT

- Guess at configuration or commands — verify from actual files
- Rewrite a README that already accurately reflects the codebase
- Include placeholder text like "TODO" or "[your-value-here]"
- Skip codebase exploration
- Write a generic template — every README must be project-specific
- Include sections that don't apply to the project
