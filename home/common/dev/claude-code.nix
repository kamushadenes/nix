# Claude Code (claude.ai/code) configuration
#
# Uses the built-in home-manager programs.claude-code module for settings.
# MCP servers are managed separately to support secret substitution.
# Secrets are encrypted with agenix and substituted at activation time.
#
# Memory (CLAUDE.md) is managed via the module's memory.text option.
# Rules are organized in ~/.claude/rules/ for modular configuration.
{
  config,
  lib,
  pkgs,
  private,
  ...
}:
let
  #############################################################################
  # tmux MCP Server - Terminal automation for interacting with CLI apps
  #############################################################################
  tmuxMcpServer = ''
    #!/usr/bin/env python3
    """MCP server for tmux terminal automation - uses tmux directly"""
    import subprocess
    import hashlib
    import time
    import os
    import json
    from mcp.server.fastmcp import FastMCP

    mcp = FastMCP("tmux")


    def run_tmux(*args) -> tuple[str, int]:
        """Run a tmux command and return (stdout, returncode)"""
        result = subprocess.run(
            ["tmux"] + list(args),
            capture_output=True,
            text=True
        )
        return result.stdout.strip(), result.returncode


    def get_current_pane() -> str:
        """Get the pane ID where Claude Code is running"""
        return os.environ.get("TMUX_PANE", "")


    @mcp.tool()
    def tmux_split(
        command: str = "zsh",
        direction: str = "right",
        size: int = 50
    ) -> str:
        """
        Create a new tmux split and run a command in it.

        Args:
            command: Command to run in the new pane (default: zsh)
            direction: Split direction - "right", "left", "up", "down"
            size: Size percentage for the new pane (1-99)

        Returns:
            Stable pane ID (e.g., "%5") that persists until the pane is killed
        """
        # Map direction to tmux flags
        dir_flags = {
            "right": ["-h"],
            "left": ["-hb"],
            "down": ["-v"],
            "up": ["-vb"]
        }
        flags = dir_flags.get(direction, ["-h"])

        # Create split with size, return stable pane ID
        args = ["split-window"] + flags + ["-l", f"{size}%", "-P", "-F",
               "#{pane_id}", command]
        output, code = run_tmux(*args)

        if code != 0:
            return f"Error creating split: {output}"
        return output


    @mcp.tool()
    def tmux_send(pane: str, text: str, enter: bool = True) -> str:
        """
        Send text/keystrokes to a tmux pane.

        Args:
            pane: Pane identifier - use stable ID from tmux_split (e.g., "%5")
            text: Text to send
            enter: Whether to press Enter after the text

        Returns:
            Success message or error
        """
        args = ["send-keys", "-t", pane, text]
        if enter:
            args.append("Enter")

        output, code = run_tmux(*args)
        if code != 0:
            return f"Error sending keys: {output}"
        return "Text sent successfully"


    @mcp.tool()
    def tmux_capture(pane: str, lines: int = 100) -> str:
        """
        Capture output from a tmux pane.

        Args:
            pane: Pane identifier - use stable ID from tmux_split (e.g., "%5")
            lines: Number of lines to capture from scrollback (default: 100)

        Returns:
            Captured pane content
        """
        args = ["capture-pane", "-t", pane, "-p", "-S", f"-{lines}"]
        output, code = run_tmux(*args)

        if code != 0:
            return f"Error capturing pane: {output}"
        return output


    @mcp.tool()
    def tmux_list() -> str:
        """
        List all panes in the current window.

        Returns:
            JSON-formatted list of panes with their IDs, commands, and status
        """
        format_str = "#{pane_id}|#{pane_index}|#{pane_current_command}|#{pane_active}|#{pane_width}x#{pane_height}"
        output, code = run_tmux("list-panes", "-F", format_str)

        if code != 0:
            return f"Error listing panes: {output}"

        panes = []
        current = get_current_pane()
        for line in output.split("\n"):
            if line:
                parts = line.split("|")
                panes.append({
                    "id": parts[0],
                    "index": parts[1],
                    "command": parts[2],
                    "active": parts[3] == "1",
                    "size": parts[4],
                    "is_claude": parts[0] == current
                })

        return json.dumps(panes, indent=2)


    @mcp.tool()
    def tmux_kill(pane: str) -> str:
        """
        Kill a tmux pane.

        Args:
            pane: Pane identifier to kill

        Returns:
            Success message or error
        """
        # Safety: prevent killing own pane (using stable pane IDs)
        current = get_current_pane()
        if pane == current:
            return "Error: Cannot kill Claude's own pane!"

        output, code = run_tmux("kill-pane", "-t", pane)
        if code != 0:
            return f"Error killing pane: {output}"
        return "Pane killed successfully"


    @mcp.tool()
    def tmux_interrupt(pane: str) -> str:
        """
        Send Ctrl+C interrupt to a pane.

        Args:
            pane: Pane identifier

        Returns:
            Success message
        """
        run_tmux("send-keys", "-t", pane, "C-c")
        return "Interrupt sent"


    @mcp.tool()
    def tmux_wait_idle(pane: str, idle_seconds: float = 2.0, timeout: int = 60) -> str:
        """
        Wait for a pane to become idle (no output changes).

        Args:
            pane: Pane identifier
            idle_seconds: Seconds of no change to consider idle
            timeout: Maximum seconds to wait

        Returns:
            "idle" when pane is idle, or "timeout" if timeout reached
        """
        start = time.time()
        last_hash = ""
        last_change = time.time()

        while time.time() - start < timeout:
            content, _ = run_tmux("capture-pane", "-t", pane, "-p")
            current_hash = hashlib.md5(content.encode()).hexdigest()

            if current_hash != last_hash:
                last_hash = current_hash
                last_change = time.time()
            elif time.time() - last_change >= idle_seconds:
                return "idle"

            time.sleep(0.5)

        return "timeout"


    if __name__ == "__main__":
        mcp.run()
  '';

  #############################################################################
  # tmux Skill File - Teaches Claude Code how to use the tmux MCP tools
  # Follows best practices from platform.claude.com/docs
  #############################################################################
  tmuxSkillFile = ''
    ---
    name: automating-tmux-panes
    description: Automates terminal sessions in tmux panes using MCP tools. Use when launching background processes, monitoring builds/servers, sending commands to debuggers (pdb/gdb), interacting with CLI prompts, or orchestrating parallel tasks across multiple terminal sessions.
    ---

    # Automating tmux Panes

    Control tmux panes programmatically: split windows, send commands, capture output, and manage processes.

    ## Quick Reference

    | Tool | Purpose |
    |------|---------|
    | `mcp__tmux__tmux_split` | Create split pane |
    | `mcp__tmux__tmux_send` | Send text/keys |
    | `mcp__tmux__tmux_capture` | Get pane output |
    | `mcp__tmux__tmux_list` | List panes (JSON) |
    | `mcp__tmux__tmux_kill` | Close pane |
    | `mcp__tmux__tmux_interrupt` | Send Ctrl+C |
    | `mcp__tmux__tmux_wait_idle` | Wait for idle |

    ## Critical: Always Start with a Shell

    Launch a shell first, then run commands. Direct command execution loses output on exit:

    ```
    # Correct workflow - save the stable pane ID
    pane_id = mcp__tmux__tmux_split(command="zsh", direction="right")  # Returns "%5"
    mcp__tmux__tmux_send(pane=pane_id, text="python script.py")

    # Wrong - output lost if script exits/errors
    mcp__tmux__tmux_split(command="python script.py")
    ```

    ## Pane Identifiers

    **Always use the stable pane ID returned by `tmux_split`** (e.g., `"%5"`). These IDs:
    - Never change when other panes are created or killed
    - Persist until the pane itself is destroyed
    - Are the only reliable way to reference panes across operations

    Legacy formats (index `"1"` or `"main:0.1"`) still work but shift when panes are killed.

    ## Standard Workflow

    ```
    # 1. Create pane with shell - SAVE THE RETURNED ID
    pane_id = mcp__tmux__tmux_split(command="zsh", direction="right", size=40)  # Returns "%5"

    # 2. Run command using the stable ID
    mcp__tmux__tmux_send(pane=pane_id, text="npm run build")

    # 3. Wait for completion
    mcp__tmux__tmux_wait_idle(pane=pane_id, idle_seconds=2.0)  # Returns "idle" or "timeout"

    # 4. Get output
    output = mcp__tmux__tmux_capture(pane=pane_id, lines=50)

    # 5. Cleanup - safe even if other panes were killed
    mcp__tmux__tmux_kill(pane=pane_id)
    ```

    ## Split Directions

    - `"right"` - New pane on right (default)
    - `"left"` - New pane on left
    - `"down"` - New pane below
    - `"up"` - New pane above

    ## Safety

    - Cannot kill own pane (server prevents this)
    - Use `tmux_interrupt` to stop runaway processes
    - Check `is_claude` field in `tmux_list` to identify your pane
    - **Always store and reuse the pane ID from `tmux_split`** - indices shift when panes are killed
  '';

  # Global user memory - applies to all projects
  # Project-specific CLAUDE.md files take precedence
  globalMemory = ''
    # Global Claude Code Instructions

    These rules apply to all projects unless overridden by project-specific CLAUDE.md files.

    ## Git Commit Rules

    Never introduce Claude, Claude Code or Anthropic as Co-Authored-By in git commits, or mention it was used in any way.

    ## Code Style

    - Follow existing project conventions
    - Prefer simplicity over cleverness
    - Write self-documenting code with minimal comments
  '';

  # Modular rules - each becomes a file in ~/.claude/rules/
  rulesConfig = {
    # Git and version control rules
    "git-rules.md" = ''
      # Git Rules

      ## Commit Messages

      - Use conventional commit format when appropriate
      - Never mention AI assistance in commits
      - Keep messages concise and descriptive

      ## Branch Workflow

      - Always check current branch before making changes
      - Prefer feature branches for significant changes
    '';

    # Nix-specific rules
    "nix-rules.md" = ''
      ---
      paths: **/*.nix
      ---

      # Nix Development Rules

      ## Flakes

      - New files must be committed before nix can see them (flakes only track git-tracked files)
      - Run `nix flake check` before rebuilding
      - Use `nix fmt` to format nix files

      ## Home Manager

      - Test changes with `rebuild` alias
      - Check for option conflicts with existing modules
      - Prefer editing existing files over creating new ones
    '';

    # Security rules
    "nix-security-rules.md" = ''
      ---
      paths: **/*.nix
      ---

      # Security Rules

      ## Secrets Management

      - Never commit plaintext secrets
      - Use agenix for secret encryption
      - Secrets use @PLACEHOLDER@ syntax for substitution
    '';

    "security-rules.md" = ''
      ## Code Review

      - Check for command injection vulnerabilities
      - Validate user inputs at boundaries
      - Follow OWASP guidelines
    '';
  };

  # Statusline script - shows directory, git branch, and model info
  statuslineScript = ''
    #!/usr/bin/env bash
    input=$(cat)
    cwd=$(echo "$input" | jq -r '.workspace.current_dir')
    model=$(echo "$input" | jq -r '.model.display_name')
    LAVENDER='\033[38;2;183;189;248m'
    MAUVE='\033[38;2;198;160;246m'
    RESET='\033[0m'
    user=""; host=""
    [ -n "$SSH_CONNECTION" ] && user=$(whoami) && host=$(hostname -s)
    dir_parts=$(echo "$cwd" | tr '/' '\n' | grep -v '^$' | tail -n 4 | paste -sd '/' -)
    [ "$cwd" = "$HOME" ] && display_dir="~" || { [ -z "$dir_parts" ] && display_dir="/" || display_dir="$dir_parts"; }
    git_branch=""
    if git -C "$cwd" -c core.useBuiltinFSMonitor=false -c core.fsmonitor= rev-parse --git-dir >/dev/null 2>&1; then
      branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false -c core.fsmonitor= branch --show-current 2>/dev/null || git -C "$cwd" -c core.useBuiltinFSMonitor=false -c core.fsmonitor= rev-parse --short HEAD 2>/dev/null)
      [ -n "$branch" ] && git_branch=" on $(printf "''${MAUVE}%s''${RESET}" "$branch")"
    fi
    prompt=""
    [ -n "$user" ] && prompt="''${user}@''${host} "
    prompt="''${prompt}$(printf "''${LAVENDER}%s''${RESET}" "$display_dir")''${git_branch} | ''${model}"
    printf "%s" "$prompt"
  '';

  # MCP server configurations with @PLACEHOLDER@ for secrets
  # These get written to ~/.claude.json with secrets substituted at activation
  mcpServersConfig = {
    # DeepWiki - GitHub repository documentation
    deepwiki = {
      type = "http";
      url = "https://mcp.deepwiki.com/mcp";
    };

    # Ref - Documentation search (requires API key)
    Ref = {
      type = "http";
      url = "https://api.ref.tools/mcp";
      headers = {
        "x-ref-api-key" = "@REF_API_KEY@";
      };
    };

    # Repomix - Codebase packaging for AI analysis
    repomix = {
      type = "stdio";
      command = "npx";
      args = [
        "-y"
        "repomix"
        "--mcp"
      ];
      env = { };
    };

    # PAL - Multi-model AI assistant
    pal = {
      type = "stdio";
      command = "uvx";
      args = [
        "--from"
        "git+https://github.com/BeehiveInnovations/pal-mcp-server.git"
        "pal-mcp-server"
      ];
      env = {
        OPENROUTER_API_KEY = "@OPENROUTER_API_KEY@";
        DISABLED_TOOLS = "tracer";
      };
    };

    # Go documentation server
    godoc = {
      type = "stdio";
      command = "godoc-mcp";
      args = [ ];
      env = { };
    };

    # Terraform MCP - Terraform Cloud/Enterprise integration
    terraform = {
      type = "stdio";
      command = "docker";
      args = [
        "run"
        "-i"
        "--rm"
        "-e"
        "TFE_TOKEN=@TFE_TOKEN@"
        "-e"
        "TFE_ADDRESS=https://app.terraform.io"
        "hashicorp/terraform-mcp-server"
      ];
      env = { };
    };

    # tmux MCP - Terminal automation for pane management
    # Uses uvx to run with fastmcp dependency automatically installed
    tmux = {
      type = "stdio";
      command = "uvx";
      args = [
        "--with"
        "fastmcp"
        "python"
        "${config.home.homeDirectory}/.config/tmux-mcp/server.py"
      ];
      env = { };
    };
  };

  # Placeholders to secret paths mapping for substitution
  secretSubstitutions = {
    "@REF_API_KEY@" = "${config.home.homeDirectory}/.claude/secrets/ref-api-key";
    "@OPENROUTER_API_KEY@" = "${config.home.homeDirectory}/.claude/secrets/openrouter-api-key";
    "@TFE_TOKEN@" = "${config.home.homeDirectory}/.claude/secrets/tfe-token";
  };

  # Template file for MCP servers (with placeholders)
  mcpConfigTemplate = builtins.toJSON { mcpServers = mcpServersConfig; };
