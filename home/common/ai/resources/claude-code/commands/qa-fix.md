---
description:
  Pick a bug from .sisyphus/qa-bugs.md, fix it, and verify the fix with
  Playwright
argument-hint: [bug-number]
---

## Your Task

Read `.sisyphus/qa-bugs.md`, pick one bug, fix it, and verify the fix using
Playwright.

**Arguments:** $ARGUMENTS

If a bug number is provided, fix that specific bug. Otherwise, pick the
highest-severity unfixed bug.

## Workflow

### 1. Read the Bug Report

Read `.sisyphus/qa-bugs.md`. Parse the summary table and details sections.

Identify which bugs are still open:

- Bugs in the summary table that have NOT been marked with ~~strikethrough~~ or
  moved to the withdrawn section are open
- Fixed bugs have ` ✅` appended to their summary description
- If the user specified a bug number, use that one
- Otherwise, pick the highest-severity open bug (high > medium > low)

### 2. Understand the Bug

Read the detailed bug section carefully:

- **Root cause** — understand WHY the bug happens before touching code
- **Files to fix** — the report suggests files, but verify they're correct by
  reading them
- **Steps to reproduce** — you'll need these for verification

### 3. Reproduce the Bug with Playwright

Before fixing, confirm the bug is still present:

1. Open the URL from the bug report in Playwright
2. Follow the exact steps to reproduce
3. Verify the bug manifests as described
4. If the bug no longer exists (already fixed or can't reproduce), update the
   report and pick the next bug

### 4. Fix the Bug

Apply the minimal fix:

- Fix ONLY the specific bug — do not refactor, clean up, or improve unrelated
  code
- Follow existing code patterns and conventions
- If the root cause analysis in the report is wrong, note what the actual cause
  was

### 5. Verify the Fix with Playwright

After fixing:

1. Open the same URL in Playwright
2. Follow the exact reproduction steps from the bug report
3. Verify the expected behavior now occurs
4. Check that the fix didn't break adjacent functionality (e.g., if you fixed a
   tab, make sure other tabs still work)
5. Check browser console for new JS errors

### 6. Update the Bug Report

Edit `.sisyphus/qa-bugs.md`:

- In the **Summary** table, append ` ✅` to the description of the fixed bug
- In the **Details** section, add a `**Fixed:**` line at the end of the bug:

```markdown
**Fixed:** {date} — {brief description of the fix}
```

## Important

- **One bug per invocation.** Fix one bug, verify it, update the report. Run
  `/qa-fix` again for the next bug.
- **Minimal fixes only.** Don't refactor. Don't improve. Don't "also fix" nearby
  issues.
- **Always verify with Playwright.** A fix without verification is not a fix.
- **Update the report.** The qa-bugs.md file is the source of truth — keep it
  current.
