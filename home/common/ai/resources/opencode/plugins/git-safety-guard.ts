import type { Plugin } from "@opencode-ai/plugin"

const DESTRUCTIVE_PATTERNS: Array<{ pattern: RegExp; reason: string }> = [
  { pattern: /git\s+checkout\s+--\s+/, reason: "git checkout -- discards uncommitted changes permanently. Use 'git stash' first." },
  { pattern: /git\s+checkout\s+(?!-b\b)(?!--orphan\b)[^\s]+\s+--\s+/, reason: "git checkout <ref> -- <path> overwrites working tree. Use 'git stash' first." },
  { pattern: /git\s+restore\s+(?!--staged\b)(?!-S\b)/, reason: "git restore discards uncommitted changes. Use 'git stash' or 'git diff' first." },
  { pattern: /git\s+restore\s+.*(?:--worktree|-W\b)/, reason: "git restore --worktree/-W discards uncommitted changes permanently." },
  { pattern: /git\s+reset\s+--hard/, reason: "git reset --hard destroys uncommitted changes. Use 'git stash' first." },
  { pattern: /git\s+reset\s+--merge/, reason: "git reset --merge can lose uncommitted changes." },
  { pattern: /git\s+clean\s+-[a-z]*f/, reason: "git clean -f removes untracked files permanently. Review with 'git clean -n' first." },
  { pattern: /git\s+push\s+.*--force(?![-a-z])/, reason: "Force push can destroy remote history. Use --force-with-lease if necessary." },
  { pattern: /git\s+push\s+.*-f\b/, reason: "Force push (-f) can destroy remote history. Use --force-with-lease if necessary." },
  { pattern: /git\s+branch\s+-D\b/, reason: "git branch -D force-deletes without merge check. Use -d for safety." },
  { pattern: /rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+[*]|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+[*]/, reason: "rm -rf * is EXTREMELY DANGEROUS." },
  { pattern: /rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+\/\s*$|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+\/\s*$/, reason: "rm -rf / is EXTREMELY DANGEROUS." },
  { pattern: /rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+\/[*]|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+\/[*]/, reason: "rm -rf /* is EXTREMELY DANGEROUS." },
  { pattern: /rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+~\s*$|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+~\s*$/, reason: "rm -rf ~ is EXTREMELY DANGEROUS." },
  { pattern: /git\s+stash\s+drop/, reason: "git stash drop permanently deletes stashed changes." },
  { pattern: /git\s+stash\s+clear/, reason: "git stash clear permanently deletes ALL stashed changes." },
]

const SAFE_PATTERNS: RegExp[] = [
  /git\s+checkout\s+-b\s+/,
  /git\s+checkout\s+--orphan\s+/,
  /git\s+restore\s+--staged\s+(?!.*--worktree)(?!.*-W\b)/,
  /git\s+restore\s+-S\s+(?!.*--worktree)(?!.*-W\b)/,
  /git\s+clean\s+-[a-z]*n[a-z]*/,
  /git\s+clean\s+--dry-run/,
]

function normalizeAbsolutePaths(cmd: string): string {
  return cmd
    .replace(/^\/(?:\S*\/)*s?bin\/rm(?=\s|$)/, "rm")
    .replace(/^\/(?:\S*\/)*s?bin\/git(?=\s|$)/, "git")
}

export const GitSafetyGuard: Plugin = async () => ({
  "tool.execute.before": async (input, output) => {
    const tool = String(input?.tool ?? "").toLowerCase()
    if (tool !== "bash" && tool !== "shell") return
    const args = output?.args
    if (!args || typeof args !== "object") return
    const rawCommand = (args as Record<string, unknown>).command
    if (typeof rawCommand !== "string" || !rawCommand) return
    const command = normalizeAbsolutePaths(rawCommand)
    for (const safe of SAFE_PATTERNS) {
      if (safe.test(command)) return
    }
    for (const { pattern, reason } of DESTRUCTIVE_PATTERNS) {
      if (pattern.test(command)) {
        throw new Error(`BLOCKED by git-safety-guard: ${reason}\nCommand: ${rawCommand}`)
      }
    }
  },
})
