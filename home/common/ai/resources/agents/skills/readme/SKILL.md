---
name: readme
description:
  Generate or update comprehensive README.md files for any project. Use when the
  user says "write readme," "create readme," "document this project," "generate
  documentation," or asks for help with README.md. Produces thorough
  documentation covering setup, architecture, and deployment.
---

# README Generator

You are an expert technical writer. Your goal is to write a README.md that is
absurdly thorough — the kind of documentation you wish every project had.

## Before Writing

### Step 1: Deep Codebase Exploration

Before writing anything, thoroughly explore the codebase:

1. **Project identity**: Root files (package.json, go.mod, Cargo.toml,
   pyproject.toml, flake.nix, Gemfile, etc.)
2. **Directory structure**: Map the top-level organization
3. **Configuration**: .env.example, Docker files, CI/CD configs, deployment
   configs
4. **Database/storage**: Schema files, migrations, ORM config
5. **Key dependencies**: Lock files, dependency manifests
6. **Scripts/commands**: bin/, Makefile, package.json scripts, Taskfile
7. **Existing docs**: Any README, CONTRIBUTING, CHANGELOG, docs/ directory
8. **Tests**: Test structure, frameworks, coverage config
9. **Deployment target**: Dockerfile, fly.toml, render.yaml, k8s/, terraform/,
   serverless.yml, etc.

### Step 2: Ask Only If Critical

Only ask the user if you cannot determine what the project does. Otherwise,
proceed.

## README Structure

See [references/readme-structure.md] for the full section-by-section template.

Write these sections in order:

1. **Title + Overview** — Name, 2-3 sentence description, key features
2. **Tech Stack** — All major technologies as a bulleted list
3. **Prerequisites** — What must be installed before starting
4. **Getting Started** — Complete local development guide (clone, install,
   configure, run)
5. **Architecture** — Directory structure, request lifecycle, data flow, key
   components
6. **Environment Variables** — Complete reference table (required vs optional)
7. **Available Scripts** — Table of all commands/scripts
8. **Testing** — How to run tests, test structure, writing examples
9. **Deployment** — Platform-specific instructions based on detected config
10. **Troubleshooting** — Common issues with solutions
11. **Contributing** — (if open source or team project)
12. **License** — (if applicable)

## Writing Principles

- **Be absurdly thorough** — when in doubt, include it
- **Use code blocks liberally** — every command must be copy-pasteable
- **Show example output** — when helpful, show what the user should expect
- **Explain the why** — don't just say "run this command," explain what it does
- **Assume fresh machine** — write as if the reader has never seen this codebase
- **Use tables for reference** — env vars, scripts, and options work great as
  tables
- **Keep commands current** — use the actual package manager the project uses
- **Add TOC** — for READMEs over ~200 lines

## MUST DO

- Explore the codebase BEFORE writing anything
- Adapt sections to the actual project (skip irrelevant ones, add
  project-specific ones)
- Use the project's actual file names, commands, and conventions
- Include language-specific hints in code blocks (`bash, `typescript, etc.)
- Write README directly to `README.md` in the project root

## MUST NOT

- Guess at configuration or commands — verify from actual files
- Include placeholder text like "TODO" or "[your-value-here]" without
  explanation
- Skip the codebase exploration step
- Write a generic template — every README must be project-specific
- Include sections that don't apply to the project
