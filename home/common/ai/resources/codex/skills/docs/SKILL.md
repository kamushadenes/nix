---
name: docs
description: Generate or update comprehensive project documentation (API reference, architecture, developer guides, deployment docs, runbooks, changelogs). Use "wiki" mode to write to GitHub Wiki instead of the repo. Always updates README.md via the readme skill as a final step.
---

# Documentation Generation Workflow

Generate or update documentation for the current project.

## Workflow

### 1. Explore the Codebase

- Map the project structure, key modules, entry points, and dependencies
- Identify existing documentation files (docs/, wiki, README, CHANGELOG, etc.)

### 2. Audit Existing Docs

- Check for outdated, missing, or incomplete documentation
- Note which doc types exist and which are needed

### 3. Choose Destination

- Ask the user whether to write docs to the repo (e.g., `docs/` directory) or to the GitHub Wiki
- If the user's additional instructions mention "wiki", use GitHub Wiki hybrid mode

### 4. Build a Plan

- Determine which doc types to generate based on the codebase:
  - API reference
  - Architecture overview / ADRs
  - Developer guide / contributing guide
  - Configuration reference
  - Deployment guide
  - Migration guide
  - Runbooks
  - Changelog
- If a specific doc type is mentioned in the user's instructions, generate only that type
- Present the plan to the user for approval before writing

### 5. Write Pages

- Spawn an agent for each documentation page to write them in parallel
- Each agent should:
  - Read the relevant source code and existing docs
  - Write comprehensive, accurate documentation
  - Use consistent formatting and cross-references

### 6. Verify Consistency

- Cross-check all generated pages for consistent terminology, links, and structure
- Verify code examples compile/run where applicable

### 7. Update README.md

- As a final step, update the project's README.md to reflect the new documentation
- Follow the readme skill workflow for this step

## Important

- For README-only changes, use the `readme` skill directly
- Adapt all sections to what actually exists in the codebase -- do not document features that don't exist
- Preserve existing project-specific content when updating
