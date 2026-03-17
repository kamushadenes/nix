import type { Plugin } from "@opencode-ai/plugin"

// Devbox/direnv setup plugin - sets up devbox environment in web/remote sessions.
// Only runs when OPENCODE_REMOTE (or CLAUDE_CODE_REMOTE) is "true".

export const DevboxSetup: Plugin = async ({ $ }) => ({
  "shell.env": async (input, output) => {
    // Only run in web/remote environment
    const isRemote =
      process.env.OPENCODE_REMOTE === "true" ||
      process.env.CLAUDE_CODE_REMOTE === "true"
    if (!isRemote) return

    // Only run if devbox.json exists
    try {
      await $`test -f devbox.json`.quiet()
    } catch {
      return
    }

    // Install devbox if not present
    try {
      await $`which devbox`.quiet()
    } catch {
      try {
        await $`curl -fsSL https://get.jetify.com/devbox 2>/dev/null | bash 2>/dev/null`.quiet()
      } catch {
        return
      }
    }

    // Run direnv allow if available
    try {
      await $`which direnv`.quiet()
      await $`direnv allow .`.quiet().nothrow()
      const direnvResult = await $`direnv export bash`.quiet().nothrow()
      const direnvOutput = String(direnvResult.stdout).trim()
      // Parse export lines into env vars
      for (const line of direnvOutput.split("\n")) {
        const match = line.match(/^export\s+([^=]+)=(.*)$/)
        if (match) {
          output.env[match[1]] = match[2].replace(/^['"]|['"]$/g, "")
        }
      }
    } catch {
      // no direnv, fine
    }

    // Get devbox shell environment
    try {
      const result = await $`devbox shellenv`.quiet().nothrow()
      const shellenv = String(result.stdout).trim()
      for (const line of shellenv.split("\n")) {
        const match = line.match(/^export\s+([^=]+)=(.*)$/)
        if (match) {
          output.env[match[1]] = match[2].replace(/^['"]|['"]$/g, "")
        }
      }
    } catch {
      // devbox shellenv failed, skip
    }
  },
})
