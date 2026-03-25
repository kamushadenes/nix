---
name: docs
description:
  Generate or update comprehensive project documentation beyond README. Use for
  API reference, architecture decision records (ADRs), developer guides,
  contributing guides, configuration reference, deployment guides, migration
  guides, runbooks, changelogs, and release notes. Supports repo (docs/) or
  GitHub Wiki destinations. Always updates README.md via the `readme` skill as a
  final step. Triggers on "write docs", "document the API", "create a developer
  guide", "add an ADR", "write a runbook", "generate changelog", "docs wiki", or
  any documentation task that is NOT a README.
---

# Documentation Generator

Generate production-grade project documentation. For README-only changes, use
the `readme` skill directly.

## Orchestrator Principle

**You are the orchestrator. You must NEVER write or edit documentation files
directly.** All file creation, updates, and fixes must be delegated to agents
via `task()`. Your job is to:

1. Explore and audit the codebase
2. Build the documentation plan
3. Delegate writing, verification, and fixes to agents
4. Collect results and coordinate across agents
5. Report outcomes to the user

The only files you interact with directly are for _reading_ during exploration
and audit. Every write goes through a delegated task.

## Workflow

### Step 1: Explore the Codebase

Before writing, explore:

1. **Project identity**: Root config files (package.json, go.mod, Cargo.toml,
   pyproject.toml, flake.nix)
2. **Existing docs**: docs/, wiki, CONTRIBUTING.md, CHANGELOG.md, ADRs, \*.md
3. **API surface**: Routes, exported functions, public types, OpenAPI specs
4. **Configuration**: .env.example, config files, feature flags
5. **Infrastructure**: Dockerfile, CI/CD, deployment manifests, IaC
6. **Database**: Schemas, migrations, ORM models
7. **Tests**: Frameworks, fixtures, test utilities

### Step 2: Audit Existing Documentation

Compare every existing doc against the current codebase:

- **Current and complete?** → no changes needed
- **Current but could be improved?** → flag: wording improvements only
- **Outdated?** → flag for update: stale commands, wrong paths, changed config
  keys, upgraded dependencies
- **Obsolete?** → flag for removal: documents features, APIs, or components that
  no longer exist in the codebase. Entire pages or sections that describe
  removed functionality should be deleted, not left with a "this was removed"
  note
- **Missing?** → flag for creation

Default mode is **update**, not rewrite. Preserve existing content, voice, and
structure.

**If all existing docs are current, complete, and well-structured** → report
that no updates are needed and stop. Do not rewrite documentation that already
accurately reflects the codebase just to put your stamp on it.

Report the full audit to the user, clearly separating what will be updated,
removed, and created. **Removals require user confirmation** — never delete
pages without approval.

### Step 3: Choose Destination

- **"wiki"** explicitly → GitHub Wiki hybrid mode
- **"repo"** explicitly or a file path → repository only
- **Neither** → ask:

> Where should the main documentation live?
>
> 1. **Repository** (`docs/`) — versioned with code
> 2. **GitHub Wiki** (hybrid) — guides on wiki, code-coupled docs in repo

#### Wiki Hybrid Mode

Wiki gets guides and references browsed independently. Repo keeps code-coupled
files:

| Repo file               | Why in repo                                       |
| ----------------------- | ------------------------------------------------- |
| `README.md`             | Landing page (updated via `readme` skill, Step 8) |
| `CONTRIBUTING.md`       | Shown by GitHub on PR creation                    |
| `CHANGELOG.md`          | Versioned with code, tied to tags                 |
| `docs/adr/`             | Versioned with the decisions they document        |
| `docs/configuration.md` | Changes with code, reviewed in PRs                |

Repo files should be concise and link to the wiki for details. See
[references/github-wiki.md] for wiki workflow and conventions.

### Step 4: Build the Documentation Plan

#### Specific doc type requested

Match to the reference:

| Type                | Reference                       |
| ------------------- | ------------------------------- |
| API Reference       | [references/api-reference.md]   |
| Architecture / ADRs | [references/architecture.md]    |
| Developer Guide     | [references/developer-guide.md] |
| Operations          | [references/operations.md]      |
| Changelog           | [references/changelog.md]       |

Split into multiple pages when content warrants it (e.g., API by domain,
Operations into deploy + runbook + migration).

#### No specific type ("write docs")

Generate a full documentation suite. Present the plan for approval:

