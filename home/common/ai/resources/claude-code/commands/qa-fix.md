---
description:
  Pick a bug from .omc/qa-bugs.md, fix it via the OMC executor, and verify the
  fix with Playwright
argument-hint: [bug-number]
---

## Your Task

Read `.omc/qa-bugs.md`, pick one bug, fix it using the OMC executor agent, and
verify the fix using Playwright (the `playwriter` tool).

**Arguments:** $ARGUMENTS

If a bug number is provided, fix that specific bug. Otherwise, pick the
highest-severity unfixed bug.

## OMC Integration

- **State lives in `.omc/`.** The bug report lives at `.omc/qa-bugs.md` — do
  not read or write `.sisyphus/`, that path is deprecated.
- **Delegate the fix** to `oh-my-claudecode:executor` (use `model=opus` for
  complex multi-file bugs, `sonnet` otherwise). Pass the bug's root cause,
  files-to-fix, and reproduction steps so the executor has enough context to
  work without re-reading the report.
- **Cancellable** via `/oh-my-claudecode:cancel`. Because state persists under
  `.omc/`, a later run resumes from whichever bug is still open.

## Workflow

### 1. Read the Bug Report

Read `.omc/qa-bugs.md`. Parse the summary table and details sections.

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

### 4. Fix the Bug via the OMC Executor

Delegate the code change to `oh-my-claudecode:executor`:

- Pass the bug's title, root cause, files to fix, and reproduction steps
- Instruct the executor to apply the **minimal** fix — no refactors, no
  drive-by cleanups, no adjacent improvements
- Tell the executor to follow existing code patterns and conventions
- If the root-cause analysis in the report turns out to be wrong, capture the
  real cause in the updated report (step 6)

Pick the model by task size:

- `model=haiku` — trivial one-line tweaks
- `model=sonnet` — standard single-file fixes (default)
- `model=opus` — multi-file or architectural fixes

If the fix falls fully within a single obvious edit and delegation would be
pure overhead, an inline edit is acceptable — but prefer the executor so the
fix is verified and logged by OMC.

### 5. Verify the Fix with Playwright

After the executor returns:

1. Open the same URL in Playwright
2. Follow the exact reproduction steps from the bug report
3. Verify the expected behavior now occurs
4. Check that the fix didn't break adjacent functionality (e.g., if you fixed a
   tab, make sure other tabs still work)
5. Check browser console for new JS errors

If verification fails, hand the failure back to the executor (or escalate to
`model=opus`) and retry — do not mark the bug fixed until Playwright confirms.

### 6. Update the Bug Report

Edit `.omc/qa-bugs.md`:

- In the **Summary** table, append ` ✅` to the description of the fixed bug
- In the **Details** section, add a `**Fixed:**` line at the end of the bug:

```markdown
**Fixed:** {date} — {brief description of the fix}
```

If the real root cause differed from what was originally recorded, update the
**Root cause** line in the same edit.

## Important

- **One bug per invocation.** Fix one bug, verify it, update the report. Run
  `/qa-fix` again for the next bug.
- **Minimal fixes only.** Don't refactor. Don't improve. Don't "also fix" nearby
  issues.
- **Always verify with Playwright.** A fix without verification is not a fix.
- **Update the report.** `.omc/qa-bugs.md` is the source of truth — keep it
  current so `/qa-fix`, `/oh-my-claudecode:autopilot`, and other OMC flows can
  resume cleanly.
