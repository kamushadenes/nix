---
description: Fix or dismiss GitHub CodeQL code scanning alerts
argument-hint: "[repo-url-or-owner/repo]"
---

## Context

- Repo:
  !`gh repo view --json owner,name --jq '.owner.login + "/" + .name' 2>/dev/null || echo "unknown"`
- Default branch:
  !`gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "main"`
- Date: !`date +%Y%m%d`

## Your Task

Fix or dismiss open CodeQL code scanning alerts for a GitHub repository by
evaluating each alert, applying code fixes for real issues, and dismissing false
positives via the API.

### Step 1: Determine the Repo

Parse `$ARGUMENTS`:

- If URL (contains `github.com`): extract `owner/repo`
- If `owner/repo` format: use directly
- If empty: use current repo (from context above)

If the target repo differs from the current working directory, inform the user
that fixes require a local checkout and stop.

### Step 2: Ensure Clean Default Branch

```bash
git checkout DEFAULT_BRANCH && git pull
```

Use the default branch from context (not hardcoded `main`).

### Step 3: Fetch Open Alerts

```bash
gh api --paginate "repos/OWNER/REPO/code-scanning/alerts?state=open&per_page=100"
```

If the response is empty or errors with 404, the repo may not have code scanning
enabled. Inform the user and stop.

### Step 4: Present Summary

Show the user:

- Total open alerts
- Count by severity and rule category
- Files affected (grouped)

If zero alerts, inform the user and stop.

### Step 5: Triage Alerts

Before processing, batch-evaluate all alerts using the suggestion-critic task:

```
task(
  subagent_type="suggestion-critic",
  prompt="""Evaluate these CodeQL code scanning alerts for triage.

Alerts:
ALERTS_JSON

For each alert, categorize as:
1. **ACTIONABLE** - Real issue in first-party code that should be fixed
2. **FALSE_POSITIVE** - Alert is incorrect or doesn't apply
3. **WONT_FIX** - Real but acceptable risk (test code, dev-only, etc.)
4. **DUPLICATE** - Same root cause as another alert

Return categorized alerts with reasoning.
Final response under 2000 characters. List outcomes, not process.""",
  description="Triage code scanning alerts"
)
```

Present triage results to the user before proceeding.

### Step 6: Create Branch

```bash
git checkout -b fix/code-scanning-YYYYMMDD
```

Use the date from context. If branch exists, append a counter suffix (e.g.,
`-2`).

### Step 7: Process Alerts by File

Group actionable alerts by file path. Process files in alphabetical order.
Within each file, process alerts from **bottom to top** (highest line number
first) to avoid line number shifts from edits.

For each file group, use the `security-auditor` task to evaluate and recommend
fixes:

```
task(
  subagent_type="security-auditor",
  prompt="""Evaluate these CodeQL alerts for `FILE_PATH` and recommend fixes.

Alerts:
ALERT_JSON

Read the file. For each alert return:
- Alert number
- Exact code change needed (old code -> new code)
- Brief explanation

Final response under 2000 characters. List outcomes, not process.""",
  description="Evaluate alerts for FILE_PATH"
)
```

Apply the recommended fixes using Edit tool.

### Step 8: Commit and Push

If any code changes were made:

1. Use `skill(name="git-master")` to commit, summarizing the security fixes
   applied
2. Push: `git push -u origin BRANCH_NAME`

### Step 9: Create PR

If code changes were made, create a PR with `gh pr create`. Include:

- Summary of fixes and dismissals
- List of fixed alerts (rule ID, file, fix description)
- List of dismissed alerts (rule ID, file, reason)

### Step 10: Dismiss Alerts via API

For each alert marked as false positive, won't-fix, or used-in-tests:

```bash
gh api -X PATCH "repos/OWNER/REPO/code-scanning/alerts/ALERT_NUMBER" \
  -f state=dismissed \
  -f dismissed_reason="false positive" \
  -f dismissed_comment="REASON"
```

Valid `dismissed_reason` values: `"false positive"`, `"won't fix"`,
`"used in tests"`.

**If all alerts are dismissed with no code changes**, skip Steps 8-9 and dismiss
directly on the default branch.

### Step 11: Report

Summarize:

- **Fixed** (N): alert number, rule, file, fix description
- **Dismissed** (M): alert number, rule, file, dismissal reason
- **PR**: URL (if created)
- **Remaining**: alerts that couldn't be resolved (with explanation)
