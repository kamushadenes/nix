---
allowed-tools: Bash(bd sync:*), Bash(bd import:*), Bash(git checkout:*), Bash(git pull:*), Bash(git push:*), Bash(git status:*), Bash(git branch:*), Bash(gh pr:*), Bash(test:*)
description: Merge beads-sync branch to main (for protected branch workflows)
---

## Context

- Current directory: !`pwd`
- Beads initialized: !`test -d .beads && echo "yes" || echo "no"`
- Current branch: !`git branch --show-current`
- Sync branch exists: !`git branch -a | grep -q beads-sync && echo "yes" || echo "no"`
- Uncommitted changes: !`git status --porcelain | head -5`

## Your task

Merge the beads-sync branch into main. This is used in protected branch workflows where beads data is kept on a separate sync branch.

### Option 1: Direct merge (if you have push access to main)

If the user has direct push access:

```bash
# Preview changes first
bd sync --merge --dry-run

# Execute the merge (switches to main, merges beads-sync with --no-ff, pushes)
bd sync --merge
```

### Option 2: Pull request (for protected branches)

If main requires PRs:

1. Ensure beads-sync is pushed:
   ```bash
   git push origin beads-sync
   ```

2. Create a PR:
   ```bash
   gh pr create --base main --head beads-sync --title "Sync beads metadata" --body "Merge beads issue tracking data to main branch."
   ```

3. After PR is merged, update local:
   ```bash
   git checkout main
   git pull
   bd import
   ```

### Handling merge conflicts

If conflicts occur in `.beads/issues.jsonl`:
1. Keep the line with the newer `updated_at` timestamp
2. Remove conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
3. Commit resolution and run `bd import`

**Ask the user** which approach they prefer (direct merge or PR) before proceeding.
