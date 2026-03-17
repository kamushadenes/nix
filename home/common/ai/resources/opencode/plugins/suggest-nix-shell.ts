import type { Plugin } from "@opencode-ai/plugin"

// Suggests nix-shell packages when a command is not found.
// Uses nix-locate to find the package that provides the missing binary.

export const SuggestNixShell: Plugin = async ({ $ }) => {
  try {
    await $`which nix-locate`.quiet()
  } catch {
    return {}
  }

  return {
    "tool.execute.after": async (input, output) => {
      const tool = String(input?.tool ?? "").toLowerCase()
      if (tool !== "bash" && tool !== "shell") return

      const text = output?.output ?? ""
      if (!text.includes("command not found") && !text.includes("not found")) return

      // Extract the missing binary name
      let binary = ""
      for (const line of text.split("\n")) {
        const m1 = line.match(/^([^:]+): command not found$/)
        if (m1) { binary = m1[1]; break }
        const m2 = line.match(/^bash: ([^:]+): command not found$/)
        if (m2) { binary = m2[1]; break }
      }
      if (!binary) return

      try {
        const result = await $`nix-locate --minimal --whole-name --at-root /bin/${binary}`.quiet().nothrow()
        const packages = String(result.stdout).trim()
        if (!packages) return

        const lines = packages.split("\n").slice(0, 3)
        const pkg = lines[0].replace(/\.(out|bin)$/, "")
        const pkgList = lines.map((p) => `   - ${p.replace(/\.(out|bin)$/, "")}`).join("\n")
        const originalCmd = typeof input?.args?.command === "string" ? input.args.command : binary

        const suggestion = [
          `Command '${binary}' not found. Available in nixpkgs:`,
          pkgList,
          "",
          `Run with: nix-shell -p ${pkg} --run "${originalCmd}"`,
        ].join("\n")

        // Append suggestion to tool output so the model sees it
        output.output = `${text}\n\n${suggestion}`
      } catch {
        // nix-locate failed, skip
      }
    },
  }
}
