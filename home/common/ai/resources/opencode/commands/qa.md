---
description:
  QA audit of a web app using Playwright — find all UI/UX bugs and save to
  .sisyphus/qa-bugs.md
argument-hint: "<url> [focus-areas]"
---

## Your Task

Act as a senior QA engineer. Open the web application using Playwright (the
`playwriter` tool) and systematically find all UI/UX bugs.

**Arguments:** $ARGUMENTS

If no URL is provided, check for a running dev server (localhost:3000,
localhost:8080, etc.) or ask the user.

## What to Test

Focus on **functional UI bugs** — things that are broken, not style opinions:

- **Dead clicks**: Buttons, links, or interactive elements that do nothing when
  clicked
- **Broken navigation**: Tabs that don't switch, links that don't navigate, back
  button issues
- **JS framework issues**: Unpoly/HTMX/Turbo/Stimulus/Alpine bindings that fail
  to attach (compilers not running, event handlers missing)
- **Drawer/modal issues**: Overlays that don't open, don't close, or corrupt
  browser history
- **URL state**: Tabs/filters that don't update the URL (can't bookmark/share),
  page refresh losing state
- **Form issues**: Submissions that silently fail, missing validation feedback
- **Broken rendering**: Raw HTML shown instead of rendered templates, missing
  content, layout collapse
- **Console errors**: JS exceptions during normal user flows

## How to Test

1. **Open the app** in Playwright and take an initial snapshot
2. **Map the navigation** — identify all top-level pages from nav/sidebar
3. **Test each page systematically:**
   - Navigate to the page, snapshot, check for rendering issues
   - Click every interactive element (buttons, links, tabs, dropdowns, menus)
   - After each click, snapshot again to verify something changed
   - Check browser URL updates where expected
   - Open browser console logs for JS errors
4. **Test cross-cutting concerns:**
   - Browser back/forward behavior
   - Drawer/modal open and dismiss flows
   - Page refresh on each major view
5. **Verify findings** — re-test each bug to confirm it's real, not a Playwright
   artifact. Use DOM inspection (`page.evaluate`) when uncertain.

## Handling False Positives

Playwright snapshots can mislead. Before reporting a bug:

- **Re-test** with a fresh navigation to the same page
- **Check DOM directly** via `page.evaluate()` if snapshot seems wrong
- **Verify the element exists** before claiming it's broken
- If something only fails in Playwright but works via manual DOM interaction,
  it's likely a test artifact — note it in the withdrawn section

## Output Format

Create `.sisyphus/qa-bugs.md` (mkdir -p .sisyphus first) with this structure:

```markdown
# {Project Name} UI Bug Report

Generated: {date} Verified: Yes — each bug re-tested with DOM inspection Total
confirmed bugs: {count}

## Summary

| #   | Severity | Area | Description |
| --- | -------- | ---- | ----------- |
| 1   | high     | ...  | ...         |

## Withdrawn (false positives from automation)

- ~~Description~~ — reason it's not a real bug

## Details

---

### BUG #1 [HIGH] — Title

**Description**

**URL:** http://... **Steps to reproduce:**

1. ...

**Expected:** ... **Actual:** ...

**Root cause:**

- ...

**Files to fix:**

- `path/to/file` — what to change

---

## Test Coverage

### Tested and working:

- ...

### Not tested (out of scope):

- ...
```

**Severity levels:**

- **high** — Core functionality broken (can't use a feature at all)
- **medium** — Feature works but with UX issues (no URL state, confusing
  behavior)
- **low** — Minor polish issues (visual glitches, minor inconsistencies)

## Important

- **Do NOT fix any bugs.** Only document them.
- **Be thorough.** Test every page and every interactive element you can find.
- **Be honest about false positives.** Move withdrawn bugs to the withdrawn
  section with explanation rather than deleting them.
- The withdrawn section is valuable — it tells the fixer what was already
  checked and ruled out.
