# PR Description Format

## Structure

```markdown
## Summary

[1-3 sentences describing what this PR does - be specific about the outcome]

## Changes

- [Bullet point for each logical change]
- [Group related file changes together]
- [Focus on WHAT changed, not HOW you developed it]

## Testing

[How to verify these changes work - manual steps or test commands]
[If no obvious testing needed, state "No testing required" with brief reason]
```

## Principles

**FOCUS ON FINAL STATE ONLY:**
- Describe what the diff shows, not how you got there
- Ignore development iterations in commit history
- Ignore approaches that were tried and reverted

**CONTENT RULES:**
- Reviewers care about WHAT changed, not HOW you developed it
- Be specific about outcomes, not process
- Use action verbs: Add, Update, Fix, Remove, Refactor, Rename
- Group related file changes into single bullet points

## Examples

### Good Summary
> Add PR scope rules and update suggestion-critic agent to filter scope-expanding suggestions

### Bad Summary
> After trying several approaches, finally settled on adding PR scope rules.

### Good Changes
```
- Add `pr-rules.md` with single-responsibility and scope guidelines
- Update suggestion-critic agent to include scope creep validation
```

### Bad Changes
```
- Created a new file after realizing we needed it
- Went back and forth on where to put the logic
```