in
{
  #############################################################################
  # Agenix Secrets
  #############################################################################

  age.secrets = {
    "claude-ref-api-key" = {
      file = "${private}/home/common/dev/resources/claude/ref-api-key.age";
      path = "${config.home.homeDirectory}/.claude/secrets/ref-api-key";
    };
    "claude-openrouter-api-key" = {
      file = "${private}/home/common/dev/resources/claude/openrouter-api-key.age";
      path = "${config.home.homeDirectory}/.claude/secrets/openrouter-api-key";
    };
    "claude-tfe-token" = {
      file = "${private}/home/common/dev/resources/claude/tfe-token.age";
      path = "${config.home.homeDirectory}/.claude/secrets/tfe-token";
    };
  };

  #############################################################################
  # Claude Code Configuration (uses home-manager built-in module)
  #############################################################################

  programs.claude-code = {
    enable = true;

    # Note: mcpServers are NOT set here because home-manager doesn't support
    # secret substitution. They're managed separately below via ~/.claude.json

    # Global CLAUDE.md content - applies to all projects
    memory.text = globalMemory;

    # Note: rules option is not available in this home-manager version
    # Rules are managed manually via ~/.claude/rules/ directory

    # Settings that go into ~/.claude/settings.json
    settings = {
      # Hooks - commands that run at various points in Claude Code's lifecycle
      hooks = {
        # Run before file modifications - TDD guard ensures tests exist
        PreToolUse = [
          {
            matcher = "Write|Edit|MultiEdit|TodoWrite";
            hooks = [
              {
                type = "command";
                command = "tdd-guard";
              }
            ];
          }
        ];

        # Run on every user prompt submission
        UserPromptSubmit = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "tdd-guard";
              }
            ];
          }
        ];

        # Run at session start/resume/clear
        SessionStart = [
          {
            matcher = "startup|resume|clear";
            hooks = [
              {
                type = "command";
                command = "tdd-guard";
              }
            ];
          }
        ];

        # Run when Claude stops working
        Stop = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/post-lint.sh";
              }
              {
                type = "command";
                command = "echo \"Make sure to update AGENTS.md and README.md\"";
              }
            ];
          }
        ];

        # Run after file modifications - security scanning for IaC files
        PostToolUse = [
          {
            matcher = "Edit(*.tf)|Write(*.tf)";
            hooks = [
              {
                type = "command";
                command = ".claude/hooks/trivy-tf.sh";
              }
            ];
          }
          {
            matcher = "Edit(*.hcl)|Write(*.hcl)";
            hooks = [
              {
                type = "command";
                command = ".claude/hooks/trivy-tf.sh";
              }
            ];
          }
        ];
      };

      # Custom status line command
      statusLine = {
        type = "command";
        command = "bash ${config.home.homeDirectory}/.claude/statusline-command.sh";
      };

      # Enabled plugins from various marketplaces
      enabledPlugins = {
        # Official plugins
        "gopls-lsp@claude-plugins-official" = true;
        "github@claude-plugins-official" = true;
        "playwright@claude-plugins-official" = true;
        "typescript-lsp@claude-plugins-official" = true;
        "pyright-lsp@claude-plugins-official" = true;
        "commit-commands@claude-plugins-official" = true;
        "security-guidance@claude-plugins-official" = true;
        "pr-review-toolkit@claude-plugins-official" = true;

        # Claude Code Workflows
        "backend-api-security@claude-code-workflows" = true;
        "backend-development@claude-code-workflows" = true;
        "dependency-management@claude-code-workflows" = true;
        "full-stack-orchestration@claude-code-workflows" = true;
        "python-development@claude-code-workflows" = true;
        "security-scanning@claude-code-workflows" = true;
        "cloud-infrastructure@claude-code-workflows" = true;
        "cicd-automation@claude-code-workflows" = true;

        # Third-party
        "fullstack-dev-skills@fullstack-dev-skills" = true;
        "superpowers@superpowers-marketplace" = true;
      };
    };
  };

  #############################################################################
  # MCP Server Configuration Template + Rules
  # Uses lib.mapAttrs' to generate home.file entries from rulesConfig
  #############################################################################

  home.file = {
    # MCP template with @PLACEHOLDER@ values - secrets substituted at activation
    ".claude/mcp-servers.json.template".text = mcpConfigTemplate;

    # Statusline script - executable bash script for custom status display
    ".claude/statusline-command.sh" = {
      text = statuslineScript;
      executable = true;
    };

    # tmux MCP server - terminal automation for Claude Code
    ".config/tmux-mcp/server.py" = {
      text = tmuxMcpServer;
      executable = true;
    };

    # tmux skill - teaches Claude Code how to use the tmux MCP tools
    ".claude/skills/automating-tmux-panes/SKILL.md".text = tmuxSkillFile;
  } // lib.mapAttrs' (name: content: {
    # Rules - Manual file creation (until home-manager rules option is available)
    name = ".claude/rules/${name}";
    value = { text = content; };
  }) rulesConfig;

  #############################################################################
  # Secret Substitution and MCP Config Activation
  #############################################################################

  home.activation.claudeCodeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${config.home.homeDirectory}/.claude/secrets

    # Remove existing mcp-servers.json if it exists (may be a symlink or locked file)
    run rm -f ${config.home.homeDirectory}/.claude/mcp-servers.json

    # Copy MCP template to working file
    run cp ${config.home.homeDirectory}/.claude/mcp-servers.json.template \
           ${config.home.homeDirectory}/.claude/mcp-servers.json

    # Substitute each @PLACEHOLDER@ with its decrypted secret value
    ${lib.concatMapStrings (
      ph:
      let
        secretPath = secretSubstitutions.${ph};
      in
      ''
        if [ -f "${secretPath}" ]; then
          run ${lib.getExe pkgs.gnused} -i "s|${ph}|$(cat ${secretPath})|g" \
              ${config.home.homeDirectory}/.claude/mcp-servers.json
        fi
      ''
    ) (lib.attrNames secretSubstitutions)}

    # Merge MCP servers into ~/.claude.json using jq
    # This preserves existing user settings while updating mcpServers
    if [ -f "${config.home.homeDirectory}/.claude.json" ]; then
      run ${lib.getExe pkgs.jq} -s '.[0] * .[1]' \
          ${config.home.homeDirectory}/.claude.json \
          ${config.home.homeDirectory}/.claude/mcp-servers.json \
          > ${config.home.homeDirectory}/.claude.json.tmp
      run mv ${config.home.homeDirectory}/.claude.json.tmp \
             ${config.home.homeDirectory}/.claude.json
    else
      run cp ${config.home.homeDirectory}/.claude/mcp-servers.json \
             ${config.home.homeDirectory}/.claude.json
    fi
  '';
}