```
Documentation Plan (repo):

 1. Architecture Overview         → docs/architecture.md
 2. API Reference — Users         → docs/api/users.md
 3. API Reference — Resources     → docs/api/resources.md
 4. Developer Guide               → docs/developer-guide.md
 5. Contributing Guide            → CONTRIBUTING.md
 6. Deployment Guide              → docs/deployment.md
 7. Configuration Reference       → docs/configuration.md
 8. Runbook                       → docs/runbook.md

Final step: update README.md via `readme` skill.
Proceed?
```

```
Documentation Plan (wiki + repo):

Wiki:
 1. Architecture Overview         → wiki: Architecture
 2. API Reference — Users         → wiki: API-Users
 3. API Reference — Resources     → wiki: API-Resources
 4. Developer Guide               → wiki: Developer-Guide
 5. Deployment Guide              → wiki: Deployment
 6. Configuration Reference       → wiki: Configuration-Reference
 7. Runbook                       → wiki: Runbook
 8. Home + Sidebar                → wiki: Home, _Sidebar

Repo:
 1. Contributing Guide            → CONTRIBUTING.md
 2. Changelog                     → CHANGELOG.md
 3. ADRs                          → docs/adr/

Final step: update README.md via `readme` skill.
Proceed?
```

### Step 5: Write Pages in Parallel

Prepare a shared brief for all agents:

```
PROJECT BRIEF:
- Project name, language/framework, repo URL
- Key terminology with definitions
- Destination: repo docs/ | GitHub Wiki
- All pages being generated (for cross-references)
- Naming conventions
```

Delegate each page with
`task(category="writing", load_skills=["docs"], run_in_background=true)`.
Include the brief, relevant source files, output path, and the specific
reference template to follow. Fire all simultaneously.

Collect all results before verification.

### Step 6: Verify Statements Against Codebase

Every factual claim in every doc page must be verified against the actual
codebase. This catches hallucinated commands, wrong paths, stale config keys,
and invented behavior.

**Create a todo item per doc page** for tracking. Then delegate one verification
agent per page in parallel:

```
task(
  category="quick",
  load_skills=[],
  run_in_background=true,
  description="Verify <page-name> claims",
  prompt="
    TASK: Verify every factual statement in <file-path> against the codebase.
    EXPECTED OUTCOME: All claims verified or fixed in-place.
    REQUIRED TOOLS: Read, Grep, Glob, Edit
    MUST DO:
    - Read the doc file
    - For EACH factual claim, verify it by searching the codebase:
      • Commands and CLI flags → find the script/config that defines them
      • File paths → confirm they exist
      • Config keys/values → find the actual config definition
      • API endpoints/signatures → find the handler/route
      • Architecture claims → find the referenced modules/files
      • Behavior descriptions → find the implementing code
    - Fix incorrect statements in-place (edit the file)
    - If a claim cannot be verified (no matching code), flag it with
      a <!-- UNVERIFIED: reason --> HTML comment
    - Report: number of claims checked, fixed, and unverifiable
    MUST NOT:
    - Rewrite prose or change style — only fix factual errors
    - Remove content — only correct it
    - Skip any verifiable claim
    CONTEXT: [include project brief and relevant source directories]
  "
)
```

Fire all verification agents simultaneously. Collect all results. Mark each todo
item complete as agents finish.

If any agent reports fixes, do a quick read of those files to confirm the fixes
are coherent.

### Step 7: Verify Cross-Page Consistency

After statement verification, delegate a consistency check across all pages:

```
task(
  category="quick",
  load_skills=[],
  run_in_background=false,
  description="Check cross-page consistency",
  prompt="
    TASK: Verify consistency across all documentation pages.
    EXPECTED OUTCOME: All cross-page issues found and fixed.
    REQUIRED TOOLS: Read, Grep, Edit
    MUST DO:
    - Read every doc page listed below
    - Check for:
      • Terminology: same concept uses the same name everywhere
      • Cross-references: all links resolve; no broken refs
      • Contradictions: no conflicting statements between pages
      • Completeness: no orphan pages; navigation includes all pages
      • Cleanup: no references to removed pages or dead links
      • Style: consistent heading levels, code block hints, formatting
    - Fix all issues found in-place
    MUST NOT:
    - Rewrite content beyond fixing inconsistencies
    - Change factual claims (those were verified in Step 6)
    CONTEXT:
    - Pages: [list all doc file paths]
    - Destination: [repo docs/ | GitHub Wiki]
  "
)
```

