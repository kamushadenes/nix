import type { Plugin } from "@opencode-ai/plugin"

// Runs project linter on session.idle if lintable files changed since last run.
// Uses a fingerprint cache to skip redundant lint runs.

const LINT_EXTS = /\.(go|py|ts|tsx|js|jsx|nix|sh|bash|yml|yaml|json|toml|tf|hcl|sql|rs|rb|java|kt|swift|c|cpp|h)$/i

let lastFingerprint = ""

export const PostLint: Plugin = async ({ $ }) => ({
  event: async ({ event }) => {
    if (event.type !== "session.idle") return

    // Check prerequisites
    try {
      await $`git rev-parse --is-inside-work-tree`.quiet()
    } catch {
      return
    }

    try {
      await $`which just`.quiet()
    } catch {
      return
    }

    const listResult = await $`just --list`.quiet().nothrow()
    const list = String(listResult.stdout)
    if (!/^\s+lint(-fix)?(\s|$)/m.test(list)) return

    // Collect changed files (staged, unstaged, untracked)
    const changed = await $`(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null) | sort -u`.quiet().nothrow()
    const changedFiles = String(changed.stdout).trim()

    // Filter to lintable extensions
    const lintable = changedFiles
      .split("\n")
      .filter((f) => f && LINT_EXTS.test(f))
    if (lintable.length === 0) return

    // Fingerprint cache
    const headResult = await $`git rev-parse HEAD`.quiet().nothrow()
    const headSha = String(headResult.stdout).trim() || "none"
    const fingerprint = `${headSha}:${lintable.join(",")}`
    if (fingerprint === lastFingerprint) return

    // Load devbox if available
    try {
      await $`test -f devbox.json && command -v devbox`.quiet()
      await $`eval "$(devbox shellenv 2>/dev/null)" 2>/dev/null`.quiet().nothrow()
    } catch {
      // no devbox, fine
    }

    // Run lint
    const lintCmd = /^\s+lint-fix(\s|$)/m.test(list) ? "lint-fix" : "lint"
    const result = await $`just ${lintCmd}`.quiet().nothrow()

    if (result.exitCode === 0) {
      lastFingerprint = fingerprint
    }
    // If lint fails, don't cache so it reruns next time
  },
})
