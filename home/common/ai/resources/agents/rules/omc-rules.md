# OMC Rules

## Learned Skill Paths

OMC `/learner` and any manual skill extraction MUST write outside the project repository. Worktree-local skills die on worktree deletion.

**Allowed global paths** (either is valid):

- `~/.claude/skills/omc-learned/` — learner's default write target
- `~/.omc/skills/` — OMC global shared skill path

**Never write skills to:**

- `./.omc/skills/` (worktree-scoped, ephemeral)
- Any path inside the current project repo

## Paths Reference

- Skills: `~/.claude/skills/omc-learned/` or `~/.omc/skills/`
- State: `$OMC_STATE_DIR` (currently `~/.local/share/omc`) — separate concern, not a skill path
- Worktree-only state: `.omc/` (gitignored, ephemeral) — fine for session state, never for learned skills