### Step 8: Update README.md via `readme` Skill

**Mandatory final step.** Delegate a README update to the `readme` skill:

```
task(
  category="writing",
  load_skills=["readme"],
  run_in_background=false,
  description="Update README with docs links",
  prompt="
    TASK: Update README.md to reflect documentation just generated.
    CONTEXT:
    - Destination: [repo docs/ | GitHub Wiki]
    - Pages: [list all pages with paths or wiki names]
    - If README.md exists, update it (preserve existing content)
    - If README.md does not exist, generate a full README
    MUST DO: Include Documentation section linking to all generated pages
    MUST NOT: Remove existing sections unrelated to documentation
  "
)
```

The `readme` skill is docs/wiki-aware and will include a Documentation section
with correct links.

**For repository docs**: Also create `docs/README.md` as a TOC linking all doc
pages.

**For GitHub Wiki**: Also create `Home.md` as navigation hub and `_Sidebar.md`.
See [references/github-wiki.md].

## Writing Principles

### Readability First

Documentation should be a pleasant reading experience, not a wall of facts.
Build knowledge progressively: start with the big picture, then layer in detail
so the reader is never overwhelmed.

- **Lead with context** — open each section with a sentence explaining _why_
  this matters before diving into _what_
- **Build progressively** — introduce concepts from simple to complex. A reader
  who stops halfway should still walk away with useful understanding
- **One idea per paragraph** — dense paragraphs with multiple concepts lose
  readers. Break them up
- **Transitions matter** — connect sections so the document flows like a
  narrative, not a reference dump
- **Explain the why** — rationale and trade-offs, not just what

### Technical Quality

- **Ground in code** — verify every claim against source files
- **Code blocks liberally** — every command and config must be copy-pasteable
- **Real examples** — actual project names, paths, patterns; no placeholders
- **Keep current** — actual tools, versions, and conventions
- **Be extensive** — thorough and self-contained, not brief overviews

### Formatting

- **Structure for scanning** — headers, tables, bullet points
- **TOC** — for documents over 150 lines
- **Mermaid for diagrams** — always use ` ```mermaid ` fenced code blocks for
  architecture diagrams, data flows, and component relationships. Never use
  ASCII art for diagrams

## Output Locations

### Repository (default)

| Type            | Location                                                     |
| --------------- | ------------------------------------------------------------ |
| API Reference   | `docs/api.md` or `docs/api/` (split by domain)               |
| Architecture    | `docs/architecture.md` or `docs/adr/` for ADRs               |
| Developer Guide | `CONTRIBUTING.md` or `docs/developer-guide.md`               |
| Operations      | `docs/deployment.md`, `docs/runbook.md`, `docs/migration.md` |
| Configuration   | `docs/configuration.md`                                      |
| Changelog       | `CHANGELOG.md` (root)                                        |
| Index           | `docs/README.md`                                             |

Respect existing `docs/` structure.

### GitHub Wiki

See [references/github-wiki.md].

## MUST DO

- Explore codebase before writing
- Audit existing docs — if they're accurate and complete, say so and stop
- Flag obsolete pages/sections for removal and get user confirmation before
  deleting
- After removals: clean up all cross-references and navigation that pointed to
  removed content
- Get user approval on the documentation plan before writing
- Delegate ALL file writes to agents — the orchestrator never writes files
- Write pages in parallel using writing agents with a shared project brief
- After writing, verify every factual statement per page via parallel agents
  (Step 6)
- Create a todo per doc page for verification tracking
- Verify cross-page consistency after statement verification (Step 7)
- Always run the `readme` skill as the final step to update README.md
- In wiki mode: create/update repo-side files (CONTRIBUTING.md, CHANGELOG.md,
  ADRs) alongside wiki pages
- Make each page extensive and thorough

## MUST NOT

- Write, edit, or create documentation files directly — always delegate via
  `task()`
- Guess at configuration, commands, or architecture — verify from code
- Rewrite docs that already accurately reflect the codebase
- Delete pages or sections without user confirmation
- Leave orphaned references to removed pages or sections
- Include placeholder text
- Write generic templates — every doc must be project-specific
- Document features that don't exist in the codebase
- Leave stale commands, paths, or removed features in existing docs
- Edit README.md directly — always delegate to the `readme` skill
- Skip statement verification (Step 6) or consistency verification (Step 7)
- Write pages sequentially when they can be parallelized
- Skip verification todos — every page must have a tracked verification item
