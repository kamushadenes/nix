---
description:
  Generate or update comprehensive project documentation (API reference,
  architecture, developer guides, deployment docs, runbooks, changelogs). Use
  "/docs wiki" to write to GitHub Wiki instead of the repo. Always updates
  README.md via the `readme` skill as a final step.
---

Load the `docs` skill, then generate or update documentation for the current
project.

Follow the skill's workflow: explore the codebase, audit existing docs, choose
destination, build a plan, get user approval, write pages in parallel, verify
consistency, and update README.md via the `readme` skill.

If the argument is "wiki", use GitHub Wiki hybrid mode. If no argument is given,
ask the user whether to write to the repo or the wiki.

If a specific doc type is mentioned (e.g., "API reference", "runbook"), generate
or update only that type. Otherwise, generate a full documentation suite.

For README-only changes, use `/readme` directly.

$ARGUMENTS
