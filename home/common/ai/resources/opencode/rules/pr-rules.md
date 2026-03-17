# PR Rules

## Single Responsibility
- Each PR addresses ONE specific concern (bug fix, feature, refactor)
- Never bundle unrelated changes in the same PR
- If you notice something to fix outside scope, create a separate issue/task

## What NOT to Mix
- Feature changes + unrelated refactors
- Bug fixes + linting/formatting of unrelated files
- New functionality + "drive-by" cleanups
- Implementation + opportunistic improvements

## Allowed in Same PR
- Changes directly required by the feature/fix
- Formatting of files YOU modified for the task
- Tests for the specific changes made
- Documentation updates for the specific changes

## When Tempted to Scope Creep
1. STOP - recognize the unrelated improvement
2. Note it in a TODO comment or create a separate issue
3. Stay focused on the original task
4. Address improvements in dedicated PRs

## PR Size Guidelines
- Aim for under 400 changed lines
- If larger, consider splitting into multiple PRs
- Large PRs slow reviews and hide bugs

## PR Description Guidelines
- Describe the FINAL changes against the base branch only
- Do NOT include development history (approaches tried and abandoned)
- Do NOT mention iterations or pivots during implementation
- Reviewers care about WHAT changed, not HOW you got there
- The git history captures the journey; the description captures the destination
