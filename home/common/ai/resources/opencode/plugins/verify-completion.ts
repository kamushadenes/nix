import type { Plugin } from "@opencode-ai/plugin"

// Checks for uncommitted git changes before allowing task completion.
// Uses tool.execute.before to intercept todo/task completion actions.

export const VerifyCompletion: Plugin = async ({ $ }) => ({
  "tool.execute.before": async (input, output) => {
    const tool = String(input?.tool ?? "").toLowerCase()
    // Intercept todowrite or task-completion-like tools
    if (tool !== "todowrite" && tool !== "todoupdate") return

    // Check if we're in a git repo
    try {
      await $`git rev-parse --is-inside-work-tree`.quiet()
    } catch {
      return
    }

    // Check if there are any commits
    try {
      await $`git rev-parse HEAD`.quiet()
    } catch {
      return // no commits yet, skip
    }

    // Check for uncommitted changes (staged + unstaged)
    const diffResult = await $`git diff --quiet HEAD`.quiet().nothrow()
    const untrackedResult = await $`git ls-files --others --exclude-standard`.quiet().nothrow()
    const untracked = String(untrackedResult.stdout).trim()

    if (diffResult.exitCode !== 0 || untracked.length > 0) {
      throw new Error(
        "Cannot mark task complete with uncommitted changes. Commit or stash first.",
      )
    }
  },
})
